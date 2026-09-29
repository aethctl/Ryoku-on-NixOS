import QtQuick
import inir.modules.common.widgets

StyledText {
    required property var face
    property real size: 40

    color: face.ink
    font.family: face.fontNumbers
    font.pixelSize: face.px(size)
    font.weight: face.figureWeight
    font.features: ({ "tnum": 1 })
    font.letterSpacing: -face.px(size) * 0.03
    maximumLineCount: 1
}
