pragma ComponentBehavior: Bound

import QtQuick
import inir
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.iris.style

Item {
    id: root

    property real value: 0
    property string icon: "volume_up"
    property bool muted: false
    property bool vertical: false
    property color fillColor: IrisStyle.fillStrong
    signal moved(real value)
    signal iconClicked()

    property real dragValue: -1
    readonly property real shownValue: Math.max(0, Math.min(1, root.dragValue >= 0 ? root.dragValue : root.value))
    readonly property real thickness: root.vertical ? root.width : root.height
    readonly property real span: root.vertical ? root.height : root.width

    implicitWidth: root.vertical ? Math.round(46 * IrisStyle.density) : 260
    implicitHeight: root.vertical ? 120 : Math.round(44 * IrisStyle.density)
    Accessible.role: Accessible.Slider

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.thickness / 2
        color: IrisStyle.fill
        scale: pointer.pressed ? 1.015 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        Item {
            id: fillClip
            property real length: root.span * root.shownValue
            Behavior on length {
                enabled: root.dragValue < 0
                NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing }
            }
            y: root.vertical ? track.height - fillClip.length : 0
            width: root.vertical ? track.width : fillClip.length
            height: root.vertical ? fillClip.length : track.height
            clip: true
            Rectangle {
                y: -fillClip.y
                width: track.width
                height: track.height
                radius: root.thickness / 2
                color: root.muted ? IrisStyle.textTertiary : root.fillColor
            }
        }

        MaterialSymbol {
            readonly property real pocket: (root.thickness - iconSize) / 2
            x: pocket
            y: root.vertical ? track.height - root.thickness + pocket : pocket
            text: root.icon
            fill: 1
            iconSize: Math.round((root.vertical ? 19 : 20) * IrisStyle.density)
            readonly property bool overFill: !root.muted && fillClip.length >= root.thickness * 0.72
            color: overFill ? IrisStyle.surface : IrisStyle.text
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
        }
    }

    onMoved: GlobalStates.quietIrisLevels()
    onIconClicked: GlobalStates.quietIrisLevels()

    MouseArea {
        id: pointer
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        hoverEnabled: true
        function valueAt(mouse): real {
            return Math.max(0, Math.min(1, root.vertical ? 1 - mouse.y / Math.max(1, height) : mouse.x / Math.max(1, width)))
        }
        function inPocket(mouse): bool {
            return root.vertical ? mouse.y > height - root.thickness : mouse.x < root.thickness
        }
        onPressed: mouse => {
            if (inPocket(mouse)) return
            root.dragValue = valueAt(mouse)
            root.moved(root.dragValue)
        }
        onPositionChanged: mouse => {
            wheelIntent.track(mouse.x, mouse.y)
            if (!pressed || root.dragValue < 0) return
            root.dragValue = valueAt(mouse)
            root.moved(root.dragValue)
        }
        onReleased: mouse => {
            if (root.dragValue < 0 && inPocket(mouse)) root.iconClicked()
            root.dragValue = -1
        }
        onCanceled: root.dragValue = -1
        property real wheelAccumulator: 0
        IrisWheelIntent { id: wheelIntent; hovered: pointer.containsMouse }
        onWheel: wheel => {
            if (!wheelIntent.take(wheel)) return
            const delta = (wheel.angleDelta.y || wheel.angleDelta.x) || (wheel.pixelDelta.y || wheel.pixelDelta.x) * 4
            pointer.wheelAccumulator += delta
            const steps = Math.trunc(pointer.wheelAccumulator / 120)
            if (steps === 0) return
            pointer.wheelAccumulator -= steps * 120
            root.moved(Math.max(0, Math.min(1, root.value + steps * 0.05)))
        }
    }
}
