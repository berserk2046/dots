import QtQuick
import qs.shared

// macOS slider: thin track with an accent fill and a round knob. Optional tick marks and labels
// at both ends. `moved` fires while dragging (with values snapped to `step`).
Item {
    id: slider

    property real from: 0
    property real to: 1
    property real step: 0
    property real value: 0
    property int ticks: 0
    property string minLabel
    property string maxLabel
    signal moved(real value)

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : value
    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (shown - from) / (to - from))) : 0

    implicitWidth: 220
    implicitHeight: minLabel !== "" || maxLabel !== "" ? 34 : 20
    opacity: enabled ? 1 : 0.4

    function valueAt(x) {
        const usable = track.width - knob.width;
        let v = from + Math.max(0, Math.min(1, (x - knob.width / 2) / usable)) * (to - from);
        if (step > 0)
            v = Math.round((v - from) / step) * step + from;
        return Math.max(from, Math.min(to, v));
    }

    Item {
        id: track

        width: parent.width
        height: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: knob.width / 2 - 2
            width: parent.width - knob.width + 4
            height: 4
            radius: 2
            color: Theme.track

            Rectangle {
                width: knob.x + knob.width / 2 - parent.x
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }

        Repeater {
            model: slider.ticks

            Rectangle {
                required property int index

                x: knob.width / 2 + (track.width - knob.width) * index / Math.max(1, slider.ticks - 1) - 1
                y: 16
                width: 2
                height: 5
                radius: 1
                color: Theme.textTertiary
            }
        }

        Rectangle {
            id: knob

            x: (track.width - width) * slider.ratio
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: "#ffffff"
            border.width: 1
            border.color: "#33000000"
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: event => {
                slider.dragValue = slider.valueAt(event.x);
                slider.dragging = true;
                slider.moved(slider.dragValue);
            }
            onPositionChanged: event => {
                if (!slider.dragging)
                    return;
                const v = slider.valueAt(event.x);
                if (v !== slider.dragValue) {
                    slider.dragValue = v;
                    slider.moved(v);
                }
            }
            onReleased: slider.dragging = false
            onCanceled: slider.dragging = false
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        visible: slider.minLabel !== ""
        text: slider.minLabel
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(10)
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: slider.maxLabel !== ""
        text: slider.maxLabel
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(10)
    }
}
