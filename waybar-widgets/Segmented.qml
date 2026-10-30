import QtQuick

// Segmented control (e.g. DHCP / Manual, energy modes).
Rectangle {
    id: seg

    property var options: []
    property int current: 0
    signal picked(int index)

    width: parent?.width ?? 0
    height: 26
    radius: 7
    color: Theme.field

    Row {
        anchors.fill: parent
        anchors.margins: 2

        Repeater {
            model: seg.options

            Rectangle {
                required property string modelData
                required property int index

                width: (seg.width - 4) / seg.options.length
                height: seg.height - 4
                radius: 5
                color: seg.current === index ? "#3dffffff" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(parent.index)
                }
            }
        }
    }
}
