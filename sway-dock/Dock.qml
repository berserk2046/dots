import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: dock

    property var pinnedApps: []
    property MimeIndex mimeIndex: null
    property LauncherBadges badges: null
    property HyprlandEvents hyprland: null
    property int iconSize: 40
    property int maxIconSize: 64
    property int spacing: 6
    property int padding: 8
    property int sidePadding: 14 // left/right padding inside the bar
    property int separatorWidth: 9 // gap holding the line between apps and the trash
    property int edgeMargin: 2
    property real magnifyRange: 120 // px from an icon's center where magnification fades out
    // Screen edge the dock sits on: "bottom", "top", "left" or "right".
    property string position: "bottom"
    // Slides off screen until the pointer touches the edge; reserves no space.
    property bool autoHide: false
    property bool showIndicators: true
    readonly property bool vertical: position === "left" || position === "right"
    // Room beside the bar for magnified icons, labels and the menu.
    readonly property int headroom: vertical ? 280 : 260
    // Used for Terminal=true apps such as nvim; {appId} lets the dock recognize the window.
    property var terminal: ["foot", "--app-id={appId}"]

    readonly property int barHeight: iconSize + padding * 2
    // Desktop entries are passed only so app matching re-runs once they finish loading.
    readonly property var apps: buildApps(pinnedApps, ToplevelManager.toplevels.values,
                                          DesktopEntries.applications.values)

    // Unmagnified layout (apps, separator, trash), used to compute magnification without jitter.
    readonly property real baseRowWidth: (apps.length + 1) * iconSize + (apps.length + 1) * spacing + separatorWidth
    readonly property real baseRowLeft: ((vertical ? content.height : content.width) - baseRowWidth) / 2

    signal pinRequested(string id)
    signal unpinRequested(string id)
    signal pinnedOrderRequested(var ids)

    // Reorder state: index being dragged, slot it would drop into, pointer x at start and now.
    property int dragFrom: -1
    property int dragTo: -1
    property real dragStartX: 0
    property real dragX: 0
    property real dragStartY: 0
    property real dragY: 0
    property DockItem dragItem: null
    // Where the pointer grabbed the icon, in unmagnified icon coordinates.
    property real dragGrabX: 0
    property real dragGrabY: 0
    // A pinned icon dragged this far away from the dock is unpinned on release.
    readonly property bool dragRemoving: dragFrom >= 0 && apps[dragFrom]?.pinned === true
                                         && depthOf(dragX, dragY) > edgeMargin + barHeight + iconSize * 1.5
    // In-memory focus history (window -> serial), shared with icons so they raise the most
    // recently used window. Covers every window, however it was launched; nothing is saved.
    property var focusStamps: new Map()
    property int focusSerial: 0
    // After files are dropped on an app, a new window of it appearing shortly after gets focus.
    property var dropWatch: null

    // Icon under the pointer; hovering a running app opens the window preview list.
    property DockItem hoveredItem: null
    // Pointer x when it entered the preview; magnification stays frozen there meanwhile.
    property real previewHoverX: -1

    // Pointer x when the menu opened; magnification stays frozen there while the menu is open.
    property real menuHoverX: -1

    // Magnification starts only when the pointer enters the bar itself, then stays on while it
    // moves over the magnified icons above it. Being in the strip above the bar (e.g. after a
    // click there closed the menu) doesn't start it.
    property bool magnifying: false

    // App keys launched from the dock -> time they stop bouncing if no window shows up.
    property var launchingApps: ({})

    // Auto-hide: shown after the pointer rests on the screen edge, hidden shortly after it leaves.
    property bool hoverReveal: false
    readonly property bool revealed: !autoHide || hoverReveal || menu.visible || dragFrom >= 0
    // How far the bar is slid off screen (animated).
    property real hiddenShift: revealed ? 0 : barHeight + edgeMargin + 8

    Behavior on hiddenShift {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // Top left corner of this surface on its screen, for the fullscreen overlays. Read from
    // `hyprctl layers`, since other bars' reserved space (e.g. waybar's) can move the dock.
    property point surfaceOrigin: Qt.point(0, 0)

    // Hidden (but keeping its reserved space) while the focused window is fullscreen here.
    readonly property bool fullscreenHere: {
        const active = ToplevelManager.activeToplevel;
        if (!active || !active.fullscreen)
            return false;
        return Array.from(active.screens ?? []).some(s => s === screen || s?.name === screen?.name);
    }

    anchors {
        bottom: position !== "top"
        top: position !== "bottom"
        left: position !== "right"
        right: position !== "left"
    }
    // Headroom beside the bar for magnification, labels and the menu.
    // Fixed so the surface never resizes (resizing makes the icons jump); the mask lets clicks through.
    implicitHeight: vertical ? 0 : maxIconSize + padding * 2 + edgeMargin + headroom
    implicitWidth: vertical ? maxIconSize + padding * 2 + edgeMargin + headroom : 0
    exclusiveZone: autoHide ? 0 : barHeight + edgeMargin
    color: "transparent"

    WlrLayershell.namespace: "sway-dock"
    WlrLayershell.layer: WlrLayer.Top

    // Only the dock itself takes input; the transparent headroom passes clicks through.
    mask: Region {
        item: inputArea
    }

    onFullscreenHereChanged: {
        closeMenu();
        preview.target = null;
    }

    onPositionChanged: {
        closeMenu();
        preview.target = null;
        refreshOrigin();
    }
    onWidthChanged: refreshOrigin()
    onHeightChanged: refreshOrigin()
    Component.onCompleted: refreshOrigin()

    function refreshOrigin() {
        if (!originProc.running)
            originProc.running = true;
    }

    Process {
        id: originProc

        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const levels = JSON.parse(text)[dock.screen?.name]?.levels ?? {};
                    for (const level in levels) {
                        const layer = levels[level].find(l => l.namespace === "sway-dock");
                        if (layer) {
                            dock.surfaceOrigin = Qt.point(layer.x - (dock.screen?.x ?? 0), layer.y - (dock.screen?.y ?? 0));
                            return;
                        }
                    }
                } catch (error) {}
            }
        }
    }

    // Distance from the dock's screen edge into the screen, for a point in this surface.
    function depthOf(x, y) {
        switch (position) {
        case "top":
            return y;
        case "left":
            return x;
        case "right":
            return content.width - x;
        default:
            return content.height - y;
        }
    }

    // Coordinate along the dock (x for a horizontal dock, y for a vertical one).
    function along(point) {
        return vertical ? point.y : point.x;
    }

    // Where a menu or preview of this size goes, next to the target icon on the inner side.
    function popupPosition(target, width, height) {
        if (!target)
            return Qt.point(0, 0);
        const reach = edgeMargin + barHeight + (maxIconSize - iconSize) + 6;
        const cx = Math.max(4, Math.min(content.width - width - 4, row.x + target.x + target.width / 2 - width / 2));
        const cy = Math.max(4, Math.min(content.height - height - 4, row.y + target.y + target.height / 2 - height / 2));
        switch (position) {
        case "top":
            return Qt.point(cx, reach);
        case "left":
            return Qt.point(reach, cy);
        case "right":
            return Qt.point(content.width - reach - width, cy);
        default:
            return Qt.point(cx, content.height - reach - height);
        }
    }

    onAppsChanged: {
        closeMenu();
        dragFrom = -1;
        dragTo = -1;
        dragItem = null;
        hoveredItem = null;
        preview.target = null;
    }

    function markLaunching(appId) {
        const next = Object.assign({}, launchingApps);
        next[appKey(appId)] = Date.now() + 10000;
        launchingApps = next;
    }

    function isLaunching(app) {
        return app.windows.length === 0 && appKey(app.id) in launchingApps;
    }

    // A window of a launching app appeared: stop its bounce now rather than at the timeout,
    // so closing the app soon after doesn't make it bounce again.
    function clearLaunching(window) {
        if (!window.appId)
            return;
        const key = appKey(window.appId);
        if (!(key in launchingApps))
            return;
        const next = Object.assign({}, launchingApps);
        delete next[key];
        launchingApps = next;
    }

    function pruneLaunching() {
        const now = Date.now();
        const next = {};
        for (const key in launchingApps) {
            if (launchingApps[key] > now)
                next[key] = launchingApps[key];
        }
        launchingApps = next;
    }

    function isUrgent(app) {
        const key = appKey(app.id);
        if (badges?.badgeFor(key)?.urgent === true)
            return true;
        return (hyprland?.urgentAppIds ?? []).some(id => appKey(id) === key);
    }

    function forceQuit(app) {
        const key = appKey(app.id);
        hyprland?.forceQuit(id => appKey(id) === key);
    }

    function noteFocus(window) {
        focusStamps.set(window, ++focusSerial);
    }

    function forgetWindow(window) {
        focusStamps.delete(window);
    }

    function recencyOf(window) {
        return focusStamps.get(window) ?? 0;
    }

    function watchDrop(appId) {
        dropWatch = {
            key: appKey(appId),
            until: Date.now() + 3000
        };
    }

    function checkDropWindow(window) {
        if (!dropWatch || !window.appId)
            return;
        if (Date.now() > dropWatch.until) {
            dropWatch = null;
        } else if (appKey(window.appId) === dropWatch.key) {
            dropWatch = null;
            window.activate();
        }
    }

    function appKey(id) {
        const entry = DesktopEntries.heuristicLookup(id);
        return String(entry ? entry.id : id).toLowerCase();
    }

    function buildApps(pinned, toplevels, entries) {
        const result = [];
        const byKey = {};
        for (const id of pinned) {
            const app = {
                id: id,
                pinned: true,
                windows: []
            };
            byKey[appKey(id)] = app;
            result.push(app);
        }
        for (const toplevel of toplevels) {
            if (!toplevel.appId)
                continue;
            const key = appKey(toplevel.appId);
            let app = byKey[key];
            if (!app) {
                app = {
                    id: toplevel.appId,
                    pinned: false,
                    windows: []
                };
                byKey[key] = app;
                result.push(app);
            }
            app.windows.push(toplevel);
        }
        return result;
    }

    function startReorder(index, x, y, target) {
        closeMenu();
        refreshOrigin();
        preview.target = null;
        const origin = target.mapToItem(null, 0, 0);
        dragGrabX = (x - origin.x) * iconSize / target.width;
        dragGrabY = (y - origin.y) * iconSize / target.height;
        dragItem = target;
        dragFrom = index;
        dragTo = index;
        dragStartX = x;
        dragX = x;
        dragStartY = y;
        dragY = y;
    }

    function moveReorder(x, y) {
        dragX = x;
        dragY = y;
        const step = iconSize + spacing;
        const center = dragFrom * step + iconSize / 2 + dragDelta();
        dragTo = Math.max(0, Math.min(apps.length - 1, Math.round((center - iconSize / 2) / step)));
    }

    // Pinned apps are reordered; an unpinned app dropped among the pinned ones gets pinned there.
    function finishReorder(target) {
        const from = dragFrom;
        const to = dragTo;
        const app = apps[from];
        const removing = dragRemoving;
        dragItem = null;
        dragFrom = -1;
        dragTo = -1;
        if (app && removing) {
            Qt.callLater(() => dock.unpinRequested(app.id));
            return;
        }
        const ids = apps.filter(a => a.pinned).map(a => a.id);
        if (!app || from === to || (!app.pinned && to >= ids.length))
            return;
        if (app.pinned)
            ids.splice(from, 1);
        ids.splice(Math.min(to, ids.length), 0, app.pinned ? app.id : target.pinId);
        Qt.callLater(() => dock.pinnedOrderRequested(ids));
    }

    // How far the dragged icon has moved along the dock.
    function dragDelta() {
        return vertical ? dragY - dragStartY : dragX - dragStartX;
    }

    function shiftFor(index) {
        if (dragFrom < 0)
            return 0;
        if (index === dragFrom)
            return dragDelta();
        const step = iconSize + spacing;
        // While removing, the icons after the dragged one close the gap.
        if (dragRemoving)
            return index > dragFrom ? -step : 0;
        if (dragFrom < dragTo && index > dragFrom && index <= dragTo)
            return -step;
        if (dragTo < dragFrom && index >= dragTo && index < dragFrom)
            return step;
        return 0;
    }

    function updateMagnifying() {
        if (!hover.hovered) {
            magnifying = false;
            return;
        }
        const p = hover.point.position;
        const start = vertical ? background.y : background.x;
        const length = vertical ? background.height : background.width;
        const overColumn = along(p) >= start && along(p) <= start + length;
        const depth = depthOf(p.x, p.y);
        const overBar = overColumn && depth <= edgeMargin + barHeight;
        const overIcons = overColumn && depth <= edgeMargin + barHeight + (maxIconSize - iconSize);
        magnifying = revealed && (overBar || (magnifying && overIcons));
    }

    function sizeFor(index) {
        const pointerX = menu.visible ? menuHoverX : previewHover.hovered ? previewHoverX : magnifying
                                                                                     ? along(hover.point.position) : -1;
        if (pointerX < 0 || dragFrom >= 0)
            return iconSize;
        // Index apps.length is the trash, which sits after the separator.
        const separator = index >= apps.length ? separatorWidth + spacing : 0;
        const center = baseRowLeft + index * (iconSize + spacing) + separator + iconSize / 2;
        const t = Math.max(0, 1 - Math.abs(pointerX - center) / magnifyRange);
        const eased = t * t * (3 - 2 * t);
        return iconSize + (maxIconSize - iconSize) * eased;
    }

    function openMenu(target, alternate) {
        menuHoverX = magnifying ? along(hover.point.position) : -1;
        refreshOrigin();
        preview.target = null;
        menu.alternate = alternate;
        menu.confirmEmpty = false;
        menu.target = menu.target === target ? null : target;
    }

    function closeMenu() {
        menu.target = null;
    }

    component MenuSeparator: Rectangle {
        x: 6
        width: parent.width - 12
        height: 1
        color: "#26ffffff"
    }

    component MenuEntry: Rectangle {
        id: entry

        property string text
        property bool checkable: false // window entries: leave room for the checkmark
        property bool checked: false
        property bool closesMenu: true
        property color textColor: "#ffffff"
        signal triggered

        width: parent.width
        height: 30
        radius: 7
        color: entryMouse.containsMouse ? "#33ffffff" : "transparent"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 9
            text: "✓"
            color: "#ffffff"
            font.family: "SF Pro"
            font.pixelSize: 13
            visible: entry.checked
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: entry.checkable ? 26 : 10
            anchors.rightMargin: 10
            elide: Text.ElideRight
            text: entry.text
            color: entry.textColor
            font.family: "SF Pro"
            font.pixelSize: 13
        }

        MouseArea {
            id: entryMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                entry.triggered();
                if (entry.closesMenu)
                    dock.closeMenu();
            }
        }
    }

    Item {
        id: content

        anchors.fill: parent
        visible: !dock.fullscreenHere

        HoverHandler {
            id: hover

            onHoveredChanged: {
                dock.updateMagnifying();
                if (hovered) {
                    concealTimer.stop();
                    revealTimer.restart();
                } else {
                    revealTimer.stop();
                    concealTimer.restart();
                }
            }
            onPointChanged: dock.updateMagnifying()
        }

        Timer {
            id: revealTimer

            interval: 150
            onTriggered: dock.hoverReveal = true
        }

        Timer {
            id: concealTimer

            interval: 450
            onTriggered: dock.hoverReveal = false
        }

        // While the menu is open the dock's input area also covers the empty space around the
        // menu; clicks there (or on the bar between icons) dismiss it like clicks elsewhere do.
        MouseArea {
            anchors.fill: parent
            enabled: menu.visible
            acceptedButtons: Qt.AllButtons
            onPressed: dock.closeMenu()
        }

        Item {
            id: inputArea

            readonly property Item popup: menu.visible ? menu : preview.visible ? preview : null
            // Grows inward while hovered so magnified icons (and the menu/preview) stay clickable.
            readonly property real grow: dock.magnifying ? dock.maxIconSize - dock.iconSize : 0
            // The bar from the screen edge to its inner side, plus the popup.
            readonly property rect barRect: {
                const b = Qt.rect(background.x, background.y, background.width, background.height);
                switch (dock.position) {
                case "top":
                    return Qt.rect(b.x, 0, b.width, b.y + b.height + grow);
                case "left":
                    return Qt.rect(0, b.y, b.x + b.width + grow, b.height);
                case "right":
                    return Qt.rect(b.x - grow, b.y, content.width - b.x + grow, b.height);
                default:
                    return Qt.rect(b.x, b.y - grow, b.width, content.height - b.y + grow);
                }
            }
            // Hidden: a thin strip on the screen edge along the bar reveals it.
            readonly property rect area: {
                if (!dock.revealed) {
                    const strip = 3;
                    switch (dock.position) {
                    case "top":
                        return Qt.rect(barRect.x, 0, barRect.width, strip);
                    case "left":
                        return Qt.rect(0, barRect.y, strip, barRect.height);
                    case "right":
                        return Qt.rect(content.width - strip, barRect.y, strip, barRect.height);
                    default:
                        return Qt.rect(barRect.x, content.height - strip, barRect.width, strip);
                    }
                }
                if (!popup)
                    return barRect;
                const left = Math.min(barRect.x, popup.x);
                const top = Math.min(barRect.y, popup.y);
                const right = Math.max(barRect.x + barRect.width, popup.x + popup.width);
                const bottom = Math.max(barRect.y + barRect.height, popup.y + popup.height);
                return Qt.rect(left, top, right - left, bottom - top);
            }

            x: area.x
            y: area.y
            width: dock.fullscreenHere ? 0 : area.width
            height: dock.fullscreenHere ? 0 : area.height
        }

        Rectangle {
            id: background

            // Distance of the bar's outer side from the screen edge (negative while hidden).
            readonly property real inset: dock.edgeMargin - dock.hiddenShift

            x: dock.position === "left" ? inset : dock.position === "right" ? content.width - inset - width
                                                                             : (content.width - width) / 2
            y: dock.position === "top" ? inset : dock.position === "bottom" ? content.height - inset - height
                                                                             : (content.height - height) / 2
            width: dock.vertical ? dock.barHeight : row.width + dock.sidePadding * 2
            height: dock.vertical ? row.height + dock.sidePadding * 2 : dock.barHeight
            radius: 22
            color: "#e612121a"
            border.width: 1
            border.color: "#26ffffff"
        }

        // Icons line up on the screen edge side, so magnified ones grow inward.
        Grid {
            id: row

            x: dock.position === "left" ? background.x + dock.padding
                                        : dock.position === "right" ? background.x + background.width - dock.padding - width
                                                                    : background.x + dock.sidePadding
            y: dock.position === "top" ? background.y + dock.padding
                                       : dock.position === "bottom" ? background.y + background.height - dock.padding - height
                                                                    : background.y + dock.sidePadding
            // One row (or column) however many apps there are
            columns: dock.vertical ? 1 : 1000
            spacing: dock.spacing
            horizontalItemAlignment: dock.position === "left" ? Grid.AlignLeft : dock.position === "right" ? Grid.AlignRight
                                                                                                        : Grid.AlignHCenter
            verticalItemAlignment: dock.position === "top" ? Grid.AlignTop : dock.position === "bottom" ? Grid.AlignBottom
                                                                                                       : Grid.AlignVCenter

            Repeater {
                model: dock.apps

                DockItem {
                    id: dockItem

                    required property var modelData
                    required property int index

                    app: modelData
                    terminal: dock.terminal
                    size: dock.sizeFor(index)
                    showLabel: !menu.visible && !preview.visible && dock.dragFrom < 0
                    shift: dock.shiftFor(index)
                    edge: dock.position
                    showIndicator: dock.showIndicators
                    dragging: dock.dragFrom === index
                    menuOpen: menu.visible
                    launching: dock.isLaunching(modelData)
                    urgent: dock.isUrgent(modelData)
                    badge: dock.badges?.badgeFor(pinId) ?? null
                    onLaunched: dock.markLaunching(modelData.id)
                    onMenuRequested: alternate => dock.openMenu(dockItem, alternate)
                    onHoveredChanged: {
                        if (hovered)
                            dock.hoveredItem = dockItem;
                        else if (dock.hoveredItem === dockItem)
                            dock.hoveredItem = null;
                    }
                    onDismissRequested: dock.closeMenu()
                    recencyOf: window => dock.recencyOf(window)
                    acceptsDrag: dock.mimeIndex ? dock.mimeIndex.accepts(pinId, dock.mimeIndex.dragTypes) : true
                    onFileDragEntered: urls => dock.mimeIndex?.resolveDrag(urls)
                    onFilesDropped: dock.watchDrop(modelData.id)
                    onReorderStarted: (x, y) => dock.startReorder(index, x, y, dockItem)
                    onReorderMoved: (x, y) => dock.moveReorder(x, y)
                    onReorderFinished: dock.finishReorder(dockItem)
                }
            }

            Item {
                width: dock.vertical ? dock.iconSize : dock.separatorWidth
                height: dock.vertical ? dock.separatorWidth : dock.iconSize

                Rectangle {
                    anchors.centerIn: parent
                    width: dock.vertical ? dock.iconSize * 0.8 : 1
                    height: dock.vertical ? 1 : dock.iconSize * 0.8
                    color: "#33ffffff"
                }
            }

            TrashItem {
                id: trashItem

                size: dock.sizeFor(dock.apps.length)
                edge: dock.position
                showLabel: !menu.visible && !preview.visible && dock.dragFrom < 0
                menuOpen: menu.visible
                onMenuRequested: dock.openMenu(trashItem, false)
                onDismissRequested: dock.closeMenu()
            }
        }

        // Stops launch bounces for apps that never opened a window.
        Timer {
            interval: 1000
            repeat: true
            running: Object.keys(dock.launchingApps).length > 0
            onTriggered: dock.pruneLaunching()
        }

        // Hover preview: the app's open windows; click one to focus it.
        Rectangle {
            id: preview

            property DockItem target: null

            visible: target !== null && target.running
            width: 260
            height: previewColumn.implicitHeight + 12
            x: dock.popupPosition(target, width, height).x
            y: dock.popupPosition(target, width, height).y
            radius: 12
            color: "#f012121a"
            border.width: 1
            border.color: "#26ffffff"

            HoverHandler {
                id: previewHover

                onHoveredChanged: {
                    if (hovered)
                        dock.previewHoverX = dock.along(hover.point.position);
                }
            }

            Column {
                id: previewColumn

                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                Text {
                    x: 10
                    width: parent.width - 20
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: preview.target?.entry?.name || preview.target?.app.id || ""
                    color: "#99ffffff"
                    font.family: "SF Pro"
                    font.pixelSize: 12
                    font.bold: true
                }

                Repeater {
                    model: preview.target?.app.windows ?? []

                    MenuEntry {
                        required property var modelData

                        text: modelData.title || modelData.appId
                        checkable: true
                        checked: modelData.activated
                        onTriggered: {
                            modelData.activate();
                            preview.target = null;
                        }
                    }
                }
            }
        }

        // Open the preview after a short hover (switching between icons is instant once open),
        // and close it shortly after the pointer leaves both the icon and the preview.
        Timer {
            interval: preview.visible ? 60 : 400
            running: dock.hoveredItem !== null && dock.hoveredItem.running && preview.target !== dock.hoveredItem
                     && !menu.visible && dock.dragFrom < 0
            onTriggered: preview.target = dock.hoveredItem
        }

        Timer {
            interval: 300
            running: preview.visible && !previewHover.hovered && dock.hoveredItem !== preview.target
            onTriggered: preview.target = null
        }

        Rectangle {
            id: menu

            property Item target: null
            readonly property DockItem app: target instanceof DockItem ? target : null
            readonly property bool forTrash: target !== null && target === trashItem
            property bool alternate: false // Alt held: Quit becomes Force Quit, as on macOS
            property bool confirmEmpty: false

            visible: target !== null
            width: 240
            height: menuColumn.implicitHeight + 12
            x: dock.popupPosition(target, width, height).x
            y: dock.popupPosition(target, width, height).y
            radius: 12
            color: "#f012121a"
            border.width: 1
            border.color: "#26ffffff"

            // Clicks on the menu's padding and separators don't dismiss it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Column {
                id: menuColumn

                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // The app's own desktop actions, e.g. Firefox's "New Private Window".
                Repeater {
                    model: menu.app?.entry?.actions ?? []

                    MenuEntry {
                        required property var modelData

                        text: modelData.name
                        onTriggered: menu.app.runAction(modelData)
                    }
                }

                MenuSeparator {
                    visible: (menu.app?.entry?.actions.length ?? 0) > 0
                }

                MenuEntry {
                    visible: menu.app !== null
                    text: qsTr("New Window")
                    onTriggered: menu.app.launch()
                }

                MenuEntry {
                    visible: menu.app !== null
                    text: menu.app?.app.pinned ? qsTr("Unpin from Dock") : qsTr("Pin to Dock")
                    onTriggered: menu.app.app.pinned ? dock.unpinRequested(menu.app.app.id)
                                                     : dock.pinRequested(menu.app.pinId)
                }

                MenuSeparator {
                    visible: menu.app?.running === true
                }

                MenuEntry {
                    visible: menu.app?.running === true
                    text: menu.alternate ? qsTr("Force Quit") : qsTr("Quit")
                    onTriggered: menu.alternate ? dock.forceQuit(menu.app.app) : menu.app.quit()
                }

                // Trash
                MenuEntry {
                    visible: menu.forTrash
                    text: qsTr("Open")
                    onTriggered: trashItem.open()
                }

                MenuEntry {
                    visible: menu.forTrash
                    enabled: trashItem.full
                    opacity: enabled ? 1 : 0.4
                    closesMenu: menu.confirmEmpty
                    textColor: menu.confirmEmpty ? "#ff6961" : "#ffffff"
                    text: menu.confirmEmpty ? qsTr("Click again to erase %n item(s)", "", trashItem.itemCount)
                                            : qsTr("Empty Trash")
                    onTriggered: {
                        if (menu.confirmEmpty)
                            trashItem.empty();
                        else
                            menu.confirmEmpty = true;
                    }
                }
            }
        }

    }

    // Watches every window's focus (for the focus history) and new windows (for file drops).
    Variants {
        model: ToplevelManager.toplevels.values

        Connections {
            required property var modelData

            target: modelData
            Component.onCompleted: {
                if (modelData.activated)
                    dock.noteFocus(modelData);
                dock.checkDropWindow(modelData);
                dock.clearLaunching(modelData);
            }
            Component.onDestruction: dock.forgetWindow(modelData)

            function onActivatedChanged() {
                if (modelData.activated)
                    dock.noteFocus(modelData);
            }

            function onAppIdChanged() {
                dock.checkDropWindow(modelData);
                dock.clearLaunching(modelData);
            }
        }
    }

    // The dragged icon is drawn on a fullscreen overlay so it is never clipped by the dock's
    // own surface. It takes no input; the pointer grab stays with the dock.
    PanelWindow {
        id: dragOverlay

        screen: dock.screen
        visible: dock.dragItem !== null
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "sway-dock-drag"
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {}

        IconImage {
            id: dragIcon

            x: dock.surfaceOrigin.x + dock.dragX - dock.dragGrabX
            y: dock.surfaceOrigin.y + dock.dragY - dock.dragGrabY
            implicitSize: dock.iconSize
            source: dock.dragItem?.iconSource ?? ""
            opacity: dock.dragRemoving ? 0.6 : 1
        }

        Rectangle {
            anchors.horizontalCenter: dragIcon.horizontalCenter
            anchors.bottom: dragIcon.top
            anchors.bottomMargin: 8
            width: removeLabel.implicitWidth + 16
            height: removeLabel.implicitHeight + 8
            radius: 6
            color: "#f012121a"
            visible: dock.dragRemoving

            Text {
                id: removeLabel

                anchors.centerIn: parent
                text: qsTr("Remove")
                color: "#ffffff"
                font.family: "SF Pro"
                font.pixelSize: 12
            }
        }
    }

    // Layer surfaces get no click-outside events, so while the menu is open a transparent
    // fullscreen surface catches clicks anywhere except the dock and closes the menu.
    PanelWindow {
        id: clickCatcher

        screen: dock.screen
        visible: menu.visible
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "sway-dock-menu"
        WlrLayershell.layer: WlrLayer.Top
        // OnDemand, not Exclusive: Hyprland sends pointer input only to exclusive-keyboard layers, which
        // blocked the dock's own menu and other surfaces. Hyprland still focuses it on map (Esc, Alt work).
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        mask: Region {
            item: catcherArea

            Region {
                intersection: Intersection.Subtract
                x: dock.surfaceOrigin.x + inputArea.x
                y: dock.surfaceOrigin.y + inputArea.y
                width: inputArea.width
                height: inputArea.height
            }
        }

        MouseArea {
            id: catcherArea

            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            focus: true
            onPressed: dock.closeMenu()
            Keys.onEscapePressed: dock.closeMenu()
            // Holding Alt swaps Quit for Force Quit while the menu is open.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Alt)
                    menu.alternate = true;
            }
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Alt)
                    menu.alternate = false;
            }
        }
    }
}
