import QtQuick
import Quickshell
import Quickshell.Io

// Apps known to the notification daemon: everything in its saved history plus apps that already
// have rules, with an icon for each. Also tracks Do Not Disturb through the lock screen's IPC.
Scope {
    id: apps

    property var history: []
    property bool doNotDisturb: false

    readonly property var names: {
        const set = new Set(history.map(h => h.appName).filter(n => n));
        for (const name in Store.get("notifications", "apps", {}))
            set.add(name);
        for (const name of Store.get("focus", "allowedApps", []))
            set.add(name);
        return Array.from(set).sort((a, b) => a.localeCompare(b));
    }

    function iconFor(name) {
        const entry = DesktopEntries.heuristicLookup(name);
        if (entry?.icon)
            return Quickshell.iconPath(entry.icon, true);
        const image = history.find(h => h.appName === name && h.image)?.image ?? "";
        return image.startsWith("/") ? "file://" + image : image;
    }

    function countFor(name) {
        return history.filter(h => h.appName === name).length;
    }

    function rule(name) {
        return Store.get("notifications", "apps", {})[name] ?? {};
    }

    function setRule(name, key, value) {
        const rules = Object.assign({}, Store.get("notifications", "apps", {}));
        rules[name] = Object.assign({}, rules[name] ?? {});
        rules[name][key] = value;
        Store.set("notifications", "apps", rules);
    }

    function summary(name) {
        const r = rule(name);
        if (r.allow === false)
            return qsTr("Off");
        const parts = [];
        if (r.sound !== false)
            parts.push(qsTr("Sounds"));
        if (r.banners !== false)
            parts.push(qsTr("Banners"));
        if (r.lockScreen !== false)
            parts.push(qsTr("Lock Screen"));
        return parts.length ? parts.join(", ") : qsTr("Notification Center only");
    }

    function refreshDnd() {
        Store.lockscreenIpc(["notifications", "isDnd"], (code, out) => apps.doNotDisturb = out.trim() === "true");
    }

    function setDnd(on) {
        doNotDisturb = on;
        Store.runQueued("dnd", ["qs", "-p", Store.lockscreenDir, "ipc", "call", "notifications", "setDnd", on ? "true" : "false"], () => refreshDnd());
    }

    Component.onCompleted: refreshDnd()

    // The daemon writes its history here.
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/by-shell/lockscreen/notifications.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                apps.history = data.history ?? [];
                apps.doNotDisturb = data.dnd === true || apps.doNotDisturb;
            } catch (error) {}
            apps.refreshDnd();
        }
    }
}
