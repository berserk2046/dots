import QtQuick

// Small bold gray heading, with optional content on the right (spinner, button...).
Item {
    id: label

    property string text
    default property alias trailing: trailingRow.data

    width: parent?.width ?? 0
    height: 24

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: label.text
        color: Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
        font.weight: Font.DemiBold
    }

    Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
}
