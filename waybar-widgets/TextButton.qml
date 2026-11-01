import QtQuick

// Small rounded button; `primary` fills it with the accent color.
Rectangle {
    id: button

    property string text
    property bool primary: false
    property bool destructive: false
    signal clicked

    implicitWidth: label.implicitWidth + 22
    implicitHeight: 24
    radius: 7
    opacity: enabled ? 1 : 0.4
    color: primary ? (mouse.pressed ? Qt.darker(Theme.accent, 1.2) : Theme.accent)
                   : (mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.buttonHover : Theme.button)
    border.width: primary ? 0 : 1
    border.color: Theme.buttonBorder

    Text {
        id: label

        anchors.centerIn: parent
        text: button.text
        color: button.destructive ? Theme.danger : button.primary ? "#ffffff" : Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
        font.weight: button.primary ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
