pragma ComponentBehavior: Bound

import QtQuick
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.style

Item {
    id: root

    property bool active: false
    readonly property var organic: Config.options?.background?.edgeWidgets?.organic ?? ({})
    readonly property var edges: Array.from(root.organic?.edges ?? ["left", "right"])
    readonly property real drive: Math.max(0, Math.min(2, Number(root.organic?.bassDrive ?? 88) / 100))
    readonly property real reach: Math.round(18 * IrisStyle.density * root.drive)
    property real level: 0
    property real phase: 0
    readonly property vector4d amplitudes: Qt.vector4d(
        root.edges.includes("left") ? root.level * root.reach : 0,
        root.edges.includes("top") ? root.level * root.reach : 0,
        root.edges.includes("right") ? root.level * root.reach : 0,
        root.edges.includes("bottom") ? root.level * root.reach : 0)

    CavaProcess {
        id: cava
        active: root.active && (MprisController.activePlayer?.isPlaying ?? false)
        sampleCount: 16
    }
    FrameAnimation {
        running: root.active && (cava.held || root.level > 0.002)
        onTriggered: {
            const points = cava.points ?? []
            let bass = 0
            const count = Math.min(4, points.length)
            for (let i = 0; i < count; ++i) bass += Number(points[i] ?? 0)
            bass = count > 0 ? Math.min(1, bass / count / Math.max(1, cava.normalizationCeiling)) : 0
            const step = Math.min(0.05, frameTime)
            const rate = bass > root.level ? 18 : 3.2
            root.level += (bass - root.level) * Math.min(1, rate * step)
            if (root.level < 0.002 && !cava.held) root.level = 0
            root.phase = (root.phase + step * (0.6 + 2.4 * root.level)) % 6283.185
        }
    }
}
