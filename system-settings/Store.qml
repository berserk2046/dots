pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Everything the app changes lives in settings.json next to this file, as {section: {key: value}}.
// The desktop's shell and the lock screen read that file directly (shell-common/Settings.qml) and
// follow its changes. For Hyprland, the
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
    readonly property var hyprSections: ["general", "appearance", "displays", "keyboard", "pointer", "windows", "hyprland"]

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

    // Hyprland's blur size and passes for System Settings → Hyprland → Blur. The blur reaches about
    // size × 2^passes pixels; "medium" is hyprland.lua's default.
    readonly property var blurStrengths: ({
            light: {
                size: 6,
                passes: 2
            },
            medium: {
                size: 8,
                passes: 3
            },
            strong: {
                size: 12,
                passes: 3
            }
        })

    // The values hyprland.lua reads (see the `S.` uses there).
    function hyprTable() {
        const S = {};
        const put = (key, value) => {
            if (value !== undefined && value !== null)
                S[key] = value;
        };
        put("terminal", get("general", "terminal"));
        put("desktop_wallpaper", get("desktop", "drawWallpaper"));
        const items = get("general", "loginItems");
        if (items)
            put("login_items", items.filter(i => i.enabled !== false && i.command).map(i => i.command));
        put("single_render_thread", get("general", "singleRenderThread"));
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
        // Focus mode from Hyprland (0 click, 1 hover, 2 hover but keys on click), else the older on/off
        const followMode = get("hyprland", "followMouse");
        const follow = get("pointer", "focusFollowsMouse");
        if (followMode !== undefined)
            put("follow_mouse", followMode);
        else if (follow !== undefined)
            put("follow_mouse", follow ? 1 : 0);
        put("float_by_default", get("windows", "floatByDefault"));
        put("title_bars", get("windows", "titleBars"));
        put("gaps_in", get("windows", "gapsIn"));
        put("gaps_out", get("windows", "gapsOut"));
        put("rounding", get("windows", "rounding"));
        put("border_size", get("windows", "borderSize"));
        // System Settings → Hyprland
        const h = key => get("hyprland", key);
        put("layout", h("layout"));
        put("inactive_opacity", h("inactiveOpacity"));
        put("dim_inactive", h("dimInactive"));
        put("dim_strength", h("dimStrength"));
        put("shadows", h("shadows"));
        put("blur", h("blur"));
        const blur = blurStrengths[h("blurStrength")];
        if (blur) {
            put("blur_size", blur.size);
            put("blur_passes", blur.passes);
        }
        put("animations", h("animations"));
        put("focus_on_activate", h("focusOnActivate"));
        put("warp_pointer", h("warpPointer"));
        put("hide_on_key_press", h("hideCursorTyping"));
        put("cursor_timeout", h("cursorTimeout"));
        put("middle_click_paste", h("middleClickPaste"));
        put("vrr", h("vrr"));
        put("numlock", h("numlock"));
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
            // Written to the command's stdin, which is then closed: for text that mustn't be an
            // argument, where every user could read it in the process list
            property var input: null
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

            stdinEnabled: input !== null
            onStarted: {
                if (input !== null) {
                    write(input);
                    stdinEnabled = false;
                }
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

    // Runs a command; callback(code, stdout, stderr) when it ends. `input`, if given, is its stdin.
    function run(command, callback, input) {
        const proc = commandComponent.createObject(store, {
            command: command,
            callback: callback ?? null,
            input: input ?? null
        });
        proc.running = true;
    }

    // Like run, but commands with the same key run one after another, in order. For commands
    // whose order matters, e.g. two quick edits of the same file or on/off/on of a setting.
    property var queues: ({})

    function runQueued(key, command, callback, input) {
        const queue = queues[key] ?? [];
        queue.push({
            command: command,
            callback: callback,
            input: input
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
        }, job.input);
    }

    function script(name) {
        return dir + "/" + name;
    }

    // Writes a file atomically, then runs `after` (a command) if given. Writes to one file run in order.
    // The text goes in on stdin, not as an argument. `secret` creates the file readable by you only.
    function writeFile(path, text, after, callback, secret) {
        runQueued("file:" + path, ["sh", "-c", 'umask "$2"; mkdir -p "$(dirname "$1")" && cat > "$1.tmp" && mv "$1.tmp" "$1" && shift 2 && [ $# -eq 0 ] || "$@"',
             "sh", path, secret ? "077" : "022", ...(after ?? [])], callback, text);
    }

    // Starts a program through Hyprland, so it isn't tied to this app's lifetime.
    function launch(command) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(" + JSON.stringify(command) + ")"]);
    }

    function restart(program) {
        run(["sh", "-c", 'pkill -x "$1"; for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x "$1" >/dev/null || break; sleep 0.1; done', "sh", program],
            () => launch(program));
    }

    // The lock screen's shell: lock, lockNow
    function lockscreenIpc(args, callback) {
        run(["qs", "-p", lockscreenDir, "ipc", "call", ...args], callback);
    }

    // The desktop's shell (the Dock, the window switcher, the menu bar panels, the desktop, the
    // notifications and the password dialog, in one process): notifications, panel, switcher
    readonly property string desktopShellDir: home + "/.config/desktop-shell"

    function desktopIpc(args, callback) {
        run(["qs", "-p", desktopShellDir, "ipc", "call", ...args], callback);
    }

    // What a Quickshell shell starts with, the same as hyprland.lua gives it at login (see there):
    // one memory pool (MALLOC_CONF), the icon theme (QS_ICON_THEME, from icon_theme in
    // system-settings.lua) and, if picked in General → Performance, one thread drawing every window
    // (QSG_RENDER_LOOP).
    function shellCommand(folder) {
        const theme = get("appearance", "iconTheme", "MacTahoe-dark");
        return "MALLOC_CONF=narenas:1 " + (/^[A-Za-z0-9._+-]+$/.test(theme) ? "QS_ICON_THEME=" + theme + " " : "")
               + (get("general", "singleRenderThread", false) ? "QSG_RENDER_LOOP=basic " : "") + "qs -p " + folder;
    }

    // General → Performance: takes effect by restarting the desktop's shell (a second without the
    // Dock and the desktop icons); system-settings.lua is rewritten for the next login.
    function setSingleRenderThread(on) {
        set("general", "singleRenderThread", on);
        restartShell(desktopShellDir);
    }

    // Restarts a Quickshell shell (by folder) through Hyprland: only if it was running, unless `always`.
    function restartShell(folder, always) {
        run(["qs", "kill", "-p", folder], code => {
            if (code === 0 || always)
                launch(shellCommand(folder));
        });
    }

    // ---- Desktop: icons and wallpaper ----

    // Whether the desktop draws the wallpaper, rather than hyprpaper (System Settings → Wallpaper)
    function desktopDrawsWallpaper() {
        return get("desktop", "drawWallpaper", true);
    }

    function setDesktop(key, value) {
        set("desktop", key, value);
        if (key === "drawWallpaper") {
            writeHyprland(false); // what hyprland.lua starts at login
            applyDesktop();
        }
    }

    // Starts or stops hyprpaper to match the setting. It stops a moment after the desktop has had
    // time to draw the wallpaper, so the screen doesn't flash black.
    function applyDesktop() {
        run(["sh", "-c", `if [ "$1" = 1 ]; then
                pgrep -x hyprpaper >/dev/null || hyprctl dispatch 'hl.dsp.exec_cmd("hyprpaper")' >/dev/null
            else
                sleep 1.5
                pkill -x hyprpaper
            fi
            true`, "sh", desktopDrawsWallpaper() ? "0" : "1"]);
    }

    // ---- Appearance ----

    function appearance(args, callback) {
        run(["sh", script("appearance.sh"), ...args], callback);
    }

    // GTK and the desktop's shell (the Dock, the window switcher, notifications, desktop icons).
    // Quickshell takes its icon theme from QS_ICON_THEME when it starts, so the shell restarts with
    // the new one; system-settings.lua is rewritten (the appearance section is one of hyprSections)
    // for the next login. This app shows the new icons the next time it's opened.
    function setIconTheme(name) {
        set("appearance", "iconTheme", name);
        appearance(["icons", name]);
        restartShell(desktopShellDir);
    }

    // ---- Wallpaper: hyprpaper (or the desktop, see desktopDrawsWallpaper) ----

    readonly property string defaultWallpaper: home + "/Pictures/Wallpapers/wallpaper.jpg"

    // Writes hyprpaper.conf (read when hyprpaper starts) and switches the running hyprpaper over IPC.
    // wallpaper.py first scales the picture down to each connected display's size, since hyprpaper
    // keeps pictures decoded at their full size. The settings are passed along, as settings.json may
    // not be saved yet. Queued, so quick picks apply in order. When the desktop draws the wallpaper it
    // follows settings.json by itself, and hyprpaper.conf is only kept up to date, for when it doesn't.
    function writeWallpaper() {
        const settings = {
            path: get("wallpaper", "path", defaultWallpaper),
            monitors: get("wallpaper", "monitors", {}),
            fit: get("wallpaper", "fit", "cover"),
            startHyprpaper: !desktopDrawsWallpaper()
        };
        runQueued("wallpaper", ["python3", script("wallpaper.py"), JSON.stringify(settings)]);
    }

    // ---- Lock screen: hypridle ----

    function writeIdle() {
        // lock_cmd answers `loginctl lock-session`, which the idle timer below sends: any key unlocks
        // for the grace period. Before sleep the password is asked right away, and the screen is locked
        // at once (lockForSleep takes no pictures of the desktop first); inhibit_sleep = 3 makes
        // hypridle hold the sleep back until the screen really is locked.
        const lockCmd = "qs -p " + lockscreenDir + " ipc call lock lock";
        const dpms = action => "hyprctl dispatch 'hl.dsp.dpms({ action = \"" + action + "\" })'";
        const lines = ["# Written by System Settings → Lock Screen; changes here are overwritten.", "general {",
                       "    lock_cmd = " + lockCmd];
        if (get("lockScreen", "lockBeforeSleep", true))
            lines.push("    before_sleep_cmd = qs -p " + lockscreenDir + " ipc call lock lockForSleep", "    inhibit_sleep = 3");
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
