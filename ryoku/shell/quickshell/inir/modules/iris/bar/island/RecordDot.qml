pragma ComponentBehavior: Bound

import QtQuick
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.style
import inir.modules.iris.components

Rectangle {
    id: dot
    implicitWidth: 9 * IrisStyle.density
    implicitHeight: implicitWidth
    radius: width / 2
    color: IrisStyle.danger
    SequentialAnimation on opacity {
        running: dot.visible && IrisStyle.motionEnabled
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) dot.opacity = 1
    }
}
