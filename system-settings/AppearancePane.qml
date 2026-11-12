import QtQuick
import Quickshell.Widgets
import qs.shared
import qs.common

// Appearance: light/dark/auto for apps, GTK theme, icon theme (also the Dock's), pointer and apps' fonts.
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

    // Fonts: installed families (list-fonts.sh) and what apps use now (gsettings), as "<family> <size>".
    // Saved under "fonts" rather than "appearance", whose changes also reload Hyprland's config.
    property var uiFonts: []
    property var monoFonts: []
    property var fontsNow: ({})
    readonly property var uiFont: splitFont(Store.get("fonts", "font", fontsNow["font-name"] ?? "Adwaita Sans 11"))
    readonly property var monoFont: splitFont(Store.get("fonts", "monoFont", fontsNow["monospace-font-name"] ?? "Adwaita Mono 11"))
    readonly property real textScale: Store.get("fonts", "textScale", Number(fontsNow["text-scaling-factor"]) || 1)
    readonly property var fontSizes: [8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20].map(n => ({
                label: n + " pt",
                value: n
            }))

    function splitFont(name) {
        const m = /^(.*\S)\s+(\d+(?:\.\d+)?)$/.exec(name ?? "");
        return m ? {
            family: m[1],
            size: Number(m[2])
        } : {
            family: name ?? "",
            size: 11
        };
    }

    // key: "font" or "monoFont" (also appearance.sh's command: "font" or "mono")
    function setFont(key, family, size) {
        const name = family + " " + size;
        Store.set("fonts", key, name);
        Store.appearance([key === "font" ? "font" : "mono", name]);
    }

    function setFontOption(key, value) {
        Store.set("fonts", key, value);
        Store.appearance([key, value]);
    }

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
        Store.run(["sh", Store.script("list-fonts.sh")], (code, out) => {
            const ui = [];
            const mono = [];
            const now = {};
            for (const line of out.split("\n")) {
                const eq = line.indexOf("=");
                const [key, value] = [line.slice(0, eq), line.slice(eq + 1)];
                if (key === "ui")
                    ui.push(value);
                else if (key === "mono")
                    mono.push(value);
                else if (key.startsWith("current-"))
                    now[key.slice(8)] = value;
            }
            pane.uiFonts = ui;
            pane.monoFonts = mono;
            pane.fontsNow = now;
        });
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
        target: Appearance

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
            textFormat: Text.PlainText
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
        text: qsTr("Changing icons restarts the Dock, the window switcher and the lock screen shell (your notifications are kept). More themes: install them to ~/.themes and ~/.local/share/icons, e.g. MacTahoe-gtk-theme or WhiteSur-gtk-theme from the AUR.")
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
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: pane.cursorSize + " px"
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }
        }
    }

    // ---- Fonts ----

    GroupTitle {
        text: qsTr("Fonts")
    }

    SettingsGroup {
        SettingRow {
            title: qsTr("Interface font")
            subtitle: qsTr("Menus, buttons and text in apps")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.uiFonts
                value: pane.uiFont.family
                onPicked: family => pane.setFont("font", family, pane.uiFont.size)
            }

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.fontSizes
                value: pane.uiFont.size
                onPicked: size => pane.setFont("font", pane.uiFont.family, size)
            }
        }

        SettingRow {
            title: qsTr("Monospaced font")
            subtitle: qsTr("Code and text editors in apps that use it")

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.monoFonts
                value: pane.monoFont.family
                onPicked: family => pane.setFont("monoFont", family, pane.monoFont.size)
            }

            Dropdown {
                anchors.verticalCenter: parent.verticalCenter
                options: pane.fontSizes
                value: pane.monoFont.size
                onPicked: size => pane.setFont("monoFont", pane.monoFont.family, size)
            }
        }

        SettingRow {
            title: qsTr("Text size")
            below: SettingSlider {
                width: parent.width
                from: 0.8
                to: 1.5
                step: 0.05
                minLabel: qsTr("Smaller")
                maxLabel: qsTr("Larger")
                value: pane.textScale
                onMoved: v => scaleTimer.restartWith(Math.round(v * 100) / 100)
            }

            Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(pane.textScale * 100) + " %"
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(12)
            }
        }

        SettingRow {
            id: smoothingRow

            readonly property var modes: ["none", "grayscale", "rgba"]

            title: qsTr("Font smoothing")
            subtitle: qsTr("Subpixel is sharper on most LCD screens")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 260
                options: [qsTr("Off"), qsTr("Grayscale"), qsTr("Subpixel")]
                current: smoothingRow.modes.indexOf(Store.get("fonts", "smoothing", pane.fontsNow["font-antialiasing"] ?? "grayscale"))
                onPicked: index => pane.setFontOption("smoothing", smoothingRow.modes[index])
            }
        }

        SettingRow {
            id: hintingRow

            readonly property var styles: ["none", "slight", "medium", "full"]

            title: qsTr("Hinting")
            subtitle: qsTr("Fits letters to the pixel grid")

            Segmented {
                anchors.verticalCenter: parent.verticalCenter
                width: 280
                options: [qsTr("None"), qsTr("Slight"), qsTr("Medium"), qsTr("Full")]
                current: hintingRow.styles.indexOf(Store.get("fonts", "hinting", pane.fontsNow["font-hinting"] ?? "slight"))
                onPicked: index => pane.setFontOption("hinting", hintingRow.styles[index])
            }
        }
    }

    Caption {
        text: qsTr("For GTK and Qt apps; open apps may need a restart to pick up a new font. The menu bar, the Dock, the panels and title bars keep SF Pro, which they're designed around, and the terminal (foot) has its own font in foot.ini.")
    }

    // Text size: applied once the slider rests, so dragging doesn't make every app redo its layout.
    Timer {
        id: scaleTimer

        property real scale: 1

        function restartWith(v) {
            scale = v;
            Store.set("fonts", "textScale", v);
            restart();
        }

        interval: 300
        onTriggered: Store.appearance(["scale", String(scale)])
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
