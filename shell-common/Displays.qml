pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which monitor is which. A display is told apart by its make, model and serial number (Hyprland's
// monitor description), so its settings (its Dock, its wallpaper, its desktop arrangement, being the
// main display) follow the monitor to whatever port it's plugged into. A display without a serial
// number (most built-in screens) is told apart by its port too.
//
// Settings saved per display use this key. Older settings.json files used the port name ("DP-1"):
// pick() still finds those.
Singleton {
    id: displays

    // Connected displays: port name -> key
    readonly property var keys: {
        const result = {};
        for (const m of Hyprland.monitors.values) {
            const o = m.lastIpcObject;
            if (o && o.description)
                result[m.name] = o.serial ? o.description : o.description + " (" + m.name + ")";
        }
        return result;
    }

    function keyOf(name) {
        return keys[name] ?? name ?? "";
    }

    // The port a display is on right now; "" while it isn't connected
    function nameOf(key) {
        for (const name in keys) {
            if (keys[name] === key)
                return name;
        }
        return Quickshell.screens.some(s => s.name === key) ? key : "";
    }

    // A display's entry in a per-display map from settings.json
    function pick(map, name) {
        if (!map || !name)
            return undefined;
        const key = keys[name];
        return (key !== undefined ? map[key] : undefined) ?? map[name];
    }

    // The main display (System Settings → Displays): its port name, or "" when none is picked or the
    // picked one isn't connected.
    function mainName(wanted) {
        return wanted ? nameOf(wanted) : "";
    }

    // The same without Hyprland's help, for code that only has `hyprctl monitors -j` objects
    function keyFromIpc(o) {
        if (!o || !o.description)
            return o?.name ?? "";
        return o.serial ? o.description : o.description + " (" + o.name + ")";
    }

    Component.onCompleted: Hyprland.refreshMonitors()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "monitoraddedv2" || event.name === "monitorremovedv2" || event.name === "configreloaded")
                refresh.restart();
        }
    }

    Timer {
        id: refresh

        interval: 300
        onTriggered: Hyprland.refreshMonitors()
    }
}
