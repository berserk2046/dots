import QtQuick
import qs.shared

// macOS grouped box: a rounded card of SettingRows, each drawing the line above it.
Rectangle {
    id: group

    default property alias rows: column.data

    width: parent?.width ?? 0
    height: column.implicitHeight
    radius: 10
    color: Theme.solidCard
    border.width: 1
    border.color: Theme.light ? "#14000000" : "#0fffffff"
    clip: true

    Column {
        id: column

        width: parent.width
    }
}
