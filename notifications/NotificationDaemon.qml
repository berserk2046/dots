import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.common

// The notification daemon: banners while unlocked, a saved history for the Notification Center, and
// Do Not Disturb. Do Not Disturb silences banners and the lock screen (critical notifications and apps
// allowed in Focus still show); everything still lands in the history. Per-app rules, the banner
// duration and the Do Not Disturb schedule come from System Settings (Settings).
//
// Runs in desktop-shell, not in the lock screen's process: notifications are text, pictures and icons
// sent by any app, and the lock screen must not be the one to handle them (if it crashed while locked,
// the session would be stuck). The lock screen only learns how many arrived while locked, and from
// which apps: it tells this daemon when it locks and unlocks (`ipc call notifications setLocked`), and
// reads the count from `statusPath`. Waybar's custom/notifications module reads that file too and is
// refreshed with SIGRTMIN+9.
Scope {
    id: daemon

    // Set by the lock screen (setLocked)
    property bool locked: false

    // App names of the notifications that arrived while locked, newest first
    property var lockApps: []

    // ---- From System Settings ----

    // Notification text: "always" or "unlocked" (banners show it), or "never". The lock screen never
    // shows text, only how many notifications wait and from which apps ("never" hides the apps too).
    readonly property string previews: Settings.get("notifications", "previews", "unlocked")
    // Seconds a banner stays on screen (critical ones stay until closed).
    readonly property int bannerSeconds: Settings.get("notifications", "bannerSeconds", 5)
    // Notifications kept in the Notification Center (oldest are dropped first).
    readonly property int historyLimit: Settings.get("notifications", "historyLimit", 200)
    // Per app (by app name): {allow, banners, lockScreen, sound}; apps not listed get everything.
    readonly property var appRules: Settings.get("notifications", "apps", {})
    // Scheduled Do Not Disturb: {enabled, from: "22:00", to: "07:00"}, and apps that still notify
    // during Do Not Disturb.
    readonly property var focusSchedule: Settings.get("focus", "schedule", {})
    readonly property var focusAllowedApps: Settings.get("focus", "allowedApps", [])
    // Alert sound: a sound from System Settings' sounds folder (by name) or a file path; "" plays
    // nothing. Volume is 0..1.
    readonly property string alertSound: Settings.get("sound", "alert", "Ping")
    readonly property real alertVolume: Settings.get("sound", "alertVolume", 0.6)
    readonly property string alertSoundPath: alertSound === "" ? "" : alertSound.startsWith("/") ? alertSound
                                             : Quickshell.env("HOME") + "/.config/system-settings/sounds/" + alertSound + ".wav"

    property var banners: []
    property bool centerOpen: false
    // On by hand, or during the schedule (unless turned off for the rest of that period).
    readonly property bool doNotDisturb: store.dnd || (inSchedule(clock) && clock >= store.dndSkipUntil)
    property real clock: Date.now()
    readonly property var history: store.history // {id, appName, summary, body, image, time}, newest first

    // History id -> Notification, while the app still has it open (for click actions).
    property var live: ({})

    readonly property string statusPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lockscreen/notifications.json"

    // History, unread count and Do Not Disturb survive restarts in
    // ~/.local/state/quickshell/by-shell/lockscreen/notifications.json (where they have always been,
    // from when the lock screen's shell was the daemon). The folder is private (mode 700): the history
    // holds the text of your notifications.
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
                                       + "/quickshell/by-shell/lockscreen"

    FileView {
        path: daemon.stateDir + "/notifications.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: daemon.writeStatus()

        JsonAdapter {
            id: store

            property var history: []
            property bool dnd: false
            property int unread: 0
            // Turning Do Not Disturb off during its schedule skips the schedule until this time.
            property real dndSkipUntil: 0
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1"; [ ! -f "$1/notifications.json" ] || chmod 600 "$1/notifications.json"',
                                 "sh", stateDir]);
        writeStatus();
    }

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: notification => daemon.receive(notification)
    }

    function receive(notification) {
        const rule = appRules[notification.appName] ?? {};
        // Notifications turned off for this app: dropped entirely, as on macOS.
        if (rule.allow === false)
            return;
        notification.tracked = true;
        notification.closed.connect(() => forget(notification));
        if (!notification.transient)
            remember(notification);
        const breaksThrough = notification.urgency === NotificationUrgency.Critical
                              || focusAllowedApps.includes(notification.appName);
        if (doNotDisturb && !breaksThrough)
            return;
        if (rule.sound !== false && notification.hints?.["suppress-sound"] !== true)
            playAlert();
        if (locked) {
            if (rule.lockScreen !== false) {
                lockApps = [notification.appName || qsTr("Notification"), ...lockApps];
                writeStatus();
            }
        } else if (!centerOpen && rule.banners !== false) {
            banners = [{
                    notification: notification,
                    received: new Date()
                }, ...banners].slice(0, 4);
        }
    }

    // The lock screen locked or unlocked. What arrived while locked is in the Notification Center;
    // the lock screen's count starts over.
    function setLocked(on) {
        locked = on;
        lockApps = [];
        if (on) {
            for (const entry of banners)
                entry.notification.expire();
            banners = [];
            centerOpen = false;
        }
        writeStatus();
    }

    // One alert at a time, so a burst of notifications doesn't stack sounds.
    property real lastAlert: 0

    function playAlert() {
        if (alertSoundPath === "" || Date.now() - lastAlert < 300)
            return;
        lastAlert = Date.now();
        Quickshell.execDetached(["pw-play", "--volume", String(alertVolume), alertSoundPath]);
    }

    function minutesOf(time) {
        const [hours, minutes] = String(time).split(":").map(Number);
        return (hours || 0) * 60 + (minutes || 0);
    }

    // Whether the Do Not Disturb schedule covers this moment; the range may cross midnight.
    function inSchedule(time) {
        const schedule = focusSchedule;
        if (!schedule?.enabled)
            return false;
        const date = new Date(time);
        const now = date.getHours() * 60 + date.getMinutes();
        const from = minutesOf(schedule.from ?? "22:00");
        const to = minutesOf(schedule.to ?? "07:00");
        return from <= to ? now >= from && now < to : now >= from || now < to;
    }

    // End of the scheduled period running at this moment.
    function scheduleEnd(time) {
        const to = minutesOf(focusSchedule?.to ?? "07:00");
        const end = new Date(time);
        end.setHours(Math.floor(to / 60), to % 60, 0, 0);
        if (end.getTime() <= time)
            end.setDate(end.getDate() + 1);
        return end.getTime();
    }

    onDoNotDisturbChanged: writeStatus()

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: daemon.clock = Date.now()
    }

    // A picture or icon a notification names, if it's one to show: a file on this computer, picture
    // data sent with the notification, or an icon from the icon theme. Anything else (a web address,
    // say) is dropped: showing it would fetch whatever address an app or a web page put there.
    function safeImage(source) {
        source = String(source ?? "");
        if (source === "")
            return "";
        if (source.startsWith("/"))
            return "file://" + source;
        if (source.startsWith("file:///") || source.startsWith("image://qsimage/") || source.startsWith("image://icon/"))
            return source;
        if (source.includes(":") || source.includes("/"))
            return "";
        return Quickshell.iconPath(source, true);
    }

    function iconOf(n) {
        return safeImage(n.image) || safeImage(n.appIcon) || safeImage(n.desktopEntry);
    }

    // Icon that still works after the notification is gone: a file or themed icon.
    // Inline image data (e.g. a sender's avatar) only lives as long as the notification.
    function lastingIcon(n) {
        const image = safeImage(n.image);
        if (image && !image.startsWith("image://qsimage"))
            return image;
        return safeImage(n.appIcon) || safeImage(n.desktopEntry);
    }

    function remember(n) {
        const id = Date.now() + "-" + n.id;
        live = Object.assign({}, live, {
            [id]: n
        });
        store.history = [{
                id: id,
                appName: n.appName,
                // With previews off, the text isn't kept either
                summary: previews === "never" ? "" : n.summary,
                body: previews === "never" ? "" : n.body,
                image: lastingIcon(n),
                appIcon: "",
                desktopEntry: "",
                time: Date.now()
            }, ...store.history].slice(0, Math.max(1, historyLimit));
        if (!centerOpen)
            store.unread++;
        writeStatus();
    }

    function forget(notification) {
        banners = banners.filter(e => e.notification !== notification);
        const next = {};
        for (const id in live) {
            if (live[id] !== notification)
                next[id] = live[id];
        }
        live = next;
    }

    // Deleting from the history also closes the notification in its app, if it's still open.
    function remove(ids) {
        for (const id of ids)
            live[id]?.dismiss();
        store.history = store.history.filter(h => !ids.includes(h.id));
        writeStatus();
    }

    function clearApp(appName) {
        remove(store.history.filter(h => h.appName === appName).map(h => h.id));
    }

    function clearAll() {
        remove(store.history.map(h => h.id));
    }

    // Runs the notification's default action (usually opening the app or the chat), if it's still open.
    function activate(id) {
        const n = live[id];
        const action = n?.actions.find(a => a.identifier === "default");
        if (action) {
            action.invoke();
            centerOpen = false;
        }
    }

    function setDnd(on) {
        clock = Date.now();
        store.dnd = on;
        // Off during the schedule: skip the rest of this scheduled period.
        store.dndSkipUntil = !on && inSchedule(clock) ? scheduleEnd(clock) : 0;
        if (on) {
            for (const entry of banners)
                entry.notification.expire();
            banners = [];
        }
        writeStatus();
    }

    function setCenterOpen(open) {
        centerOpen = open;
        if (open) {
            store.unread = 0;
            for (const entry of banners)
                entry.notification.expire();
            banners = [];
            writeStatus();
        }
    }

    // For waybar's bell (the unread count, or a moon while Do Not Disturb is on), which reads the
    // status file when it gets SIGRTMIN+9, and for the lock screen, which reads the same file.
    // One write at a time, so quick bursts of notifications can't land out of order.
    function writeStatus() {
        if (statusProc.running) {
            statusProc.again = true;
            return;
        }
        const unread = store.unread;
        const status = {
            // For waybar's bell
            text: doNotDisturb ? Theme.iMoon : Theme.iBell + (unread > 0 ? " " + unread : ""),
            class: doNotDisturb ? "dnd" : unread > 0 ? "unread" : "none",
            tooltip: doNotDisturb ? qsTr("Do Not Disturb is on") : qsTr("%n unread notification(s)", "", unread),
            // For the lock screen (waybar ignores these)
            dnd: doNotDisturb,
            lockCount: lockApps.length,
            lockApps: previews === "never" ? [] : [...new Set(lockApps)].slice(0, 4)
        };
        statusProc.command = ["sh", "-c", 'umask 077; mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1.tmp" && mv "$1.tmp" "$1" && pkill -RTMIN+9 -x waybar',
                              "sh", statusPath, JSON.stringify(status)];
        statusProc.running = true;
    }

    Process {
        id: statusProc

        property bool again: false

        onExited: {
            if (again) {
                again = false;
                daemon.writeStatus();
            }
        }
    }

    NotificationBanners {
        banners: daemon.banners
        duration: daemon.bannerSeconds * 1000
        showText: daemon.previews !== "never"
        iconOf: n => daemon.iconOf(n)
        onBannerExpired: entry => entry.notification.expire()
        onBannerClosed: entry => entry.notification.dismiss()
        onBannerActivated: entry => {
            const action = entry.notification.actions.find(a => a.identifier === "default");
            if (action)
                action.invoke();
            else
                entry.notification.dismiss();
        }
    }

    NotificationCenter {
        daemon: daemon
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            daemon.setCenterOpen(!daemon.centerOpen);
        }

        function open(): void {
            daemon.setCenterOpen(true);
        }

        function close(): void {
            daemon.setCenterOpen(false);
        }

        function toggleDnd(): void {
            daemon.setDnd(!daemon.doNotDisturb);
        }

        function setDnd(on: bool): void {
            daemon.setDnd(on);
        }

        function isDnd(): bool {
            return daemon.doNotDisturb;
        }

        function clearAll(): void {
            daemon.clearAll();
        }

        function clearApp(appName: string): void {
            daemon.clearApp(appName);
        }

        // From the lock screen's shell, when it locks and unlocks
        function setLocked(on: bool): void {
            daemon.setLocked(on);
        }
    }
}
