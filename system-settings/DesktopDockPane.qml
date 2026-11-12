import QtQuick
import Quickshell
import qs.shared
import qs.common

// Desktop & Dock: the Dock (size, magnification, position, auto-hide, indicators; per display on its
// own page), the desktop's files and folders (the desktop folder's shell), default apps, windows (floating, title bars; the rest is in the Hyprland pane), the window
// switcher (Alt+Tab) and Hot Corners (own page).
Column {
    id: pane

    property string pageTitle: Ui.subpage === "hotCorners" ? qsTr("Hot Corners") : Ui.subpage === "dockDisplays" ? qsTr("Dock on Each Display") : ""
    property var defaults: ({})

    readonly property int iconSize: Store.get("dock", "iconSize", 40)
    readonly property bool magnification: Store.get("dock", "magnification", true)
    readonly property int maxIconSize: Store.get("dock", "maxIconSize", 64)

    // Per display, by monitor (make, model and serial, see Displays; older files used the port name):
    // {enabled, custom, iconSize, magnification, maxIconSize, position, autoHide},
    // read by the Dock's shell.qml. Values a display can have of its own, and their defaults:
    readonly property var dockMonitors: Store.get("dock", "monitors", {})
    readonly property var displayKeys: ({
            iconSize: 40,
            magnification: true,
            maxIconSize: 64,
            position: "bottom",
            autoHide: false
        })

    function setMonitor(name, values) {
        const next = Object.assign({}, dockMonitors);
        const key = Displays.keyOf(name);
        next[key] = Object.assign({}, Displays.pick(dockMonitors, name) ?? {}, values);
        // Saved under the port name by an older version: moved to the monitor's own key
        if (key !== name)
            delete next[name];
        Store.set("dock", "monitors", next);
    }

    // Own settings on: start from what every display uses (or this display's earlier own values),
    // so nothing moves until one is changed.
    function setCustom(name, on) {
        const values = {
            custom: on
        };
        if (on) {
            const own = Displays.pick(dockMonitors, name) ?? {};
            for (const key in displayKeys) {
                if (own[key] === undefined || own[key] === null)
                    values[key] = Store.get("dock", key, displayKeys[key]);
            }
        }
        setMonitor(name, values);
    }

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

        SettingRow {
            title: qsTr("Show only windows on the Dock's display")
            subtitle: qsTr("With several displays, each Dock lists the apps open on its own display")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("dock", "ownWindowsOnly", false)
                onToggled: on => Store.set("dock", "ownWindowsOnly", on)
            }
        }

        SettingRow {
            title: qsTr("Dock on Each Display…")
            subtitle: {
                const of = s => Displays.pick(pane.dockMonitors, s.name);
                const off = Quickshell.screens.filter(s => of(s)?.enabled === false).length;
                const own = Quickshell.screens.filter(s => of(s)?.enabled !== false && of(s)?.custom === true).length;
                const parts = [];
                if (off > 0)
                    parts.push(off === 1 ? qsTr("Off on 1 display") : qsTr("Off on %1 displays").arg(off));
                if (own > 0)
                    parts.push(own === 1 ? qsTr("own settings on 1 display") : qsTr("own settings on %1 displays").arg(own));
                return parts.length > 0 ? parts.join(", ") : qsTr("Turn it off, or give it its own size and position, per display");
            }
            glyph: Theme.iMonitor
            tileColor: "#0a84ff"
            chevron: true
            onClicked: Ui.openSub("dockDisplays")
        }
    }

    // ---- Desktop ----

    GroupTitle {
        visible: Ui.subpage === ""
        text: qsTr("Desktop")
    }

    SettingsGroup {
        id: desktopGroup

        readonly property bool shown: Store.get("desktop", "showIcons", true)

        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Show files and folders on the desktop")
            subtitle: qsTr("From ~/Desktop, on every display; each monitor keeps its own arrangement")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: desktopGroup.shown
                onToggled: on => Store.setDesktop("showIcons", on)
            }
        }

        SettingRow {
            visible: desktopGroup.shown
            title: qsTr("Icon size")
            below: SettingSlider {
                width: parent.width
                from: 32
                to: 96
                step: 4
                minLabel: qsTr("Small")
                maxLabel: qsTr("Large")
                value: Store.get("desktop", "iconSize", 56)
                onMoved: v => Store.setDesktop("iconSize", v)
            }
        }

        SettingRow {
            visible: desktopGroup.shown
            title: qsTr("Grid spacing")
            below: SettingSlider {
                width: parent.width
                from: 0
                to: 40
                step: 2
                minLabel: qsTr("Tight")
                maxLabel: qsTr("Wide")
                value: Store.get("desktop", "gridSpacing", 12)
                onMoved: v => Store.setDesktop("gridSpacing", v)
            }
        }

        SettingRow {
            visible: desktopGroup.shown
            title: qsTr("Text size")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: [10, 11, 12, 13, 14].map(n => ({
                            label: n + " pt",
                            value: n
                        }))
                value: Store.get("desktop", "textSize", 12)
                onPicked: v => Store.setDesktop("textSize", v)
            }
        }
    }

    Caption {
        visible: Ui.subpage === "" && desktopGroup.shown
        text: qsTr("Drag items to arrange them, also onto another display. Right-click the desktop for New Folder, Clean Up and more.")
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
            title: qsTr("Borders, Corners, Gaps and Focus…")
            subtitle: qsTr("Hyprland settings")
            glyph: Theme.iDesktop
            tileColor: "#5e5ce6"
            chevron: true
            onClicked: Ui.open("hyprland")
        }
    }

    GroupTitle {
        visible: Ui.subpage === ""
        text: qsTr("Window Switcher")
    }

    SettingsGroup {
        visible: Ui.subpage === ""

        SettingRow {
            title: qsTr("Show window previews")
            subtitle: qsTr("Alt+Tab; off shows large app icons, like macOS")

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Store.get("switcher", "previews", true)
                onToggled: on => Store.set("switcher", "previews", on)
            }
        }

        SettingRow {
            title: qsTr("Show windows from")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                options: [qsTr("All Workspaces"), qsTr("This Workspace")]
                current: Store.get("switcher", "scope", "all") === "workspace" ? 1 : 0
                onPicked: index => Store.set("switcher", "scope", ["all", "workspace"][index])
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

    // ---- Dock on each display ----

    component DisplayDock: Column {
        id: display

        required property var modelData // a connected screen
        readonly property string name: modelData.name
        readonly property var own: Displays.pick(pane.dockMonitors, name) ?? {}
        readonly property bool shown: own.enabled !== false
        readonly property bool custom: own.custom === true

        // This display's own value, or the one every display uses
        function value(key) {
            return custom && own[key] !== undefined && own[key] !== null ? own[key] : Store.get("dock", key, pane.displayKeys[key]);
        }

        readonly property int iconSize: value("iconSize")
        readonly property bool magnification: value("magnification")
        readonly property int maxIconSize: value("maxIconSize")

        width: pane.width
        spacing: 10

        GroupTitle {
            text: display.modelData.model ? display.name + " · " + display.modelData.model : display.name
        }

        SettingsGroup {
            SettingRow {
                title: qsTr("Show the Dock on this display")
                subtitle: display.modelData.width + " × " + display.modelData.height

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: display.shown
                    onToggled: on => pane.setMonitor(display.name, {
                            enabled: on
                        })
                }
            }

            SettingRow {
                visible: display.shown
                title: qsTr("Use its own settings")
                subtitle: display.custom ? qsTr("Size, magnification, position and hiding below") : qsTr("Off: the same as the Dock settings on the previous page")

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: display.custom
                    onToggled: on => pane.setCustom(display.name, on)
                }
            }

            SettingRow {
                visible: display.shown && display.custom
                title: qsTr("Size")
                below: SettingSlider {
                    width: parent.width
                    from: 24
                    to: 80
                    step: 2
                    minLabel: qsTr("Small")
                    maxLabel: qsTr("Large")
                    value: display.iconSize
                    onMoved: v => pane.setMonitor(display.name, {
                            iconSize: v,
                            maxIconSize: Math.max(display.maxIconSize, v)
                        })
                }
            }

            SettingRow {
                visible: display.shown && display.custom
                title: qsTr("Magnification")
                below: SettingSlider {
                    width: parent.width
                    visible: display.magnification
                    from: display.iconSize
                    to: 128
                    step: 2
                    minLabel: qsTr("Small")
                    maxLabel: qsTr("Large")
                    value: display.maxIconSize
                    onMoved: v => pane.setMonitor(display.name, {
                            maxIconSize: v
                        })
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: display.magnification
                    onToggled: on => pane.setMonitor(display.name, {
                            magnification: on
                        })
                }
            }

            SettingRow {
                visible: display.shown && display.custom
                title: qsTr("Position on screen")

                Segmented {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 240
                    options: [qsTr("Left"), qsTr("Bottom"), qsTr("Right"), qsTr("Top")]
                    current: ["left", "bottom", "right", "top"].indexOf(display.value("position"))
                    onPicked: index => pane.setMonitor(display.name, {
                            position: ["left", "bottom", "right", "top"][index]
                        })
                }
            }

            SettingRow {
                visible: display.shown && display.custom
                title: qsTr("Automatically hide and show the Dock")

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: display.value("autoHide")
                    onToggled: on => pane.setMonitor(display.name, {
                            autoHide: on
                        })
                }
            }
        }
    }

    Repeater {
        model: Ui.subpage === "dockDisplays" ? Quickshell.screens : []

        DisplayDock {}
    }

    Caption {
        visible: Ui.subpage === "dockDisplays"
        text: qsTr("Displays connected later get the Dock with the settings on the previous page. Saved by display name, so a display keeps its settings when it's connected again.")
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
