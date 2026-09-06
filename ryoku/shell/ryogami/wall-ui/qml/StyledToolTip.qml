import QtQuick
import QtQuick.Controls

// Ryoku tooltip: a bone plate (the inverse surface) with its on-colour text, so
// it inverts with the theme and always reads -- dark plate + light ink on a
// light theme, light plate + dark ink on a dark theme. Never the old dark box
// with dim ink that vanished on light palettes.
ToolTip {
    id: root

    property int maxWidth: 300
    property var colors: null

    readonly property color _plate: colors ? colors.inverseSurface : "#e0e2e8"
    readonly property color _ink: colors ? colors.inverseSurfaceText : "#101418"

    TextMetrics {
        id: metrics
        text: root.text
        font: root.font
    }

    padding: 7
    contentWidth: Math.min(Math.ceil(metrics.advanceWidth), maxWidth)

    background: Rectangle {
        radius: 6
        color: root._plate
        border.width: 1
        border.color: Qt.rgba(root._ink.r, root._ink.g, root._ink.b, 0.18)
    }

    contentItem: Text {
        text: root.text
        font: root.font
        wrapMode: Text.WordWrap
        color: root._ink
    }
}
