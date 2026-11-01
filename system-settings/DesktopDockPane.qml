import QtQuick
import Quickshell
import qs.shared

// Desktop & Dock: the Dock (size, magnification, position, auto-hide, indicators), default apps,
// windows (floating, title bars, gaps, corners) and Hot Corners (own page).
Column {
    id: pane

    property string pageTitle: Ui.subpage === "hotCorners" ? qsTr("Hot Corners") : ""
    property var defaults: ({})

    readonly property int iconSize: Store.get("dock", "iconSize", 40)
    readonly property bool magnification: Store.get("dock", "magnification", true)
    readonly property int maxIconSize: Store.get("dock", "maxIconSize", 64)

    spacing: 10

    Component.onCompleted: loadDefaults()

    function loadDefaults() {
        Store.run(["python3", Store.script("default-apps.py")], (code, out) => {
            try {
                pane.defaults = JSON.parse(out);
            } catch (error) {}
        });
    }

    function setDefault(role, id) {
        Store.run(["python3", Store.script("default-apps.py"), "set", role, id], () => pane.loadDefaults());
    }

    function setWindows(key, value) {
        Store.set("windows", key, value);
    }

    component DefaultAppRow: SettingRow {
        id: defaultRow

        property string role

        Dropdown {
            anchors.verticalCenter: parent.verticalCenter
            options: (pane.defaults[defaultRow.role]?.options ?? []).map(o => ({
                        label: o.name,
                        value: o.id
                    }))
            value: pane.defaults[defaultRow.role]?.current
            onPicked: id => pane.setDefault(defaultRow.role, id)
        }
    }

    // ---- Main page ----

    GroupTitle {
        visible: Ui.subpage === ""
        text: qsTr("Dock")
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Size")
            below: SettingSlider {
                width: parent.width
                from: 24
                to: 80
                step: 2
                minLabel: qsTr("Small")
                maxLabel: qsTr("Large")
                value: pane.iconSize
                onMoved: v => Store.setMany("dock", {
                        iconSize: v,
                        maxIconSize: Math.max(pane.maxIconSize, v)
                    })
            }
        }

        SettingRow {
            title: qsTr("Magnification")
            below: SettingSlider {
                width: parent.width
                visible: pane.magnification
                from: pane.iconSize
                to: 128
                step: 2
                minLabel: qsTr("Small")
                maxLabel: qsTr("Large")
                value: pane.maxIconSize
                onMoved: v => Store.set("dock", "maxIconSize", v)
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: pane.magnification
                onToggled: on => Store.set("dock", "magnification", on)
            }
        }

        SettingRow {
            title: qsTr("Position on screen")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 240
                options: [qsTr("Left"), qsTr("Bottom"), qsTr("Right"), qsTr("Top")]
                current: ["left", "bottom", "right", "top"].indexOf(Store.get("dock", "position", "bottom"))
                onPicked: index => Store.set("dock", "position", ["left", "bottom", "right", "top"][index])
            }
        }

        SettingRow {
            title: qsTr("Automatically hide and show the Dock")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("dock", "autoHide", false)
                onToggled: on => Store.set("dock", "autoHide", on)
            }
        }

        SettingRow {
            title: qsTr("Show indicators for open applications")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("dock", "showIndicators", true)
                onToggled: on => Store.set("dock", "showIndicators", on)
            }
        }
    }

    GroupTitle {
        visible: Ui.subpage === ""
        text: qsTr("Default Apps")
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        DefaultAppRow {
            title: qsTr("Web browser")
            role: "browser"
        }

        DefaultAppRow {
            title: qsTr("File manager")
            role: "files"
        }

        DefaultAppRow {
            title: qsTr("Mail")
            role: "mail"
        }

        SettingRow {
            title: qsTr("Terminal")
            subtitle: qsTr("$mod+Return, and terminal apps in the Dock")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: (pane.defaults.terminal?.options ?? []).map(o => ({
                            label: o.name + (o.id !== o.name.toLowerCase() ? " (" + o.id + ")" : ""),
                            value: o.id
                        }))
                value: Store.get("general", "terminal", "foot")
                onPicked: id => Store.set("general", "terminal", id)
            }
        }
    }

    GroupTitle {
        visible: Ui.subpage === ""
        text: qsTr("Windows")
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Open windows floating")
            subtitle: qsTr("Centered, like on macOS; $mod+Shift+Space tiles one")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("windows", "floatByDefault", true)
                onToggled: on => pane.setWindows("floatByDefault", on)
            }
        }

        SettingRow {
            title: qsTr("Title bars")
            subtitle: qsTr("hyprbars, with close, hide and zoom buttons")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("windows", "titleBars", true)
                onToggled: on => pane.setWindows("titleBars", on)
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
                onMoved: v => pane.setWindows("rounding", v)
            }
        }

        SettingRow {
            title: qsTr("Border width")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                options: ["0", "1", "2", "3"]
                current: Store.get("windows", "borderSize", 1)
                onPicked: index => pane.setWindows("borderSize", index)
            }
        }
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Hot Corners…")
            glyph: Theme.iCorner
            tileColor: "#8e8e93"
            chevron: true
            onClicked: Ui.openSub("hotCorners")
        }
    }

    // ---- Hot Corners ----

    Item {
        id: corners

        readonly property var actions: [
            {
                label: "—",
                value: ""
            },
            {
                label: qsTr("Lock Screen"),
                value: "lock"
            },
            {
                label: qsTr("Notification Center"),
                value: "notifications"
            },
            {
                label: qsTr("App Launcher"),
                value: "launcher"
            },
            {
                label: qsTr("Put Display to Sleep"),
                value: "displaySleep"
            },
            {
                label: qsTr("System Settings"),
                value: "settings"
            }
        ]
        readonly property var current: Store.data.hotCorners ?? {}

        width: parent.width
        height: 300
        visible: Ui.subpage === "hotCorners"

        function setCorner(corner, action) {
            Store.set("hotCorners", corner, action);
        }

        // A small screen with the four menus around it.
        Rectangle {
            anchors.centerIn: parent
            width: 240
            height: 150
            radius: 8
            color: "#0a84ff"
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#2a6fdb"
                }
                GradientStop {
                    position: 1
                    color: "#8e44ad"
                }
            }
            border.width: 4
            border.color: Theme.solidBorder
        }

        Dropdown {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 30
            options: corners.actions
            value: corners.current.topLeft ?? ""
            onPicked: v => corners.setCorner("topLeft", v)
        }

        Dropdown {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 30
            options: corners.actions
            value: corners.current.topRight ?? ""
            onPicked: v => corners.setCorner("topRight", v)
        }

        Dropdown {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            options: corners.actions
            value: corners.current.bottomLeft ?? ""
            onPicked: v => corners.setCorner("bottomLeft", v)
        }

        Dropdown {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            options: corners.actions
            value: corners.current.bottomRight ?? ""
            onPicked: v => corners.setCorner("bottomRight", v)
        }
    }

    Caption {
        visible: Ui.subpage === "hotCorners"
        text: qsTr("Rest the pointer in a corner of any screen to run its action. Handled by the Dock's shell.")
    }
}
