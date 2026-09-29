import QtQuick

Text {
    id: segment

    property string label: ""
    property real reveal: 1

    text: segment.label
    font.family: Theme.ui
    font.weight: Theme.uiWeight
    font.pixelSize: Theme.fontSegment
    color: Theme.withAlpha(Theme.surfaceText, segment.reveal)
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
