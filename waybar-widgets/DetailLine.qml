import QtQuick

// "Label        value" line used in network details.
Item {
    property string label
    property string value

    width: parent?.width ?? 0
    height: 18
    visible: value !== ""

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: parent.label
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.62
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
        text: parent.value
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }
}
