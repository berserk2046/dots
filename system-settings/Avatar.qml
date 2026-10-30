import QtQuick
import Quickshell.Widgets
import qs.shared

// Round account picture from ~/.face, or initials like a macOS account without one.
Rectangle {
    id: avatar

    property string name
    property int version: 0 // bump to re-read the picture

    width: 36
    height: 36
    radius: width / 2
    gradient: Gradient {
        GradientStop {
            position: 0
            color: "#8e8e93"
        }
        GradientStop {
            position: 1
            color: "#48484a"
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        visible: face.status === Image.Ready

        Image {
            id: face

            anchors.fill: parent
            source: "file://" + Store.home + "/.face?v=" + avatar.version
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 256
            sourceSize.height: 256
            cache: false
            asynchronous: true
        }
    }

    Text {
        anchors.centerIn: parent
        visible: face.status !== Image.Ready
        text: avatar.name.split(/\s+/).filter(w => w).slice(0, 2).map(w => w[0].toUpperCase()).join("")
        color: "#ffffff"
        font.family: Theme.font
        font.pixelSize: Math.round(avatar.width * 0.42)
        font.weight: Font.DemiBold
    }
}
