import QtQuick

// Thin rounded usage bar with up to two stacked segments (e.g. used + cached).
Rectangle {
    id: meter

    property real value: 0 // 0..1, first segment
    property real secondary: 0 // 0..1, stacked after the first
    property color barColor: Theme.accent
    property color secondaryColor: Theme.textTertiary

    width: parent?.width ?? 0
    implicitHeight: 8
    radius: height / 2
    color: Theme.track
    clip: true

    Rectangle {
        id: first

        width: meter.width * Math.max(0, Math.min(1, meter.value))
        height: parent.height
        color: meter.barColor

        Behavior on width {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.left: first.right
        width: meter.width * Math.max(0, Math.min(1 - meter.value, meter.secondary))
        height: parent.height
        color: meter.secondaryColor

        Behavior on width {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }
}
