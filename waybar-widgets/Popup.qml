import QtQuick
import Quickshell
import Quickshell.Wayland

// A Control Center style card that drops down under the bar. The window covers the screen
// (minus the bar's reserved space) so a click anywhere outside the card closes it.
PanelWindow {
    id: popup

    property bool shown: false
    property string namespace: "waybar-widgets"
    // Used when the pointer position can't be read: card's right edge distance from the screen edge.
    property int fallbackRightMargin: 210
    property int cardWidth: Theme.panelWidth
    default property alias content: column.data

    // Pointer x when the popup opened; the card centers under it (i.e. under the bar icon).
    property real pointerX: -1
    property bool placed: false

    function open() {
        placed = false;
        pointerX = -1;
        shown = true;
        placeTimer.restart();
    }

    // Opens centered under x (screen-local), e.g. the cursor position reported by the compositor.
    function openAt(x) {
        pointerX = x;
        placed = true;
        shown = true;
    }

    function close() {
        if (!shown)
            return;
        shown = false;
    }

    function notePointer(x) {
        if (shown && !placed && x > 0) {
            pointerX = x;
            placed = true;
        }
    }

    function toggle() {
        shown ? close() : open();
    }

    visible: shown || card.opacity > 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: namespace
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand, not Exclusive: Hyprland sends pointer input only to exclusive-keyboard layers while
    // one is open, which made waybar ignore clicks. The card still gets the keyboard once clicked.
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Wait briefly for the pointer-enter event that tells where the click happened.
    Timer {
        id: placeTimer

        interval: 120
        onTriggered: popup.placed = true
    }

    Item {
        id: root

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: popup.close()

        HoverHandler {
            onPointChanged: popup.notePointer(point.position.x)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: popup.close()
        }

        Rectangle {
            id: card

            readonly property real wantedX: popup.pointerX >= 0 ? popup.pointerX - width / 2
                                                                : root.width - width - popup.fallbackRightMargin

            x: Math.max(8, Math.min(root.width - width - 8, wantedX))
            y: popup.shown && popup.placed ? 4 : 0
            width: popup.cardWidth
            height: Math.min(column.implicitHeight + 16, root.height - 16)
            radius: Theme.radius
            color: Theme.panel
            border.width: 1
            border.color: Theme.border
            clip: true
            opacity: popup.shown && popup.placed ? 1 : 0
            scale: popup.shown && popup.placed ? 1 : 0.97
            transformOrigin: Item.Top

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            // Clicks on the card's padding don't close it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Column {
                id: column

                x: 8
                y: 8
                width: parent.width - 16
                spacing: 2
            }
        }
    }

    // Clicks come from waybar, which this window doesn't cover (it starts below the bar), so a strip
    // over the bar is mapped while opening to read the pointer's x from its enter event.
    PanelWindow {
        screen: popup.screen
        visible: popup.shown && !popup.placed
        color: "transparent"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 64
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: popup.namespace + "-probe"
        WlrLayershell.layer: WlrLayer.Overlay

        Item {
            anchors.fill: parent

            HoverHandler {
                onPointChanged: popup.notePointer(point.position.x)
            }
        }
    }
}
