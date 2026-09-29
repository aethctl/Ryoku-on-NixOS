import QtQuick

Canvas {
    id: blueprint

    property real reveal: 1
    property real centreX: 0.76
    property real centreY: 0.48
    property var radii: [92, 184, 276]
    property real diamond: 7

    renderTarget: Canvas.FramebufferObject

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onRevealChanged: requestPaint()
    Connections {
        target: Theme
        function onPaletteChanged() { blueprint.requestPaint() }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0)
            return

        var cx = width * blueprint.centreX
        var cy = height * blueprint.centreY
        var s = Theme.scale
        var line = Theme.withAlpha(Theme.outline, 0.07 * blueprint.reveal)
        var accent = Theme.withAlpha(Theme.primary, 0.10 * blueprint.reveal)

        ctx.lineWidth = 1
        ctx.strokeStyle = line

        for (var i = 0; i < blueprint.radii.length; ++i) {
            ctx.beginPath()
            ctx.arc(cx, cy, blueprint.radii[i] * s, 0, Math.PI * 2)
            ctx.stroke()
        }

        ctx.beginPath()
        ctx.moveTo(0, cy); ctx.lineTo(width, cy)
        ctx.moveTo(cx, 0); ctx.lineTo(cx, height)
        ctx.stroke()

        var r = blueprint.diamond * s
        ctx.strokeStyle = accent
        ctx.beginPath()
        ctx.moveTo(cx, cy - r)
        ctx.lineTo(cx + r, cy)
        ctx.lineTo(cx, cy + r)
        ctx.lineTo(cx - r, cy)
        ctx.closePath()
        ctx.stroke()
    }
}
