import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: item

    required property var app
    property var terminal: []
    property real size: 48
    property bool showLabel: true
    property real shift: 0 // offset while icons are being reordered (along the dock)
    property string edge: "bottom" // screen edge the dock sits on
    property bool showIndicator: true // dot under running apps
    readonly property bool vertical: edge === "left" || edge === "right"
    // Bounce height; the icon hops away from the screen edge.
    property real hop: 0
    // Focus recency of a window (higher = more recent), supplied by the dock.
    property var recencyOf: window => 0
    // Whether this app can open the files being dragged (from their MIME types).
    property bool acceptsDrag: true
    property bool dragging: false
    property bool menuOpen: false // any dock menu; a left/middle click then only dismisses it
    property bool launching: false // started from the dock, no window yet: launch bounce
    property bool urgent: false // a window asks for attention: attention bounce
    property var badge: null // { count, countVisible, progress, progressVisible } from LauncherBadges

    readonly property var entry: DesktopEntries.heuristicLookup(app.id)
    readonly property string pinId: entry ? entry.id : app.id
    readonly property bool running: app.windows.length > 0
    readonly property bool focused: app.windows.some(w => w.activated)
    readonly property bool hovered: mouse.containsMouse
    readonly property string iconSource: Quickshell.iconPath(entry?.icon || app.id, "application-x-executable")

    signal menuRequested(bool alternate) // alternate: Alt held, offer Force Quit
    signal launched
    signal dismissRequested
    signal filesDropped
    signal fileDragEntered(var urls)
    signal reorderStarted(real sceneX, real sceneY)
    signal reorderMoved(real sceneX, real sceneY)
    signal reorderFinished

    width: size
    height: size
    z: dragging ? 1 : 0
    opacity: dragging ? 0 : 1 // the dock draws the dragged icon in an overlay instead

    transform: Translate {
        x: item.vertical ? 0 : item.shift
        y: item.vertical ? item.shift : 0

        Behavior on x {
            enabled: !item.dragging

            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            enabled: !item.dragging

            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on size {
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutCubic
        }
    }

    // Builds an Exec command with the given files, filling %f/%F/%u/%U field codes
    // (or appending the files when there are none) and wrapping Terminal=true apps.
    function commandFor(exec, files) {
        const paths = files.map(url => decodeURIComponent(String(url).replace(/^file:\/\//, "")));
        const urls = files.map(String);
        const command = [];
        let usedFiles = false;
        for (const arg of exec) {
            if (/^%[fF]$/.test(arg)) {
                command.push(...paths);
                usedFiles = true;
            } else if (/^%[uU]$/.test(arg)) {
                command.push(...urls);
                usedFiles = true;
            } else if (!/^%[a-zA-Z]$/.test(arg)) {
                command.push(arg.replace(/%%/g, "%"));
            }
        }
        if (!usedFiles)
            command.push(...paths);
        if (!entry.runInTerminal)
            return command;
        return terminal.map(arg => arg.replace("{appId}", entry.id)).concat(command);
    }

    function launch(files) {
        if (!running)
            launched();
        if (entry && entry.command && entry.command.length > 0)
            Quickshell.execDetached(commandFor(entry.command, files || []));
        else if (entry)
            entry.execute();
        else
            Quickshell.execDetached([app.id]);
    }

    function runAction(action) {
        if (action.command && action.command.length > 0)
            Quickshell.execDetached(commandFor(action.command, []));
        else
            action.execute();
    }

    function quit() {
        for (const window of app.windows)
            window.close();
    }

    function recentWindow() {
        return app.windows.reduce((best, w) => recencyOf(w) > recencyOf(best) ? w : best);
    }

    // Bring the app forward with its most recently used window, without cycling.
    function focusApp() {
        if (running && !focused)
            recentWindow().activate();
    }

    // Launch if not running; focus its most recent window if unfocused; cycle windows if focused.
    function activate() {
        const windows = app.windows;
        if (windows.length === 0)
            return launch();
        const current = windows.findIndex(w => w.activated);
        if (current < 0)
            recentWindow().activate();
        else
            windows[(current + 1) % windows.length].activate();
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: 12
        color: DockTheme.dropHighlight
        visible: dropArea.containsDrag && item.acceptsDrag
    }

    // Icon plus badge and progress bar; this is what bounces.
    Item {
        anchors.fill: parent

        transform: Translate {
            x: item.edge === "left" ? item.hop : item.edge === "right" ? -item.hop : 0
            y: item.edge === "top" ? item.hop : item.edge === "bottom" ? -item.hop : 0
        }

        // Plain Image with a fixed sourceSize: IconImage ties sourceSize to its current size, so
        // every magnification step reloaded the icon (asynchronously, blank meanwhile) and it blinked.
        Image {
            anchors.fill: parent
            sourceSize.width: 128 // render resolution; scaled down to the current size
            sourceSize.height: 128
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            source: item.iconSource
            asynchronous: true
        }

        Rectangle {
            readonly property int count: item.badge?.count ?? 0

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -height * 0.25
            anchors.topMargin: -height * 0.25
            height: Math.round(item.size * 0.4)
            width: Math.max(height, countText.implicitWidth + height * 0.5)
            radius: height / 2
            color: "#ff3b30"
            visible: item.running && item.badge?.countVisible === true && count > 0

            Text {
                id: countText

                anchors.centerIn: parent
                text: parent.count > 99 ? "99+" : parent.count
                color: "#ffffff"
                font.family: "SF Pro"
                font.pixelSize: parent.height * 0.62
                font.bold: true
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.08
            width: parent.width * 0.8
            height: Math.max(4, Math.round(item.size * 0.11))
            radius: height / 2
            color: "#b3000000"
            border.width: 1
            border.color: "#40ffffff"
            visible: item.running && item.badge?.progressVisible === true

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, item.badge?.progress ?? 0))
                height: parent.height
                radius: parent.radius
                color: "#0a84ff"
            }
        }
    }

    // Launching: quick repeated hops. Attention: higher hops with a pause between them.
    // When it stops, the icon lands right away instead of finishing the current hop.
    SequentialAnimation {
        running: item.launching || (item.urgent && !item.focused)
        loops: Animation.Infinite
        onRunningChanged: {
            if (!running)
                land.start();
        }

        NumberAnimation {
            target: item
            property: "hop"
            to: item.height * (item.launching ? 0.4 : 0.6)
            duration: 200
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: item
            property: "hop"
            to: 0
            duration: 200
            easing.type: Easing.InQuad
        }

        PauseAnimation {
            duration: item.launching ? 100 : 900
        }
    }

    NumberAnimation {
        id: land

        target: item
        property: "hop"
        to: 0
        duration: 120
        easing.type: Easing.InQuad
    }

    // Running dot, between the icon and the screen edge.
    Rectangle {
        x: item.edge === "left" ? -width - 2 : item.edge === "right" ? parent.width + 2 : (parent.width - width) / 2
        y: item.edge === "top" ? -height - 2 : item.edge === "bottom" ? parent.height + 2 : (parent.height - height) / 2
        width: 4
        height: 4
        radius: 2
        visible: item.running && item.showIndicator
        color: item.focused ? DockTheme.indicator : DockTheme.indicatorDim
    }

    // Name label, on the inner side of the icon.
    Rectangle {
        x: item.edge === "left" ? parent.width + 8 : item.edge === "right" ? -width - 8 : (parent.width - width) / 2
        y: item.edge === "top" ? parent.height + 8 : item.edge === "bottom" ? -height - 8 : (parent.height - height) / 2
        width: label.implicitWidth + 16
        height: label.implicitHeight + 8
        radius: 6
        color: DockTheme.menu
        visible: item.showLabel && (mouse.containsMouse || dropArea.containsDrag)

        Text {
            id: label

            anchors.centerIn: parent
            text: item.entry?.name || item.app.id
            color: DockTheme.text
            font.family: "SF Pro"
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        // Holding the left button and moving past a small threshold reorders instead of clicking.
        property real pressX: 0
        property real pressY: 0
        property bool reordering: false

        onPressed: event => {
            pressX = event.x;
            pressY = event.y;
            reordering = false;
        }
        onPositionChanged: event => {
            if (!(pressedButtons & Qt.LeftButton))
                return;
            const scene = mapToItem(null, event.x, event.y);
            if (!reordering && (Math.abs(event.x - pressX) > 8 || Math.abs(event.y - pressY) > 8)) {
                reordering = true;
                item.reorderStarted(scene.x, scene.y);
            }
            if (reordering)
                item.reorderMoved(scene.x, scene.y);
        }
        onReleased: {
            if (reordering)
                item.reorderFinished();
        }
        onClicked: event => {
            if (reordering)
                return;
            // As on macOS, any click while a menu is open only closes it (even a right-click on
            // another icon); the next click acts normally.
            if (item.menuOpen)
                item.dismissRequested();
            else if (event.button === Qt.RightButton)
                item.menuRequested((event.modifiers & Qt.AltModifier) !== 0);
            else if (event.button === Qt.MiddleButton)
                item.launch();
            else
                item.activate();
        }
    }

    // Drop files (e.g. from a file manager) on the icon to open them with this app. As on macOS,
    // only apps that can open the file type highlight and take the drop; others ignore it.
    DropArea {
        id: dropArea

        anchors.fill: parent
        onEntered: drag => {
            drag.accepted = drag.hasUrls;
            if (drag.hasUrls)
                item.fileDragEntered(drag.urls);
        }
        onDropped: drop => {
            if (!drop.hasUrls || !item.acceptsDrag) {
                drop.accepted = false;
                return;
            }
            item.launch(drop.urls);
            item.focusApp();
            item.filesDropped();
            drop.acceptProposedAction();
        }
    }

    // Spring-loading, as on macOS: holding a file over a running app brings it forward,
    // so the file can be dropped straight into one of its windows.
    Timer {
        running: dropArea.containsDrag && item.running
        interval: 800
        onTriggered: item.focusApp()
    }
}
