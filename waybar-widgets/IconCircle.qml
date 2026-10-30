import QtQuick

// Round icon badge: blue when active (selected device, connected network), gray otherwise.
Rectangle {
    id: circle

    property bool active: false
    property string glyph
    default property alias inner: circle.data

    width: 26
    height: 26
    radius: 13
    color: active ? Theme.accent : Theme.circle

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Glyph {
        anchors.centerIn: parent
        visible: circle.glyph !== ""
        text: circle.glyph
        size: 15
    }
}
