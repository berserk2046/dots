import QtQuick

// macOS style battery: rounded outline, terminal nub, fill for the level, bolt while charging.
Item {
    id: glyph

    property real level: 1 // 0..1
    property bool charging: false
    property bool low: false

    implicitWidth: 27
    implicitHeight: 13

    readonly property color fillColor: charging ? Theme.success : low ? Theme.danger : Theme.text

    Rectangle {
        id: body

        width: parent.width - nub.width - 1
        height: parent.height
        radius: height * 0.28
        color: "transparent"
        border.width: Math.max(1, height * 0.08)
        border.color: Qt.rgba(1, 1, 1, 0.45)

        Rectangle {
            readonly property real inset: body.border.width + Math.max(1, body.height * 0.08)

            x: inset
            y: inset
            height: body.height - inset * 2
            width: Math.max(height * 0.3, (body.width - inset * 2) * Math.max(0, Math.min(1, glyph.level)))
            radius: Math.max(1, body.radius - inset)
            color: glyph.fillColor

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Lightning bolt
        Canvas {
            anchors.centerIn: parent
            width: body.height * 0.62
            height: body.height * 0.82
            visible: glyph.charging
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width;
                const h = height;
                ctx.beginPath();
                ctx.moveTo(w * 0.62, 0);
                ctx.lineTo(w * 0.08, h * 0.58);
                ctx.lineTo(w * 0.46, h * 0.58);
                ctx.lineTo(w * 0.36, h);
                ctx.lineTo(w * 0.92, h * 0.4);
                ctx.lineTo(w * 0.54, h * 0.4);
                ctx.closePath();
                ctx.fillStyle = "#ffffff";
                ctx.strokeStyle = "#000000";
                ctx.lineWidth = Math.max(1, w * 0.1);
                ctx.lineJoin = "round";
                ctx.stroke();
                ctx.fill();
            }
        }
    }

    Rectangle {
        id: nub

        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: body.verticalCenter
        width: Math.max(1.5, parent.height * 0.12)
        height: parent.height * 0.36
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.45)
    }
}
