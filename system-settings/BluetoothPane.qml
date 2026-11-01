import QtQuick
import Quickshell.Bluetooth
import qs.shared

// Bluetooth: turn it on or off, your devices (connect, disconnect, forget) and nearby ones to pair.
// While the pane is open it's the pairing agent (BluetoothPairing, shared with the menu bar's
// panel), so codes to confirm and PINs to type show up here as sheets.
Column {
    id: pane

    property string pageTitle: ""

    spacing: 10

    BluetoothPairing {
        id: bt

        active: true
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Bluetooth")
            subtitle: bt.adapter ? (bt.adapter.enabled ? qsTr("Discoverable as “%1”").arg(bt.adapter.name) : qsTr("Off"))
                                   : qsTr("No Bluetooth adapter")
            glyph: Theme.iBluetooth
            tileColor: "#0a84ff"

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                enabled: bt.adapter !== null
                checked: bt.adapter?.enabled ?? false
                onToggled: on => {
                    bt.adapter.enabled = on;
                    if (on)
                        bt.adapter.discovering = true;
                }
            }
        }
    }

    GroupTitle {
        text: qsTr("My Devices")
        visible: bt.adapter?.enabled ?? false
    }

    SettingsGroup {
        visible: bt.adapter?.enabled ?? false

        SettingRow {
            visible: bt.myDevices.length === 0
            title: qsTr("No devices")
            titleColor: Theme.textSecondary
        }

        Repeater {
            model: bt.myDevices

            SettingRow {
                id: deviceRow

                required property var modelData

                title: modelData.name || modelData.deviceName || modelData.address
                subtitle: modelData.state === BluetoothDeviceState.Connecting ? qsTr("Connecting…")
                          : modelData.state === BluetoothDeviceState.Disconnecting ? qsTr("Disconnecting…")
                          : modelData.connected ? (modelData.batteryAvailable ? qsTr("Connected · Battery %1%").arg(Math.round(modelData.battery * 100))
                                                                                : qsTr("Connected"))
                          : qsTr("Not Connected")
                glyph: Theme.bluetoothGlyph(modelData.icon)
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
        visible: bt.adapter?.enabled ?? false

        Spinner {
            anchors.verticalCenter: parent.verticalCenter
            running: bt.adapter?.discovering ?? false
        }
    }

    SettingsGroup {
        visible: bt.adapter?.enabled ?? false

        SettingRow {
            visible: bt.nearby.length === 0
            title: bt.adapter?.discovering ? qsTr("Searching…") : qsTr("No devices found")
            titleColor: Theme.textSecondary
        }

        Repeater {
            model: bt.nearby

            SettingRow {
                id: nearbyRow

                required property var modelData

                title: modelData.name || modelData.deviceName
                subtitle: modelData.pairing || bt.busy === modelData.address ? qsTr("Pairing…") : modelData.address
                glyph: Theme.bluetoothGlyph(modelData.icon)
                tileColor: "#48484a"

                TextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    primary: true
                    text: nearbyRow.modelData.pairing ? qsTr("Cancel") : qsTr("Connect")
                    onClicked: {
                        if (nearbyRow.modelData.pairing) {
                            bt.cancelPair(nearbyRow.modelData);
                        } else {
                            bt.connectNew(nearbyRow.modelData);
                        }
                    }
                }
            }
        }
    }

    Caption {
        visible: bt.adapter?.enabled ?? false
        text: qsTr("Keep this pane open while pairing: codes to confirm and PINs to type show up here.")
    }

    // ---- Pairing requests ----

    Sheet {
        shown: bt.request !== null
        onDismissed: bt.answer(false)

        PairingPrompt {
            pairing: bt
        }
    }
}
