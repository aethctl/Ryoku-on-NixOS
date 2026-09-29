import QtQuick
import inir.modules.common.widgets

StyledText {
    required property var face
    property real size: 13
    property int weight: Font.Medium

    color: face.ink
    font.family: face.fontMain
    font.pixelSize: face.px(size)
    font.weight: weight
    font.letterSpacing: 0
    elide: Text.ElideRight
    maximumLineCount: 1
}
