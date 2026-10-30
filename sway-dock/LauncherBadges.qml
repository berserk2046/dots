import QtQuick
import Quickshell
import Quickshell.Io

// Badge counts and progress bars that apps publish over D-Bus with the Unity LauncherEntry
// API (used by Telegram, KDE apps, some Electron apps, ...). Only that signal is monitored.
Scope {
    id: root

    // lowercase desktop ID -> { count, countVisible, progress, progressVisible, urgent }
    property var entries: ({})

    readonly property var keys: ({
            "count": "count",
            "count-visible": "countVisible",
            "progress": "progress",
            "progress-visible": "progressVisible",
            "urgent": "urgent"
        })

    function badgeFor(desktopId) {
        return entries[String(desktopId).toLowerCase()] ?? null;
    }

    // Updates only carry the properties that changed, so merge them into what we have.
    function update(uri, properties) {
        const id = String(uri).replace(/^application:\/\//, "").replace(/\.desktop$/, "").toLowerCase();
        const entry = Object.assign({}, entries[id] || {});
        for (const key in properties) {
            if (key in keys)
                entry[keys[key]] = properties[key].data;
        }
        const next = Object.assign({}, entries);
        next[id] = entry;
        entries = next;
    }

    Process {
        command: ["busctl", "--user", "monitor", "--json=short", "--match",
            "type='signal',interface='com.canonical.Unity.LauncherEntry',member='Update'"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const [uri, properties] = JSON.parse(line).payload.data;
                    root.update(uri, properties);
                } catch (error) {}
            }
        }
    }
}
