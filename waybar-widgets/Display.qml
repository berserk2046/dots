import QtQuick
import Quickshell
import Quickshell.Io

// Brightness (brightnessctl) and Night Shift (hyprsunset). Night Shift uses System Settings' values
// (`displays.nightShift` in its settings.json, so both stay in sync) and is applied the same way as
// its Store.writeNightShift: hyprsunset.conf is rewritten and hyprsunset restarted.
Scope {
    id: display

    property bool active: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string settingsPath: home + "/.config/system-settings/settings.json"
    readonly property string sunsetPath: home + "/.config/hypr/hyprsunset.conf"
    readonly property string luaPath: home + "/.config/hypr/system-settings.lua"

    property real brightness: -1 // 0..1, -1 without a backlight

    property var settings: ({})
    // Only written back once read (or missing), so a settings.json that doesn't parse isn't replaced.
    property bool writable: false
    readonly property var night: Object.assign({
        schedule: "off",
        from: "22:00",
        to: "7:00",
        manual: false,
        temperature: 4500
    }, settings?.displays?.nightShift ?? {})

    // Minutes since midnight, for whether the schedule is on right now.
    property int now: 0
    readonly property bool inSchedule: {
        const from = minutesOf(night.from), to = minutesOf(night.to);
        return from < to ? now >= from && now < to : now >= from || now < to;
    }
    readonly property bool nightShiftOn: night.manual === true || (night.schedule === "custom" && inSchedule)

    function minutesOf(time) {
        const [h, m] = String(time).split(":").map(Number);
        return (h || 0) * 60 + (m || 0);
    }

    // "22:30" -> "10:30 PM", like System Settings' time pickers.
    function timeLabel(time) {
        const minutes = minutesOf(time);
        const h = Math.floor(minutes / 60);
        return (h % 12 === 0 ? 12 : h % 12) + ":" + String(minutes % 60).padStart(2, "0") + (h < 12 ? " AM" : " PM");
    }

    // A time moved by `delta` minutes, wrapping around midnight, in settings.json's "H:MM" form.
    function shiftTime(time, delta) {
        const minutes = ((minutesOf(time) + delta) % 1440 + 1440) % 1440;
        return Math.floor(minutes / 60) + ":" + String(minutes % 60).padStart(2, "0");
    }

    onActiveChanged: {
        if (active) {
            updateNow();
            readBrightness();
        }
    }

    function updateNow() {
        const d = new Date();
        now = d.getHours() * 60 + d.getMinutes();
    }

    // ---- Brightness ----

    Process {
        id: readProc

        command: ["brightnessctl", "-m", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent%,max
                const percent = parseInt(text.split(",")[3]);
                display.brightness = isNaN(percent) ? -1 : percent / 100;
            }
        }
    }

    function readBrightness() {
        if (!readProc.running)
            readProc.running = true;
    }

    // Follows changes made elsewhere (scrolling on the bar, brightness keys) while open; restarted on
    // every move of the slider so a read doesn't jump it back mid-drag.
    Timer {
        id: pollTimer

        interval: 1000
        repeat: true
        running: display.active
        onTriggered: {
            display.updateNow();
            display.readBrightness();
        }
    }

    function setBrightness(value) {
        brightness = Math.max(0.01, Math.min(1, value));
        pollTimer.restart();
        brightnessTimer.restart();
    }

    Timer {
        id: brightnessTimer

        interval: 60
        onTriggered: Quickshell.execDetached(["sh", "-c", 'brightnessctl -q set "$1%" || sudo -n brightnessctl -q set "$1%"', "sh",
                                              String(Math.round(display.brightness * 100))])
    }

    // ---- Night Shift ----

    FileView {
        id: settingsFile

        path: display.settingsPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // Keep a change of ours that isn't saved yet.
            if (applyTimer.running)
                return;
            try {
                display.settings = JSON.parse(text());
                display.writable = true;
            } catch (error) {
                display.writable = false;
            }
        }
        onLoadFailed: {
            display.settings = {};
            display.writable = true;
        }
    }

    function setNight(key, value) {
        const next = Object.assign({}, night);
        next[key] = value;
        const data = Object.assign({}, settings);
        data.displays = Object.assign({}, data.displays ?? {}, {
            nightShift: next
        });
        settings = data;
        // Saves once the temperature slider rests, as System Settings does.
        applyTimer.interval = key === "temperature" ? 300 : 0;
        applyTimer.restart();
    }

    Timer {
        id: applyTimer

        onTriggered: {
            if (display.writable)
                settingsFile.setText(JSON.stringify(display.settings, null, 2) + "\n");
            display.applyNightShift();
        }
    }

    // Same profiles as Store.writeNightShift: by hand, one warm profile all day; on a schedule, warm
    // from `from` and normal again at `to`. hyprland.lua starts hyprsunset at login if `night_shift`
    // in system-settings.lua is true, so that line follows too.
    function applyNightShift() {
        const lines = ["# Written by System Settings → Displays → Night Shift; changes here are overwritten."];
        const profile = (time, body) => lines.push("", "profile {", "    time = " + time, ...body.map(l => "    " + l), "}");
        if (night.manual) {
            profile("0:00", ["temperature = " + night.temperature]);
        } else if (night.schedule === "custom") {
            profile(night.to, ["identity = true"]);
            profile(night.from, ["temperature = " + night.temperature]);
        } else {
            profile("0:00", ["identity = true"]);
        }
        const running = night.manual === true || night.schedule === "custom";
        applyProc.startAfter = running;
        applyProc.command = ["sh", "-c", `printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"
            [ -f "$3" ] && sed -i -E "s/^( *night_shift = )(true|false),/\\1$4,/" "$3"
            pkill -x hyprsunset
            for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x hyprsunset >/dev/null || break; sleep 0.1; done`, "sh",
                             sunsetPath, lines.join("\n") + "\n", luaPath, String(running)];
        if (applyProc.running)
            applyProc.again = true;
        else
            applyProc.running = true;
    }

    Process {
        id: applyProc

        property bool startAfter: false
        property bool again: false

        onExited: {
            if (again) {
                again = false;
                display.applyNightShift();
                return;
            }
            // Through Hyprland, so hyprsunset isn't tied to this shell.
            if (startAfter)
                Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("hyprsunset")']);
        }
    }
}
