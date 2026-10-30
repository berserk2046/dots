// Fixed ID so `qs ipc` finds this shell wherever the folder lives.
//@ pragma ShellId lockscreen
//@ pragma IconTheme MacTahoe-dark
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// macOS-style lock screen and notification daemon. Runs for the whole session; lock with
//   qs -p <this folder> ipc call lock lock       (any key unlocks for Config.graceSeconds)
//   qs -p <this folder> ipc call lock lockNow    (password right away, e.g. before sleep)
// and open the Notification Center with
//   qs -p <this folder> ipc call notifications toggle   (also: toggleDnd, clearAll)
ShellRoot {
    id: root

    // Lock state shared by every monitor's surface
    property bool capturing: false
    property bool pendingGrace: false
    property bool graceActive: false
    property string primaryName: ""
    property int shotVersion: 0
    readonly property string shotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lockscreen"
    property bool authBusy: false
    property string pendingPassword: ""
    property string errorText: ""
    property int failures: 0
    property bool unlocking: false

    property var nextEvent: null

    function lock(grace) {
        if (sessionLock.locked || capturing)
            return;
        capturing = true;
        pendingGrace = grace;
        const names = Quickshell.screens.map(s => s.name);
        const wanted = Config.mainScreen || Hyprland.focusedMonitor?.name || "";
        primaryName = names.includes(wanted) ? wanted : names[0] ?? "";
        shotVersion++;
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
        daemon.clearLockNotifications();
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
            daemon.clearLockNotifications();
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

            LockScreen {
                primary: surface.screen?.name === root.primaryName
                desktopImage: root.shotDir + "/" + (surface.screen?.name ?? "") + "-" + root.shotVersion + ".ppm"
                showPrivate: true
                notifications: daemon.lockNotifications
                doNotDisturb: daemon.doNotDisturb
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

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock(true);
        }

        function lockNow(): void {
            root.lock(false);
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

    // Notifications: banners, lock screen list, history and Notification Center, Do Not Disturb
    NotificationDaemon {
        id: daemon

        locked: sessionLock.locked
    }
}
