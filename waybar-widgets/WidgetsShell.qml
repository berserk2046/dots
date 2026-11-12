import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// Dropdown panels for waybar's network, pulseaudio, bluetooth, battery, system, backlight, power, date
// and spotify modules, opened over IPC (toggle.sh):
//   qs -p ~/.config/desktop-shell ipc call panel toggle <name>
//   qs -p ~/.config/desktop-shell ipc call panel toggleAt <name> <x> <y>   (centered under a global point)
//   qs -p ~/.config/desktop-shell ipc call panel open <name>   |   ... panel close
// <name>: wifi, volume, bluetooth, battery, system, display, power, date, media.
//
// One window shows whichever panel is open, and a panel only exists while it's open: it's built
// when its icon is clicked and thrown away once closed, so the panels cost nothing at login or while
// closed. Loaded by desktop-shell.
Scope {
    id: root

    // The panel shown (or shown last), by name
    property string current: ""
    // Given to the panel as `shown` a moment after it's built, so it sees itself open (its
    // onShownChanged runs) as it did when panels were kept around
    property bool contentShown: false

    readonly property var panels: ({
            "wifi": wifiPanel,
            "volume": volumePanel,
            "bluetooth": bluetoothPanel,
            "battery": batteryPanel,
            "system": systemPanel,
            "display": displayPanel,
            "power": powerPanel,
            "date": datePanel,
            "media": mediaPanel
        })
    // Cards wider than Theme.panelWidth
    readonly property var widths: ({
            "date": 360,
            "media": 420
        })

    // The popup opens on the focused monitor, falling back to the first screen.
    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    function isOpen(name) {
        return popup.shown && current === name;
    }

    // Shows a panel on `screen`, centered under x (screen-local) or, without one, under the pointer.
    function show(name, screen, x) {
        if (panels[name] === undefined)
            return;
        contentShown = false;
        current = name;
        popup.screen = screen ?? focusedScreen;
        if (x === undefined)
            popup.open();
        else
            popup.openAt(x);
        Qt.callLater(() => root.contentShown = popup.shown);
    }

    function close() {
        contentShown = false;
        popup.close();
    }

    function toggle(name) {
        isOpen(name) ? close() : show(name);
    }

    // Like toggle, but opens centered under a point in global coordinates (the cursor, from toggle.sh).
    function toggleAt(name, x, y) {
        if (isOpen(name)) {
            close();
            return;
        }
        const screen = Quickshell.screens.find(s => x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
                       ?? focusedScreen;
        show(name, screen, x - screen.x);
    }

    // What the panels show: small, and idle unless their panel is open
    Network {
        id: network

        active: root.isOpen("wifi")
    }

    System {
        id: system

        active: root.isOpen("battery") || root.isOpen("system")
    }

    Display {
        id: display

        active: root.isOpen("display")
    }

    Calendars {
        id: calendars

        active: root.isOpen("date")
    }

    Popup {
        id: popup

        namespace: "waybar-widgets-" + (root.current || "panel")
        cardWidth: root.widths[root.current] ?? Theme.panelWidth
        onShownChanged: {
            if (!shown)
                root.contentShown = false;
        }

        Loader {
            width: parent?.width ?? 0
            // Until the card has faded out
            active: popup.visible && root.panels[root.current] !== undefined
            sourceComponent: root.panels[root.current] ?? null
        }
    }

    Component {
        id: wifiPanel

        WifiPanel {
            net: network
            shown: root.contentShown
        }
    }

    Component {
        id: volumePanel

        AudioPanel {
            shown: root.contentShown
        }
    }

    Component {
        id: bluetoothPanel

        BluetoothPanel {
            shown: root.contentShown
            onCloseRequested: root.close()
        }
    }

    Component {
        id: batteryPanel

        BatteryPanel {
            sys: system
            shown: root.contentShown
        }
    }

    Component {
        id: systemPanel

        SystemPanel {
            sys: system
            shown: root.contentShown
        }
    }

    Component {
        id: displayPanel

        DisplayPanel {
            disp: display
            shown: root.contentShown
            onCloseRequested: root.close()
        }
    }

    Component {
        id: powerPanel

        PowerPanel {
            shown: root.contentShown
            onCloseRequested: root.close()
        }
    }

    Component {
        id: datePanel

        DatePanel {
            cals: calendars
            shown: root.contentShown
        }
    }

    // Now Playing for the bar's Spotify item: the Sound panel's player card, larger. Spotify first,
    // other players only when it isn't running.
    Component {
        id: mediaPanel

        Column {
            id: media

            readonly property var players: Mpris.players.values
            readonly property var spotify: players.filter(p => p.identity === "Spotify")

            width: parent?.width ?? 0

            Repeater {
                model: media.spotify.length > 0 ? media.spotify : media.players

                PlayerCard {
                    required property MprisPlayer modelData

                    p: modelData
                    shown: root.contentShown
                    width: media.width
                    zoom: 1.5
                    showQueue: true
                }
            }
        }
    }

    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            root.toggle(name);
        }

        function toggleAt(name: string, x: int, y: int): void {
            root.toggleAt(name, x, y);
        }

        function open(name: string): void {
            if (!root.isOpen(name))
                root.show(name);
        }

        function close(): void {
            root.close();
        }
    }
}
