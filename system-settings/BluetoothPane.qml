import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs.shared

// Bluetooth: turn it on or off, your devices (connect, disconnect, forget) and nearby ones to pair.
// While the pane is open, bt-agent.py is the pairing agent, so codes to confirm and PINs to type
// show up here as sheets.
Column {
    id: pane

    property string pageTitle: ""
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var myDevices: devices.filter(d => d.paired || d.bonded)
    // Devices without a name (shown by BlueZ as their address) are left out, as on macOS.
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name || d.deviceName || d.address))
    property string busy: "" // address of the device being paired/connected
    property var request: null // pairing request from bt-agent.py waiting for an answer

    spacing: 10

    // Look for nearby devices while this pane is open. BlueZ can stop discovery on its own (or the
    // adapter may show up late), so it's asked again every few seconds.
    Timer {
        interval: 4000
        repeat: true
        running: pane.adapter?.enabled ?? false
        triggeredOnStart: true
        onTriggered: {
            if (!pane.adapter.discovering)
                pane.adapter.discovering = true;
        }
    }

    Component.onDestruction: {
        if (adapter)
            adapter.discovering = false;
    }

    Process {
        id: agent

        command: ["python3", "-I", Store.script("bt-agent.py")]
        running: pane.adapter !== null
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
                    pane.request = null;
                    pane.busy = "";
                } else if (message.type !== "ready") {
                    pane.request = message;
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
            pane.devices.find(d => d.address === pane.busy)?.cancelPair();
            busy = "";
        }
        request = null;
    }

    function iconFor(device) {
        const icon = device.icon ?? "";
        if (icon.includes("headset") || icon.includes("headphone"))
            return Theme.iHeadphones;
        if (icon.includes("audio") || icon.includes("speaker"))
            return Theme.iSpeaker;
        if (icon.includes("keyboard"))
            return Theme.iKeyboard;
        if (icon.includes("mouse"))
            return Theme.iMouse;
        if (icon.includes("phone"))
            return String.fromCodePoint(0xF011C);
        if (icon.includes("computer"))
            return Theme.iDesktop;
        return Theme.iBluetooth;
    }

    function connectNew(device) {
        busy = device.address;
        device.trusted = true;
        device.pair();
    }

    // A freshly paired device gets connected right away.
    Connections {
        target: pane.devices.find(d => d.address === pane.busy) ?? null

        function onPairedChanged() {
            const device = pane.devices.find(d => d.address === pane.busy);
            if (device?.paired) {
                device.connect();
                pane.busy = "";
            }
        }
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Bluetooth")
            subtitle: pane.adapter ? (pane.adapter.enabled ? qsTr("Discoverable as “%1”").arg(pane.adapter.name) : qsTr("Off"))
                                   : qsTr("No Bluetooth adapter")
            glyph: Theme.iBluetooth
            tileColor: "#0a84ff"

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                enabled: pane.adapter !== null
                checked: pane.adapter?.enabled ?? false
                onToggled: on => {
                    pane.adapter.enabled = on;
                    if (on)
                        pane.adapter.discovering = true;
                }
            }
        }
    }

    GroupTitle {
        text: qsTr("My Devices")
        visible: pane.adapter?.enabled ?? false
    }

    SettingsGroup {
        visible: pane.adapter?.enabled ?? false

        SettingRow {
            visible: pane.myDevices.length === 0
            title: qsTr("No devices")
            titleColor: Theme.textSecondary
        }

        Repeater {
            model: pane.myDevices

            SettingRow {
                id: deviceRow

                required property var modelData

                title: modelData.name || modelData.deviceName || modelData.address
                subtitle: modelData.state === BluetoothDeviceState.Connecting ? qsTr("Connecting…")
                          : modelData.state === BluetoothDeviceState.Disconnecting ? qsTr("Disconnecting…")
                          : modelData.connected ? (modelData.batteryAvailable ? qsTr("Connected · Battery %1%").arg(Math.round(modelData.battery * 100))
                                                                                : qsTr("Connected"))
                          : qsTr("Not Connected")
                glyph: pane.iconFor(modelData)
                tileColor: modelData.connected ? "#0a84ff" : "#48484a"

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: deviceRow.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
                    onClicked: deviceRow.modelData.connected ? deviceRow.modelData.disconnect() : deviceRow.modelData.connect()
                }

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Forget")
                    destructive: true
                    onClicked: deviceRow.modelData.forget()
                }
            }
        }
    }

    GroupTitle {
        text: qsTr("Nearby Devices")
        visible: pane.adapter?.enabled ?? false

        Spinner {
            anchors.verticalCenter: parent.verticalCenter
            running: pane.adapter?.discovering ?? false
        }
    }

    SettingsGroup {
        visible: pane.adapter?.enabled ?? false

        SettingRow {
            visible: pane.nearby.length === 0
            title: pane.adapter?.discovering ? qsTr("Searching…") : qsTr("No devices found")
            titleColor: Theme.textSecondary
        }

        Repeater {
            model: pane.nearby

            SettingRow {
                id: nearbyRow

                required property var modelData

                title: modelData.name || modelData.deviceName
                subtitle: modelData.pairing || pane.busy === modelData.address ? qsTr("Pairing…") : modelData.address
                glyph: pane.iconFor(modelData)
                tileColor: "#48484a"

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    primary: true
                    text: nearbyRow.modelData.pairing ? qsTr("Cancel") : qsTr("Connect")
                    onClicked: {
                        if (nearbyRow.modelData.pairing) {
                            nearbyRow.modelData.cancelPair();
                            pane.busy = "";
                        } else {
                            pane.connectNew(nearbyRow.modelData);
                        }
                    }
                }
            }
        }
    }

    Caption {
        visible: pane.adapter?.enabled ?? false
        text: qsTr("Keep this pane open while pairing: codes to confirm and PINs to type show up here.")
    }

    // ---- Pairing requests ----

    Sheet {
        shown: pane.request !== null
        onDismissed: pane.answer(false)

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: {
                const r = pane.request;
                if (!r)
                    return "";
                switch (r.type) {
                case "confirm":
                    return qsTr("Pair with “%1”?").arg(r.device);
                case "pin":
                case "passkey":
                    return qsTr("Enter the PIN for “%1”").arg(r.device);
                case "authorize":
                    return qsTr("Allow “%1” to connect?").arg(r.device);
                default:
                    return qsTr("Type this code on “%1”").arg(r.device);
                }
            }
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: text !== ""
            text: {
                const r = pane.request;
                if (r?.type === "confirm")
                    return qsTr("Make sure this code matches the one on the device:");
                if (r?.type === "displayPasskey" || r?.type === "displayPin")
                    return qsTr("Then press Return on it.");
                if (r?.type === "pin" || r?.type === "passkey")
                    return qsTr("Often 0000 or 1234, or the code shown on the device.");
                return "";
            }
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: 12
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pane.request?.passkey !== undefined
            text: (pane.request?.passkey ?? "").replace(/(\d{3})(\d{3})/, "$1 $2")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 34
            font.weight: Font.DemiBold
            font.letterSpacing: 4
        }

        Field {
            id: pinField

            width: parent.width
            visible: pane.request?.type === "pin" || pane.request?.type === "passkey"
            placeholder: qsTr("PIN")
            onVisibleChanged: {
                text = "";
                if (visible)
                    input.forceActiveFocus();
            }
            onAccepted: pane.answer(true, text)
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            TextButton {
                text: qsTr("Cancel")
                onClicked: pane.answer(false)
            }

            TextButton {
                primary: true
                visible: pane.request?.type !== "displayPasskey" && pane.request?.type !== "displayPin"
                text: pane.request?.type === "authorize" ? qsTr("Allow") : pane.request?.type === "confirm" ? qsTr("Pair") : qsTr("Connect")
                enabled: !pinField.visible || pinField.text.trim() !== ""
                onClicked: pane.answer(true, pinField.text.trim())
            }
        }
    }
}
