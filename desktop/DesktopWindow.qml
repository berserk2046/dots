import QtQuick
import Quickshell
import Quickshell.Wayland

// One display's desktop: its wallpaper, when the desktop draws it, and the items that live on this
// display (DesktopShell.qml decides which and where). Under the windows, on every workspace.
//   Click selects (Ctrl or Shift adds), dragging on empty space selects several, dragging items moves
//   them, also onto another display. Double-click or Return opens, F2 renames, Delete moves to the
//   Trash, Ctrl+A selects all, right-click for a menu. Files dropped here from elsewhere are copied in.
PanelWindow {
    id: win

    property var desktop: null // DesktopShell
    readonly property bool icons: desktop?.showIcons ?? false
    readonly property var placed: icons ? (desktop.placements[screen?.name] ?? []) : []
    readonly property var grid: desktop ? desktop.grid(screen) : null
    readonly property real dpr: screen?.devicePixelRatio ?? 1

    // This display's selected item ids
    property var selection: []
    // Dragging items (a real drag and drop, so they can go to another display, the Dock, a file manager)
    property bool dragging: false
    // Selecting with a rectangle
    property bool banding: false
    property rect band: Qt.rect(0, 0, 0, 0)
    // The entry being renamed
    property var renaming: null
    // Context menu: [{label, act} or {separator: true}]
    property var menuEntries: []
    property point menuAt: Qt.point(0, 0)

    // Full screen, under the menu bar and the Dock too, like a wallpaper; the grid leaves their space free.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"

    // Above hyprpaper's wallpaper when that draws it. Hyprland's blur of the wallpaper for the menu bar
    // (xray) includes this layer too, so the bar looks the same either way.
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "desktop"
    // Keys (Delete, Return, F2, renaming) only after the desktop is clicked, and only while the pointer
    // stays on it. Hyprland gives keyboard focus to any layer that can take it as soon as the pointer is
    // over it, with any focus mode, without updating its own idea of the focused window. So a desktop that
    // could always take keys would steal focus from a window whenever the pointer left it (focus follows
    // mouse), and clicking that window again wouldn't give it back (focus on click: Hyprland thinks it
    // still has focus). Hence: no keys until clicked, and given back as soon as the pointer leaves for a
    // window, the bar or the Dock (Hyprland then refocuses the last window), or when Hyprland focuses
    // something else.
    property bool keysWanted: false
    // Right after the click, briefly Exclusive: Hyprland gives an exclusive layer the keys at once
    // (On demand alone would wait for the pointer to move); back to On demand, it keeps them.
    // Taken when the button goes up (or items are dropped here), never while it's held: taking the keys
    // makes Hyprland refocus, which cancels the press, and with it a drag about to start.
    property bool keysGrab: false
    WlrLayershell.keyboardFocus: !icons || !keysWanted ? WlrKeyboardFocus.None
                               : keysGrab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    function takeKeys() {
        if (keysWanted)
            return;
        keysWanted = true;
        keysGrab = true;
        keysGrabTimer.restart();
    }

    function releaseKeys() {
        if (!keysWanted)
            return;
        if (renaming)
            commitRename();
        keysGrabTimer.stop();
        keysGrab = false;
        keysWanted = false;
    }

    Timer {
        id: keysGrabTimer

        interval: 120
        onTriggered: win.keysGrab = false
    }

    // Lost the keys to something else (a window focused by a shortcut, the desktop on another display)
    readonly property bool hasKeys: keys.Window.active
    onHasKeysChanged: {
        if (!hasKeys && !keysGrab)
            releaseKeys();
    }

    // Only a wallpaper: clicks go through
    property Region noInput: Region {}
    mask: icons ? null : noInput

    // The wallpaper shown: wallpaper.py's copy at this display's exact size when there's a current one.
    // Otherwise one is asked for and the previous picture stays meanwhile; after 5 seconds without one
    // (e.g. no System Settings), the full picture, decoded at this display's size.
    property string wallpaperShown: ""
    readonly property string wallpaperWanted: desktop?.drawWallpaper ? desktop.wallpaperFor(screen?.name ?? "") : ""
    readonly property string wallpaperScaled: desktop?.scaledIndexLoaded ? desktop.scaledWallpaper(screen) : ""
    readonly property bool scaledIndexLoaded: desktop?.scaledIndexLoaded ?? false

    onWallpaperWantedChanged: updateWallpaper()
    onWallpaperScaledChanged: updateWallpaper()
    onScaledIndexLoadedChanged: updateWallpaper()
    Component.onCompleted: updateWallpaper()

    function updateWallpaper() {
        if (!wallpaperWanted) {
            wallpaperShown = "";
            fallback.stop();
        } else if (desktop.wallpaperFit === "tile") {
            wallpaperShown = wallpaperWanted;
        } else if (wallpaperScaled) {
            wallpaperShown = wallpaperScaled;
            fallback.stop();
        } else if (scaledIndexLoaded) {
            desktop.requestScaled();
            fallback.restart();
        }
    }

    Timer {
        id: fallback

        interval: 5000
        onTriggered: {
            if (!win.wallpaperScaled && win.wallpaperWanted)
                win.wallpaperShown = win.wallpaperWanted;
        }
    }

    onPlacedChanged: {
        // Items that went to another display or away from the desktop aren't selected here anymore
        const here = new Set(placed.map(e => e.item.id));
        if (selection.some(id => !here.has(id)))
            selection = selection.filter(id => here.has(id));
        // A new folder: edit its name right away
        if (desktop?.editName) {
            const entry = placed.find(e => e.item.name === desktop.editName);
            if (entry) {
                desktop.editName = "";
                selection = [entry.item.id];
                Qt.callLater(() => win.startRename(entry));
            }
        }
    }

    function iconSource(item) {
        if (item.kind === "image")
            return item.uri;
        for (const name of item.icons) {
            if (name.startsWith("/"))
                return "file://" + name;
            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
        }
        return Quickshell.iconPath(item.dir ? "folder" : "text-x-generic");
    }

    function isSelected(entry) {
        return selection.includes(entry.item.id);
    }

    function selectedEntries() {
        return placed.filter(e => isSelected(e));
    }

    function entryAt(x, y) {
        const pad = desktop.gridSpacing / 2;
        for (const e of placed) {
            const p = desktop.cellPos(grid, e.col, e.row);
            if (x >= p.x + pad && x < p.x + desktop.cellWidth - pad && y >= p.y && y < p.y + desktop.cellHeight - pad)
                return e;
        }
        return null;
    }

    // Dragging the selected items, from the item `anchor` (pressed at `from`): a Wayland drag and drop
    // carrying their file URIs, so the compositor draws them under the pointer on every display, and they
    // can be dropped on another display's desktop (moved there), on the Dock (opened with that app, or
    // trashed) or in a file manager (moved or copied, as it decides). The picture carried is the selected
    // items as laid out here, drawn off-screen first.
    function startDrag(anchor, from) {
        const sel = selectedEntries();
        if (sel.length === 0)
            return;
        dragging = true;
        closeMenu();
        const pts = sel.map(e => ({
                    item: e.item,
                    p: desktop.cellPos(grid, e.col, e.row)
                }));
        const minX = Math.min(...pts.map(q => q.p.x));
        const minY = Math.min(...pts.map(q => q.p.y));
        dragImage.width = Math.max(...pts.map(q => q.p.x)) - minX + desktop.cellWidth;
        dragImage.height = Math.max(...pts.map(q => q.p.y)) - minY + desktop.cellHeight;
        dragImage.entries = pts.map(q => ({
                    item: q.item,
                    x: q.p.x - minX,
                    y: q.p.y - minY
                }));
        dragImage.Drag.hotSpot = Qt.point(from.x - minX, from.y - minY);
        dragImage.Drag.mimeData = {
            "text/uri-list": sel.map(e => e.item.uri).join("\r\n") + "\r\n"
        };
        const a = desktop.cellPos(grid, anchor.col, anchor.row);
        // For the desktop the items are dropped on (maybe this one): which items, and where in the
        // anchor's cell the pointer holds it, so they land where they're seen
        desktop.dragged = {
            ids: sel.map(e => e.item.id),
            anchor: {
                col: anchor.col,
                row: anchor.row
            },
            grab: Qt.point(from.x - a.x, from.y - a.y),
            moves: sel.map(e => ({
                        id: e.item.id,
                        col: e.col,
                        row: e.row
                    })),
            screen: screen.name
        };
        dragImage.grabToImage(result => {
            if (!win.dragging)
                return; // released meanwhile
            dragImage.Drag.imageSource = result.url;
            dragImage.Drag.active = true;
        });
    }

    function endDrag() {
        dragging = false;
        dragImage.Drag.active = false;
        dragImage.entries = [];
        pointer.pressed = null;
        // Dropped somewhere else than a desktop (the Dock, a window): this one lets go of the keys, as
        // the pointer is gone from it. Dropped on a desktop, that one has taken them (dropMoved).
        if (!desktop.dragged?.landed)
            releaseKeys();
        // After any drop handler that still wants it has run
        Qt.callLater(() => {
            if (!win.dragging && win.desktop.dragged?.screen === win.screen?.name)
                win.desktop.dragged = null;
        });
    }

    // The desktop's own items dropped here at (x, y): the item held goes to the cell its middle is over,
    // the others keep their places relative to it.
    function dropMoved(x, y, d) {
        // The desktop stays the thing being worked with: the keys come here, no window gets them
        d.landed = true;
        selection = d.ids;
        Qt.callLater(() => win.takeKeys());
        const cell = desktop.cellAt(grid, x - d.grab.x + desktop.cellWidth / 2, y - d.grab.y + desktop.cellHeight / 2);
        const dc = cell.col - d.anchor.col;
        const dr = cell.row - d.anchor.row;
        if (d.screen === screen.name && dc === 0 && dr === 0)
            return;
        desktop.moveItems(d.moves.map(m => ({
                        id: m.id,
                        col: m.col + dc,
                        row: m.row + dr
                    })), screen);
    }

    function startRename(entry) {
        closeMenu();
        renaming = entry;
        renameInput.text = entry.item.name;
        renameInput.forceActiveFocus();
        const dot = entry.item.dir ? -1 : entry.item.name.lastIndexOf(".");
        renameInput.select(0, dot > 0 ? dot : entry.item.name.length);
    }

    function commitRename() {
        const entry = renaming;
        renaming = null;
        if (entry)
            desktop.rename(entry.item, renameInput.text);
        keys.forceActiveFocus();
    }

    function cancelRename() {
        renaming = null;
        keys.forceActiveFocus();
    }

    function openMenu(hit, x, y) {
        const cell = desktop.cellAt(grid, x, y);
        if (hit) {
            const sel = selectedEntries();
            menuEntries = [
                {
                    label: qsTr("Open"),
                    act: () => sel.slice(0, 10).forEach(e => desktop.open(e.item))
                },
                ...(sel.length === 1 ? [
                        {
                            label: qsTr("Rename"),
                            act: () => win.startRename(sel[0])
                        }
                    ] : []),
                ...(sel.length === 1 && sel[0].item.untrusted ? [
                        {
                            label: qsTr("Allow Launching"),
                            act: () => desktop.allowLaunching(sel[0].item)
                        }
                    ] : []),
                {
                    separator: true
                },
                {
                    label: qsTr("Move to Trash"),
                    act: () => desktop.trash(sel.map(e => e.item))
                }
            ];
        } else {
            menuEntries = [
                {
                    label: qsTr("New Folder"),
                    act: () => desktop.newFolder(win.screen, cell)
                },
                {
                    separator: true
                },
                {
                    label: qsTr("Sort by Name"),
                    act: () => desktop.sortBy(win.screen, "name")
                },
                {
                    label: qsTr("Sort by Kind"),
                    act: () => desktop.sortBy(win.screen, "kind")
                },
                {
                    label: qsTr("Sort by Date Modified"),
                    act: () => desktop.sortBy(win.screen, "date")
                },
                {
                    separator: true
                },
                {
                    label: qsTr("Open Desktop Folder"),
                    act: () => desktop.openFolder()
                },
                {
                    label: qsTr("Change Wallpaper…"),
                    act: () => desktop.openSettings("wallpaper")
                },
                {
                    label: qsTr("Desktop Settings…"),
                    act: () => desktop.openSettings("desktopDock")
                }
            ];
        }
        menuAt = Qt.point(x, y);
        menu.visible = true;
    }

    function closeMenu() {
        menu.visible = false;
    }

    // ---- Wallpaper ----

    // Everything the window shows, in one item (also what a screenshot of the desktop grabs)
    readonly property Item canvas: canvasItem

    Item {
        id: canvasItem

        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "black"
            visible: win.desktop?.drawWallpaper ?? false
        }

        Image {
            anchors.fill: parent
            visible: win.desktop?.drawWallpaper ?? false
            readonly property string fit: win.desktop?.wallpaperFit ?? "cover"
            source: visible && win.width > 0 && win.wallpaperShown ? "file://" + win.wallpaperShown : ""
            fillMode: fit === "contain" ? Image.PreserveAspectFit : fit === "tile" ? Image.Tile : Image.PreserveAspectCrop
            // Decoded at this display's size (just covering it, for Fill), not the picture's
            sourceSize: fit === "tile" ? Qt.size(0, 0) : Qt.size(Math.round(win.width * win.dpr), Math.round(win.height * win.dpr))
            asynchronous: true
            cache: false
        }

        // ---- Items ----

        // Holds keyboard focus for the shortcuts
        Item {
            id: keys

            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (win.renaming)
                    return;
                const sel = win.selectedEntries();
                if (event.key === Qt.Key_Delete) {
                    win.desktop.trash(sel.map(e => e.item));
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sel.slice(0, 10).forEach(e => win.desktop.open(e.item));
                } else if (event.key === Qt.Key_F2 && sel.length === 1) {
                    win.startRename(sel[0]);
                } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                    win.selection = win.placed.map(e => e.item.id);
                } else if (event.key === Qt.Key_Escape) {
                    win.closeMenu();
                    win.selection = [];
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        Repeater {
            model: win.placed

            ItemView {
                required property var modelData
                readonly property point pos: win.desktop.cellPos(win.grid, modelData.col, modelData.row)

                item: modelData.item
                selected: win.selection.includes(modelData.item.id)
                labelShown: win.renaming?.item.id !== modelData.item.id
                x: pos.x
                y: pos.y
                // Left in place, faded, while the compositor shows them under the pointer
                opacity: selected && win.dragging ? 0.4 : 1
            }
        }

        // What the pointer carries while dragging items: drawn here, off-screen, then grabbed as a picture
        Item {
            id: dragImage

            property var entries: [] // [{item, x, y}]

            x: -width - 100
            y: 0
            visible: entries.length > 0

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.MoveAction | Qt.CopyAction | Qt.LinkAction
            Drag.proposedAction: Qt.MoveAction
            Drag.onDragFinished: dropAction => win.endDrag()

            Repeater {
                model: dragImage.entries

                ItemView {
                    required property var modelData

                    item: modelData.item
                    selected: true
                    // Loaded right away, so the grab doesn't catch an empty icon (it's cached anyway)
                    asyncIcon: false
                    x: modelData.x
                    y: modelData.y
                }
            }
        }

        Rectangle {
            visible: win.banding
            x: win.band.x
            y: win.band.y
            width: win.band.width
            height: win.band.height
            color: "#260a84ff"
            border.width: 1
            border.color: "#b30a84ff"
        }

        // Drops: the desktop's own items dragged here (from this display or another) move to where they're
        // dropped; files dragged in from a file manager (or anything that drags files) are copied to the
        // desktop, except files already on it (e.g. dragged from ~/Desktop in a file manager), which move.
        DropArea {
            anchors.fill: parent
            enabled: win.icons

            onEntered: drag => drag.accepted = drag.hasUrls
            onDropped: drop => {
                if (!drop.hasUrls)
                    return;
                const desktop = win.desktop;
                const paths = drop.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(p => p.startsWith("/"));
                const d = desktop.dragged;
                const ownIds = paths.map(p => desktop.items.find(i => i.path === p.replace(/\/+$/, ""))?.id).filter(id => id !== undefined);
                if (d && ownIds.length === paths.length && ownIds.every(id => d.ids.includes(id))) {
                    win.dropMoved(drop.x, drop.y, d);
                    drop.accept(Qt.MoveAction);
                    return;
                }
                const cell = desktop.cellAt(win.grid, drop.x, drop.y);
                if (ownIds.length > 0)
                    desktop.moveItems(ownIds.map(id => ({
                                    id: id,
                                    col: cell.col,
                                    row: cell.row
                                })), win.screen);
                desktop.dropFiles(paths, win.screen, cell);
                drop.accept(ownIds.length === paths.length ? Qt.MoveAction : Qt.CopyAction);
            }
        }

        MouseArea {
            id: pointer

            property point start: Qt.point(0, 0)
            property var pressed: null
            property var bandBase: []

            anchors.fill: parent
            enabled: win.icons
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // To notice the pointer leaving for a window, the bar or the Dock
            hoverEnabled: true

            // (Not while dragging: Hyprland takes the pointer away from the desktop for the drag, which
            // isn't the pointer leaving it.)
            onExited: {
                if (pressedButtons === 0 && !win.dragging)
                    win.releaseKeys();
            }

            onCanceled: {
                if (win.dragging && !dragImage.Drag.active)
                    win.endDrag();
                win.banding = false;
            }

            onPressed: mouse => {
                win.closeMenu();
                if (win.renaming)
                    win.commitRename();
                keys.forceActiveFocus();
                const hit = win.entryAt(mouse.x, mouse.y);
                const adding = mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier);
                start = Qt.point(mouse.x, mouse.y);
                pressed = hit;
                if (win.dragging)
                    win.endDrag();
                win.banding = false;
                if (mouse.button === Qt.RightButton) {
                    if (!hit)
                        win.selection = [];
                    else if (!win.isSelected(hit))
                        win.selection = [hit.item.id];
                    win.openMenu(hit, mouse.x, mouse.y);
                    return;
                }
                if (hit) {
                    if (adding)
                        win.selection = win.isSelected(hit) ? win.selection.filter(id => id !== hit.item.id) : [...win.selection, hit.item.id];
                    else if (!win.isSelected(hit))
                        win.selection = [hit.item.id];
                } else {
                    bandBase = adding ? win.selection : [];
                    win.selection = bandBase;
                    win.band = Qt.rect(mouse.x, mouse.y, 0, 0);
                    win.banding = true;
                }
            }

            onPositionChanged: mouse => {
                if (win.banding) {
                    const x = Math.min(start.x, mouse.x);
                    const y = Math.min(start.y, mouse.y);
                    win.band = Qt.rect(x, y, Math.abs(mouse.x - start.x), Math.abs(mouse.y - start.y));
                    const inBand = win.placed.filter(e => {
                        const p = win.desktop.cellPos(win.grid, e.col, e.row);
                        return p.x + win.desktop.cellWidth > x && p.x < x + win.band.width && p.y + win.desktop.cellHeight > y && p.y < y + win.band.height;
                    }).map(e => e.item.id);
                    win.selection = [...new Set([...bandBase, ...inBand])];
                    return;
                }
                if (pressed && !win.dragging && (mouse.buttons & Qt.LeftButton) && win.isSelected(pressed) && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 6)
                    win.startDrag(pressed, start);
            }

            onReleased: mouse => {
                if (win.dragging) {
                    // Let go before the drag got going: nothing moves
                    if (!dragImage.Drag.active)
                        win.endDrag();
                } else if (pressed && mouse.button === Qt.LeftButton && !(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
                    win.selection = [pressed.item.id];
                }
                win.banding = false;
                if (!win.dragging) {
                    pressed = null;
                    win.takeKeys();
                }
            }

            onDoubleClicked: mouse => {
                const hit = win.entryAt(mouse.x, mouse.y);
                if (hit && mouse.button === Qt.LeftButton)
                    win.desktop.open(hit.item);
            }
        }

        // ---- Renaming ----

        Rectangle {
            id: renameBox

            readonly property point pos: win.renaming ? win.desktop.cellPos(win.grid, win.renaming.col, win.renaming.row) : Qt.point(0, 0)

            visible: win.renaming !== null
            x: pos.x + 2
            y: pos.y + win.desktop.iconSize + 12
            width: win.desktop.cellWidth - 4
            height: renameInput.contentHeight + 6
            radius: 4
            color: "white"
            border.width: 2
            border.color: "#0a84ff"

            TextInput {
                id: renameInput

                anchors.fill: parent
                anchors.margins: 3
                horizontalAlignment: TextInput.AlignHCenter
                wrapMode: TextInput.WrapAnywhere
                color: "black"
                selectionColor: "#b3d7ff"
                selectedTextColor: "black"
                selectByMouse: true
                font.family: "SF Pro Text"
                font.pixelSize: win.desktop?.textSize ?? 12

                Keys.onReturnPressed: win.commitRename()
                Keys.onEnterPressed: win.commitRename()
                Keys.onEscapePressed: win.cancelRename()
                onActiveFocusChanged: {
                    if (!activeFocus && win.renaming)
                        win.commitRename();
                }
            }
        }

        // ---- Menu ----

        Rectangle {
            id: menu

            readonly property bool light: win.desktop?.light ?? false

            visible: false
            x: Math.max(4, Math.min(win.menuAt.x, win.width - width - 4))
            y: Math.max(4, Math.min(win.menuAt.y, win.height - height - 4))
            width: 230
            height: menuColumn.implicitHeight + 10
            radius: 9
            color: light ? "#f5f6f6f6" : "#f21e1e20"
            border.width: 1
            border.color: light ? "#1f000000" : "#26ffffff"

            Column {
                id: menuColumn

                x: 5
                y: 5
                width: parent.width - 10

                Repeater {
                    model: win.menuEntries

                    Item {
                        id: entry

                        required property var modelData

                        width: menuColumn.width
                        height: modelData.separator ? 9 : 26

                        Rectangle {
                            visible: entry.modelData.separator === true
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: 1
                            color: menu.light ? "#1f000000" : "#26ffffff"
                        }

                        Rectangle {
                            visible: entry.modelData.separator !== true
                            anchors.fill: parent
                            radius: 5
                            color: entryMouse.containsMouse ? "#0a84ff" : "transparent"

                            Text {
                                textFormat: Text.PlainText
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                text: entry.modelData.label ?? ""
                                color: entryMouse.containsMouse || !menu.light ? "white" : "#e6000000"
                                font.family: "SF Pro Text"
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: entryMouse

                                anchors.fill: parent
                                enabled: entry.modelData.separator !== true
                                hoverEnabled: true
                                onClicked: {
                                    win.closeMenu();
                                    entry.modelData.act();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // One item as it shows on the desktop, one grid cell big: its icon and its name
    component ItemView: Item {
        id: view

        property var item: null
        property bool selected: false
        property bool labelShown: true
        property bool asyncIcon: true

        width: win.desktop.cellWidth
        height: win.desktop.cellHeight

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 2
            width: win.desktop.iconSize + 12
            height: width
            radius: 7
            color: "#47000000"
            border.width: 1
            border.color: "#33ffffff"
            visible: view.selected
        }

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: win.desktop.iconSize
            height: width
            source: view.item ? win.iconSource(view.item) : ""
            sourceSize: Qt.size(Math.round(width * win.dpr), Math.round(height * win.dpr))
            fillMode: Image.PreserveAspectFit
            asynchronous: view.asyncIcon
        }

        Rectangle {
            anchors.horizontalCenter: label.horizontalCenter
            y: label.y - 1
            width: label.contentWidth + 10
            height: label.contentHeight + 2
            radius: 4
            color: "#0a64d6"
            visible: view.selected && label.visible
        }

        Text {
            textFormat: Text.PlainText
            id: label

            anchors.horizontalCenter: parent.horizontalCenter
            y: win.desktop.iconSize + 14
            width: parent.width - win.desktop.gridSpacing - 8
            text: view.item?.label ?? ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
            color: "white"
            style: view.selected ? Text.Normal : Text.Raised
            styleColor: "#b3000000"
            font.family: "SF Pro Text"
            font.pixelSize: win.desktop.textSize
            font.weight: Font.Medium
            visible: view.labelShown
        }
    }
}
