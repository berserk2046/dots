// Fixed ID so `qs ipc` finds this shell wherever the folder lives.
//@ pragma ShellId waybar-widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Dropdown panels for waybar's network, pulseaudio, bluetooth, battery, system, backlight, power and date modules, opened over IPC:
//   qs -p <this folder> ipc call wifi|volume|bluetooth|battery|system|display|power|date toggle
//   qs -p <this folder> ipc call <name> toggleAt <x> <y>   (centered under a global point)
ShellRoot {
    id: root

    // The popup opens on the focused monitor, falling back to the first screen.
    // The panels follow System Settings → Appearance, light or dark.
    Component.onCompleted: Theme.followScheme = true

    readonly property var focusedScreen: {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    function show(which) {
        for (const popup of [wifiPopup, volumePopup, bluetoothPopup, batteryPopup, systemPopup, displayPopup, powerPopup, datePopup]) {
            if (popup !== which)
                popup.close();
        }
        if (!which.shown) {
            which.screen = focusedScreen;
            which.open();
        }
    }

    function toggle(which) {
        which.shown ? which.close() : show(which);
    }

    // Like toggle, but opens centered under a point in global coordinates (the cursor, from toggle.sh).
    function toggleAt(which, x, y) {
        if (which.shown) {
            which.close();
            return;
        }
        for (const popup of [wifiPopup, volumePopup, bluetoothPopup, batteryPopup, systemPopup, displayPopup, powerPopup, datePopup]) {
            if (popup !== which)
                popup.close();
        }
        const screen = Quickshell.screens.find(s => x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height)
                       ?? focusedScreen;
        which.screen = screen;
        which.openAt(x - screen.x);
    }

    Network {
        id: network

        active: wifiPopup.shown
    }

    Popup {
        id: wifiPopup

        namespace: "waybar-widgets-wifi"

        WifiPanel {
            net: network
            shown: wifiPopup.shown
        }
    }

    Popup {
        id: volumePopup

        namespace: "waybar-widgets-volume"

        AudioPanel {
            shown: volumePopup.shown
        }
    }

    Popup {
        id: bluetoothPopup

        namespace: "waybar-widgets-bluetooth"

        BluetoothPanel {
            shown: bluetoothPopup.shown
            onCloseRequested: bluetoothPopup.close()
        }
    }

    System {
        id: system

        active: batteryPopup.shown || systemPopup.shown
    }

    Popup {
        id: batteryPopup

        namespace: "waybar-widgets-battery"

        BatteryPanel {
            sys: system
            shown: batteryPopup.shown
        }
    }

    Popup {
        id: systemPopup

        namespace: "waybar-widgets-system"

        SystemPanel {
            sys: system
            shown: systemPopup.shown
        }
    }

    Display {
        id: display

        active: displayPopup.shown
    }

    Popup {
        id: displayPopup

        namespace: "waybar-widgets-display"

        DisplayPanel {
            disp: display
            shown: displayPopup.shown
            onCloseRequested: displayPopup.close()
        }
    }

    Popup {
        id: powerPopup

        namespace: "waybar-widgets-power"

        PowerPanel {
            id: powerPanel

            shown: powerPopup.shown
            onCloseRequested: powerPopup.close()
        }
    }

    Calendars {
        id: calendars

        active: datePopup.shown
    }

    Popup {
        id: datePopup

        namespace: "waybar-widgets-date"
        cardWidth: 360

        DatePanel {
            cals: calendars
            shown: datePopup.shown
        }
    }

    IpcHandler {
        target: "wifi"

        function toggle(): void {
            root.toggle(wifiPopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(wifiPopup, x, y);
        }

        function open(): void {
            root.show(wifiPopup);
        }

        function close(): void {
            wifiPopup.close();
        }
    }

    IpcHandler {
        target: "volume"

        function toggle(): void {
            root.toggle(volumePopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(volumePopup, x, y);
        }

        function open(): void {
            root.show(volumePopup);
        }

        function close(): void {
            volumePopup.close();
        }
    }

    IpcHandler {
        target: "bluetooth"

        function toggle(): void {
            root.toggle(bluetoothPopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(bluetoothPopup, x, y);
        }

        function open(): void {
            root.show(bluetoothPopup);
        }

        function close(): void {
            bluetoothPopup.close();
        }
    }

    IpcHandler {
        target: "battery"

        function toggle(): void {
            root.toggle(batteryPopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(batteryPopup, x, y);
        }

        function open(): void {
            root.show(batteryPopup);
        }

        function close(): void {
            batteryPopup.close();
        }
    }

    IpcHandler {
        target: "system"

        function toggle(): void {
            root.toggle(systemPopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(systemPopup, x, y);
        }

        function open(): void {
            root.show(systemPopup);
        }

        function close(): void {
            systemPopup.close();
        }
    }

    IpcHandler {
        target: "display"

        function toggle(): void {
            root.toggle(displayPopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(displayPopup, x, y);
        }

        function open(): void {
            root.show(displayPopup);
        }

        function close(): void {
            displayPopup.close();
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle(powerPopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(powerPopup, x, y);
        }

        function open(): void {
            root.show(powerPopup);
        }

        function close(): void {
            powerPopup.close();
        }
    }

    IpcHandler {
        target: "date"

        function toggle(): void {
            root.toggle(datePopup);
        }

        function toggleAt(x: int, y: int): void {
            root.toggleAt(datePopup, x, y);
        }

        function open(): void {
            root.show(datePopup);
        }

        function close(): void {
            datePopup.close();
        }
    }
}
