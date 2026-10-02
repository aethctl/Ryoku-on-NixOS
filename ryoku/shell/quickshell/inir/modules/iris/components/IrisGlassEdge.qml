pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import inir.modules.common.functions
import inir.modules.iris.style

// The cut edge of iRiS glass on a plate drawn in QML (glass widgets, framed controls): the shell's
// Appearance › Glass › Edge light, Edge line, Edge width and Edge colour, like IrisField draws it on bodies.
// Native borders keep the curve antialiased; the light is faded downward by a smooth vertical mask, never a
// ring mask (that pixelated every corner, 2026-09-30).
Item {
    id: root
    property real radius: 0
    readonly property real lineWidth: Math.max(1, Math.round(IrisStyle.glassEdgeWidth * IrisStyle.density))
    readonly property bool shown: IrisStyle.glassEdgeLight > 0 || IrisStyle.glassEdgeLine > 0
    visible: root.shown

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: IrisStyle.glassEdgeLine > 0 ? root.lineWidth : 0
        border.color: ColorUtils.applyAlpha(IrisStyle.glassEdgeColour, IrisStyle.glassEdgeLine)
    }

    // The lit top: the same ring at Edge light, masked the way faded lists are (IrisSettings' sidebar): the mask
    // on the ring's own layer, a smooth threshold, so the light fades down the sides instead of ringing the plate.
    Rectangle {
        anchors.fill: parent
        visible: IrisStyle.glassEdgeLight > IrisStyle.glassEdgeLine
        radius: root.radius
        color: "transparent"
        antialiasing: true
        border.width: root.lineWidth
        border.color: ColorUtils.applyAlpha(IrisStyle.glassEdgeColour, IrisStyle.glassEdgeLight)
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: litFade
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Rectangle {
        id: litFade
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: "white" }
            GradientStop { position: 0.55; color: "transparent" }
        }
    }
}
