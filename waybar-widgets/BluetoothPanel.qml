import QtQuick
import Quickshell.Bluetooth

// Bluetooth menu, like macOS's: on/off, your devices (click one to connect or disconnect it, with its
// battery when the device reports one), nearby devices to pair (as in System Settings → Bluetooth;
// codes to confirm and PINs to type show up inline) and a link to the full pane.
Column {
    id: panel

    property bool shown: false
    signal closeRequested

    readonly property var adapter: bt.adapter
    readonly property var devices: bt.myDevices

    width: parent?.width ?? 0
    spacing: 2

    // Pairing agent and discovery while the panel is open
    BluetoothPairing {
        id: bt

        active: panel.shown
    }

    function busy(device) {
        return device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting;
    }

    Item {
        width: parent.width
        height: 34

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Bluetooth")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(14)
            font.weight: Font.Bold
        }

        Toggle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: panel.adapter !== null
            checked: panel.adapter?.enabled ?? false
            onToggled: on => panel.adapter.enabled = on
        }
    }

    Text {
        x: 8
        height: 28
        visible: panel.adapter === null
        verticalAlignment: Text.AlignVCenter
        text: qsTr("No Bluetooth adapter")
        color: Theme.textTertiary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    // A pairing request: a code to compare or a PIN to type
    Rectangle {
        width: parent.width
        height: prompt.implicitHeight + 24
        visible: bt.request !== null
        radius: 10
        color: Theme.field

        PairingPrompt {
            id: prompt

            x: 12
            y: 12
            width: parent.width - 24
            pairing: bt
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: panel.adapter?.enabled ?? false

        Separator {}

        SectionLabel {
            text: qsTr("Devices")
        }

        Repeater {
            model: panel.devices

            ListRow {
                id: deviceRow

                required property var modelData

                title: modelData.name || modelData.deviceName || modelData.address
                subtitle: modelData.state === BluetoothDeviceState.Connecting ? qsTr("Connecting…")
                          : modelData.state === BluetoothDeviceState.Disconnecting ? qsTr("Disconnecting…")
                          : modelData.connected ? qsTr("Connected") : ""
                icon: IconCircle {
                    active: deviceRow.modelData.connected
                    glyph: Theme.bluetoothGlyph(deviceRow.modelData.icon)
                }
                trailing: [
                    Spinner {
                        anchors.verticalCenter: parent.verticalCenter
                        running: panel.busy(deviceRow.modelData)
                    },
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: deviceRow.modelData.connected && deviceRow.modelData.batteryAvailable
                        text: Math.round(deviceRow.modelData.battery * 100) + "%"
                        color: Theme.textSecondary
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize(11)
                    }
                ]
                onClicked: {
                    if (panel.busy(modelData))
                        return;
                    modelData.connected ? modelData.disconnect() : modelData.connect();
                }
            }
        }

        Text {
            x: 8
            height: 26
            visible: panel.devices.length === 0
            verticalAlignment: Text.AlignVCenter
            text: qsTr("No devices")
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
        }

        Item {
            width: 1
            height: 4
        }

        SectionLabel {
            text: qsTr("Nearby Devices")

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: panel.adapter?.discovering ?? false
            }
        }

        // The first few, so the card stays on screen; System Settings lists them all.
        Repeater {
            model: bt.nearby.slice(0, 6)

            ListRow {
                id: nearbyRow

                required property var modelData
                readonly property bool pairing: modelData.pairing || bt.busy === modelData.address

                title: modelData.name || modelData.deviceName
                subtitle: pairing ? qsTr("Pairing…") : ""
                icon: IconCircle {
                    glyph: Theme.bluetoothGlyph(nearbyRow.modelData.icon)
                    opacity: 0.7
                }
                trailing: Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    running: nearbyRow.pairing
                }
                // Click to pair and connect; click again to cancel
                onClicked: pairing ? bt.cancelPair(modelData) : bt.connectNew(modelData)
            }
        }

        Text {
            x: 8
            height: 26
            visible: bt.nearby.length === 0
            verticalAlignment: Text.AlignVCenter
            text: panel.adapter?.discovering ? qsTr("Searching…") : qsTr("No devices found")
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
        }
    }

    Separator {}

    SettingsLink {
        text: qsTr("Bluetooth Settings…")
        pane: "bluetooth"
        onOpened: panel.closeRequested()
    }
}
