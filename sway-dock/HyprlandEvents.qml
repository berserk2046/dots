import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Hyprland IPC: which apps have urgent windows (for the attention bounce) and force quitting,
// which needs process IDs from `hyprctl clients`.
Scope {
    id: root

    readonly property var urgentAppIds: Hyprland.toplevels.values.filter(toplevel => toplevel.urgent).map(toplevel => appIdOf(toplevel))

    function appIdOf(toplevel) {
        return String(toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "").toLowerCase();
    }

    // Kills (SIGKILL) every process owning a window whose app id satisfies `matches`.
    function forceQuit(matches) {
        clientsProcess.matches = matches;
        clientsProcess.running = true;
    }

    Process {
        id: clientsProcess

        property var matches: appId => false

        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pids = JSON.parse(text).filter(client => client.pid > 0 && clientsProcess.matches(String(client.class || client.initialClass || "").toLowerCase())).map(client => String(client.pid));
                    if (pids.length > 0)
                        Quickshell.execDetached(["kill", "-KILL", ...new Set(pids)]);
                } catch (error) {}
            }
        }
    }
}
