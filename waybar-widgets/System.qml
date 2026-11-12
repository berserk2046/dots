import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, battery and busy processes from sys-status.sh; disks, energy mode and charge limit from
// sys-info.sh, less often. Polls only while `active`; otherwise it reads just /proc/stat for the CPU graph.
Scope {
    id: sys

    property bool active: false
    property int interval: 2000

    // Next to this file, so the System Settings app (which imports this folder) finds them too.
    function scriptPath(name) {
        return decodeURIComponent(Qt.resolvedUrl(name).toString().replace(/^file:\/\//, ""));
    }

    readonly property string statusScript: scriptPath("sys-status.sh")
    readonly property int historyLength: 60

    property bool loaded: false
    property string cpuModel: ""
    property real uptime: 0
    property var load: [0, 0, 0]
    property real temperature: -1 // the processor's, in °C; -1 without a sensor
    property real gpuTemperature: -1 // the graphics card's (the hottest, with several)

    // CPU usage 0..1 since the previous poll, split like Activity Monitor.
    property real cpuUser: 0
    property real cpuSystem: 0
    readonly property real cpuTotal: cpuUser + cpuSystem
    property var coreUsage: [] // per core, 0..1
    property var history: [] // [{user, system}], oldest first
    property var previousStat: null

    // Memory, in bytes.
    property real memTotal: 0
    property real memUsed: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memRatio: memTotal > 0 ? memUsed / memTotal : 0

    property var disks: [] // {device, size, used, avail, mount, fstype, model}
    property var battery: null
    // power-profiles-daemon
    property string profile: ""
    property var profiles: []
    property string profileError: ""
    // UPower charge limit, which IdeaPads implement as conservation mode.
    property string chargeDevice: ""
    property bool chargeLimitSupported: false
    property bool chargeLimitEnabled: false
    property string chargeError: ""
    property var processes: [] // grouped by app: {name, icon, cpu, mem}

    // Battery power draw is averaged over the last few polls so the time estimate doesn't jump.
    property var powerSamples: []

    // Disks, energy mode, charge limit and CPU model barely change, so they're read less often.
    property int infoInterval: 30000
    readonly property string infoScript: scriptPath("sys-info.sh")

    onActiveChanged: {
        if (active) {
            profileError = "";
            chargeError = "";
            // Process CPU use is the change between two runs: take a second one shortly after the
            // first, so the list fills in right away (the old samples are too old to compare with).
            previousProcs = null;
            refresh();
            refreshInfo();
            firstSample.restart();
        }
    }

    Timer {
        interval: sys.interval
        repeat: true
        running: sys.active
        onTriggered: sys.refresh()
    }

    Timer {
        id: firstSample

        interval: 500
        onTriggered: sys.refresh()
    }

    Timer {
        interval: Math.max(sys.interval, sys.infoInterval)
        repeat: true
        running: sys.active
        onTriggered: sys.refreshInfo()
    }

    // While closed, keep sampling just the CPU counters so the graph has history when opened, five
    // times less often than while open (each point is then the average since the last one). Read
    // directly, without starting a program.
    Timer {
        interval: sys.interval * 5
        repeat: true
        running: !sys.active
        onTriggered: statFile.reload()
    }

    FileView {
        id: statFile

        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            if (!sys.active)
                sys.applyStat(text().split("\n").filter(l => l.startsWith("cpu")));
        }
    }

    property bool busy: false
    property bool infoBusy: false

    Process {
        id: statusProc

        command: ["sh", sys.statusScript]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.busy = false;
                sys.apply(text);
            }
        }
    }

    Process {
        id: infoProc

        command: ["sh", sys.infoScript]
        stdout: StdioCollector {
            onStreamFinished: {
                sys.infoBusy = false;
                sys.applyInfo(text);
            }
        }
    }

    function refresh() {
        if (busy)
            return;
        busy = true;
        statusProc.running = true;
    }

    function refreshInfo() {
        if (infoBusy)
            return;
        infoBusy = true;
        infoProc.running = true;
    }

    Process {
        id: profileProc

        stderr: StdioCollector {
            id: profileErr
        }
        onExited: code => {
            if (code !== 0)
                sys.profileError = profileErr.text.trim().split("\n").pop() || qsTr("Couldn't change the energy mode");
            sys.refreshInfo();
        }
    }

    function setProfile(name) {
        profileError = "";
        profile = name;
        profileProc.command = ["powerprofilesctl", "set", name];
        profileProc.running = true;
    }

    // Allowed for the active session by UPower's polkit policy; UPower keeps it across reboots.
    Process {
        id: chargeProc

        stderr: StdioCollector {
            id: chargeErr
        }
        onExited: code => {
            if (code !== 0)
                sys.chargeError = chargeErr.text.trim().split("\n").pop() || qsTr("Couldn't change the charge limit");
            sys.refreshInfo();
        }
    }

    function setChargeLimit(on) {
        if (!chargeDevice)
            return;
        chargeError = "";
        chargeLimitEnabled = on;
        chargeProc.command = ["busctl", "--system", "call", "org.freedesktop.UPower", chargeDevice,
            "org.freedesktop.UPower.Device", "EnableChargeThreshold", "b", on ? "true" : "false"];
        chargeProc.running = true;
    }

    // Firefox and Steam run their work in helper processes; count those as the app.
    readonly property var processAliases: ({
            "Isolated Web Co": "firefox",
            "Web Content": "firefox",
            "WebExtensions": "firefox",
            "RDD Process": "firefox",
            "Socket Process": "firefox",
            "Utility Process": "firefox",
            "GPU Process": "firefox",
            "Privileged Cont": "firefox",
            "steamwebhelper": "steam",
            "chrome": "chromium",
            ".Discord-wrappe": "discord",
            "Discord": "discord"
        })

    // "@name arg" headers; the arg is kept as sections["name@"].
    function parseSections(text) {
        const sections = {};
        let current = null;
        for (const line of text.split("\n")) {
            if (line.startsWith("@")) {
                const parts = line.slice(1).trim().split(" ");
                current = parts[0];
                sections[current] = [];
                sections[current + "@"] = parts.slice(1).join(" ");
            } else if (current && line.trim() !== "") {
                sections[current].push(line);
            }
        }
        return sections;
    }

    // From sys-status.sh: CPU, memory, temperature, battery and processes.
    function apply(text) {
        const s = parseSections(text);
        if (!s.end)
            return;
        uptime = parseFloat((s.uptime ?? ["0"])[0]);
        load = ((s.load ?? [""])[0].split(" ").slice(0, 3)).map(Number);
        // "cpu 47250", "gpu 45000" (thousandths of a degree)
        const temps = kind => (s.temp ?? []).filter(l => l.startsWith(kind + " ")).map(l => parseInt(l.split(" ")[1]) / 1000).filter(t => t > 0);
        temperature = temps("cpu")[0] ?? -1;
        gpuTemperature = temps("gpu").length ? Math.max(...temps("gpu")) : -1;

        applyStat(s.stat ?? []);

        const mem = {};
        for (const line of s.mem ?? []) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                mem[m[1]] = parseInt(m[2]) * 1024;
        }
        memTotal = mem.MemTotal ?? 0;
        memUsed = memTotal - (mem.MemAvailable ?? 0);
        memCached = Math.max(0, (mem.Cached ?? 0) + (mem.Buffers ?? 0) + (mem.SReclaimable ?? 0) - (mem.Shmem ?? 0));
        swapTotal = mem.SwapTotal ?? 0;
        swapUsed = swapTotal - (mem.SwapFree ?? 0);

        applyBattery(s.battery ?? []);
        applyProcs(s.procs ?? [], s.stat ?? []);
        loaded = true;
    }

    // From sys-info.sh: CPU model, disks, energy mode and charge limit.
    property bool infoLoaded: false

    function applyInfo(text) {
        const s = parseSections(text);
        if (!s.end)
            return;
        cpuModel = (s.cpu ?? [""])[0].replace(/ with .*$/, "").replace(/\(\w+\)/g, "").trim();
        pageSize = parseInt((s.pagesize ?? [""])[0]) || 4096;

        disks = (s.disks ?? []).map(line => {
            const p = line.split(" ");
            return {
                device: p[0],
                size: parseFloat(p[1]),
                used: parseFloat(p[2]),
                avail: parseFloat(p[3]),
                mount: p[4],
                fstype: p[5],
                model: p.slice(6).join(" ")
            };
        });

        const json = (lines, i) => {
            try {
                return JSON.parse(lines?.[i] ?? "").data;
            } catch (e) {
                return undefined;
            }
        };
        profile = json(s.profiles, 0) ?? "";
        profiles = (json(s.profiles, 1) ?? []).map(p => p.Profile?.data).filter(p => p);
        chargeDevice = s["charge@"] ?? "";
        chargeLimitSupported = json(s.charge, 0) === true;
        chargeLimitEnabled = json(s.charge, 1) === true;
        infoLoaded = true;
    }

    // Each process's CPU time at the previous run ("pid starttime" -> clock ticks), and the CPU
    // counters' total then, to turn the change into a percentage of one core, as top does.
    property var previousProcs: null
    property real previousProcTotal: 0
    property int pageSize: 4096

    // `lines` are /proc/<pid>/stat lines, `statLines` the /proc/stat cpu lines read with them.
    function applyProcs(lines, statLines) {
        let total = 0;
        let cores = 0;
        for (const line of statLines) {
            const p = line.trim().split(/\s+/);
            if (p[0] === "cpu")
                total = p.slice(1, 9).reduce((a, b) => a + Number(b), 0);
            else
                cores++;
        }
        // Clock ticks that passed per core since the previous run
        const elapsed = previousProcs && cores > 0 ? (total - previousProcTotal) / cores : 0;
        const now = {};
        const byApp = {};
        for (const line of lines) {
            // "pid (comm) state ...": comm can hold spaces and parentheses, so split around the last ")".
            const open = line.indexOf("(");
            const close = line.lastIndexOf(")");
            if (open < 0 || close < open)
                continue;
            const f = line.slice(close + 2).split(" "); // f[0] is field 3 (state)
            const id = line.slice(0, open - 1) + " " + f[19]; // pid and start time, in case a pid is reused
            const ticks = Number(f[11]) + Number(f[12]); // utime + stime
            now[id] = ticks;
            const comm = line.slice(open + 1, close);
            const key = processAliases[comm] ?? comm;
            const entry = byApp[key] ?? {
                key: key,
                cpu: 0,
                mem: 0
            };
            const before = previousProcs?.[id];
            if (elapsed > 0 && before !== undefined)
                entry.cpu += Math.max(0, ticks - before) / elapsed * 100;
            entry.mem += (Number(f[21]) || 0) * pageSize; // rss, in pages
            byApp[key] = entry;
        }
        const first = previousProcs === null;
        previousProcs = now;
        previousProcTotal = total;
        // Nothing to compare with yet: keep the last list until the next run.
        if (first)
            return;
        processes = Object.values(byApp).filter(p => p.cpu > 0).sort((a, b) => b.cpu - a.cpu).slice(0, 12).map(p => {
            const entry = DesktopEntries.heuristicLookup(p.key);
            return Object.assign(p, {
                name: entry?.name || p.key,
                icon: entry?.icon || ""
            });
        });
    }

    function applyStat(lines) {
        const stat = {};
        for (const line of lines) {
            const p = line.trim().split(/\s+/);
            const v = p.slice(1).map(Number);
            stat[p[0]] = {
                user: v[0] + v[1],
                system: v[2] + v[5] + v[6] + (v[7] ?? 0),
                total: v.slice(0, 8).reduce((a, b) => a + b, 0)
            };
        }
        const prev = previousStat;
        previousStat = stat;
        if (!prev || !stat.cpu)
            return;
        const delta = (name, key) => (stat[name]?.[key] ?? 0) - (prev[name]?.[key] ?? 0);
        const total = delta("cpu", "total");
        if (total <= 0)
            return;
        cpuUser = delta("cpu", "user") / total;
        cpuSystem = delta("cpu", "system") / total;
        coreUsage = Object.keys(stat).filter(k => k !== "cpu").sort((a, b) => parseInt(a.slice(3)) - parseInt(b.slice(3)))
            .map(k => {
                const t = delta(k, "total");
                return t > 0 ? (delta(k, "user") + delta(k, "system")) / t : 0;
            });
        history = [...history, {
                user: cpuUser,
                system: cpuSystem
            }].slice(-historyLength);
    }

    function applyBattery(lines) {
        if (lines.length === 0) {
            battery = null;
            return;
        }
        const b = {};
        for (const line of lines) {
            const eq = line.indexOf("=");
            if (eq > 0)
                b[line.slice(0, eq)] = line.slice(eq + 1);
        }
        // Some batteries report charge (µAh) instead of energy (µWh); convert with the voltage.
        const volts = (parseFloat(b.voltage_now) || 0) / 1e6;
        const wh = (energy, charge) => energy !== undefined ? parseFloat(energy) / 1e6 : (parseFloat(charge) || 0) / 1e6 * volts;
        const now = wh(b.energy_now, b.charge_now);
        const full = wh(b.energy_full, b.charge_full);
        const design = wh(b.energy_full_design, b.charge_full_design);
        let watts = b.power_now !== undefined ? parseFloat(b.power_now) / 1e6 : (parseFloat(b.current_now) || 0) / 1e6 * volts;
        watts = Math.abs(watts);

        const status = b.status ?? "Unknown";
        powerSamples = watts > 0.1 && (status === "Charging" || status === "Discharging")
            ? [...powerSamples, watts].slice(-8) : [];
        const avg = powerSamples.length ? powerSamples.reduce((a, c) => a + c, 0) / powerSamples.length : 0;

        let remaining = -1; // hours
        if (avg > 0.1 && status === "Discharging")
            remaining = now / avg;
        else if (avg > 0.1 && status === "Charging")
            remaining = Math.max(0, full - now) / avg;

        battery = {
            status: status,
            level: parseInt(b.capacity ?? "0"),
            cycles: b.cycle_count !== undefined ? parseInt(b.cycle_count) : -1,
            now: now,
            full: full,
            design: design,
            health: design > 0 ? full / design : -1,
            watts: watts,
            volts: volts,
            remaining: remaining,
            acOnline: b.ac_online === "1",
            model: [b.manufacturer, b.model_name].filter(x => x).join(" "),
            technology: b.technology ?? ""
        };
    }

    // --- formatting helpers shared by the panels ---

    function bytes(value, digits) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let v = value;
        let i = 0;
        while (v >= 1000 && i < units.length - 1) {
            v /= 1000;
            i++;
        }
        return v.toFixed(i >= 3 ? (digits ?? 1) : 0) + " " + units[i];
    }

    // Memory is shown in binary units, as Activity Monitor does.
    function memory(value) {
        return (value / 1073741824).toFixed(1) + " GB";
    }

    function duration(hours) {
        if (!(hours >= 0) || !isFinite(hours))
            return "";
        const total = Math.round(hours * 60);
        const h = Math.floor(total / 60);
        const m = total % 60;
        return h > 0 ? qsTr("%1 h %2 min").arg(h).arg(m) : qsTr("%1 min").arg(m);
    }

    Component.onCompleted: {
        if (active) {
            refresh();
            refreshInfo();
            firstSample.restart();
        } else {
            statFile.reload();
        }
    }
}
