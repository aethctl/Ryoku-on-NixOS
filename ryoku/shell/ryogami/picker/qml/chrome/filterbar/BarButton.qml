import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: chip

    property string label: ""
    property string glyph: ""
    // "straight" | "slices" | "geometric"; the caller resolves "match".
    property string barStyle: "straight"
    property bool active: false
    property bool destructive: false
    property bool prominent: false
    property string tooltip: ""
    property real hpad: 12
    property real minWidth: 0
    // Width of the vertical bar's rail; 0 sizes the chip to its content.
    property real railWidth: 0

    signal triggered()

    readonly property color accent: chip.destructive ? Theme.tertiary : Theme.primary
    readonly property bool hovered: hover.containsMouse
    readonly property real skew: chip.barStyle === "slices" ? 10 * Theme.scale : 0
    readonly property real chamfer: chip.barStyle === "geometric"
        ? Math.min(height * 0.32, 8 * Theme.scale) : 0

    implicitHeight: 26 * Theme.scale
    implicitWidth: Math.max(chip.minWidth * Theme.scale,
        content.implicitWidth + chip.hpad * 2 * Theme.scale + chip.skew + chip.chamfer)
    width: chip.railWidth > 0 ? chip.railWidth : implicitWidth
    height: chip.railWidth > 0 ? 24 * Theme.scale : implicitHeight

    readonly property color fillColor: !chip.enabled
        ? Theme.withAlpha(Theme.surfaceContainer, 0.42)
        : chip.active ? chip.accent
        : chip.hovered ? Theme.withAlpha(Theme.surfaceVariant, 0.82)
        : Theme.withAlpha(Theme.surfaceContainer, 0.92)
    readonly property color strokeColor: !chip.enabled
        ? Theme.withAlpha(Theme.outline, 0.18)
        : chip.active ? Theme.withAlpha(Theme.outline, 0.72)
        : (chip.hovered || chip.prominent)
            ? Theme.withAlpha(chip.accent, chip.prominent ? 0.85 : 0.58)
        : Theme.withAlpha(Theme.outline, 0.40)
    readonly property color textColor: !chip.enabled
        ? Theme.withAlpha(Theme.surfaceText, 0.34)
        : chip.active ? (chip.destructive ? Theme.background : Theme.primaryText)
        : Theme.surfaceText

    Canvas {
        id: face
        anchors.fill: parent
        renderTarget: Canvas.Image

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: chip
            function onFillColorChanged() { face.requestPaint() }
            function onStrokeColorChanged() { face.requestPaint() }
            function onBarStyleChanged() { face.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (width <= 0 || height <= 0)
                return
            var w = width, h = height, s = chip.skew, c = chip.chamfer
            ctx.beginPath()
            if (c > 0) {
                ctx.moveTo(c, 0)
                ctx.lineTo(w - c, 0)
                ctx.lineTo(w, c)
                ctx.lineTo(w, h - c)
                ctx.lineTo(w - c, h)
                ctx.lineTo(c, h)
                ctx.lineTo(0, h - c)
                ctx.lineTo(0, c)
            } else {
                ctx.moveTo(s + 0.5, 0.5)
                ctx.lineTo(w - 0.5, 0.5)
                ctx.lineTo(w - s - 0.5, h - 0.5)
                ctx.lineTo(0.5, h - 0.5)
            }
            ctx.closePath()
            ctx.fillStyle = chip.fillColor
            ctx.fill()
            ctx.lineWidth = 1
            ctx.strokeStyle = chip.strokeColor
            ctx.stroke()
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6 * Theme.scale

        Text {
            visible: chip.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.glyph
            font.family: Theme.icon
            font.pixelSize: Theme.fontBody
            color: chip.textColor
            renderType: Text.NativeRendering
        }
        Text {
            visible: chip.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontSmall
            color: chip.textColor
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: chip.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.triggered()
        onExited: tipTimer.stop()
        onEntered: if (chip.tooltip.length > 0) tipTimer.restart()
    }

    Timer { id: tipTimer; interval: 550 }

    Rectangle {
        id: tip
        visible: opacity > 0.01
        opacity: (chip.hovered && chip.tooltip.length > 0 && !tipTimer.running) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        z: 50
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6 * Theme.scale
        width: tipText.implicitWidth + 14 * Theme.scale
        height: tipText.implicitHeight + 8 * Theme.scale
        color: Theme.withAlpha(Theme.surfaceContainer, 0.98)
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.45)
        Text {
            id: tipText
            anchors.centerIn: parent
            text: chip.tooltip
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontFine
            color: Theme.surfaceText
            renderType: Text.NativeRendering
        }
    }
}
