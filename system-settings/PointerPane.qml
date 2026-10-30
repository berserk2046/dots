import QtQuick
import qs.shared

// Trackpad & Mouse: tracking speed, scrolling direction, tap to click, typing, focus follows mouse.
Column {
    id: pane

    property string pageTitle: ""

    spacing: 10

    component SwitchRow: SettingRow {
        id: switchRow

        property string key
        property bool fallback: false

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: Store.get("pointer", switchRow.key, switchRow.fallback)
            onToggled: on => Store.set("pointer", switchRow.key, on)
        }
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Tracking speed")
            below: SettingSlider {
                width: parent.width
                from: -1
                to: 1
                step: 0.1
                ticks: 11
                minLabel: qsTr("Slow")
                maxLabel: qsTr("Fast")
                value: Store.get("pointer", "sensitivity", 0)
                onMoved: v => Store.set("pointer", "sensitivity", Math.round(v * 10) / 10)
            }
        }
    }

    GroupTitle {
        text: qsTr("Trackpad")
    }

    SettingsGroup {
        SwitchRow {
            title: qsTr("Natural scrolling")
            subtitle: qsTr("Content follows your fingers")
            key: "naturalScroll"
        }

        SwitchRow {
            title: qsTr("Tap to click")
            key: "tapToClick"
            fallback: true
        }

        SwitchRow {
            title: qsTr("Ignore the trackpad while typing")
            key: "disableWhileTyping"
            fallback: true
        }
    }

    GroupTitle {
        text: qsTr("Mouse")
    }

    SettingsGroup {
        SwitchRow {
            title: qsTr("Natural scrolling")
            key: "mouseNaturalScroll"
        }

        SwitchRow {
            title: qsTr("Focus follows mouse")
            subtitle: qsTr("Hovering a window focuses it, instead of clicking it")
            key: "focusFollowsMouse"
        }
    }
}
