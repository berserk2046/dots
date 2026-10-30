import QtQuick
import qs.shared

// Battery: the waybar Battery panel (level, health, Energy Mode, Battery Conservation, busy apps).
Column {
    id: pane

    property string pageTitle: ""

    spacing: 10

    System {
        id: system

        active: true
    }

    SettingsGroup {
        Item {
            width: parent.width
            height: panel.implicitHeight + 16

            BatteryPanel {
                id: panel

                x: 8
                y: 8
                width: parent.width - 16
                sys: system
                shown: true
            }
        }
    }

    Caption {
        text: qsTr("Battery Conservation keeps the charge below the limit set by the firmware (on IdeaPads, about 80%), which slows battery wear when the laptop is mostly plugged in.")
    }
}
