import QtQuick
import qs.shared

// Network: Ethernet adapters (link, speed, addresses, DHCP or manual IPv4, Renew Lease), plus a
// summary of the Wi-Fi connection that opens the Wi-Fi pane.
Column {
    id: pane

    property string pageTitle: ""

    spacing: 10

    Network {
        id: network

        active: true
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Wi-Fi")
            subtitle: !network.wifiEnabled ? qsTr("Off") : network.connected ? qsTr("Connected to %1").arg(network.currentSsid)
                                                                                : qsTr("Not Connected")
            glyph: Theme.iWifi
            tileColor: "#0a84ff"
            chevron: true
            onClicked: Ui.open("wifi")

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: network.connected ? Theme.success : network.wifiEnabled ? "#ff9f0a" : Theme.textTertiary
            }
        }
    }

    SettingsGroup {
        Item {
            width: parent.width
            height: panel.implicitHeight + 16

            WifiPanel {
                id: panel

                x: 8
                y: 8
                width: parent.width - 16
                net: network
                shown: true
                showWifi: false
            }
        }
    }

    Caption {
        text: qsTr("Click an adapter for its details and to switch between DHCP and a manual address. Changes go through net-admin.sh and dhcpcd.")
    }
}
