import QtQuick
import Quickshell
import Quickshell.Wayland

// What every display's Dock shares: the apps (pinned ones, then running ones), which window of each
// was used last, which apps are still starting, and the window to focus after a file drop. Kept once
// here instead of once per Dock, so a second display doesn't watch every window a second time.
Scope {
    id: model

    property var pinnedApps: []

    // [{id, pinned, windows}]. Desktop entries are passed only so app matching re-runs once they
    // finish loading.
    readonly property var apps: buildApps(pinnedApps, ToplevelManager.toplevels.values,
                                          DesktopEntries.applications.values)

    function appKey(id) {
        const entry = DesktopEntries.heuristicLookup(id);
        return String(entry ? entry.id : id).toLowerCase();
    }

    function buildApps(pinned, toplevels, entries) {
        const result = [];
        const byKey = {};
        for (const id of pinned) {
            const app = {
                id: id,
                pinned: true,
                windows: []
            };
            byKey[appKey(id)] = app;
            result.push(app);
        }
        for (const toplevel of toplevels) {
            if (!toplevel.appId)
                continue;
            const key = appKey(toplevel.appId);
            let app = byKey[key];
            if (!app) {
                app = {
                    id: toplevel.appId,
                    pinned: false,
                    windows: []
                };
                byKey[key] = app;
                result.push(app);
            }
            app.windows.push(toplevel);
        }
        return result;
    }

    // In-memory focus history (window -> serial), so icons raise the most recently used window.
    // Covers every window, however it was launched; nothing is saved.
    property var focusStamps: new Map()
    property int focusSerial: 0

    function noteFocus(window) {
        focusStamps.set(window, ++focusSerial);
    }

    function forgetWindow(window) {
        focusStamps.delete(window);
    }

    function recencyOf(window) {
        return focusStamps.get(window) ?? 0;
    }

    // App keys launched from a Dock -> time they stop bouncing if no window shows up.
    property var launchingApps: ({})

    function markLaunching(appId) {
        const next = Object.assign({}, launchingApps);
        next[appKey(appId)] = Date.now() + 10000;
        launchingApps = next;
    }

    function isLaunching(app) {
        return app.windows.length === 0 && appKey(app.id) in launchingApps;
    }

    // A window of a launching app appeared: stop its bounce now rather than at the timeout,
    // so closing the app soon after doesn't make it bounce again.
    function clearLaunching(window) {
        if (!window.appId)
            return;
        const key = appKey(window.appId);
        if (!(key in launchingApps))
            return;
        const next = Object.assign({}, launchingApps);
        delete next[key];
        launchingApps = next;
    }

    function pruneLaunching() {
        const now = Date.now();
        const next = {};
        for (const key in launchingApps) {
            if (launchingApps[key] > now)
                next[key] = launchingApps[key];
        }
        launchingApps = next;
    }

    // Stops launch bounces for apps that never opened a window.
    Timer {
        interval: 1000
        repeat: true
        running: Object.keys(model.launchingApps).length > 0
        onTriggered: model.pruneLaunching()
    }

    // After files are dropped on an app, a new window of it appearing shortly after gets focus.
    property var dropWatch: null

    function watchDrop(appId) {
        dropWatch = {
            key: appKey(appId),
            until: Date.now() + 3000
        };
    }

    function checkDropWindow(window) {
        if (!dropWatch || !window.appId)
            return;
        if (Date.now() > dropWatch.until) {
            dropWatch = null;
        } else if (appKey(window.appId) === dropWatch.key) {
            dropWatch = null;
            window.activate();
        }
    }

    // Watches every window's focus (for the focus history) and new windows (for file drops).
    Variants {
        model: ToplevelManager.toplevels.values

        Connections {
            required property var modelData

            target: modelData
            Component.onCompleted: {
                if (modelData.activated)
                    model.noteFocus(modelData);
                model.checkDropWindow(modelData);
                model.clearLaunching(modelData);
            }
            Component.onDestruction: model.forgetWindow(modelData)

            function onActivatedChanged() {
                if (modelData.activated)
                    model.noteFocus(modelData);
            }

            function onAppIdChanged() {
                model.checkDropWindow(modelData);
                model.clearLaunching(modelData);
            }
        }
    }
}
