import QtQuick
import Quickshell
import Quickshell.Io

// Settings written by the System Settings app (~/.config/system-settings/settings.json),
// re-read whenever the file changes. Missing values use the fallback given to get().
Scope {
    id: settings

    property var data: ({})

    function get(section, key, fallback) {
        const value = data?.[section]?.[key];
        return value === undefined || value === null ? fallback : value;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/system-settings/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                settings.data = JSON.parse(text());
            } catch (error) {
                settings.data = {};
            }
        }
        onLoadFailed: settings.data = {}
    }
}
