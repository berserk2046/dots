pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Light or dark, following the GTK color scheme that System Settings → Appearance sets. Read once
// per process and shared by every part (the Dock's, the switcher's and the panels' colors, the
// desktop's menus), instead of each part watching and asking by itself.
Singleton {
    id: appearance

    property string scheme: "" // org.gnome.desktop.interface color-scheme
    readonly property bool light: scheme === "prefer-light"

    // Read again whenever dconf's database changes (every gsettings write rewrites it) instead of
    // keeping a `gsettings monitor` running alongside: one left behind by a shell that didn't quit
    // cleanly lingered until the scheme next changed. Any app's gsettings write lands here, so the
    // reads are bundled: one shortly after the last change.
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/dconf/user"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            readTimer.restart();
        }
    }

    Timer {
        id: readTimer

        interval: 80
        onTriggered: appearance.readScheme()
    }

    property bool queued: false

    function readScheme() {
        if (schemeProc.running)
            queued = true;
        else
            schemeProc.running = true;
    }

    Process {
        id: schemeProc

        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector {
            onStreamFinished: appearance.scheme = text.replace(/'/g, "").trim() // "'prefer-dark'"
        }
        onExited: {
            if (appearance.queued) {
                appearance.queued = false;
                running = true;
            }
        }
    }

    Component.onCompleted: readScheme()
}
