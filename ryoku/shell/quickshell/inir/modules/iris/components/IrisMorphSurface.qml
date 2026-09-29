pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import inir
import inir.modules.common.functions
import inir.modules.iris.style

Item {
    id: root

    property bool open: false
    property bool contentReady: true
    property string motionSurface: ""
    property var origin: null
    property Item originItem: null
    property real originItemRadius: 0
    property real radius: IrisStyle.radius
    property color color: IrisStyle.surface
    property color light: "transparent"
    property string lightFrom: "top"
    property real contentScaleFrom: 0.965
    property real contentFadeStart: IrisStyle.contentRise
    property real contentFadeSpan: IrisStyle.contentSpan
    property int animationDuration: 0
    property bool contentTravels: false
    property real originShare: IrisStyle.absorbShare
    property bool fieldBacked: false
    property bool compositorBlurred: false
    readonly property string material: !IrisStyle.glassy ? "solid"
        : root.fieldBacked ? "field"
        : IrisStyle.glassCompositor && root.compositorBlurred ? "compositor" : "wallpaper"
    default property alias content: contentHost.data
    readonly property real progress: root.presentation
    readonly property var bodyRect: {
        void (chassis.x + chassis.y + chassis.width + chassis.height + chassis.radius + root.x + root.y)
        return { x: root.x + chassis.x, y: root.y + chassis.y,
            width: chassis.width, height: chassis.height, radius: chassis.radius }
    }
    readonly property bool settled: root.presentation >= 1
    signal closed()

    property var originScene: null
    property string originOwner: ""
    property point windowOffset: Qt.point(0, 0)
    property real fromRadius: root.radius
    readonly property rect from: root.originItem ? root.itemRect()
        : root.origin ? Qt.rect(root.origin.x - root.x, root.origin.y - root.y, root.origin.width, root.origin.height)
        : root.originScene ? root.sceneRect(root.originScene)
        : Qt.rect(root.width * 0.04, root.height * 0.04, root.width * 0.92, root.height * 0.92)
    readonly property bool absorbs: IrisStyle.revealDrops && !root.contentTravels
        && (root.originItem !== null || root.origin !== null || root.originScene !== null)
    readonly property rect start: {
        if (!root.absorbs) return root.from
        const k = root.originShare
        return Qt.rect(root.from.x + root.from.width * (1 - k) / 2, root.from.y + root.from.height * (1 - k) / 2,
            root.from.width * k, root.from.height * k)
    }
    function sceneRect(r: var): rect {
        void (root.x + root.y + (root.parent?.x ?? 0) + (root.parent?.y ?? 0))
        const p = root.mapFromItem(null, r.x - root.windowOffset.x, r.y - root.windowOffset.y)
        return Qt.rect(p.x, p.y, r.width, r.height)
    }
    function itemRect(): rect {
        void (root.x + root.y + root.width + root.height + (root.Window.window?.height ?? 0))
        const item = root.originItem
        const p = item.mapToItem(root, 0, 0)
        return Qt.rect(p.x, p.y, item.width * item.scale, item.height * item.scale)
    }
    property bool armed: false
    property bool launched: false
    property int launchFrames: 0
    Connections {
        target: root.Window.window
        enabled: root.armed && !root.launched
        function onFrameSwapped(): void { if (++root.launchFrames >= 2) root.launched = true }
    }
    Timer { interval: 90; running: root.armed && !root.launched; onTriggered: root.launched = true }
    readonly property alias presentation: presentationSpring.value
    IrisSpring {
        id: presentationSpring
        surface: root.motionSurface
        to: root.armed && root.launched ? 1 : 0
        intent: root.animationDuration > 0 ? "move" : "auto"
        minimum: 0
    }
    onPresentationChanged: if (root.presentation <= 0 && !root.open) root.closed()

    readonly property bool fromIsland: !root.originItem && !root.origin && root.originScene !== null

    function captureOrigin(): void {
        if (root.originItem) { root.originOwner = ""; root.fromRadius = root.originItemRadius; return }
        if (root.origin) { root.originOwner = ""; root.fromRadius = root.origin.radius ?? root.radius; return }
        const origin = root.origin ?? GlobalStates.irisMorphOrigin
        const screenName = root.origin ? "" : (GlobalStates.focusedScreen?.name ?? "")
        if (origin && origin.width > 0 && (!origin.screen || origin.screen === screenName)) {
            root.originOwner = GlobalStates.irisMorphOwner
            root.originScene = Qt.rect(origin.x, origin.y, origin.width, origin.height)
            root.fromRadius = origin.radius ?? origin.height / 2
        } else {
            root.originOwner = ""
            const island = GlobalStates.irisIslandGeometry?.[screenName] ?? null
            root.originScene = island && island.width > 0 ? Qt.rect(island.x, island.y, island.width, island.height) : null
            root.fromRadius = island ? island.height / 2 : root.radius
        }
    }
    readonly property bool canArm: root.open && root.contentReady && root.width > 0 && root.height > 0
    function arm(): void {
        if (!root.canArm || root.armed) return
        if (root.presentation <= 0) {
            root.captureOrigin()
            root.launched = false
            root.launchFrames = 0
        }
        root.armed = true
    }
    onCanArmChanged: if (root.canArm) Qt.callLater(root.arm)
    onOpenChanged: {
        if (!root.open) {
            root.armed = false
            if (root.fromIsland && root.originOwner.length === 0) Qt.callLater(root.captureOrigin)
        } else {
            Qt.callLater(root.arm)
        }
    }
    Component.onCompleted: Qt.callLater(root.arm)

    function lerp(a: real, b: real): real { return a + (b - a) * Math.min(1, root.presentation) }
    readonly property bool pullsAcross: Math.abs(root.width / 2 - root.start.x - root.start.width / 2)
        >= Math.abs(root.height / 2 - root.start.y - root.start.height / 2)
    readonly property real lagging: {
        const p = Math.min(1, Math.max(0, root.presentation))
        return root.absorbs ? Math.pow(p, IrisStyle.pullLag) : p
    }
    readonly property real progressX: root.absorbs && !root.pullsAcross ? root.lagging : Math.min(1, root.presentation)
    readonly property real progressY: root.absorbs && root.pullsAcross ? root.lagging : Math.min(1, root.presentation)
    function lerpX(a: real, b: real): real { return a + (b - a) * root.progressX }
    function lerpY(a: real, b: real): real { return a + (b - a) * root.progressY }

    readonly property real swell: Math.max(0, root.presentation - 1)
    readonly property real anchorX: Math.max(0, Math.min(root.width, root.from.x + root.from.width / 2))
    readonly property real anchorY: Math.max(0, Math.min(root.height, root.from.y + root.from.height / 2))
    readonly property real swellX: Math.max(0, root.width - root.start.width) * root.swell
    readonly property real swellY: Math.max(0, root.height - root.start.height) * root.swell

    readonly property real restX: root.lerpX(root.start.x, 0)
    readonly property real restY: root.lerpY(root.start.y, 0)
    readonly property real restWidth: root.lerpX(root.start.width, root.width)
    readonly property real restHeight: root.lerpY(root.start.height, root.height)
    readonly property bool originBefore: root.pullsAcross
        ? root.start.x + root.start.width / 2 < root.width / 2
        : root.start.y + root.start.height / 2 < root.height / 2
    readonly property real rideX: !root.absorbs ? 0 : root.pullsAcross
        ? (root.originBefore ? root.restX + root.restWidth - root.width : root.restX)
        : root.restX + (root.restWidth - root.width) / 2
    readonly property real rideY: !root.absorbs ? 0 : root.pullsAcross
        ? root.restY + (root.restHeight - root.height) / 2
        : (root.originBefore ? root.restY + root.restHeight - root.height : root.restY)

    readonly property bool drops: IrisStyle.revealDrops && !root.contentTravels
    readonly property bool dropping: root.drops && root.presentation < 1
    readonly property real snapX: Math.round(root.x) - root.x
    readonly property real snapY: Math.round(root.y) - root.y

    ClippingRectangle {
        id: chassis
        x: Math.round(root.x + root.lerpX(root.start.x, 0)
            - root.swellX * root.anchorX / Math.max(1, root.width)) - root.x
        y: Math.round(root.y + root.lerpY(root.start.y, 0)
            - root.swellY * root.anchorY / Math.max(1, root.height)) - root.y
        width: Math.round(root.lerpX(root.start.width, root.width) + root.swellX)
        height: Math.round(root.lerpY(root.start.height, root.height) + root.swellY)
        radius: Math.min(width / 2, height / 2, root.absorbs
            ? root.lerp(Math.min(Math.min(root.start.width, root.start.height) / 2, root.fromRadius * root.originShare), root.radius)
            : root.lerp(root.fromRadius, root.radius))
        color: root.material === "field" ? IrisStyle.bodyClip
            : root.material === "compositor" ? IrisStyle.placeSurface : root.color
        // Visible from the request: forceActiveFocus() is ignored on invisible subtrees.
        visible: root.open || root.presentation > 0
        opacity: root.armed || root.presentation > 0 ? 1 : 0

        Loader {
            anchors.fill: parent
            active: root.material === "wallpaper"
            sourceComponent: IrisGlassPane {
                sceneOffset: {
                    void (root.x + root.y + chassis.x + chassis.y + (root.parent?.x ?? 0) + (root.parent?.y ?? 0))
                    return chassis.mapToItem(null, 0, 0)
                }
                windowOffset: root.windowOffset
            }
        }

        IrisLightWash {
            anchors.fill: parent
            radius: chassis.radius
            light: root.light
            from: root.lightFrom
            presence: Math.max(0, Math.min(1, root.presentation))
        }

        Item {
            id: contentHost
            x: root.contentTravels ? 0 : Math.round(root.x + root.rideX) - root.x - chassis.x
            y: root.contentTravels ? 0 : Math.round(root.y + root.rideY) - root.y - chassis.y
            width: root.width
            height: root.height
            opacity: root.drops
                ? IrisStyle.ramp(root.lagging, IrisStyle.dropRise, IrisStyle.dropSpan)
                : IrisStyle.ramp(root.presentation, root.contentFadeStart, root.contentFadeSpan)
            scale: {
                if (root.presentation >= 1) return 1
                if (root.drops) return 0.96 + 0.04 * root.lagging
                if (IrisStyle.revealFades) return 1
                if (IrisStyle.revealInflates)
                    return Math.max(0.35, Math.min(1, chassis.height / Math.max(1, root.height)))
                return root.contentScaleFrom + (1 - root.contentScaleFrom) * root.presentation
            }
            enabled: root.open
        }
    }
}
