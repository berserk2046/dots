import QtQuick

// Hoverable menu row: icon on the left, title (and optional subtitle), trailing items on the right.
// Children go below the row's header, for inline details that expand under it.
Rectangle {
    id: row

    property string title
    property string subtitle
    property bool bold: false
    property bool highlight: false // keep the hover background (e.g. while expanded)
    property alias icon: iconSlot.data
    property alias trailing: trailingRow.data
    default property alias details: detailsColumn.data
    property bool clickable: true
    signal clicked
    signal rightClicked

    width: parent?.width ?? 0
    height: header.height + (detailsColumn.visibleChildren.length > 0 ? detailsColumn.implicitHeight + 8 : 0)
    radius: 8
    color: highlight ? Theme.hover : (mouse.containsMouse && clickable ? Theme.hover : "transparent")

    Item {
        id: header

        width: parent.width
        height: Theme.rowHeight

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: event => event.button === Qt.RightButton ? row.rightClicked() : row.clicked()
        }

        Item {
            id: iconSlot

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
        }

        Column {
            anchors.left: iconSlot.right
            anchors.leftMargin: 10
            anchors.right: trailingRow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: row.title
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(13)
                font.weight: row.bold ? Font.DemiBold : Font.Normal
            }

            Text {
                width: parent.width
                visible: row.subtitle !== ""
                elide: Text.ElideRight
                text: row.subtitle
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize(11)
            }
        }

        Row {
            id: trailingRow

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    Column {
        id: detailsColumn

        anchors.top: header.bottom
        x: 10
        width: parent.width - 20
        spacing: 6
    }
}
