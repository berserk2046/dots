import QtQuick
import qs.shared

// A card centered over the dimmed window, like macOS sheets (confirmations, add dialogs).
// Its children go in the card; it sits on Ui.overlay so it covers the whole window.
Item {
    id: sheet

    property bool shown: false
    property int cardWidth: 380
    default property alias content: column.data
    signal dismissed

    parent: Ui.overlay
    anchors.fill: parent
    visible: shown
    z: 900

    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: sheet.dismissed()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: sheet.cardWidth
        height: Math.min(column.implicitHeight + 36, sheet.height - 60)
        radius: 14
        color: Theme.solidCard
        border.width: 1
        border.color: Theme.border
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column

            x: 18
            y: 18
            width: parent.width - 36
            spacing: 10
        }
    }
}
