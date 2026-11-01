import QtQuick
import qs.shared

// Bold heading above a SettingsGroup, with optional content on the right.
Item {
    id: title

    property string text
    default property alias trailing: trailingRow.data

    width: parent?.width ?? 0
    height: 30

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: title.text
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(13)
        font.weight: Font.DemiBold
    }

    Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 6
    }
}
