import QtQuick
import Quickshell
import Quickshell.Wayland

// The switcher panel: a frosted glass card centered on the focused display, one tile per window,
// the selected one on a rounded square. With previews off it is macOS's app switcher (big icons,
// the selected window's name under it); with previews on each tile shows the window itself.
PanelWindow {
    id: panel

    property bool shown: false
    property var windows: []
    property int selected: 0
    property bool previews: true

    readonly property int count: windows.length
    readonly property int padding: previews ? 14 : 12
    readonly property int spacing: previews ? 8 : 4
    // Tile size before scaling down to fit the display
    readonly property real baseWidth: previews ? 240 : 116
    readonly property real baseHeight: previews ? 184 : 116
    // Icon mode: the selected window's name sits under the grid
    readonly property int labelHeight: previews ? 0 : 30
    readonly property var fit: fitLayout(count, (screen?.width ?? 1920) * 0.86 - padding * 2,
                                         (screen?.height ?? 1080) * 0.8 - padding * 2 - labelHeight)
    readonly property int columns: fit.columns
    readonly property real tileWidth: Math.round(baseWidth * fit.scale)
    readonly property real tileHeight: Math.round(baseHeight * fit.scale)

    // The pointer only selects once it moves, so a pointer resting where the panel opens doesn't steal
    // the keyboard's selection.
    property point pointerStart: Qt.point(-1, -1)
    property bool pointerMoved: false

    signal hovered(int index)
    signal picked(int index)
    signal closeRequested(int index)
    signal dismissed

    // Largest tiles that fit: one row while they stay at least 62% of full size, then more rows,
    // shrinking further only when the rows don't fit the height.
    function fitLayout(n, width, height) {
        n = Math.max(1, n);
        for (let scale = 1; scale >= 0.3; scale -= 0.02) {
            const columns = Math.min(n, Math.floor((width + spacing) / (baseWidth * scale + spacing)));
            if (columns < 1)
                continue;
            const rows = Math.ceil(n / columns);
            if (rows * (baseHeight * scale + spacing) - spacing > height)
                continue;
            if (rows === 1 || scale <= 0.62)
                return {
                    scale: scale,
                    columns: columns
                };
        }
        return {
            scale: 0.3,
            columns: Math.max(1, Math.floor((width + spacing) / (baseWidth * 0.3 + spacing)))
        };
    }

    visible: shown
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "app-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // The keys go through Hyprland (the "app-switcher" submap), so the focused app keeps focus.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onShownChanged: {
        pointerStart = Qt.point(-1, -1);
        pointerMoved = false;
        if (shown)
            appear.restart();
    }

    // A click outside the card cancels.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: panel.dismissed()
    }

    HoverHandler {
        onPointChanged: {
            const p = point.position;
            if (panel.pointerStart.x < 0)
                panel.pointerStart = p;
            else if (!panel.pointerMoved && Math.hypot(p.x - panel.pointerStart.x, p.y - panel.pointerStart.y) > 4)
                panel.pointerMoved = true;
        }
    }

    Item {
        id: card

        anchors.centerIn: parent
        width: grid.width + panel.padding * 2
        height: grid.height + panel.padding * 2 + panel.labelHeight
        transformOrigin: Item.Center

        // Opens like macOS's: a quick fade and a slight zoom
        ParallelAnimation {
            id: appear

            NumberAnimation {
                target: card
                property: "opacity"
                from: 0
                to: 1
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: card
                property: "scale"
                from: 0.97
                to: 1
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: panel.previews ? 26 : 24
            color: Theme.panel
            border.width: 1
            border.color: Theme.border
        }

        // Clicks on the card's padding don't cancel.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Rectangle {
            id: highlight

            readonly property Item target: repeater.count > 0 ? repeater.itemAt(panel.selected) : null

            visible: target !== null
            x: grid.x + (target?.x ?? 0)
            y: grid.y + (target?.y ?? 0)
            width: panel.tileWidth
            height: panel.tileHeight
            radius: panel.previews ? 14 : 16
            color: Theme.selection

            // Slides between tiles, but jumps into place when the panel opens
            Behavior on x {
                enabled: panel.shown && card.opacity === 1

                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: panel.shown && card.opacity === 1

                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }
        }

        Grid {
            id: grid

            x: panel.padding
            y: panel.padding
            columns: panel.columns
            spacing: panel.spacing

            Repeater {
                id: repeater

                // Rebuilt each time the switcher opens, so the previews are captured fresh
                model: panel.shown ? panel.windows : []

                WindowTile {
                    required property var modelData
                    required property int index

                    toplevel: modelData
                    width: panel.tileWidth
                    height: panel.tileHeight
                    zoom: panel.fit.scale
                    previews: panel.previews
                    selected: index === panel.selected
                    onEntered: {
                        if (panel.pointerMoved)
                            panel.hovered(index);
                    }
                    onMoved: {
                        if (panel.pointerMoved && !selected)
                            panel.hovered(index);
                    }
                    onClicked: panel.picked(index)
                    onCloseClicked: panel.closeRequested(index)
                }
            }
        }

        // Icon mode: the selected window's name under its icon, kept inside the card
        Text {
            id: label

            readonly property Item target: highlight.target
            readonly property real center: grid.x + (target?.x ?? 0) + panel.tileWidth / 2

            visible: !panel.previews && target !== null
            width: Math.min(implicitWidth, card.width - 24)
            x: Math.max(12, Math.min(card.width - width - 12, center - width / 2))
            y: grid.y + grid.height + (panel.labelHeight - height) / 2 + 1
            elide: Text.ElideRight
            text: target?.caption ?? ""
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
}
