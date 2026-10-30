import QtQuick
import Quickshell.Widgets
import qs.shared

// Rounded square with a white glyph, like the icons in macOS's System Settings sidebar.
// With `source` it shows that image (e.g. an app icon) instead.
Rectangle {
    id: tile

    property string glyph
    property string source
    property int size: 26

    width: size
    height: size
    radius: size * 0.26
    color: "#3a3a3c"

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: tile.source === ""
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#26ffffff"
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }

    Glyph {
        anchors.centerIn: parent
        visible: tile.source === ""
        text: tile.glyph
        size: Math.round(tile.size * 0.62)
    }

    IconImage {
        anchors.fill: parent
        visible: tile.source !== ""
        source: tile.source
        implicitSize: 64
        asynchronous: true
    }
}
