// Fixed ID so `qs ipc` finds this shell wherever the folder lives.
//@ pragma ShellId system-settings
//@ pragma IconTheme MacTahoe-dark
// Window class, so the Dock matches the window to system-settings.desktop
//@ pragma AppId system-settings
import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

// macOS-style System Settings for this Hyprland desktop. One instance at a time:
//   qs -p ~/.config/system-settings -n -d
//   qs -p ~/.config/system-settings ipc call settings open <pane> [subpage]   (e.g. open displays "")
// Closing the window quits the app. Settings are kept in settings.json (see Store.qml).
ShellRoot {
    id: root

    // Sidebar entries, in groups. `keywords` help the search field find a pane.
    readonly property var groups: [
        [
            {
                id: "wifi",
                title: qsTr("Wi-Fi"),
                glyph: Theme.iWifi,
                color: "#0a84ff",
                keywords: "wireless network internet ssid password"
            },
            {
                id: "bluetooth",
                title: qsTr("Bluetooth"),
                glyph: Theme.iBluetooth,
                color: "#0a84ff",
                keywords: "devices pair headphones speaker"
            },
            {
                id: "network",
                title: qsTr("Network"),
                glyph: Theme.iNetwork,
                color: "#0a84ff",
                keywords: "ethernet lan dhcp ip address router dns"
            }
        ],
        [
            {
                id: "notifications",
                title: qsTr("Notifications"),
                glyph: Theme.iBell,
                color: "#ff453a",
                keywords: "banners alerts previews history apps"
            },
            {
                id: "sound",
                title: qsTr("Sound"),
                glyph: Theme.iVolumeHigh,
                color: "#ff375f",
                keywords: "volume output input microphone speakers audio"
            },
            {
                id: "focus",
                title: qsTr("Focus"),
                glyph: Theme.iFocus,
                color: "#5e5ce6",
                keywords: "do not disturb schedule dnd quiet"
            }
        ],
        [
            {
                id: "general",
                title: qsTr("General"),
                glyph: Theme.iCog,
                color: "#8e8e93",
                keywords: "about storage date time timezone login items startup calendars hostname"
            },
            {
                id: "appearance",
                title: qsTr("Appearance"),
                glyph: Theme.iPalette,
                color: "#48484a",
                keywords: "dark light theme gtk icons cursor"
            },
            {
                id: "controlCenter",
                title: qsTr("Control Center"),
                glyph: Theme.iToggles,
                color: "#8e8e93",
                keywords: "menu bar waybar clock modules"
            },
            {
                id: "desktopDock",
                title: qsTr("Desktop & Dock"),
                glyph: Theme.iDock,
                color: "#3a3a3c",
                keywords: "dock position magnification hide hot corners default apps browser terminal windows gaps title bars"
            },
            {
                id: "displays",
                title: qsTr("Displays"),
                glyph: Theme.iBrightness,
                color: "#0a84ff",
                keywords: "monitors resolution scale refresh rotation arrangement mirror brightness night shift"
            },
            {
                id: "wallpaper",
                title: qsTr("Wallpaper"),
                glyph: Theme.iImage,
                color: "#32ade6",
                keywords: "background desktop picture"
            }
        ],
        [
            {
                id: "battery",
                title: qsTr("Battery"),
                glyph: Theme.iBattery,
                color: "#30d158",
                keywords: "energy power mode health conservation charge"
            },
            {
                id: "lockScreen",
                title: qsTr("Lock Screen"),
                glyph: Theme.iLock,
                color: "#48484a",
                keywords: "password idle sleep display off message"
            },
            {
                id: "users",
                title: qsTr("Users & Groups"),
                glyph: Theme.iUsers,
                color: "#0a84ff",
                keywords: "account picture name login screen"
            }
        ],
        [
            {
                id: "keyboard",
                title: qsTr("Keyboard"),
                glyph: Theme.iKeyboard,
                color: "#8e8e93",
                keywords: "layout input sources repeat shortcuts"
            },
            {
                id: "pointer",
                title: qsTr("Trackpad & Mouse"),
                glyph: Theme.iMouse,
                color: "#8e8e93",
                keywords: "tracking speed scrolling tap click focus follows"
            }
        ]
    ]
    readonly property var panes: [].concat(...groups)
    readonly property var currentPane: panes.find(p => p.id === Ui.pane) ?? panes[0]

    // Pane id -> file
    readonly property var paneFiles: ({
            "wifi": "WifiPane.qml",
            "bluetooth": "BluetoothPane.qml",
            "network": "NetworkPane.qml",
            "notifications": "NotificationsPane.qml",
            "sound": "SoundPane.qml",
            "focus": "FocusPane.qml",
            "general": "GeneralPane.qml",
            "appearance": "AppearancePane.qml",
            "controlCenter": "ControlCenterPane.qml",
            "desktopDock": "DesktopDockPane.qml",
            "displays": "DisplaysPane.qml",
            "wallpaper": "WallpaperPane.qml",
            "battery": "BatteryPane.qml",
            "lockScreen": "LockScreenPane.qml",
            "users": "UsersPane.qml",
            "keyboard": "KeyboardPane.qml",
            "pointer": "PointerPane.qml"
        })

    property string fullName: ""
    property int faceVersion: 0

    function refreshUser() {
        Store.run(["sh", "-c", 'getent passwd "$USER" | cut -d: -f5 | cut -d, -f1'], (code, out) => root.fullName = out.trim());
        faceVersion++;
    }

    Component.onCompleted: refreshUser()

    Connections {
        target: Ui

        function onUserVersionChanged() {
            root.refreshUser();
        }
    }

    // Ends this instance (closing the window quits the app, as on macOS).
    function quit() {
        Quickshell.execDetached(["kill", String(Quickshell.processId)]);
    }

    IpcHandler {
        target: "settings"

        // Brings the window up (the launcher calls this first, so a running instance is reused).
        function show(): void {
            window.visible = true;
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "class:system-settings" })']);
        }

        function open(pane: string, subpage: string): void {
            if (root.paneFiles[pane])
                Ui.open(pane, subpage);
        }

        function toggle(): void {
            root.quit();
        }

    }

    FloatingWindow {
        id: window

        title: qsTr("System Settings")
        implicitWidth: 920
        implicitHeight: 680
        minimumSize: Qt.size(780, 480)
        color: Theme.panel

        // Closing the window quits the app.
        onClosed: root.quit()

        Item {
            id: windowContent

            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                    search.input.forceActiveFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
                    window.visible = false;
                    root.quit();
                } else if (event.key === Qt.Key_Escape && Ui.subpage !== "") {
                    Ui.back();
                }
            }

            // ---- Sidebar ----

            Rectangle {
                id: sidebar

                width: 230
                height: parent.height
                color: "#0d0d0e"

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Theme.separator
                }

                Field {
                    id: search

                    x: 12
                    y: 12
                    width: parent.width - 24
                    placeholder: qsTr("Search")
                    onAccepted: {
                        if (results.length > 0)
                            Ui.open(results[0].id);
                    }

                    readonly property string query: text.trim().toLowerCase()
                    readonly property var results: query === "" ? [] : root.panes.filter(p => (p.title + " " + p.keywords).toLowerCase().includes(query))
                }

                Flickable {
                    anchors.top: search.bottom
                    anchors.topMargin: 10
                    anchors.bottom: parent.bottom
                    width: parent.width
                    contentHeight: sideColumn.implicitHeight + 12
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: sideColumn

                        x: 10
                        width: parent.width - 20
                        spacing: 2

                        // User card, opens Users & Groups
                        Rectangle {
                            width: parent.width
                            height: 54
                            radius: 8
                            visible: search.query === ""
                            color: Ui.pane === "users" ? Theme.accent : userMouse.containsMouse ? Theme.hover : "transparent"

                            Avatar {
                                id: avatar

                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                name: root.fullName || Quickshell.env("USER")
                                version: root.faceVersion
                            }

                            Column {
                                anchors.left: avatar.right
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: root.fullName || Quickshell.env("USER")
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: qsTr("Users & Groups")
                                    color: Ui.pane === "users" ? "#ccffffff" : Theme.textSecondary
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: userMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Ui.open("users")
                            }
                        }

                        Repeater {
                            model: search.query === "" ? root.groups : [search.results]

                            Column {
                                required property var modelData

                                width: parent.width
                                spacing: 2
                                topPadding: 8

                                Repeater {
                                    model: parent.modelData

                                    Rectangle {
                                        id: item

                                        required property var modelData

                                        width: parent.width
                                        height: 30
                                        radius: 7
                                        color: Ui.pane === modelData.id ? Theme.accent : itemMouse.containsMouse ? Theme.hover : "transparent"

                                        IconTile {
                                            id: itemTile

                                            x: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            size: 22
                                            glyph: item.modelData.glyph
                                            color: item.modelData.color
                                        }

                                        Text {
                                            anchors.left: itemTile.right
                                            anchors.leftMargin: 9
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            text: item.modelData.title
                                            color: Theme.text
                                            font.family: Theme.font
                                            font.pixelSize: 13
                                        }

                                        MouseArea {
                                            id: itemMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: Ui.open(item.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            visible: search.query !== "" && search.results.length === 0
                            topPadding: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: qsTr("No Results")
                            color: Theme.textSecondary
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // ---- Pane ----

            Item {
                id: paneArea

                anchors.left: sidebar.right
                anchors.right: parent.right
                height: parent.height

                // Toolbar: back/forward and the pane (or page) title
                Item {
                    id: toolbar

                    width: parent.width
                    height: 52

                    Row {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Theme.iChevronLeft
                            size: 22
                            color: Ui.subpage !== "" || Ui.history.length > 0 ? Theme.text : Theme.textTertiary

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Ui.back()
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: paneLoader.item?.pageTitle || root.currentPane.title
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.separator
                        opacity: flick.contentY > 2 ? 1 : 0
                    }
                }

                Flickable {
                    id: flick

                    anchors.top: toolbar.bottom
                    anchors.bottom: parent.bottom
                    width: parent.width
                    contentHeight: (paneLoader.item?.implicitHeight ?? 0) + 40
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Loader {
                        id: paneLoader

                        x: Math.max(24, (flick.width - width) / 2)
                        y: 4
                        width: Math.min(flick.width - 48, 620)
                        source: Qt.resolvedUrl(root.paneFiles[Ui.pane] ?? "WifiPane.qml")
                        onSourceChanged: flick.contentY = 0
                    }

                    Connections {
                        target: Ui

                        function onSubpageChanged() {
                            flick.contentY = 0;
                        }
                    }
                }
            }

            // Sheets and pop-up menus go above everything
            Item {
                id: overlay

                anchors.fill: parent
                z: 900
                Component.onCompleted: Ui.overlay = overlay
            }

            MenuLayer {
                Component.onCompleted: Ui.menu = this
            }
        }
    }
}
