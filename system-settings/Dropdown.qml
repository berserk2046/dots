import QtQuick
import qs.shared

// macOS pop-up button: the current choice with up/down chevrons; click for a menu of the options.
// Options are strings or {label, value}.
Rectangle {
    id: dropdown

    property var options: []
    property var value
    property string placeholder: qsTr("Choose…")
    signal picked(var value)

    readonly property int currentIndex: options.findIndex(o => Ui.valueOf(o) === value)

    implicitWidth: Math.min(260, Math.max(90, label.implicitWidth + 40))
    implicitHeight: 24
    radius: 6
    opacity: enabled ? 1 : 0.4
    color: Theme.light ? (mouse.pressed ? Theme.solidCardHover : mouse.containsMouse ? Theme.buttonHover : Theme.button)
                       : (mouse.pressed ? "#40ffffff" : mouse.containsMouse ? "#33ffffff" : "#26ffffff")
    border.width: 1
    border.color: Theme.buttonBorder

    Text {
        id: label

        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.right: chevrons.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: dropdown.currentIndex >= 0 ? Ui.labelOf(dropdown.options[dropdown.currentIndex]) : dropdown.placeholder
        color: dropdown.currentIndex >= 0 ? Theme.text : Theme.textSecondary
        font.family: Theme.font
        font.pixelSize: Theme.fontSize(12)
    }

    Column {
        id: chevrons

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: -7

        Glyph {
            text: Theme.iChevronUp
            size: 11
            color: Theme.textSecondary
        }

        Glyph {
            text: Theme.iChevronDown
            size: 11
            color: Theme.textSecondary
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.openMenu(dropdown, dropdown.options, dropdown.currentIndex, v => dropdown.picked(v))
    }
}
