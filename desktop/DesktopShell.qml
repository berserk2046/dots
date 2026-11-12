import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common

// The desktop, macOS style: the wallpaper (unless hyprpaper draws it; System Settings → Wallpaper) and
// the files and folders of ~/Desktop, on every display (DesktopWindow.qml, one per display).
//
// Every item remembers its display and its place there. Displays are told apart by make, model and
// serial number (Hyprland's monitor description), so a monitor gets its own arrangement back whenever
// it's connected, on any port. While it's disconnected, its items show on the main display without
// losing their place. Places are grid cells counted from the top right corner, as on macOS, so a new
// resolution or icon size doesn't scatter them; a cell that no longer fits shows its item in the
// nearest free one meanwhile. Items are told apart by inode, so renaming keeps the place, and by name,
// so does an editor that saves by replacing the file. Kept in
// ~/.local/state/quickshell/by-shell/desktop/layout.json.
//
// Loaded by desktop-shell, with the Dock, the window switcher, the menu bar panels and the notifications.
Scope {
    id: root

    readonly property bool showIcons: Settings.get("desktop", "showIcons", true)
    readonly property bool drawWallpaper: Settings.get("desktop", "drawWallpaper", true)
    readonly property int iconSize: Settings.get("desktop", "iconSize", 56)
    readonly property int textSize: Settings.get("desktop", "textSize", 12)
    readonly property int gridSpacing: Settings.get("desktop", "gridSpacing", 12)
    // Another folder instead of XDG's desktop folder (not in System Settings)
    readonly property string folderSetting: Settings.get("desktop", "folder", "")
    readonly property string wallpaperFit: Settings.get("wallpaper", "fit", "cover")

    // A display's own picture (kept per monitor, see Displays), else the one for every display
    function wallpaperFor(screenName) {
        return Displays.pick(Settings.get("wallpaper", "monitors", {}), screenName)
               || Settings.get("wallpaper", "path", Quickshell.env("HOME") + "/Pictures/Wallpapers/wallpaper.jpg");
    }

    // System Settings' wallpaper.py keeps a copy of the wallpaper scaled to each display's exact size
    // (for hyprpaper too), listed in index.json: {display: {source, path, fit, width, height}}. Showing
    // that instead of decoding the full picture saves memory.
    readonly property string scaledDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/system-settings/wallpapers"
    property var scaledIndex: ({})
    property bool scaledIndexLoaded: false

    FileView {
        path: root.scaledDir + "/index.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.scaledIndex = JSON.parse(text());
            } catch (error) {
                root.scaledIndex = {};
            }
            root.scaledIndexLoaded = true;
        }
        onLoadFailed: {
            root.scaledIndex = {};
            root.scaledIndexLoaded = true;
        }
    }

    // The copy for a display, if it's of the current picture, fit and resolution; else ""
    function scaledWallpaper(screen) {
        const e = scaledIndex[screen?.name];
        if (!e || e.source !== wallpaperFor(screen.name) || e.fit !== wallpaperFit)
            return "";
        const dpr = screen.devicePixelRatio ?? 1;
        if (Math.abs(e.width - Math.round(screen.width * dpr)) > 2 || Math.abs(e.height - Math.round(screen.height * dpr)) > 2)
            return "";
        return e.path;
    }

    // Asks wallpaper.py for copies that fit the displays as they are now (a new picture, display or
    // resolution). It also rewrites hyprpaper.conf, but doesn't start hyprpaper.
    function requestScaled() {
        scaleTimer.restart();
    }

    Timer {
        id: scaleTimer

        interval: 800
        onTriggered: {
            if (!scaleProc.running)
                scaleProc.running = true;
        }
    }

    Process {
        id: scaleProc

        command: ["python3", Quickshell.env("HOME") + "/.config/system-settings/wallpaper.py", JSON.stringify({
                path: Settings.get("wallpaper", "path", Quickshell.env("HOME") + "/Pictures/Wallpapers/wallpaper.jpg"),
                monitors: Settings.get("wallpaper", "monitors", {}),
                fit: root.wallpaperFit,
                startHyprpaper: false
            })]
    }

    function script(name) {
        return decodeURIComponent(Qt.resolvedUrl(name).toString().replace(/^file:\/\//, ""));
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    // ---- Light or dark, for the menus ----

    readonly property bool light: Appearance.light

    // ---- The folder ----

    property string folder: ""
    property bool folderExists: false
    property var items: [] // from desktop-list.py: {id, name, path, uri, dir, kind, icons, label, mtime}
    property bool listed: false
    property bool listQueued: false

    function relist() {
        if (!showIcons)
            return;
        if (listProc.running)
            listQueued = true;
        else
            listProc.running = true;
    }

    Process {
        id: listProc

        command: ["python3", root.script("desktop-list.py"), root.folderSetting]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.folder = data.folder;
                    root.folderExists = data.exists;
                    root.items = data.items;
                    root.listed = true;
                    root.schedulePlace();
                } catch (error) {
                    console.warn("desktop-list.py:", error);
                }
            }
        }
        onExited: {
            if (root.listQueued) {
                root.listQueued = false;
                root.relist();
            }
        }
    }

    onShowIconsChanged: {
        relist();
        schedulePlace();
    }
    onFolderSettingChanged: relist()

    // Watches the folder (Qt keeps it up to date) and lists it again after any change. Until the folder
    // exists, its parent, to notice it being created (a missing folder would make Qt list the current
    // directory instead).
    FolderListModel {
        id: watcher

        folder: !root.showIcons || !root.folder ? "" : "file://" + (root.folderExists ? root.folder : root.folder.replace(/\/[^\/]+\/?$/, "") || "/")
        showDirs: true
        showHidden: false
        showDotAndDotDot: false
        sortField: FolderListModel.Unsorted
    }

    Connections {
        target: watcher

        function onRowsInserted() {
            relistTimer.restart();
        }

        function onRowsRemoved() {
            relistTimer.restart();
        }

        function onDataChanged() {
            relistTimer.restart();
        }

        function onModelReset() {
            relistTimer.restart();
        }
    }

    Timer {
        id: relistTimer

        interval: 150
        onTriggered: root.relist()
    }

    // ---- Displays ----

    // Connected displays by name: the key that identifies the monitor (make, model and serial, plus
    // the port when there's no serial) and the space the menu bar and the Dock reserve
    // ([left, top, right, bottom]), from Hyprland
    readonly property var displays: {
        const result = {};
        for (const m of Hyprland.monitors.values) {
            const o = m.lastIpcObject;
            if (!o || !o.description)
                continue;
            result[m.name] = {
                key: o.serial ? o.description : o.description + " (" + m.name + ")",
                reserved: o.reserved ?? [0, 0, 0, 0]
            };
        }
        return result;
    }
    readonly property bool displaysReady: Quickshell.screens.length > 0 && Quickshell.screens.every(s => displays[s.name] !== undefined)

    onDisplaysChanged: schedulePlace()

    // The reserved space changes when bars and Docks come and go or change size.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["openlayer", "closelayer", "monitoraddedv2", "monitorremovedv2", "configreloaded"].includes(event.name))
                monitorRefresh.restart();
        }
    }

    Connections {
        target: Settings

        function onDataChanged() {
            monitorRefresh.restart();
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.schedulePlace();
        }
    }

    Timer {
        id: monitorRefresh

        interval: 400
        onTriggered: Hyprland.refreshMonitors()
    }

    function mainScreen() {
        const wanted = Displays.mainName(Settings.get("displays", "main", ""));
        return Quickshell.screens.find(s => s.name === wanted) ?? Quickshell.screens.slice().sort((a, b) => a.x - b.x || a.y - b.y)[0];
    }

    // ---- The grid ----

    readonly property int cellWidth: Math.round(Math.max(iconSize * 1.6, iconSize + 44)) + gridSpacing
    readonly property int labelHeight: Math.ceil(textSize * 1.3) * 2
    readonly property int cellHeight: iconSize + 12 + labelHeight + 6 + gridSpacing

    onCellWidthChanged: schedulePlace()
    onCellHeightChanged: schedulePlace()

    // A display's grid: the space left by the menu bar and the Dock, in this display's coordinates
    function grid(screen) {
        const r = displays[screen?.name]?.reserved ?? [0, 0, 0, 0];
        const margin = 8;
        const left = r[0] + margin;
        const top = r[1] + margin;
        const right = (screen?.width ?? 0) - r[2] - margin;
        const bottom = (screen?.height ?? 0) - r[3] - margin;
        return {
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            cols: Math.max(1, Math.floor((right - left) / cellWidth)),
            rows: Math.max(1, Math.floor((bottom - top) / cellHeight))
        };
    }

    // Columns count from the right edge, as on macOS.
    function cellPos(g, col, row) {
        return Qt.point(g.right - (col + 1) * cellWidth, g.top + row * cellHeight);
    }

    function cellAt(g, x, y) {
        return {
            col: clamp(Math.floor((g.right - x) / cellWidth), 0, g.cols - 1),
            row: clamp(Math.floor((y - g.top) / cellHeight), 0, g.rows - 1)
        };
    }

    // A free cell: the nearest one to `near` if given, else the first going down the columns from the
    // right. A full grid stacks the rest on its last cell.
    function freeCell(g, taken, near) {
        if (near) {
            const c0 = clamp(near.col, 0, g.cols - 1);
            const r0 = clamp(near.row, 0, g.rows - 1);
            for (let d = 0; d < Math.max(g.cols, g.rows); d++) {
                for (let c = c0 - d; c <= c0 + d; c++) {
                    for (let r = r0 - d; r <= r0 + d; r++) {
                        if (Math.max(Math.abs(c - c0), Math.abs(r - r0)) !== d || c < 0 || r < 0 || c >= g.cols || r >= g.rows)
                            continue;
                        if (!taken.has(c + "," + r))
                            return {
                                col: c,
                                row: r
                            };
                    }
                }
            }
        }
        for (let c = 0; c < g.cols; c++) {
            for (let r = 0; r < g.rows; r++) {
                if (!taken.has(c + "," + r))
                    return {
                        col: c,
                        row: r
                    };
            }
        }
        return {
            col: g.cols - 1,
            row: g.rows - 1
        };
    }

    // ---- Places ----

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/by-shell/desktop"
    property var layout: ({}) // item id -> {name, monitor, col, row}
    property bool layoutLoaded: false
    // Where items about to appear go (a new folder, files dropped on the desktop): name -> {monitor, col, row}
    property var pendingPlaces: ({})
    // A new folder's name, edited as soon as it shows up
    property string editName: ""
    // Items being dragged from a display (DesktopWindow.startDrag), for the display they're dropped on:
    // {ids, anchor: {col, row}, grab, moves: [{id, col, row}], screen}, or null
    property var dragged: null

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.stateDir]);
        relist();
    }

    FileView {
        id: layoutFile

        path: root.stateDir + "/layout.json"
        printErrors: false
        onLoaded: {
            try {
                root.layout = JSON.parse(text()).items ?? {};
            } catch (error) {
                root.layout = {};
            }
            root.layoutLoaded = true;
            root.schedulePlace();
        }
        onLoadFailed: {
            root.layout = {};
            root.layoutLoaded = true;
            root.schedulePlace();
        }
    }

    Timer {
        id: saveTimer

        interval: 300
        onTriggered: layoutFile.setText(JSON.stringify({
            version: 1,
            items: root.layout
        }, null, 1) + "\n")
    }

    // Where each item shows: screen name -> [{item, col, row}]
    property var placements: ({})

    function schedulePlace() {
        placeTimer.restart();
    }

    Timer {
        id: placeTimer

        interval: 30
        onTriggered: root.placeAll()
    }

    function placeAll() {
        if (!showIcons) {
            placements = {};
            return;
        }
        if (!listed || !layoutLoaded || !displaysReady)
            return;
        const screens = Quickshell.screens;
        const keyOf = s => displays[s.name].key;
        const screenByKey = {};
        const grids = {};
        const taken = {};
        const out = {};
        for (const s of screens) {
            screenByKey[keyOf(s)] = s;
            grids[s.name] = grid(s);
            taken[s.name] = new Set();
            out[s.name] = [];
        }
        const main = mainScreen();
        const next = Object.assign({}, layout);
        let changed = false;
        const present = new Set(items.map(i => i.id));
        const idByName = {};
        for (const id in layout)
            idByName[layout[id].name] = id;
        const pending = Object.assign({}, pendingPlaces);
        const later = [];

        for (const item of items) {
            let entry = layout[item.id];
            // Same name, new inode: an editor that saves by replacing the file
            if (!entry && idByName[item.name] !== undefined && !present.has(idByName[item.name])) {
                entry = layout[idByName[item.name]];
                delete next[idByName[item.name]];
                next[item.id] = entry;
                changed = true;
            }
            const wanted = pending[item.name];
            if (wanted) {
                delete pending[item.name];
                if (!entry && screenByKey[wanted.monitor]) {
                    entry = {
                        name: item.name,
                        monitor: wanted.monitor,
                        col: wanted.col,
                        row: wanted.row
                    };
                    next[item.id] = entry;
                    changed = true;
                }
            }
            // Renamed: same place, new name
            if (entry && entry.name !== item.name) {
                entry = Object.assign({}, entry, {
                    name: item.name
                });
                next[item.id] = entry;
                changed = true;
            }
            const home = entry ? screenByKey[entry.monitor] : null;
            if (home) {
                const g = grids[home.name];
                const cell = entry.col + "," + entry.row;
                if (entry.col < g.cols && entry.row < g.rows && !taken[home.name].has(cell)) {
                    taken[home.name].add(cell);
                    out[home.name].push({
                        item: item,
                        col: entry.col,
                        row: entry.row
                    });
                } else {
                    // Its cell doesn't fit this resolution, or is taken: nearby, without forgetting it
                    later.push({
                        item: item,
                        screen: home,
                        near: entry,
                        save: false
                    });
                }
            } else {
                // New: the main display's first free cell, remembered. Its display isn't connected:
                // shown on the main display meanwhile.
                later.push({
                    item: item,
                    screen: main,
                    near: null,
                    save: !entry
                });
            }
        }
        for (const p of later) {
            const cell = freeCell(grids[p.screen.name], taken[p.screen.name], p.near);
            taken[p.screen.name].add(cell.col + "," + cell.row);
            out[p.screen.name].push({
                item: p.item,
                col: cell.col,
                row: cell.row
            });
            if (p.save) {
                next[p.item.id] = {
                    name: p.item.name,
                    monitor: keyOf(p.screen),
                    col: cell.col,
                    row: cell.row
                };
                changed = true;
            }
        }
        // Forget items that are gone from the folder
        if (folderExists) {
            for (const id in next) {
                if (!present.has(id)) {
                    delete next[id];
                    changed = true;
                }
            }
        }
        pendingPlaces = pending;
        placements = out;
        if (changed) {
            layout = next;
            saveTimer.restart();
        }
    }

    // Moves items to cells on a display (dragged there): [{id, col, row}]. Cells taken by other items
    // send an item to the nearest free one.
    function moveItems(moves, screen) {
        const key = displays[screen?.name]?.key;
        if (!key)
            return;
        const g = grid(screen);
        const moving = new Set(moves.map(m => m.id));
        const taken = new Set((placements[screen.name] ?? []).filter(e => !moving.has(e.item.id)).map(e => e.col + "," + e.row));
        const next = Object.assign({}, layout);
        for (const m of moves) {
            const item = items.find(i => i.id === m.id);
            if (!item)
                continue;
            const cell = freeCell(g, taken, {
                col: m.col,
                row: m.row
            });
            taken.add(cell.col + "," + cell.row);
            next[m.id] = {
                name: item.name,
                monitor: key,
                col: cell.col,
                row: cell.row
            };
        }
        layout = next;
        saveTimer.restart();
        placeAll();
    }

    // Sorts a display's own items into the grid, once (new items still take the first free cell): "name",
    // "kind" (folders first, then shortcuts, then files by extension) or "date" (newest first). Going down
    // the columns from the top right corner, as on macOS. Items shown here only while their own display
    // is disconnected are left alone.
    function sortBy(screen, order) {
        const key = displays[screen?.name]?.key;
        if (!key)
            return;
        const g = grid(screen);
        const own = (placements[screen.name] ?? []).filter(e => layout[e.item.id]?.monitor === key).map(e => e.item);
        const byName = (a, b) => a.label.localeCompare(b.label, undefined, {
                numeric: true,
                sensitivity: "base"
            });
        const kindRank = i => i.dir ? 0 : i.kind === "launcher" ? 1 : 2;
        const ext = i => i.dir ? "" : (i.name.includes(".") ? i.name.split(".").pop().toLowerCase() : "");
        own.sort(order === "date" ? (a, b) => b.mtime - a.mtime || byName(a, b)
                 : order === "kind" ? (a, b) => kindRank(a) - kindRank(b) || ext(a).localeCompare(ext(b)) || byName(a, b)
                 : byName);
        const next = Object.assign({}, layout);
        own.forEach((item, i) => {
            next[item.id] = {
                name: item.name,
                monitor: key,
                col: Math.min(Math.floor(i / g.rows), g.cols - 1),
                row: i % g.rows
            };
        });
        layout = next;
        saveTimer.restart();
        placeAll();
    }

    // ---- Files ----

    // A shortcut (.desktop file) only starts its app once it's allowed to (see allowLaunching);
    // desktop-list.py lists the others as plain files, so they open in an editor instead.
    function open(item) {
        if (item.kind === "launcher")
            Launch.app(["gio", "launch", item.path]);
        else
            Launch.app(["gio", "open", item.uri]);
    }

    function trash(list) {
        if (list.length > 0)
            Quickshell.execDetached(["gio", "trash", "--", ...list.map(i => i.path)]);
    }

    // "Allow Launching": marks a shortcut as a program (the executable bit), as GNOME does. Until then
    // a .desktop file that landed on the desktop (a download, an archive) is just a file, whatever name
    // and icon it gives itself.
    function allowLaunching(item) {
        Quickshell.execDetached(["chmod", "u+x", "--", item.path]);
        relistTimer.restart();
    }

    function nameTaken(name) {
        return items.some(i => i.name === name);
    }

    // false if the name can't be used
    function rename(item, name) {
        name = name.trim();
        if (name === item.name)
            return true;
        if (name === "" || name === "." || name === ".." || name.includes("/") || nameTaken(name))
            return false;
        Quickshell.execDetached(["mv", "-n", "--", item.path, folder + "/" + name]);
        return true;
    }

    function newFolder(screen, cell) {
        if (!folder)
            return;
        let name = qsTr("untitled folder");
        for (let n = 2; nameTaken(name); n++)
            name = qsTr("untitled folder") + " " + n;
        remember([name], screen, cell);
        editName = name;
        Quickshell.execDetached(["mkdir", "-p", "--", folder + "/" + name]);
    }

    // Files dragged in from elsewhere are copied here, at the cells around where they were dropped.
    function dropFiles(paths, screen, cell) {
        paths = paths.filter(p => p && !p.startsWith(folder + "/"));
        if (!folder || paths.length === 0)
            return;
        remember(paths.map(p => p.replace(/\/+$/, "").split("/").pop()), screen, cell);
        Quickshell.execDetached(["cp", "-rn", "--", ...paths, folder + "/"]);
    }

    function remember(names, screen, cell) {
        const key = displays[screen?.name]?.key;
        if (!key)
            return;
        const g = grid(screen);
        const taken = new Set((placements[screen.name] ?? []).map(e => e.col + "," + e.row));
        const next = Object.assign({}, pendingPlaces);
        for (const name of names) {
            const c = freeCell(g, taken, cell);
            taken.add(c.col + "," + c.row);
            next[name] = {
                monitor: key,
                col: c.col,
                row: c.row
            };
        }
        pendingPlaces = next;
    }

    function openFolder() {
        if (folder)
            Launch.app(["gio", "open", "file://" + folder]);
    }

    // A System Settings pane, starting the app if needed
    function openSettings(pane) {
        Quickshell.execDetached(["sh", "-c", `d=$HOME/.config/system-settings
            if ! qs -p "$d" ipc call settings show 2>/dev/null; then
                qs -p "$d" -n -d >/dev/null 2>&1
                for i in 1 2 3 4 5 6 7 8 9 10; do sleep 0.2; qs -p "$d" ipc call settings show 2>/dev/null && break; done
            fi
            qs -p "$d" ipc call settings open "$1" ""`, "sh", pane]);
    }

    // ---- One window per display ----

    readonly property var windows: windowVariants.instances

    Variants {
        id: windowVariants

        model: Settings.loaded && (root.showIcons || root.drawWallpaper) ? Quickshell.screens : []

        DesktopWindow {
            required property var modelData

            screen: modelData
            desktop: root
        }
    }
}
