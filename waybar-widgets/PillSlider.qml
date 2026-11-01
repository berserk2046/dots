import QtQuick

// Control Center volume slider: rounded track, white fill with a knob, glyph inside on the left.
// Clicking the glyph emits glyphClicked (mute); dragging or scrolling emits moved(value).
Item {
    id: slider

    property real value: 0 // 0..1
    property string glyph
    property bool dimmed: false // muted: fill turns gray
    property real level: -1 // optional live level (0..1) drawn as a thin bar under the track
    signal moved(real value)
    signal glyphClicked

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: Math.max(0, Math.min(1, dragging ? dragValue : value))

    implicitHeight: 24
    implicitWidth: 200

    function valueAt(x) {
        const usable = width - height;
        return Math.max(0, Math.min(1, (x - height / 2) / usable));
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Theme.track

        Rectangle {
            id: fill

            width: slider.height + (slider.width - slider.height) * slider.shown
            height: parent.height
            radius: height / 2
            color: slider.dimmed ? Theme.fillDimmed : Theme.fill

            Behavior on width {
                enabled: !slider.dragging
                NumberAnimation {
                    duration: 90
                }
            }
        }

        // Knob at the end of the fill.
        Rectangle {
            x: fill.width - width
            width: parent.height
            height: parent.height
            radius: height / 2
            color: "#ffffff"
            border.width: 1
            border.color: "#33000000"
        }
    }

    Rectangle {
        visible: slider.level >= 0
        anchors.top: track.bottom
        anchors.topMargin: 3
        x: track.radius
        width: (track.width - track.radius * 2) * Math.min(1, Math.max(0, slider.level))
        height: 2
        radius: 1
        color: Theme.success
        opacity: 0.85
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: event => {
            if (event.x < slider.height + 2 && slider.glyph !== "") {
                slider.glyphClicked();
                event.accepted = false;
                return;
            }
            slider.dragValue = slider.valueAt(event.x);
            slider.dragging = true;
            slider.moved(slider.dragValue);
        }
        onPositionChanged: event => {
            if (!slider.dragging)
                return;
            slider.dragValue = slider.valueAt(event.x);
            slider.moved(slider.dragValue);
        }
        onReleased: slider.dragging = false
        onCanceled: slider.dragging = false
        onWheel: event => {
            const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
            slider.moved(Math.max(0, Math.min(1, slider.value + step)));
        }
    }

    Glyph {
        x: 0
        width: slider.height
        height: slider.height
        text: slider.glyph
        size: 14
        color: "#8e8e93"
    }
}
