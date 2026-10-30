import QtQuick
import qs.shared

// Small gray explanation under a group or row.
Text {
    width: parent?.width ?? 0
    leftPadding: 4
    rightPadding: 4
    wrapMode: Text.WordWrap
    color: Theme.textSecondary
    font.family: Theme.font
    font.pixelSize: 11
    lineHeight: 1.15
}
