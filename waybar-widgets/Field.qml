import QtQuick

// Single line text input with a placeholder; `secret` adds a show/hide toggle.
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder
    property bool secret: false
    property bool reveal: false
    property alias input: input
    signal accepted

    implicitHeight: 28
    radius: 7
    color: Theme.field
    border.width: 1
    border.color: input.activeFocus ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.8) : Theme.border

    TextInput {
        id: input

        anchors.left: parent.left
        anchors.right: eye.visible ? eye.left : parent.right
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: "#ffffff"
        font.family: Theme.font
        font.pixelSize: 13
        clip: true
        echoMode: field.secret && !field.reveal ? TextInput.Password : TextInput.Normal
        selectByMouse: true
        onAccepted: field.accepted()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text === "" && !input.preeditText
            text: field.placeholder
            color: Theme.textTertiary
            font: input.font
        }
    }

    Glyph {
        id: eye

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: field.secret
        text: field.reveal ? Theme.iEyeOff : Theme.iEye
        color: Theme.textSecondary
        size: 14

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: field.reveal = !field.reveal
        }
    }
}
