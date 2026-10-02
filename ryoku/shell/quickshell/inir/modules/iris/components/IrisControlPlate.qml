pragma ComponentBehavior: Bound

import QtQuick
import inir.modules.iris.style

// A row of round controls held on one plate: Settings › Appearance › Button rows (`IrisStyle.controlPlate`),
// or a surface's own choice. The plate's corners follow the bubbles' shape and stay concentric with the
// controls inside, which take `controlRadius`; Glass, or any plate under Appearance › Edges › Light, wears the
// shell's lit edge. None draws nothing and
// leaves the controls as they were.
Item {
    id: root
    property string material: IrisStyle.controlPlate
    property real controlHeight: Math.round(30 * IrisStyle.density)
    readonly property bool framed: ["veil", "glass", "solid"].includes(root.material)
    readonly property real inset: root.framed ? Math.round(4 * IrisStyle.density) : 0
    readonly property real controlRadius: root.framed ? IrisStyle.pieceRadius(root.controlHeight) : Math.round(root.controlHeight / 2)
    default property alias content: holder.data

    implicitWidth: holder.implicitWidth + root.inset * 2
    implicitHeight: holder.implicitHeight + root.inset * 2

    Rectangle {
        id: plate
        anchors.fill: parent
        visible: root.framed
        radius: root.controlRadius + root.inset
        color: IrisStyle.plateFillFor(root.material)
    }
    IrisGlassEdge {
        anchors.fill: parent
        visible: (root.material === "glass" || (root.framed && IrisStyle.edgeLit)) && shown
        radius: plate.radius
    }
    Item {
        id: holder
        x: root.inset
        y: root.inset
        implicitWidth: holder.childrenRect.width
        implicitHeight: holder.childrenRect.height
        width: holder.implicitWidth
        height: holder.implicitHeight
    }
}
