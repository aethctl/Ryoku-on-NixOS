import QtQuick
import Quickshell
import inir

Region {
    id: root

    property real canvasWidth: 0
    property real canvasHeight: 0
    property real originX: 0
    property real originY: 0
    property string screenName: ""

    readonly property var studio: GlobalStates.irisStudioRect
    readonly property bool cut: root.studio !== null && root.studio.screen === root.screenName

    x: 0
    y: 0
    width: root.canvasWidth
    height: root.canvasHeight

    Region {
        intersection: Intersection.Subtract
        x: root.cut ? root.studio.x - root.originX : 0
        y: root.cut ? root.studio.y - root.originY : 0
        width: root.cut ? root.studio.width : 0
        height: root.cut ? root.studio.height : 0
    }
}
