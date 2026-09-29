import QtQuick

Canvas {
    id: rail

    property int count: 0
    property int activeIndex: 0
    property real reveal: 1
    property real markerRadius: 5

    implicitWidth: 14 * Theme.scale
    renderTarget: Canvas.FramebufferObject

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCountChanged: requestPaint()
    onActiveIndexChanged: requestPaint()
    onRevealChanged: requestPaint()
    Connections {
        target: Theme
        function onPaletteChanged() { rail.requestPaint() }
    }

    function _y(i) {
        var pad = rail.markerRadius * Theme.scale + 2
        var usable = Math.max(0, height - pad * 2)
        var n = Math.max(1, rail.count)
        return pad + usable * ((i + 0.5) / n)
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0)
            return

        var cx = width / 2
        var s = Theme.scale

        ctx.lineWidth = 1
        ctx.strokeStyle = Theme.withAlpha(Theme.outline, 0.48 * rail.reveal)
        ctx.beginPath()
        ctx.moveTo(cx, 0); ctx.lineTo(cx, height)
        ctx.stroke()

        ctx.strokeStyle = Theme.withAlpha(Theme.outline, 0.58 * rail.reveal)
        var tick = 2.5 * s
        for (var i = 0; i < rail.count; ++i) {
            var ny = rail._y(i)
            ctx.beginPath()
            ctx.moveTo(cx - tick, ny); ctx.lineTo(cx + tick, ny)
            ctx.stroke()
        }

        if (rail.count > 0) {
            var y = rail._y(Math.max(0, Math.min(rail.count - 1, rail.activeIndex)))
            var r = rail.markerRadius * s
            ctx.beginPath()
            ctx.moveTo(cx, y - r)
            ctx.lineTo(cx + r, y)
            ctx.lineTo(cx, y + r)
            ctx.lineTo(cx - r, y)
            ctx.closePath()
            ctx.fillStyle = Theme.withAlpha(Theme.background, rail.reveal)
            ctx.fill()
            ctx.lineWidth = 1.5
            ctx.strokeStyle = Theme.withAlpha(Theme.primary, rail.reveal)
            ctx.stroke()
        }
    }
}
