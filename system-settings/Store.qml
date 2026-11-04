pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Everything the app changes lives in settings.json next to this file, as {section: {key: value}}.
// The dock and the lock screen read that file directly (and follow its changes). For Hyprland, the
// Hyprland-related values are also written to ~/.config/hypr/system-settings.lua, which hyprland.lua
// loads, followed by a config reload. hypridle and hyprsunset get their own config files.
Singleton {
    id: store

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/.config/system-settings"
    readonly property string path: dir + "/settings.json"
    readonly property string luaPath: home + "/.config/hypr/system-settings.lua"
    readonly property string lockscreenDir: home + "/.config/lockscreen"

    property var data: ({})
    property bool loaded: false
    property string lastWritten: ""

    // Sections whose values end up in system-settings.lua.
    readonly property var hyprSections: ["general", "appearance", "displays", "keyboard", "pointer", "windows"]

    function get(section, key, fallback) {
        const value = data?.[section]?.[key];
        return value === undefined || value === null ? fallback : value;
    }

    function set(section, key, value) {
        const values = {};
        values[key] = value;
        setMany(section, values);
    }

    function setMany(section, values) {
        const next = Object.assign({}, data);
        next[section] = Object.assign({}, next[section] ?? {}, values);
        data = next;
        saveTimer.restart();
        if (hyprSections.includes(section))
            hyprTimer.restart();
    }

    FileView {
        id: file

        path: store.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const text = file.text();
            // Ignore our own writes, and outside changes while one of ours is pending.
            if (text === store.lastWritten || saveTimer.running) {
                store.loaded = true;
                return;
            }
            try {
                store.data = JSON.parse(text);
            } catch (error) {
                console.warn("settings.json is not valid JSON, starting from defaults");
            }
            store.loaded = true;
        }
        onLoadFailed: store.loaded = true
    }

    Timer {
        id: saveTimer

        interval: 150
        onTriggered: {
            store.lastWritten = JSON.stringify(store.data, null, 2) + "\n";
            file.setText(store.lastWritten);
        }
    }

    // ---- Hyprland ----

    Timer {
        id: hyprTimer

        interval: 400
        onTriggered: store.writeHyprland(true)
    }

    function luaValue(value, indent) {
        const pad = "    ".repeat(indent + 1);
        if (value === null || value === undefined)
            return "nil";
        if (typeof value === "boolean" || typeof value === "number")
            return String(value);
        if (typeof value === "string")
            return JSON.stringify(value); // a valid Lua string for plain text
        if (Array.isArray(value)) {
            if (value.length === 0)
                return "{}";
            return "{\n" + value.map(v => pad + luaValue(v, indent + 1) + ",").join("\n") + "\n" + "    ".repeat(indent) + "}";
        }
        const keys = Object.keys(value);
        if (keys.length === 0)
            return "{}";
        return "{\n" + keys.map(k => pad + (/^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : "[" + JSON.stringify(k) + "]") + " = "
                                + luaValue(value[k], indent + 1) + ",").join("\n") + "\n" + "    ".repeat(indent) + "}";
    }

    // The values hyprland.lua reads (see the `S.` uses there).
    function hyprTable() {
        const S = {};
        const put = (key, value) => {
            if (value !== undefined && value !== null)
                S[key] = value;
        };
        put("terminal", get("general", "terminal"));
        const items = get("general", "loginItems");
        if (items)
            put("login_items", items.filter(i => i.enabled !== false && i.command).map(i => i.command));
        put("icon_theme", get("appearance", "iconTheme"));
        put("cursor_theme", get("appearance", "cursorTheme"));
        put("cursor_size", get("appearance", "cursorSize"));
        put("monitors", get("displays", "monitors"));
        put("night_shift", nightShiftRunning());
        const layouts = get("keyboard", "layouts");
        if (layouts && layouts.length > 0) {
            put("kb_layout", layouts.map(l => l.layout).join(","));
            put("kb_variant", layouts.map(l => l.variant ?? "").join(","));
        }
        put("repeat_rate", get("keyboard", "repeatRate"));
        put("repeat_delay", get("keyboard", "repeatDelay"));
        put("sensitivity", get("pointer", "sensitivity"));
        put("natural_scroll", get("pointer", "naturalScroll"));
        put("mouse_natural_scroll", get("pointer", "mouseNaturalScroll"));
        put("tap_to_click", get("pointer", "tapToClick"));
        put("disable_while_typing", get("pointer", "disableWhileTyping"));
        const follow = get("pointer", "focusFollowsMouse");
        if (follow !== undefined)
            put("follow_mouse", follow ? 1 : 0);
        put("float_by_default", get("windows", "floatByDefault"));
        put("title_bars", get("windows", "titleBars"));
        put("gaps_in", get("windows", "gapsIn"));
        put("gaps_out", get("windows", "gapsOut"));
        put("rounding", get("windows", "rounding"));
        put("border_size", get("windows", "borderSize"));
        return S;
    }

    // Writes system-settings.lua and reloads Hyprland's config (monitors are applied separately).
    function writeHyprland(reload) {
        const lua = "-- Written by System Settings (~/.config/system-settings); changes here are overwritten.\n"
                    + "return " + luaValue(hyprTable(), 0) + "\n";
        writeFile(luaPath, lua, reload ? ["hyprctl", "reload", "config-only"] : null);
    }

    // ---- Commands ----

    Component {
        id: commandComponent

        Process {
            id: proc

            property var callback: null
            property int code: -1
            property bool exitSeen: false
            property bool outputSeen: false

            function finish() {
                if (!exitSeen || !outputSeen)
                    return;
                try {
                    if (callback)
                        callback(code, out.text, err.text);
                } catch (error) {
                    // A pane closed while its command ran; its ids are null by now.
                    if (!String(error).includes("null"))
                        console.warn(error);
                }
                destroy();
            }

            stdout: StdioCollector {
                id: out

                onStreamFinished: {
                    proc.outputSeen = true;
                    proc.finish();
                }
            }
            stderr: StdioCollector {
                id: err
            }
            onExited: exitCode => {
                proc.code = exitCode;
                proc.exitSeen = true;
                proc.finish();
            }
        }
    }

    // Runs a command; callback(code, stdout, stderr) when it ends.
    function run(command, callback) {
        const proc = commandComponent.createObject(store, {
            command: command,
            callback: callback ?? null
        });
        proc.running = true;
    }

    // Like run, but commands with the same key run one after another, in order. For commands
    // whose order matters, e.g. two quick edits of the same file or on/off/on of a setting.
    property var queues: ({})

    function runQueued(key, command, callback) {
        const queue = queues[key] ?? [];
        queue.push({
            command: command,
            callback: callback
        });
        queues[key] = queue;
        if (queue.length === 1)
            runNext(key);
    }

    function runNext(key) {
        const job = queues[key][0];
        run(job.command, (code, out, err) => {
            try {
                job.callback?.(code, out, err);
            } finally {
                queues[key].shift();
                if (queues[key].length > 0)
                    runNext(key);
            }
        });
    }

    function script(name) {
        return dir + "/" + name;
    }

    // Writes a file atomically, then runs `after` (a command) if given. Writes to one file run in order.
    function writeFile(path, text, after, callback) {
        runQueued("file:" + path, ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1" && shift 2 && [ $# -eq 0 ] || "$@"',
             "sh", path, text, ...(after ?? [])], callback);
    }

    // Starts a program through Hyprland, so it isn't tied to this app's lifetime.
    function launch(command) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(" + JSON.stringify(command) + ")"]);
    }

    function restart(program) {
        run(["sh", "-c", 'pkill -x "$1"; for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x "$1" >/dev/null || break; sleep 0.1; done', "sh", program],
            () => launch(program));
    }

    function lockscreenIpc(args, callback) {
        run(["qs", "-p", lockscreenDir, "ipc", "call", ...args], callback);
    }

    // Restarts a Quickshell shell (by folder) through Hyprland.
    function restartShell(folder) {
        run(["qs", "kill", "-p", folder], () => launch("qs -p " + folder));
    }

    // ---- Appearance ----

    function appearance(args, callback) {
        run(["sh", script("appearance.sh"), ...args], callback);
    }

    // GTK, the Dock, the lock screen (notification icons), the window switcher and this app; Quickshell
    // reads its icon theme from the `//@ pragma IconTheme` line at startup, so the other shells restart.
    function setIconTheme(name) {
        set("appearance", "iconTheme", name);
        appearance(["icons", name]);
        const restarted = [home + "/.config/sway-dock", lockscreenDir, home + "/.config/app-switcher"];
        run(["sh", "-c", 'theme=$1; shift; for f; do [ -f "$f/shell.qml" ] && sed -i "s|^//@ pragma IconTheme .*|//@ pragma IconTheme $theme|" "$f/shell.qml"; done; true',
             "sh", name, ...restarted, dir], () => restarted.forEach(folder => restartShell(folder)));
    }

    // ---- Wallpaper: hyprpaper ----

    readonly property string defaultWallpaper: home + "/Pictures/Wallpapers/wallpaper.jpg"

    // Writes hyprpaper.conf (read when hyprpaper starts) and switches the running hyprpaper over IPC.
    function writeWallpaper(monitorNames) {
        const fit = get("wallpaper", "fit", "cover");
        const main = get("wallpaper", "path", defaultWallpaper);
        const perMonitor = get("wallpaper", "monitors", {});
        const block = (monitor, path) => ["", "wallpaper {", "    monitor = " + monitor, "    path = " + path, "    fit_mode = " + fit, "}"];
        let lines = ["# Written by System Settings → Wallpaper; changes here are overwritten.", "splash = false"];
        lines = lines.concat(block("", main));
        for (const name in perMonitor)
            lines = lines.concat(block(name, perMonitor[name]));
        const paths = monitorNames.map(name => perMonitor[name] ?? main);
        writeFile(home + "/.config/hypr/hyprpaper.conf", lines.join("\n") + "\n", null, () => {
            // hyprctl splits its argument on commas, so a path with one needs a restart instead.
            if (paths.some(p => p.includes(",")))
                return restart("hyprpaper");
            run(["pgrep", "-x", "hyprpaper"], code => {
                if (code !== 0)
                    return launch("hyprpaper");
                monitorNames.forEach((name, i) => run(["hyprctl", "hyprpaper", "wallpaper", name + "," + paths[i] + "," + fit]));
            });
        });
    }

    // ---- Lock screen: hypridle ----

    function writeIdle() {
        const lockCmd = "qs -p " + lockscreenDir + " ipc call lock lock";
        const dpms = action => "hyprctl dispatch 'hl.dsp.dpms({ action = \"" + action + "\" })'";
        const lines = ["# Written by System Settings → Lock Screen; changes here are overwritten.", "general {",
                       "    lock_cmd = " + lockCmd];
        if (get("lockScreen", "lockBeforeSleep", true))
            lines.push("    before_sleep_cmd = qs -p " + lockscreenDir + " ipc call lock lockNow");
        lines.push("    after_sleep_cmd = " + dpms("on"), "}");
        const listener = (minutes, onTimeout, onResume) => {
            if (!(minutes > 0))
                return;
            lines.push("", "listener {", "    timeout = " + Math.round(minutes * 60), "    on-timeout = " + onTimeout);
            if (onResume)
                lines.push("    on-resume = " + onResume);
            lines.push("}");
        };
        listener(get("lockScreen", "lockAfter", 0), "loginctl lock-session");
        listener(get("lockScreen", "displayOffAfter", 0), dpms("off"), dpms("on"));
        listener(get("lockScreen", "sleepAfter", 0), "systemctl suspend");
        writeFile(home + "/.config/hypr/hypridle.conf", lines.join("\n") + "\n", null, () => restart("hypridle"));
    }

    // ---- Displays: Night Shift (hyprsunset) ----

    function nightShiftRunning() {
        const night = get("displays", "nightShift", {});
        return night.schedule === "custom" || night.manual === true;
    }

    // hyprsunset applies the profile for the current time when it starts: turned on by hand, one
    // warm profile all day; on a schedule, warm from `from` and normal again at `to`.
    function writeNightShift() {
        const night = get("displays", "nightShift", {});
        const temperature = night.temperature ?? 4500;
        const lines = ["# Written by System Settings → Displays → Night Shift; changes here are overwritten."];
        const profile = (time, body) => lines.push("", "profile {", "    time = " + time, ...body.map(l => "    " + l), "}");
        if (night.manual) {
            profile("0:00", ["temperature = " + temperature]);
        } else if (night.schedule === "custom") {
            profile(night.to ?? "7:00", ["identity = true"]);
            profile(night.from ?? "22:00", ["temperature = " + temperature]);
        } else {
            profile("0:00", ["identity = true"]);
        }
        writeFile(home + "/.config/hypr/hyprsunset.conf", lines.join("\n") + "\n", null, () => {
            run(["sh", "-c", "pkill -x hyprsunset; for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x hyprsunset >/dev/null || break; sleep 0.1; done"], () => {
                if (nightShiftRunning())
                    launch("hyprsunset");
            });
        });
        writeHyprland(false);
    }
}
