import QtQuick

// The Wi-Fi fan: a wedge plus two arcs; `bars` (0-3) of them are lit, the rest dimmed.
Canvas {
    id: glyph

    property int bars: 3
    property color color: Theme.text

    implicitWidth: 16
    implicitHeight: 13

    onBarsChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2;
        const cy = height - 1;
        const full = height - 1.5;
        const start = -Math.PI * 0.75;
        const end = -Math.PI * 0.25;
        const lit = Qt.rgba(color.r, color.g, color.b, color.a);
        const dim = Qt.rgba(color.r, color.g, color.b, color.a * 0.3);
        ctx.lineCap = "round";

        // Inner wedge
        ctx.fillStyle = bars >= 1 ? lit : dim;
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.arc(cx, cy, full * 0.36, start, end, false);
        ctx.closePath();
        ctx.fill();

        const stroke = Math.max(1.6, full * 0.15);
        ctx.lineWidth = stroke;
        const radii = [full * 0.66, full - stroke / 2];
        for (let i = 0; i < radii.length; i++) {
            ctx.strokeStyle = bars >= i + 2 ? lit : dim;
            ctx.beginPath();
            ctx.arc(cx, cy, radii[i], start, end, false);
            ctx.stroke();
        }
    }
}
