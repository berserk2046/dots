import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon: banners while unlocked, the lock screen list while locked, a saved history
// for the Notification Center, and Do Not Disturb. Do Not Disturb silences banners and the lock screen
// (critical notifications and apps allowed in Focus still show); everything still lands in the history.
// Per-app rules, the banner duration and the Do Not Disturb schedule come from Config (System Settings).
// Waybar's custom/notifications module reads `statusPath` and is refreshed with SIGRTMIN+9.
Scope {
    id: daemon

    property bool locked: false

    property var lockNotifications: [] // {notification, received}, newest first
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
    // ~/.local/state/quickshell/by-shell/lockscreen/notifications.json
    FileView {
        path: Quickshell.statePath("notifications.json")
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
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1#file://}"', "sh", Quickshell.stateDir]);
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
        const rule = Config.appRules[notification.appName] ?? {};
        // Notifications turned off for this app: dropped entirely, as on macOS.
        if (rule.allow === false)
            return;
        notification.tracked = true;
        notification.closed.connect(() => forget(notification));
        if (!notification.transient)
            remember(notification);
        const breaksThrough = notification.urgency === NotificationUrgency.Critical
                              || Config.focusAllowedApps.includes(notification.appName);
        if (doNotDisturb && !breaksThrough)
            return;
        if (rule.sound !== false && notification.hints?.["suppress-sound"] !== true)
            playAlert();
        const entry = {
            notification: notification,
            received: new Date()
        };
        if (locked) {
            if (rule.lockScreen !== false)
                lockNotifications = [entry, ...lockNotifications];
        } else if (!centerOpen && rule.banners !== false) {
            banners = [entry, ...banners].slice(0, 4);
        }
    }

    // One alert at a time, so a burst of notifications doesn't stack sounds.
    property real lastAlert: 0

    function playAlert() {
        if (Config.alertSoundPath === "" || Date.now() - lastAlert < 300)
            return;
        lastAlert = Date.now();
        Quickshell.execDetached(["pw-play", "--volume", String(Config.alertVolume), Config.alertSoundPath]);
    }

    function minutesOf(time) {
        const [hours, minutes] = String(time).split(":").map(Number);
        return (hours || 0) * 60 + (minutes || 0);
    }

    // Whether the Do Not Disturb schedule covers this moment; the range may cross midnight.
    function inSchedule(time) {
        const schedule = Config.focusSchedule;
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
        const to = minutesOf(Config.focusSchedule?.to ?? "07:00");
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

    // Icon that still works after the notification is gone: a file or themed icon.
    // Inline image data (e.g. a sender's avatar) only lives as long as the notification.
    function lastingIcon(n) {
        if (n.image && !n.image.startsWith("image://qsimage"))
            return n.image;
        if (n.appIcon)
            return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return n.desktopEntry ? Quickshell.iconPath(n.desktopEntry, true) : "";
    }

    function remember(n) {
        const id = Date.now() + "-" + n.id;
        live = Object.assign({}, live, {
            [id]: n
        });
        store.history = [{
                id: id,
                appName: n.appName,
                summary: n.summary,
                body: n.body,
                image: lastingIcon(n),
                appIcon: "",
                desktopEntry: "",
                time: Date.now()
            }, ...store.history].slice(0, Math.max(1, Config.historyLimit));
        if (!centerOpen)
            store.unread++;
        writeStatus();
    }

    function forget(notification) {
        lockNotifications = lockNotifications.filter(e => e.notification !== notification);
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

    function clearLockNotifications() {
        for (const entry of lockNotifications)
            entry.notification.expire();
        lockNotifications = [];
    }

    // For Waybar: bell (with the unread count) or moon while Do Not Disturb is on.
    // One write at a time, so quick bursts of notifications can't land out of order.
    function writeStatus() {
        if (statusProc.running) {
            statusProc.again = true;
            return;
        }
        const unread = store.unread;
        const status = {
            text: doNotDisturb ? Theme.iMoon : Theme.iBell + (unread > 0 ? " " + unread : ""),
            class: doNotDisturb ? "dnd" : unread > 0 ? "unread" : "none",
            tooltip: doNotDisturb ? qsTr("Do Not Disturb is on") : qsTr("%n unread notification(s)", "", unread)
        };
        statusProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1" && pkill -RTMIN+9 waybar', "sh", statusPath, JSON.stringify(status)];
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
        duration: Config.bannerSeconds * 1000
        showText: Config.previews !== "never"
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
    }
}
