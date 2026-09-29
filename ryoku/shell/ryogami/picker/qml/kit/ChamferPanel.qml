import QtQuick

Canvas {
    id: panel

    property real reveal: 1

    renderTarget: Canvas.FramebufferObject

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onRevealChanged: requestPaint()
    Connections {
        target: Theme
        function onPaletteChanged() { panel.requestPaint() }
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0)
            return

        ctx.fillStyle = Theme.withAlpha(Theme.surfaceContainer, 0.80 * panel.reveal)
        ctx.fillRect(0, 0, width, height)

        var rings = [{ w: 3.0, a: 0.05 }, { w: 2.0, a: 0.08 }, { w: 1.0, a: 0.12 }]
        var inset = 0
        for (var i = 0; i < rings.length; ++i) {
            ctx.lineWidth = rings[i].w
            ctx.strokeStyle = Theme.withAlpha(Theme.primary, rings[i].a * panel.reveal)
            var o = inset + rings[i].w / 2
            ctx.strokeRect(o, o, width - o * 2, height - o * 2)
            inset += rings[i].w
        }

        ctx.lineWidth = 1
        ctx.strokeStyle = Theme.withAlpha(Theme.primary, 0.30 * panel.reveal)
        ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
    }
}
