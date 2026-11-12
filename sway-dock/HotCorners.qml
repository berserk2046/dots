import QtQuick
import Quickshell
import Quickshell.Wayland

// Hot corners (System Settings → Desktop & Dock → Hot Corners): resting the pointer in a screen
// corner for a moment runs the action picked for it. Corners with no action take no input.
// A corner where another display continues (side by side, or one above the other) isn't a corner of
// the desktop: the pointer passes through it on its way to the other display, so it stays off.
Scope {
    id: corners

    required property var screen
    // Corner name -> action name, e.g. {topLeft: "lock"}
    property var actions: ({})

    readonly property var commands: ({
            // Asks for the password right away: a lock you asked for has no grace period
            "lock": ["qs", "-p", Quickshell.env("HOME") + "/.config/lockscreen", "ipc", "call", "lock", "lockNow"],
            "notifications": ["qs", "-p", Quickshell.env("HOME") + "/.config/desktop-shell", "ipc", "call", "notifications", "toggle"],
            "launcher": ["sh", "-c", "pgrep -x fuzzel >/dev/null || hyprctl dispatch 'hl.dsp.exec_cmd(\"fuzzel\")'"],
            "displaySleep": ["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "off" })'],
            "settings": ["sh", "-c", "qs -p ~/.config/system-settings ipc call settings toggle 2>/dev/null || qs -p ~/.config/system-settings -d"]
        })

    // Whether another display touches this one at that corner
    function shared(corner) {
        const s = corners.screen;
        if (!s)
            return false;
        const x = corner.endsWith("Left") ? s.x : s.x + s.width - 1;
        const y = corner.startsWith("top") ? s.y : s.y + s.height - 1;
        const dx = corner.endsWith("Left") ? -1 : 1;
        const dy = corner.startsWith("top") ? -1 : 1;
        const taken = (px, py) => Quickshell.screens.some(o => o !== s && o.name !== s.name && px >= o.x && px < o.x + o.width
                                                               && py >= o.y && py < o.y + o.height);
        return taken(x + dx, y) || taken(x, y + dy) || taken(x + dx, y + dy);
    }

    Variants {
        model: ["topLeft", "topRight", "bottomLeft", "bottomRight"]

        PanelWindow {
            id: corner

            required property string modelData
            readonly property string action: corners.actions[modelData] ?? ""

            screen: corners.screen
            visible: action !== "" && corners.commands[action] !== undefined && !corners.shared(modelData)
            anchors {
                top: modelData.startsWith("top")
                bottom: modelData.startsWith("bottom")
                left: modelData.endsWith("Left")
                right: modelData.endsWith("Right")
            }
            implicitWidth: 2
            implicitHeight: 2
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "sway-dock-corner"
            WlrLayershell.layer: WlrLayer.Overlay

            HoverHandler {
                id: hover
            }

            // Fires once per visit; leaving the corner re-arms it.
            Timer {
                interval: 250
                running: hover.hovered
                onTriggered: Quickshell.execDetached(corners.commands[corner.action])
            }
        }
    }
}
