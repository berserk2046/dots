import QtQuick
import qs.shared

// Wi-Fi: the waybar Wi-Fi panel (switch, joined network and its details, known and other networks).
Column {
    id: pane

    property string pageTitle: ""

    spacing: 10

    Network {
        id: network

        active: true
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
                showEthernet: false
            }
        }
    }

    Caption {
        text: qsTr("Click a known network to join it; ⓘ or right-click forgets it. Networks are saved by wpa_supplicant.")
    }
}
