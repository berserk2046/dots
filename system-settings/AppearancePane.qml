import QtQuick
import Quickshell.Widgets
import qs.shared

// Appearance: light/dark/auto for apps, GTK theme, icon theme (also the Dock's) and pointer.
Column {
    id: pane

    property string pageTitle: ""
    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property var current: ({})
    property var preview: []

    readonly property string mode: Store.get("appearance", "mode", current.scheme === "prefer-light" ? "light" : "dark")
    // What GTK uses now: light/dark can swap a …-Dark/…-Light theme for its other variant (also the Dock's Auto).
    readonly property string gtkTheme: current.gtk || Store.get("appearance", "gtkTheme", "Adwaita")
    readonly property string iconTheme: Store.get("appearance", "iconTheme", current.icons ?? "MacTahoe-dark")
    readonly property string cursorTheme: Store.get("appearance", "cursorTheme", current.cursors ?? "default")
    readonly property int cursorSize: Store.get("appearance", "cursorSize", Number(current.size) || 24)

    spacing: 10

    Component.onCompleted: {
        Store.run(["sh", Store.script("list-themes.sh")], (code, out) => {
            const lists = {
                gtk: new Set(),
                icons: new Set(),
                cursors: new Set()
            };
            const current = {};
            for (const line of out.split("\n")) {
                const [key, value] = [line.slice(0, line.indexOf("=")), line.slice(line.indexOf("=") + 1)];
                if (lists[key])
                    lists[key].add(value);
                else if (key.startsWith("current-"))
                    current[key.slice(8)] = value;
            }
            const sorted = set => Array.from(set).sort((a, b) => a.localeCompare(b));
            pane.gtkThemes = sorted(lists.gtk);
            pane.iconThemes = sorted(lists.icons);
            pane.cursorThemes = ["default", ...sorted(lists.cursors)];
            pane.current = current;
        });
        loadPreview();
    }

    onIconThemeChanged: loadPreview()

    function loadPreview() {
        Store.run(["sh", Store.script("icon-preview.sh"), iconTheme], (code, out) => pane.preview = out.split("\n").filter(p => p));
    }

    // Day is 7:00-19:00 for Auto (the Dock's shell switches it while running).
    function setMode(mode) {
        Store.set("appearance", "mode", mode);
        const hour = new Date().getHours();
        Store.appearance(["scheme", mode === "auto" ? (hour >= 7 && hour < 19 ? "light" : "dark") : mode]);
    }

    // Light/dark may have swapped the GTK theme for its other variant, here or from the Dock's Auto.
    Connections {
        target: Theme

        function onSchemeChanged() {
            Store.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"], (code, out) => {
                const theme = out.trim().replace(/'/g, "");
                if (code !== 0 || !theme)
                    return;
                pane.current = Object.assign({}, pane.current, {
                    gtk: theme
                });
                Store.set("appearance", "gtkTheme", theme);
            });
        }
    }

    // Mini window drawings for the Light / Dark / Auto choices.
    component ModeTile: Column {
        id: tile

        property string mode
        property string label

        spacing: 6

        Rectangle {
            width: 112
            height: 74
            radius: 9
            color: "transparent"
            border.width: pane.mode === tile.mode ? 3 : 1
            border.color: pane.mode === tile.mode ? Theme.accent : Theme.border

            Item {
                anchors.fill: parent
                anchors.margins: 5

                Repeater {
                    model: tile.mode === "auto" ? ["light", "dark"] : [tile.mode]

                    Rectangle {
                        required property string modelData
                        required property int index

                        x: tile.mode === "auto" ? index * parent.width / 2 : 0
                        width: tile.mode === "auto" ? parent.width / 2 : parent.width
                        height: parent.height
                        radius: tile.mode === "auto" ? 0 : 5
                        color: modelData === "light" ? "#e8e8ed" : "#2c2c2e"
                        clip: true

                        Rectangle {
                            x: 8 - parent.x
                            y: 10
                            width: 86
                            height: 46
                            radius: 4
                            color: modelData === "light" ? "#ffffff" : "#1c1c1e"
                            border.width: 1
                            border.color: modelData === "light" ? "#d1d1d6" : "#3a3a3c"

                            Row {
                                x: 5
                                y: 5
                                spacing: 3

                                Repeater {
                                    model: ["#ff5f57", "#febc2e", "#28c840"]

                                    Rectangle {
                                        required property string modelData

                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: modelData
                                    }
                                }
                            }

                            Rectangle {
                                x: 5
                                y: 16
                                width: 40
                                height: 5
                                radius: 2
                                color: Theme.accent
                            }

                            Rectangle {
                                x: 5
                                y: 26
                                width: 60
                                height: 4
                                radius: 2
                                color: parent.parent.modelData === "light" ? "#d1d1d6" : "#48484a"
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: pane.setMode(tile.mode)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            color: pane.mode === tile.mode ? Theme.text : Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
            font.weight: pane.mode === tile.mode ? Font.DemiBold : Font.Normal
        }
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Appearance")
            below: Row {
                spacing: 14

                ModeTile {
                    mode: "light"
                    label: qsTr("Light")
                }

                ModeTile {
                    mode: "dark"
                    label: qsTr("Dark")
                }

                ModeTile {
                    mode: "auto"
                    label: qsTr("Auto")
                }
            }
        }
    }

    Caption {
        text: qsTr("For GTK, libadwaita and Qt apps (open libadwaita apps pick up a new theme once restarted), title bars, the menu bar and its panels, the Dock and System Settings. Auto is light from 7 AM to 7 PM. A theme named …-Dark or …-Light switches to its other variant with it.")
    }

    GroupTitle {
        text: qsTr("Themes")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("App theme")
            subtitle: qsTr("GTK 3 and GTK 4")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.gtkThemes
                value: pane.gtkTheme
                onPicked: theme => {
                    pane.current = Object.assign({}, pane.current, {
                        gtk: theme
                    });
                    Store.set("appearance", "gtkTheme", theme);
                    Store.appearance(["gtk", theme]);
                }
            }
        }

        SettingRow {
            title: qsTr("Icons")
            subtitle: qsTr("Apps, the Dock and notifications")
            below: Row {
                spacing: 12
                visible: pane.preview.length > 0

                Repeater {
                    model: pane.preview

                    IconImage {
                        required property string modelData

                        implicitSize: 36
                        source: "file://" + modelData
                        asynchronous: true
                    }
                }
            }

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.iconThemes
                value: pane.iconTheme
                onPicked: theme => Store.setIconTheme(theme)
            }
        }
    }

    Caption {
        text: qsTr("Changing icons restarts the Dock and the lock screen shell (your notifications are kept). More themes: install them to ~/.themes and ~/.local/share/icons, e.g. MacTahoe-gtk-theme or WhiteSur-gtk-theme from the AUR.")
    }

    GroupTitle {
        text: qsTr("Pointer")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Cursor theme")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.cursorThemes
                value: pane.cursorTheme
                onPicked: theme => {
                    Store.setMany("appearance", {
                        cursorTheme: theme,
                        cursorSize: pane.cursorSize
                    });
                    Store.appearance(["cursor", theme, String(pane.cursorSize)]);
                }
            }
        }

        SettingRow {
            title: qsTr("Pointer size")
            below: SettingSlider {
                width: parent.width
                from: 16
                to: 64
                step: 4
                ticks: 13
                minLabel: qsTr("Normal")
                maxLabel: qsTr("Large")
                value: pane.cursorSize
                onMoved: v => sizeTimer.restartWith(v)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pane.cursorSize + " px"
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }
        }
    }

    // Apply the size once the slider rests, so dragging doesn't flood hyprctl.
    Timer {
        id: sizeTimer

        property int size: 24

        function restartWith(v) {
            size = v;
            Store.setMany("appearance", {
                cursorTheme: pane.cursorTheme,
                cursorSize: v
            });
            restart();
        }

        interval: 250
        onTriggered: Store.appearance(["cursor", pane.cursorTheme, String(size)])
    }
}
