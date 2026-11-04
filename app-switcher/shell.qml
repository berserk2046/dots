// Icon theme used for app icons; System Settings → Appearance rewrites this line and restarts the shell.
//@ pragma IconTheme MacTahoe-dark
// Fixed ID so `qs ipc` finds this shell wherever the folder lives.
//@ pragma ShellId app-switcher
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Window switcher (Alt+Tab), macOS style. Hyprland owns the keys (hyprland.lua, "App Switcher" submap)
// and sends them here as global shortcuts; also callable as
//   qs -p <this folder> ipc call switcher next|previous|left|right|up|down|commit|cancel|close
ShellRoot {
    id: root

    // No live reload when these files change: System Settings edits the IconTheme line above and then
    // restarts the shell, and a reload just before quitting can crash Quickshell on its way out.
    settings.watchFiles: false

    // Between the first Alt+Tab and releasing Alt
    property bool active: false
    // Drawn a moment after opening, so a quick Alt+Tab just switches without flashing the panel
    property bool shown: false
    // HyprlandToplevels in switcher order, and the index of the selected one
    property var windows: []
    property int selected: 0
    // Window addresses, most recently focused first
    property var recent: []
    // Columns of the panel's grid (set by the panel), for up and down
    property int columns: 1
    property string screenName: ""
    // The submap hyprland.lua puts the keys in while the switcher is open (waybar shows its name)
    readonly property string keysSubmap: "App Switcher"

    readonly property bool previews: prefs.get("switcher", "previews", true)
    // "all": windows from every workspace and display; "workspace": the current workspace only
    readonly property string scope: prefs.get("switcher", "scope", "all")

    function norm(address) {
        return String(address ?? "").replace(/^0x/, "").toLowerCase();
    }

    function noteFocus(toplevel) {
        const address = norm(toplevel?.address);
        if (address !== "")
            recent = [address, ...recent.filter(a => a !== address)];
    }

    // Hidden windows: the title bar's yellow button and $mod+Shift+minus move them to the scratchpad.
    function isHidden(toplevel) {
        const ws = toplevel.workspace;
        return ws !== null && ws !== undefined && (ws.id < 0 || String(ws.name).startsWith("special"));
    }

    function collect() {
        const current = Hyprland.focusedWorkspace;
        const list = Hyprland.toplevels.values.filter(t => {
            // Skip the unnamed helper surfaces XWayland apps create while dragging
            if (!t.wayland && !t.title)
                return false;
            return scope !== "workspace" || isHidden(t) || t.workspace === current;
        });
        const present = new Set(list.map(t => norm(t.address)));
        recent = recent.filter(a => present.has(a));
        const rank = t => {
            const i = recent.indexOf(norm(t.address));
            return i < 0 ? recent.length : i;
        };
        // Most recent first, hidden windows last (macOS lists minimized windows after the rest)
        return list.map((t, i) => ({
                    t: t,
                    key: (isHidden(t) ? 1e6 : 0) + rank(t) * 1000 + i
                })).sort((a, b) => a.key - b.key).map(e => e.t);
    }

    function open(step) {
        const list = collect();
        if (list.length === 0) {
            finish();
            return;
        }
        // Start on the second window when the first is the focused one (it normally is)
        const first = list[0];
        const focused = norm(Hyprland.activeToplevel?.address);
        const onFocused = first.activated || first.wayland?.activated === true || (focused !== "" && norm(first.address) === focused);
        windows = list;
        selected = step < 0 ? list.length - 1 : Math.min(onFocused ? 1 : 0, list.length - 1);
        screenName = Hyprland.focusedMonitor?.name ?? "";
        active = true;
        showTimer.restart();
    }

    function move(step) {
        if (!active)
            return open(step);
        const n = windows.length;
        selected = ((selected + step) % n + n) % n;
    }

    // Up and down move a whole row; at the first or last row they stay put.
    function moveRow(direction) {
        if (!active)
            return;
        const target = selected + direction * columns;
        if (target >= 0 && target < windows.length)
            selected = target;
    }

    function select(index) {
        if (active && index >= 0 && index < windows.length)
            selected = index;
    }

    function commit(index) {
        if (!active)
            return;
        const toplevel = windows[index ?? selected];
        finish();
        if (toplevel)
            focusWindow(toplevel);
    }

    function finish() {
        showTimer.stop();
        active = false;
        shown = false;
        windows = [];
        // The keys' submap is left to hyprland.lua (it leaves it when Alt goes up). Resetting it from here
        // could land after a fast second Alt+Tab and drop that one's keys.
    }

    // Q closes the selected window and keeps the switcher open, as in macOS's app switcher.
    function closeSelected(index) {
        if (!active)
            return;
        const at = index ?? selected;
        const toplevel = windows[at];
        if (!toplevel)
            return;
        if (toplevel.wayland)
            toplevel.wayland.close();
        else
            Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${norm(toplevel.address)}" })`);
        windows = windows.filter((_, i) => i !== at);
        if (windows.length === 0)
            finish();
        else
            selected = Math.min(selected, windows.length - 1);
    }

    // The dispatches run one after another from one shell (separate Hyprland.dispatch calls can arrive
    // out of order).
    function focusWindow(toplevel) {
        const target = `"address:0x${norm(toplevel.address)}"`;
        const steps = [];
        // A hidden window comes back onto the current workspace, focused (`follow`; a separate focus
        // right after the move doesn't take)
        if (isHidden(toplevel) && Hyprland.focusedWorkspace)
            steps.push(`hl.dsp.window.move({ workspace = ${Hyprland.focusedWorkspace.id}, follow = true, window = ${target} })`);
        else
            steps.push(`hl.dsp.focus({ window = ${target} })`);
        // Focusing doesn't raise a floating window (the default here) above the others
        steps.push(`hl.dsp.window.alter_zorder({ mode = "top", window = ${target} })`);
        Quickshell.execDetached(["sh", "-c", 'for step; do hyprctl dispatch "$step" >/dev/null; done', "sh", ...steps]);
    }

    // Safety net: hyprland.lua sends commit as it leaves the keys' submap. If Hyprland is out of the
    // submap and the switcher is still open shortly after, that commit got lost: switch anyway.
    Timer {
        id: orphanTimer

        interval: 150
        onTriggered: {
            if (root.active)
                root.commit();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "submap")
                return;
            if (event.data === root.keysSubmap)
                orphanTimer.stop();
            else if (root.active)
                orphanTimer.restart();
        }
    }

    Timer {
        id: showTimer

        interval: 90
        onTriggered: root.shown = root.active
    }

    Connections {
        target: Hyprland

        function onActiveToplevelChanged() {
            root.noteFocus(Hyprland.activeToplevel);
        }
    }

    // Also from the Wayland side, which knows the focused window even before Hyprland's first event
    Connections {
        target: ToplevelManager

        function onActiveToplevelChanged() {
            const active = ToplevelManager.activeToplevel;
            if (active)
                root.noteFocus(Hyprland.toplevels.values.find(t => t.wayland === active));
        }
    }

    // Focus order from before this shell started, oldest last.
    Process {
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const seeded = JSON.parse(text).filter(c => c.focusHistoryID >= 0).sort((a, b) => a.focusHistoryID - b.focusHistoryID).map(c => root.norm(c.address));
                    root.recent = [...root.recent, ...seeded.filter(a => !root.recent.includes(a))];
                } catch (error) {}
            }
        }
    }

    // Previews and scope, from System Settings → Desktop & Dock → Window Switcher
    Settings {
        id: prefs
    }

    // The keys, bound in hyprland.lua to hl.dsp.global("app-switcher:<name>")
    component Key: GlobalShortcut {
        appid: "app-switcher"
    }

    Key {
        name: "next"
        description: qsTr("Window switcher: next window")
        onPressed: root.move(1)
    }

    Key {
        name: "previous"
        description: qsTr("Window switcher: previous window")
        onPressed: root.move(-1)
    }

    Key {
        name: "left"
        onPressed: root.active && root.move(-1)
    }

    Key {
        name: "right"
        onPressed: root.active && root.move(1)
    }

    Key {
        name: "up"
        onPressed: root.moveRow(-1)
    }

    Key {
        name: "down"
        onPressed: root.moveRow(1)
    }

    Key {
        name: "commit"
        description: qsTr("Window switcher: switch to the selected window")
        onPressed: root.commit()
    }

    Key {
        name: "cancel"
        onPressed: root.active && root.finish()
    }

    Key {
        name: "close"
        onPressed: root.closeSelected()
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.move(1);
        }
        function previous(): void {
            root.move(-1);
        }
        function left(): void {
            if (root.active)
                root.move(-1);
        }
        function right(): void {
            if (root.active)
                root.move(1);
        }
        function up(): void {
            root.moveRow(-1);
        }
        function down(): void {
            root.moveRow(1);
        }
        function commit(): void {
            root.commit();
        }
        function cancel(): void {
            if (root.active)
                root.finish();
        }
        function close(): void {
            root.closeSelected();
        }
    }

    Switcher {
        screen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0] ?? null
        shown: root.shown
        windows: root.windows
        selected: root.selected
        previews: root.previews
        onColumnsChanged: root.columns = columns
        onHovered: index => root.select(index)
        onPicked: index => root.commit(index)
        onCloseRequested: index => root.closeSelected(index)
        onDismissed: root.finish()
    }
}
