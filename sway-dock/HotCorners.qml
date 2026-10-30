import QtQuick
import Quickshell
import Quickshell.Wayland

// Hot corners (System Settings → Desktop & Dock → Hot Corners): resting the pointer in a screen
// corner for a moment runs the action picked for it. Corners with no action take no input.
Scope {
    id: corners

    required property var screen
    // Corner name -> action name, e.g. {topLeft: "lock"}
    property var actions: ({})

    readonly property var commands: ({
            "lock": ["qs", "-p", Quickshell.env("HOME") + "/.config/lockscreen", "ipc", "call", "lock", "lock"],
            "notifications": ["qs", "-p", Quickshell.env("HOME") + "/.config/lockscreen", "ipc", "call", "notifications", "toggle"],
            "launcher": ["sh", "-c", "pgrep -x fuzzel >/dev/null || hyprctl dispatch 'hl.dsp.exec_cmd(\"fuzzel\")'"],
            "displaySleep": ["hyprctl", "dispatch", 'hl.dsp.dpms({ action = "off" })'],
            "settings": ["sh", "-c", "qs -p ~/.config/system-settings ipc call settings toggle 2>/dev/null || qs -p ~/.config/system-settings -d"]
        })

    Variants {
        model: ["topLeft", "topRight", "bottomLeft", "bottomRight"]

        PanelWindow {
            id: corner

            required property string modelData
            readonly property string action: corners.actions[modelData] ?? ""

            screen: corners.screen
            visible: action !== "" && corners.commands[action] !== undefined
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
