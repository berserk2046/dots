import QtQuick
import Quickshell
import Quickshell.Widgets

// Process/app line: icon from the desktop entry (generic glyph otherwise), name, values on the right.
Item {
    id: row

    property string name
    property string iconName
    property string value
    property string detail

    width: parent?.width ?? 0
    height: 32

    Item {
        id: icon

        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22

        IconImage {
            id: image

            anchors.fill: parent
            source: row.iconName ? Quickshell.iconPath(row.iconName, true) : ""
            visible: source != ""
        }

        IconCircle {
            anchors.centerIn: parent
            width: 22
            height: 22
            visible: !image.visible
            glyph: Theme.iApp
        }
    }

    Text {
        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: values.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: row.name
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(13)
    }

    Row {
        id: values

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
            visible: row.detail !== ""
            text: row.detail
            color: Theme.textTertiary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
            font.features: {
                "tnum": 1
            }
        }

        Text {
            text: row.value
            color: Theme.textSecondary
            font.family: Theme.font
            font.pixelSize: Theme.fontSize(12)
            font.features: {
                "tnum": 1
            }
        }
    }
}
