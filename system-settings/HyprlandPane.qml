import QtQuick
import qs.shared

// Hyprland: window borders, corners, gaps, shadows and dimming; focus; animations and blur; the
// pointer; tiling layout, adaptive sync and other compositor options. Saved under "hyprland" (and
// "windows" for borders, corners and gaps) and written to hypr/system-settings.lua, which hyprland.lua
// reads; Store reloads Hyprland's config after each change.
Column {
    id: pane

    property string pageTitle: ""

    spacing: 10

    function value(key, fallback) {
        return Store.get("hyprland", key, fallback);
    }

    function setValue(key, value) {
        Store.set("hyprland", key, value);
    }

    // Focus mode, from this pane or the older on/off in Trackpad & Mouse
    readonly property int followMouse: value("followMouse", Store.get("pointer", "focusFollowsMouse", false) ? 1 : 0)

    component SwitchRow: SettingRow {
        id: switchRow

        property string key
        property bool fallback: false

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: pane.value(switchRow.key, switchRow.fallback)
            onToggled: on => pane.setValue(switchRow.key, on)
        }
    }

    // ---- Windows ----

    GroupTitle {
        text: qsTr("Windows")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Border width")
            subtitle: qsTr("0 turns window borders off")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                options: ["0", "1", "2", "3"]
                current: Store.get("windows", "borderSize", 1)
                onPicked: index => Store.set("windows", "borderSize", index)
            }
        }

        SettingRow {
            title: qsTr("Window corners")
            below: SettingSlider {
                width: parent.width
                from: 0
                to: 20
                step: 1
                minLabel: qsTr("Square")
                maxLabel: qsTr("Round")
                value: Store.get("windows", "rounding", 10)
                onMoved: v => Store.set("windows", "rounding", v)
            }
        }

        SettingRow {
            title: qsTr("Gaps around tiled windows")
            below: SettingSlider {
                width: parent.width
                from: 0
                to: 24
                step: 1
                minLabel: qsTr("None")
                maxLabel: "24 px"
                value: Store.get("windows", "gapsOut", 0)
                onMoved: v => Store.setMany("windows", {
                        gapsOut: v,
                        gapsIn: Math.round(v / 2)
                    })
            }
        }

        SwitchRow {
            title: qsTr("Shadows")
            key: "shadows"
            fallback: true
        }

        SettingRow {
            id: dimRow

            readonly property bool on: pane.value("dimInactive", false)

            title: qsTr("Dim windows that aren't focused")
            below: SettingSlider {
                width: parent.width
                visible: dimRow.on
                from: 0.05
                to: 0.6
                step: 0.05
                minLabel: qsTr("Slightly")
                maxLabel: qsTr("Strongly")
                value: pane.value("dimStrength", 0.2)
                onMoved: v => pane.setValue("dimStrength", Math.round(v * 100) / 100)
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: dimRow.on
                onToggled: on => pane.setValue("dimInactive", on)
            }
        }

        SettingRow {
            title: qsTr("Opacity of windows that aren't focused")
            below: SettingSlider {
                width: parent.width
                from: 0.6
                to: 1
                step: 0.05
                minLabel: qsTr("See-through")
                maxLabel: qsTr("Opaque")
                value: pane.value("inactiveOpacity", 1)
                onMoved: v => pane.setValue("inactiveOpacity", Math.round(v * 100) / 100)
            }
        }
    }

    Caption {
        text: qsTr("Floating windows and title bars are in Desktop & Dock.")
    }

    // ---- Focus ----

    GroupTitle {
        text: qsTr("Focus")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Focus a window by")
            subtitle: [qsTr("Clicking it"), qsTr("Moving the pointer onto it"),
                qsTr("Pointing at it; typing goes to the one clicked last")][pane.followMouse] ?? ""

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 330
                options: [qsTr("Click"), qsTr("Hover"), qsTr("Hover, keys on click")]
                current: pane.followMouse
                onPicked: index => pane.setValue("followMouse", index)
            }
        }

        SwitchRow {
            title: qsTr("Bring windows forward when they ask")
            subtitle: qsTr("For example the browser, when another app opens a link")
            key: "focusOnActivate"
        }

        SwitchRow {
            title: qsTr("Move the pointer to the window that gets focus")
            subtitle: qsTr("When focus moves with the keyboard")
            key: "warpPointer"
        }
    }

    // ---- Effects ----

    GroupTitle {
        text: qsTr("Effects")
    }

    SettingsGroup {
        SwitchRow {
            title: qsTr("Animations")
            subtitle: qsTr("Windows, workspaces and panels; off is lighter on the graphics chip")
            key: "animations"
            fallback: true
        }

        SettingRow {
            id: blurRow

            readonly property bool on: pane.value("blur", true)
            readonly property var levels: ["light", "medium", "strong"]

            title: qsTr("Blur behind see-through surfaces")
            subtitle: qsTr("The menu bar, the Dock and System Settings' sidebar")
            below: Segmented {
                width: 240
                visible: blurRow.on
                options: [qsTr("Light"), qsTr("Medium"), qsTr("Strong")]
                current: blurRow.levels.indexOf(pane.value("blurStrength", "medium"))
                onPicked: index => pane.setValue("blurStrength", blurRow.levels[index])
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: blurRow.on
                onToggled: on => pane.setValue("blur", on)
            }
        }
    }

    // ---- Pointer ----

    GroupTitle {
        text: qsTr("Pointer")
    }

    SettingsGroup {
        SwitchRow {
            title: qsTr("Hide the pointer while typing")
            key: "hideCursorTyping"
        }

        SettingRow {
            title: qsTr("Hide the pointer when it stops moving")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [
                    {
                        label: qsTr("Never"),
                        value: 0
                    },
                    {
                        label: qsTr("After 3 seconds"),
                        value: 3
                    },
                    {
                        label: qsTr("After 5 seconds"),
                        value: 5
                    },
                    {
                        label: qsTr("After 10 seconds"),
                        value: 10
                    },
                    {
                        label: qsTr("After 30 seconds"),
                        value: 30
                    }
                ]
                value: pane.value("cursorTimeout", 0)
                onPicked: v => pane.setValue("cursorTimeout", v)
            }
        }
    }

    // ---- Tiling and more ----

    GroupTitle {
        text: qsTr("Tiling and More")
    }

    SettingsGroup {
        SettingRow {
            id: layoutRow

            readonly property var layouts: ["dwindle", "master"]

            title: qsTr("Tiling layout")
            subtitle: pane.value("layout", "dwindle") === "master" ? qsTr("One large window, the others stacked beside it")
                                                                   : qsTr("Each new window splits the space of the focused one")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                options: [qsTr("Dwindle"), qsTr("Master")]
                current: layoutRow.layouts.indexOf(pane.value("layout", "dwindle"))
                onPicked: index => pane.setValue("layout", layoutRow.layouts[index])
            }
        }

        SettingRow {
            title: qsTr("Adaptive sync")
            subtitle: qsTr("Variable refresh rate, on displays that support it")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 240
                options: [qsTr("Off"), qsTr("On"), qsTr("Fullscreen")]
                current: pane.value("vrr", 0)
                onPicked: index => pane.setValue("vrr", index)
            }
        }

        SwitchRow {
            title: qsTr("Middle-click pastes the selection")
            key: "middleClickPaste"
            fallback: true
        }

        SwitchRow {
            title: qsTr("Turn Num Lock on at login")
            key: "numlock"
        }
    }

    Caption {
        text: qsTr("Applied right away by reloading Hyprland's config. Everything else is in ~/.config/hypr/hyprland.lua.")
    }
}
