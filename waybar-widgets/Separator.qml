import QtQuick

Item {
    width: parent?.width ?? 0
    height: 11

    Rectangle {
        x: 6
        width: parent.width - 12
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.separator
    }
}
