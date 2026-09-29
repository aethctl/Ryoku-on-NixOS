pragma ComponentBehavior: Bound

import QtQuick
import inir.modules.common.functions
import inir.modules.iris.style

Rectangle {
    id: root

    property color light: "transparent"
    property string from: "top"
    property real presence: 1
    readonly property bool across: root.from === "left" || root.from === "right"
    readonly property bool reversed: root.from === "bottom" || root.from === "right"
    readonly property real extent: Math.max(1, root.across ? root.width : root.height)
    readonly property real fall: Math.min(0.7, Math.max(0.12, Math.max(IrisStyle.lightReach, 1.5 * root.radius) / root.extent))
    function at(position: real): real { return root.reversed ? 1 - position : position }

    visible: IrisStyle.auraStrength > 0 && root.light.a > 0
    opacity: root.presence * Math.min(1, IrisStyle.tweak("lightReach", 0.5, 3))
    gradient: Gradient {
        orientation: root.across ? Gradient.Horizontal : Gradient.Vertical
        GradientStop { position: root.at(0); color: IrisStyle.aura(root.light) }
        GradientStop { position: root.at(root.fall * 0.45); color: IrisStyle.auraFading(root.light) }
        GradientStop { position: root.at(root.fall); color: ColorUtils.applyAlpha(root.light, 0) }
        GradientStop { position: root.at(1); color: ColorUtils.applyAlpha(root.light, 0) }
    }
}
