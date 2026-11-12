pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings written by the System Settings app (~/.config/system-settings/settings.json), re-read
// whenever the file changes. One copy per process: the Dock, the window switcher, the desktop, the
// panels, the notifications and the lock screen all read this one. Missing values use the fallback
// given to get().
// The login screen can't read your home folder: it reads the copy greetd-install.sh puts next to
// greeter.qml.
Singleton {
    id: settings

    property var data: ({})
    // Once settings.json has been read (or found missing), so nothing shows defaults first
    property bool loaded: false

    readonly property bool greeter: Quickshell.shellDir.startsWith("/etc/")
    readonly property string path: greeter ? Quickshell.shellDir + "/settings.json"
                                           : Quickshell.env("HOME") + "/.config/system-settings/settings.json"

    function get(section, key, fallback) {
        const value = data?.[section]?.[key];
        return value === undefined || value === null ? fallback : value;
    }

    FileView {
        path: settings.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                settings.data = JSON.parse(text());
            } catch (error) {
                settings.data = {};
            }
            settings.loaded = true;
        }
        onLoadFailed: {
            settings.data = {};
            settings.loaded = true;
        }
    }
}
