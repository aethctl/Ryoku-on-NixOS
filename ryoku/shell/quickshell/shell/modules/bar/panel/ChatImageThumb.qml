import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

// A single image thumbnail, attached to or produced by a turn. Click to open it
// full size in the default viewer.
Rectangle {
    id: root

    property real s: 1
    property string path: ""
    property real maxW: 200 * root.s

    width: Math.min(parent ? parent.width : root.maxW, root.maxW)
    height: Math.min(160 * root.s, width * (thumb.implicitHeight > 0 ? thumb.implicitHeight / Math.max(1, thumb.implicitWidth) : 0.6))
    radius: 6 * root.s
    color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
    clip: true

    Image {
        id: thumb
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignLeft
        source: "file://" + root.path
        asynchronous: true
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Spawn.run(["xdg-open", root.path])
    }
}
