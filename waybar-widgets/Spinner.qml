import QtQuick

Canvas {
    id: spinner

    property color color: Theme.textSecondary

    implicitWidth: 13
    implicitHeight: 13
    visible: running

    property bool running: true

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.lineWidth = 1.8;
        ctx.lineCap = "round";
        ctx.strokeStyle = color;
        ctx.beginPath();
        ctx.arc(width / 2, height / 2, width / 2 - 1.5, 0, Math.PI * 1.4, false);
        ctx.stroke();
    }

    RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: spinner.running && spinner.visible
    }
}
