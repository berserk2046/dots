import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi through wpa_supplicant (wpa_cli, no root: the control socket belongs to `wheel`)
// and wired interfaces through dhcpcd (net-admin.sh via `sudo -n`).
Scope {
    id: net

    // Wi-Fi interface; empty picks the first wireless one.
    property string wifiInterface: ""
    // Poll and scan only while a panel is showing.
    property bool active: false

    // Next to this file, so the System Settings app (which imports this folder) finds them too.
    function scriptPath(name) {
        return decodeURIComponent(Qt.resolvedUrl(name).toString().replace(/^file:\/\//, ""));
    }

    readonly property string statusScript: scriptPath("net-status.sh")
    readonly property string adminScript: scriptPath("net-admin.sh")

    property string wifi: ""
    property bool wpaReachable: false
    property bool wifiEnabled: true
    property bool wifiHardBlocked: false
    property var status: ({})
    property int rssi: 0
    property var known: [] // {id, ssid, flags}
    property var scanResults: [] // grouped by SSID: {ssid, signal, bars, secured, enterprise, sae, psk, freqs}
    property bool scanning: false
    property var ethernet: [] // {name, state, carrier, speed, mac, addr, gateway, manual}
    property var addresses: ({}) // iface -> [cidr]
    property var addresses6: ({})
    property var gateways: ({}) // iface -> router
    property var dns: []

    // In-flight join: {ssid, id, isNew, deadline}, and the last join error: {ssid, message}.
    property var joining: null
    property var joinError: null
    property string ethernetError: ""
    property string ethernetBusy: "" // interface currently being reconfigured

    readonly property bool connected: status.wpa_state === "COMPLETED"
    readonly property string currentSsid: connected ? decodeSsid(status.ssid ?? "") : ""
    readonly property int currentBars: barsFor(rssi)
    readonly property string wifiAddress: (addresses[wifi] ?? [])[0] ?? ""

    // Networks for the panel: the joined one, known ones in range, and the rest.
    readonly property var knownInRange: scanResults.filter(n => n.ssid !== currentSsid && knownIdFor(n.ssid) >= 0)
    readonly property var otherNetworks: scanResults.filter(n => n.ssid !== currentSsid && knownIdFor(n.ssid) < 0)
    readonly property var currentNetwork: scanResults.find(n => n.ssid === currentSsid) ?? null

    onWifiChanged: {
        if (active)
            scan();
    }

    onActiveChanged: {
        if (active) {
            joinError = null;
            ethernetError = "";
            refresh();
            scan();
        }
    }

    // --- process plumbing ---

    Component {
        id: commandComponent

        Process {
            id: proc

            property var callback: null
            property int code: -1
            property bool exitSeen: false
            property bool outputSeen: false

            function finish() {
                if (!exitSeen || !outputSeen)
                    return;
                if (callback)
                    callback(code, out.text, err.text);
                destroy();
            }

            stdout: StdioCollector {
                id: out

                onStreamFinished: {
                    proc.outputSeen = true;
                    proc.finish();
                }
            }
            stderr: StdioCollector {
                id: err
            }
            onExited: exitCode => {
                proc.code = exitCode;
                proc.exitSeen = true;
                proc.finish();
            }
        }
    }

    function run(command, callback) {
        const proc = commandComponent.createObject(net, {
            command: command,
            callback: callback ?? null
        });
        proc.running = true;
    }

    function wpa(args, callback) {
        run(["wpa_cli", "-i", wifi, ...args], callback);
    }

    function admin(args, callback) {
        run(["sudo", "-n", adminScript, ...args], callback);
    }

    // --- parsing ---

    // wpa_cli prints SSIDs with printf-style escapes (\xNN for bytes outside ASCII); undo that.
    function decodeSsid(text) {
        const bytes = [];
        const named = {
            "n": 10,
            "r": 13,
            "t": 9,
            "e": 27,
            "\\": 92,
            "\"": 34
        };
        for (let i = 0; i < text.length; i++) {
            const c = text[i];
            if (c === "\\" && i + 1 < text.length) {
                const next = text[i + 1];
                if (next === "x" && i + 3 < text.length + 1) {
                    bytes.push(parseInt(text.substr(i + 2, 2), 16));
                    i += 3;
                    continue;
                }
                if (next in named) {
                    bytes.push(named[next]);
                    i++;
                    continue;
                }
            }
            bytes.push(c.charCodeAt(0) & 0xff);
        }
        try {
            return decodeURIComponent(bytes.map(b => "%" + b.toString(16).padStart(2, "0")).join(""));
        } catch (e) {
            return String.fromCharCode(...bytes);
        }
    }

    // SSIDs are passed to wpa_cli as hex so any name works without quoting.
    function ssidHex(ssid) {
        const utf8 = unescape(encodeURIComponent(ssid));
        let hex = "";
        for (let i = 0; i < utf8.length; i++)
            hex += utf8.charCodeAt(i).toString(16).padStart(2, "0");
        return hex;
    }

    function barsFor(dbm) {
        if (dbm === 0)
            return 0;
        if (dbm >= -62)
            return 3;
        if (dbm >= -74)
            return 2;
        return 1;
    }

    function knownIdFor(ssid) {
        const entry = known.find(k => k.ssid === ssid);
        return entry ? entry.id : -1;
    }

    function parseSections(text) {
        const sections = {};
        let current = null;
        for (const line of text.split("\n")) {
            if (line.startsWith("@")) {
                const space = line.indexOf(" ");
                current = space < 0 ? line.slice(1) : line.slice(1, space);
                sections[current] = {
                    arg: space < 0 ? "" : line.slice(space + 1).trim(),
                    lines: []
                };
            } else if (current && line.trim() !== "") {
                sections[current].lines.push(line);
            }
        }
        return sections;
    }

    function keyValues(lines) {
        const result = {};
        for (const line of lines ?? []) {
            const eq = line.indexOf("=");
            if (eq > 0)
                result[line.slice(0, eq)] = line.slice(eq + 1);
        }
        return result;
    }

    function applyStatus(text) {
        const s = parseSections(text);
        wifi = s.wifi?.arg ?? "";
        const st = keyValues(s.status?.lines);
        wpaReachable = "wpa_state" in st;
        status = st;
        rssi = parseInt(keyValues(s.signal?.lines).RSSI ?? "0") || 0;

        known = (s.networks?.lines ?? []).map(line => {
            const parts = line.split("\t");
            return {
                id: parseInt(parts[0]),
                ssid: decodeSsid(parts[1] ?? ""),
                flags: parts[3] ?? ""
            };
        });

        let enabled = true;
        let hard = false;
        for (const line of s.rfkill?.lines ?? []) {
            const [type, soft, hardBlock] = line.split(" ");
            if (type !== "wlan")
                continue;
            if (soft === "1")
                enabled = false;
            if (hardBlock === "1")
                hard = true;
        }
        wifiEnabled = enabled && !hard;
        wifiHardBlocked = hard;

        const addrs = {};
        for (const line of s.addr?.lines ?? []) {
            const [iface, cidr] = line.split(" ");
            (addrs[iface] = addrs[iface] ?? []).push(cidr);
        }
        addresses = addrs;
        const addrs6 = {};
        for (const line of s.addr6?.lines ?? []) {
            const [iface, cidr] = line.split(" ");
            (addrs6[iface] = addrs6[iface] ?? []).push(cidr);
        }
        addresses6 = addrs6;

        const gws = {};
        for (const line of s.routes?.lines ?? []) {
            const m = line.match(/via (\S+) dev (\S+)/);
            if (m && !(m[2] in gws))
                gws[m[2]] = m[1];
        }
        gateways = gws;
        dns = s.dns?.lines ?? [];

        // Manual IPv4 blocks from dhcpcd.conf, keyed by interface.
        const manual = {};
        let block = null;
        for (const line of s.static?.lines ?? []) {
            const begin = line.match(/^# >>> waybar-widgets (\S+)/);
            if (begin) {
                block = manual[begin[1]] = {
                    address: "",
                    router: "",
                    dns: ""
                };
                continue;
            }
            if (!block)
                continue;
            const m = line.match(/^static (\w+)=(.*)$/);
            if (!m)
                continue;
            if (m[1] === "ip_address")
                block.address = m[2];
            else if (m[1] === "routers")
                block.router = m[2];
            else if (m[1] === "domain_name_servers")
                block.dns = m[2];
        }

        ethernet = (s.ethernet?.lines ?? []).map(line => {
            const [name, state, carrier, speed, mac] = line.split(" ");
            return {
                name: name,
                state: state,
                up: state !== "down",
                carrier: carrier === "1",
                speed: parseInt(speed),
                mac: mac,
                addr: (addrs[name] ?? [])[0] ?? "",
                gateway: gws[name] ?? "",
                manual: manual[name] ?? null
            };
        });

        checkJoin();
    }

    function applyScan(text) {
        const bySsid = {};
        for (const line of text.split("\n").slice(1)) {
            const parts = line.split("\t");
            if (parts.length < 5)
                continue;
            const ssid = decodeSsid(parts.slice(4).join("\t"));
            if (ssid === "" || /^\x00+$/.test(ssid))
                continue;
            const signal = parseInt(parts[2]);
            const flags = parts[3];
            const entry = bySsid[ssid] ?? {
                ssid: ssid,
                signal: -999,
                freqs: [],
                flags: ""
            };
            if (signal > entry.signal) {
                entry.signal = signal;
                entry.flags = flags;
            }
            entry.freqs.push(parseInt(parts[1]));
            bySsid[ssid] = entry;
        }
        scanResults = Object.values(bySsid).map(n => Object.assign(n, {
            bars: barsFor(n.signal),
            secured: /WPA|WEP|RSN|SAE/.test(n.flags),
            enterprise: /EAP/.test(n.flags),
            sae: /SAE/.test(n.flags),
            psk: /PSK/.test(n.flags)
        })).sort((a, b) => b.signal - a.signal);
    }

    // --- refresh & scan ---

    property bool refreshing: false

    function refresh() {
        if (refreshing)
            return;
        refreshing = true;
        run(["sh", statusScript, wifiInterface], (code, out) => {
            refreshing = false;
            applyStatus(out);
        });
    }

    function scan() {
        // Before the first status refresh the interface isn't known; onWifiChanged scans then.
        if (!wifi || !wifiEnabled)
            return;
        scanning = true;
        wpa(["scan"], () => {
            fetchScanResults();
            scanPoll.count = 0;
            scanPoll.restart();
        });
    }

    function fetchScanResults() {
        wpa(["scan_results"], (code, out) => applyScan(out));
    }

    Timer {
        id: scanPoll

        property int count: 0

        interval: 2000
        repeat: true
        onTriggered: {
            net.fetchScanResults();
            if (++count >= 3) {
                stop();
                net.scanning = false;
            }
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: net.active
        onTriggered: net.refresh()
    }

    Timer {
        interval: 20000
        repeat: true
        running: net.active && net.wifiEnabled
        onTriggered: net.scan()
    }

    // --- Wi-Fi actions ---

    function setWifiEnabled(on) {
        wifiEnabled = on;
        const verb = on ? "unblock" : "block";
        run(["rfkill", verb, "wlan"], code => {
            if (code !== 0)
                admin(["radio", on ? "on" : "off"], () => refresh());
            else
                refresh();
            if (on)
                scanAfterRadio.restart();
            else
                scanResults = [];
        });
    }

    Timer {
        id: scanAfterRadio

        interval: 2500
        onTriggered: net.scan()
    }

    // Join a network from the list. `password` is only used for networks not saved yet.
    function join(network, password, hidden) {
        joinError = null;
        const id = knownIdFor(network.ssid);
        if (id >= 0) {
            joining = {
                ssid: network.ssid,
                id: id,
                isNew: false,
                deadline: Date.now() + 20000
            };
            wpa(["select_network", String(id)], () => refresh());
            return;
        }
        const script = `
            set -e
            id=$(wpa_cli -i "$1" add_network | tail -n 1)
            case $id in *[!0-9]*|'') echo "add_network failed" >&2; exit 1 ;; esac
            set_net() { out=$(wpa_cli -i "$IF" set_network "$id" "$@"); [ "$out" = OK ] || { wpa_cli -i "$IF" remove_network "$id" >/dev/null; echo "Invalid $1" >&2; exit 1; }; }
            IF=$1
            set_net ssid "$2"
            case $3 in
                open) set_net key_mgmt NONE ;;
                sae) set_net key_mgmt SAE; set_net ieee80211w 2; set_net sae_password "\\"$4\\"" ;;
                *) set_net psk "\\"$4\\"" ;;
            esac
            [ "$5" = hidden ] && set_net scan_ssid 1
            wpa_cli -i "$IF" select_network "$id" >/dev/null
            echo "$id"
        `;
        const kind = !network.secured ? "open" : network.sae && !network.psk ? "sae" : "psk";
        joining = {
            ssid: network.ssid,
            id: -1,
            isNew: true,
            deadline: Date.now() + 25000
        };
        run(["sh", "-c", script, "sh", wifi, ssidHex(network.ssid), kind, password ?? "", hidden ? "hidden" : ""],
            (code, out, err) => {
            if (code !== 0) {
                joining = null;
                joinError = {
                    ssid: network.ssid,
                    message: kind === "open" ? qsTr("Couldn't join this network") : qsTr("Password must be 8 to 63 characters")
                };
                return;
            }
            const id = parseInt(out.trim().split("\n").pop());
            if (joining && joining.ssid === network.ssid)
                joining = Object.assign({}, joining, {
                    id: id
                });
            refresh();
        });
    }

    // Called after each status refresh while a join is in flight.
    function checkJoin() {
        if (!joining || joining.id < 0)
            return;
        const entry = known.find(k => k.id === joining.id);
        if (connected && parseInt(status.id) === joining.id) {
            // select_network disabled every other network; re-enable them so they still auto-join.
            wpa(["enable_network", "all"], () => wpa(["save_config"]));
            joining = null;
            return;
        }
        const failed = entry && entry.flags.indexOf("TEMP-DISABLED") >= 0;
        if (!failed && Date.now() < joining.deadline)
            return;
        const attempt = joining;
        joining = null;
        joinError = {
            ssid: attempt.ssid,
            message: attempt.isNew && failed ? qsTr("Incorrect password") : qsTr("Couldn't join this network")
        };
        const cleanup = attempt.isNew ? [["remove_network", String(attempt.id)]] : [];
        const next = () => {
            const step = cleanup.shift();
            if (step)
                wpa(step, next);
            else
                wpa(["enable_network", "all"], () => refresh());
        };
        next();
    }

    Timer {
        interval: 1000
        repeat: true
        running: net.joining !== null
        onTriggered: net.refresh()
    }

    function disconnect() {
        wpa(["disconnect"], () => refresh());
    }

    function forget(ssid) {
        const id = knownIdFor(ssid);
        if (id < 0)
            return;
        // Re-enable the rest before saving, so no select_network leftovers get saved as disabled=1.
        wpa(["remove_network", String(id)], () => wpa(["enable_network", "all"], () => {
            wpa(["save_config"], () => wpa(["reassociate"], () => refresh()));
        }));
    }

    // --- Ethernet actions ---

    function ethernetAction(args) {
        ethernetError = "";
        ethernetBusy = args[1];
        admin(args, (code, out, err) => {
            ethernetBusy = "";
            if (code !== 0)
                ethernetError = err.trim().split("\n").pop() || qsTr("Failed (sudo needs a password?)");
            refresh();
        });
    }

    function setLink(iface, up) {
        ethernetAction([up ? "up" : "down", iface]);
    }

    function renew(iface) {
        ethernetAction(["renew", iface]);
    }

    function useDhcp(iface) {
        ethernetAction(["dhcp", iface]);
    }

    function useManual(iface, address, router, dnsServers) {
        const servers = dnsServers.split(/[\s,]+/).filter(s => s !== "");
        ethernetAction(["static", iface, address.trim(), router.trim(), ...servers]);
    }

    Component.onCompleted: refresh()
}
