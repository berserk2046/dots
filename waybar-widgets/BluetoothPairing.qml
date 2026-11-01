import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Bluetooth devices and pairing new ones, shared by the menu bar's Bluetooth panel and System
// Settings → Bluetooth. While `active`, it looks for nearby devices and runs bt-agent.py as the
// pairing agent, so codes to confirm and PINs to type arrive as `request` (see PairingPrompt).
Scope {
    id: pairing

    property bool active: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var myDevices: devices.filter(d => d.paired || d.bonded)
    // Devices without a name (shown by BlueZ as their address) are left out, as on macOS.
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name || d.deviceName || d.address))
    property string busy: "" // address of the device being paired/connected
    property var request: null // pairing request from bt-agent.py waiting for an answer

    function scriptPath(name) {
        return decodeURIComponent(Qt.resolvedUrl(name).toString().replace(/^file:\/\//, ""));
    }

    // Look for nearby devices while active. BlueZ can stop discovery on its own (or the adapter may
    // show up late), so it's asked again every few seconds.
    Timer {
        interval: 4000
        repeat: true
        running: pairing.active && (pairing.adapter?.enabled ?? false)
        triggeredOnStart: true
        onTriggered: {
            if (!pairing.adapter.discovering)
                pairing.adapter.discovering = true;
        }
    }

    onActiveChanged: {
        if (!active) {
            if (adapter)
                adapter.discovering = false;
            request = null;
            busy = "";
        }
    }

    Component.onDestruction: {
        if (active && adapter)
            adapter.discovering = false;
    }

    Process {
        id: agent

        command: ["python3", "-I", pairing.scriptPath("bt-agent.py")]
        running: pairing.active && pairing.adapter !== null
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (error) {
                    return;
                }
                if (message.type === "cancel") {
                    pairing.request = null;
                    pairing.busy = "";
                } else if (message.type !== "ready") {
                    pairing.request = message;
                }
            }
        }
    }

    function answer(ok, value) {
        if (request && request.id > 0)
            agent.write(JSON.stringify({
                id: request.id,
                ok: ok,
                value: value ?? ""
            }) + "\n");
        if (!ok) {
            devices.find(d => d.address === busy)?.cancelPair();
            busy = "";
        }
        request = null;
    }

    function connectNew(device) {
        busy = device.address;
        device.trusted = true;
        device.pair();
    }

    function cancelPair(device) {
        device.cancelPair();
        busy = "";
    }

    // A freshly paired device gets connected right away.
    Connections {
        target: pairing.devices.find(d => d.address === pairing.busy) ?? null

        function onPairedChanged() {
            const device = pairing.devices.find(d => d.address === pairing.busy);
            if (device?.paired) {
                device.connect();
                pairing.busy = "";
            }
        }
    }
}
