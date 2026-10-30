import QtQuick

// macOS style switch.
Item {
    id: toggle

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 34
    implicitHeight: 20
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? Theme.accent : Theme.track

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    Rectangle {
        width: parent.height - 4
        height: width
        radius: width / 2
        y: 2
        x: toggle.checked ? parent.width - width - 2 : 2
        color: "#ffffff"

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
