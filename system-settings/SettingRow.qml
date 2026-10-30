import QtQuick
import qs.shared

// A row in a SettingsGroup: optional icon, title and subtitle on the left, controls on the right
// (the row's children), and an optional chevron for rows that open a page. `below` holds content
// shown under the title line, e.g. a full-width slider.
Item {
    id: row

    property string title
    property string subtitle
    property color titleColor: Theme.text
    property string glyph
    property color tileColor: "transparent"
    property string iconSource
    property bool chevron: false
    property bool clickable: chevron
    property bool selected: false
    default property alias trailing: trailingRow.data
    property alias below: belowColumn.data
    signal clicked
    signal rightClicked

    width: parent?.width ?? 0
    height: header.height + (belowColumn.visibleChildren.length > 0 ? belowColumn.implicitHeight + 12 : 0)

    // The line above every row but the first one in its group.
    Rectangle {
        x: row.glyph !== "" || row.iconSource !== "" ? 50 : 14
        width: parent.width - x - 14
        height: 1
        color: Theme.separator
        visible: row.y > 0
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 9
        color: row.selected ? Theme.hover : mouse.pressed ? Theme.pressed : mouse.containsMouse ? "#0dffffff" : "transparent"
        visible: row.clickable || row.selected
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: row.clickable
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => event.button === Qt.RightButton ? row.rightClicked() : row.clicked()
    }

    Item {
        id: header

        width: parent.width
        height: row.subtitle !== "" ? 52 : 44

        IconTile {
            id: tile

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: row.glyph !== "" || row.iconSource !== ""
            glyph: row.glyph
            color: row.tileColor
            source: row.iconSource
        }

        Column {
            anchors.left: tile.visible ? tile.right : parent.left
            anchors.leftMargin: tile.visible ? 10 : 14
            anchors.right: trailingRow.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: row.title
                color: row.titleColor
                font.family: Theme.font
                font.pixelSize: 13
            }

            Text {
                width: parent.width
                visible: row.subtitle !== ""
                elide: Text.ElideRight
                text: row.subtitle
                color: Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        Row {
            id: trailingRow

            anchors.right: chevronGlyph.visible ? chevronGlyph.left : parent.right
            anchors.rightMargin: chevronGlyph.visible ? 6 : 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }

        Glyph {
            id: chevronGlyph

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: row.chevron
            text: Theme.iChevronRight
            color: Theme.textTertiary
            size: 16
        }
    }

    Column {
        id: belowColumn

        anchors.top: header.bottom
        x: 14
        width: parent.width - 28
        spacing: 8
    }
}
