// Fixed ID so `qs ipc` finds this shell wherever the folder lives.
//@ pragma ShellId lockscreen
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
// Not used here directly: importing the folder makes Quickshell register its singletons (Settings,
// Displays), which Config.qml uses.
import qs.common

// macOS-style lock screen. Runs for the whole session, in its own process with as little in it as
// possible: if it crashed while locked, the session would be stuck behind Hyprland's red screen. So the
// notifications, which handle whatever apps send, live in desktop-shell; this shell only shows how many
// arrived while locked. Lock with
//   qs -p <this folder> ipc call lock lock          (when idle: any key unlocks for Config.graceSeconds)
//   qs -p <this folder> ipc call lock lockNow       (password right away: a lock you asked for)
//   qs -p <this folder> ipc call lock lockForSleep  (password right away and locked at once, with no
//                                                    pictures of the desktop taken first: before sleep)
ShellRoot {
    id: root

    // Lock state shared by every monitor's surface
    property bool capturing: false
    property bool pendingGrace: false
    property bool graceActive: false
    property string primaryName: ""
    property int shotVersion: 0
    // Whether pictures of the desktop were taken for this lock
    property bool hasShots: false
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lockscreen"
    property bool authBusy: false
    property string pendingPassword: ""
    property string errorText: ""
    property int failures: 0
    property bool unlocking: false

    property var nextEvent: null

    // `capture`: take pictures of the desktop first, for the slide-up when unlocking. Not before
    // sleep: the computer must be locked before it goes to sleep, not a second later.
    function lock(grace, capture) {
        if (sessionLock.locked)
            return;
        if (capturing) {
            // Already on its way: a lock that must not wait (sleep) cuts the pictures short
            if (!capture) {
                pendingGrace = pendingGrace && grace;
                engage();
            }
            return;
        }
        capturing = true;
        pendingGrace = grace;
        const names = Quickshell.screens.map(s => s.name);
        const wanted = Config.mainScreen || Hyprland.focusedMonitor?.name || "";
        primaryName = names.includes(wanted) ? wanted : names[0] ?? "";
        shotVersion++;
        if (!capture) {
            hasShots = false;
            engage();
            return;
        }
        hasShots = true;
        // Pictures of each monitor for the slide-up on unlock, in a private runtime folder.
        // Uncompressed (PPM): compressing a photo-like wallpaper into a PNG takes seconds.
        captureProc.command = ["sh", "-c", 'dir=$1; v=$2; shift 2; mkdir -p "$dir" && chmod 700 "$dir" && rm -f "$dir"/*.ppm; for n; do grim -t ppm -o "$n" "$dir/$n-$v.ppm"; done', "sh", shotDir, String(shotVersion), ...names];
        captureProc.running = true;
        captureTimeout.restart();
    }

    function engage() {
        if (!capturing)
            return;
        capturing = false;
        captureTimeout.stop();
        unlocking = false;
        errorText = "";
        graceActive = pendingGrace && Config.graceSeconds > 0;
        if (graceActive)
            graceTimer.restart();
        sessionLock.locked = true;
        syncCalendar();
    }

    function submit(password) {
        if (authBusy || unlocking)
            return;
        pendingPassword = password;
        authBusy = true;
        if (!pam.start()) {
            authBusy = false;
            pendingPassword = "";
            failures++;
        }
    }

    function finishUnlock() {
        if (unlocking)
            return;
        graceActive = false;
        unlocking = true;
        unlockTimer.restart();
    }

    function power(action) {
        const commands = {
            "sleep": ["systemctl", "suspend"],
            "restart": ["systemctl", "reboot"],
            "shutdown": ["systemctl", "poweroff"]
        };
        Quickshell.execDetached(commands[action]);
    }

    Process {
        id: captureProc

        onExited: root.engage()
    }

    // Lock even if the pictures take too long.
    Timer {
        id: captureTimeout

        interval: 1500
        onTriggered: root.engage()
    }

    Timer {
        id: graceTimer

        interval: Config.graceSeconds * 1000
        onTriggered: root.graceActive = false
    }

    Timer {
        id: unlockTimer

        // Matches LockScreen.unlockDuration, plus a frame
        interval: 570
        onTriggered: {
            sessionLock.locked = false;
            root.unlocking = false;
            Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/*.ppm', "sh", root.shotDir]);
        }
    }

    PamContext {
        id: pam

        // The system's login rules (/etc/pam.d/login), like hyprlock; includes faillock lockouts.
        config: "login"

        onPamMessage: {
            if (responseRequired)
                respond(root.pendingPassword);
        }
        onCompleted: result => {
            root.authBusy = false;
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                root.finishUnlock();
            } else {
                // Shows PAM's reason when it has one, e.g. a faillock lockout
                root.errorText = messageIsError ? message : "";
                root.failures++;
            }
        }
        onError: error => {
            root.authBusy = false;
            root.pendingPassword = "";
            root.errorText = PamError.toString(error);
            root.failures++;
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface

            color: "black"

            // Built when locking and destroyed once unlocked, so its pictures (the blurred wallpaper,
            // the desktop for the slide-up), effects and text are freed, not kept until the next lock.
            Loader {
                id: content

                // The surface's Qt window
                readonly property var qtWindow: Window.window

                anchors.fill: parent
                active: sessionLock.locked
                onActiveChanged: {
                    if (!active)
                        Qt.callLater(root.releaseGraphics, qtWindow);
                }

                sourceComponent: LockScreen {
                    primary: surface.screen?.name === root.primaryName
                    wallpaper: Config.wallpaperFor(surface.screen?.name ?? "")
                    desktopImage: surface.screen && root.hasShots ? root.shotDir + "/" + surface.screen.name + "-" + root.shotVersion + ".ppm" : ""
                    showPrivate: true
                    notificationCount: root.notificationCount
                    notificationApps: root.notificationApps
                    doNotDisturb: root.doNotDisturb
                    nextEvent: root.nextEvent
                    graceActive: root.graceActive
                    busy: root.authBusy
                    errorText: root.errorText
                    failures: root.failures
                    unlocking: root.unlocking
                    onSubmitted: password => root.submit(password)
                    onGraceUnlock: root.finishUnlock()
                    onPowerAction: action => root.power(action)
                }
            }
        }
    }

    // After unlocking: asks Qt to drop what the lock surface's window still holds for drawing (cached
    // textures, glyphs, render targets) and collects the JavaScript side of the destroyed screen.
    function releaseGraphics(qtWindow) {
        try {
            qtWindow?.releaseResources();
        } catch (error) {}
        gc();
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock(true, true);
        }

        function lockNow(): void {
            root.lock(false, true);
        }

        function lockForSleep(): void {
            root.lock(false, false);
        }

        function isLocked(): bool {
            return sessionLock.locked;
        }
    }

    // Next calendar event, from the date panel's calendar-sync.py (cached for 10 minutes)
    function syncCalendar() {
        calendarProc.running = true;
    }

    Process {
        id: calendarProc

        command: ["python3", Quickshell.env("HOME") + "/.config/waybar-widgets/calendar-sync.py", "--days-back", "1", "--days-ahead", "2"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const now = new Date();
                    const events = data.events.map(e => {
                        let start = new Date(e.start);
                        let end = new Date(e.end);
                        if (e.allDay) {
                            const [y, m, d] = e.day.split("-").map(Number);
                            start = new Date(y, m - 1, d);
                            end = new Date(y, m - 1, d + e.days);
                        }
                        return {
                            title: e.title,
                            location: e.location,
                            start: start,
                            end: end,
                            allDay: e.allDay,
                            color: data.calendars[e.calendar]?.color ?? Theme.accent
                        };
                    }).filter(e => e.end > now);
                    // Timed events first (current or next), all-day ones only when nothing else is coming up
                    root.nextEvent = events.filter(e => !e.allDay).sort((a, b) => a.start - b.start)[0] ?? events[0] ?? null;
                } catch (error) {
                    root.nextEvent = null;
                }
            }
        }
    }

    Timer {
        interval: 600000
        repeat: true
        running: sessionLock.locked
        onTriggered: root.syncCalendar()
    }

    // ---- Notifications ----

    // The daemon runs in desktop-shell (see the top of this file). It's told when the screen locks
    // and unlocks, and writes how many notifications arrived since, and from which apps, to its
    // status file (the one waybar's bell reads): {dnd, lockCount, lockApps}.
    property int notificationCount: 0
    property var notificationApps: []
    property bool doNotDisturb: false

    Connections {
        target: sessionLock

        function onLockedChanged() {
            Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/desktop-shell", "ipc", "call", "notifications", "setLocked",
                                     sessionLock.locked ? "true" : "false"]);
            if (!sessionLock.locked) {
                root.notificationCount = 0;
                root.notificationApps = [];
            }
        }
    }

    FileView {
        path: root.shotDir + "/notifications.json"
        watchChanges: sessionLock.locked
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const status = JSON.parse(text());
                root.doNotDisturb = status.dnd === true;
                // Only numbers and names are taken from it, and only while locked
                root.notificationCount = sessionLock.locked ? Math.max(0, Math.round(Number(status.lockCount) || 0)) : 0;
                root.notificationApps = sessionLock.locked && Array.isArray(status.lockApps) ? status.lockApps.slice(0, 4).map(a => String(a).slice(0, 40)) : [];
            } catch (error) {}
        }
    }
}
