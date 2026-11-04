import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// One window in the switcher. Previews: a snapshot of the window with its icon and title under it.
// Icon mode: just the app's icon, large, as in macOS's app switcher. Hidden windows are dimmed.
Item {
    id: tile

    required property var toplevel // HyprlandToplevel
    property bool previews: true
    property bool selected: false
    property real zoom: 1 // the panel shrinks tiles to fit many windows

    readonly property string appId: String(toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || "")
    readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
    readonly property string appName: entry?.name || appId
    readonly property string title: String(toplevel?.title || "")
    // Shown under the selected icon in icon mode
    readonly property string caption: title !== "" && title !== appName ? title : appName
    readonly property string iconSource: Quickshell.iconPath(entry?.icon || appId.toLowerCase(), "application-x-executable")
    readonly property bool hidden: {
        const ws = toplevel?.workspace;
        return ws !== null && ws !== undefined && (ws.id < 0 || String(ws.name).startsWith("special"));
    }
    readonly property bool hovered: mouse.containsMouse

    readonly property real pad: Math.round(10 * zoom)
    readonly property real captionHeight: previews ? Math.round(30 * zoom) : 0

    signal entered
    signal moved
    signal clicked
    signal closeClicked

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onEntered: tile.entered()
        onPositionChanged: tile.moved()
        // Middle click closes the window, like on a browser tab
        onClicked: event => event.button === Qt.MiddleButton ? tile.closeClicked() : tile.clicked()
    }

    // ---- Previews ----

    Rectangle {
        id: well

        visible: tile.previews
        x: tile.pad
        y: tile.pad
        width: tile.width - tile.pad * 2
        height: tile.height - tile.pad * 2 - tile.captionHeight
        radius: Math.round(9 * tile.zoom)
        color: shot.hasContent ? "transparent" : Theme.well

        // The window's picture, fitted inside the well and rounded like a window
        ClippingRectangle {
            id: frame

            readonly property real aspect: shot.sourceSize.height > 0 ? shot.sourceSize.width / shot.sourceSize.height : 16 / 10
            readonly property real fitWidth: Math.min(well.width, well.height * aspect)

            anchors.centerIn: parent
            width: Math.round(fitWidth)
            height: Math.round(fitWidth / aspect)
            radius: Math.round(8 * tile.zoom)
            color: "transparent"
            opacity: shot.hasContent ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }

            ScreencopyView {
                id: shot

                anchors.fill: parent
                // Hidden windows aren't drawn by Hyprland, so there is nothing to capture
                captureSource: tile.previews && !tile.hidden ? (tile.toplevel?.wayland ?? null) : null
                live: false
                constraintSize: Qt.size(Math.ceil(well.width * 1.5), Math.ceil(well.height * 1.5))
            }
        }

        // Until the picture arrives, and for hidden windows: the app's icon
        Column {
            anchors.centerIn: parent
            visible: !shot.hasContent
            spacing: Math.round(6 * tile.zoom)

            IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: Math.round(Math.min(64 * tile.zoom, well.height * 0.55))
                source: tile.iconSource
                asynchronous: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: tile.hidden
                text: qsTr("Hidden")
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: Math.max(10, Math.round(11 * tile.zoom))
            }
        }
    }

    Row {
        visible: tile.previews
        anchors.horizontalCenter: parent.horizontalCenter
        y: well.y + well.height + Math.round((tile.captionHeight - height) / 2) + 1
        width: Math.min(implicitWidth, tile.width - tile.pad * 2)
        spacing: Math.round(6 * tile.zoom)

        IconImage {
            id: smallIcon

            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Math.round(18 * tile.zoom)
            source: tile.iconSource
            asynchronous: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, tile.width - tile.pad * 2 - smallIcon.width - parent.spacing)
            elide: Text.ElideRight
            text: tile.caption
            color: tile.selected ? Theme.text : Theme.textDim
            font.family: Theme.font
            font.pixelSize: Math.max(10, Math.round(12 * tile.zoom))
            font.weight: tile.selected ? Font.Medium : Font.Normal
        }
    }

    // ---- Icon mode ----

    IconImage {
        visible: !tile.previews
        anchors.centerIn: parent
        implicitSize: Math.round(tile.width * 0.83)
        source: tile.iconSource
        opacity: tile.hidden ? 0.55 : 1
        asynchronous: true
    }

    // Close button on the hovered tile, at the top left like a window's red button
    Rectangle {
        id: closeButton

        readonly property real size: Math.max(16, Math.round(18 * tile.zoom))

        visible: tile.hovered || closeMouse.containsMouse
        x: tile.previews ? well.x + frame.x - size / 3 : Math.round(tile.pad * 0.6)
        y: tile.previews ? well.y + frame.y - size / 3 : Math.round(tile.pad * 0.6)
        width: size
        height: size
        radius: size / 2
        color: closeMouse.containsMouse ? "#ff5f57" : Theme.panel
        border.width: 1
        border.color: closeMouse.containsMouse ? "#e0443e" : Theme.border

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: "×"
            color: closeMouse.containsMouse ? "#4d0000" : Theme.text
            font.family: Theme.font
            font.pixelSize: Math.round(closeButton.size * 0.8)
        }

        MouseArea {
            id: closeMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.closeClicked()
        }
    }
}
