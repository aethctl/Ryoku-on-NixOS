pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import inir.services
import inir.modules.common
import inir.modules.iris.style
import inir.modules.iris.frame

Item {
    id: root

    property var shapes: []
    property color tint: IrisStyle.bodySurface
    property color rim: IrisStyle.rim
    property real rimWidth: IrisStyle.rimWidth
    property real smoothing: IrisStyle.fuse
    property bool framed: IrisFrame.framed
    property real band: IrisFrame.band
    property real cornerRadius: IrisFrame.cornerRadius
    readonly property int capacity: 20
    readonly property int shadowSlots: root.capacity
    readonly property real reach: root.smoothing + 2
    property bool compositorAllowed: false
    readonly property int glassCode: IrisStyle.glassCompositor ? (root.compositorAllowed ? 2 : 1) : IrisStyle.glassWallpaper ? 1 : 0
    property int frameGlass: root.glassCode
    property vector4d edgeWave: Qt.vector4d(0, 0, 0, 0)
    property real waveClock: 0
    readonly property var restingIds: ["island", "dock", "dockEdge", "edge", "plate:", "piece:", "satellite:", "pieceEdge:"]
    function rests(shape: var): bool {
        const id = String(shape?.id ?? "")
        return id.length > 0 && root.restingIds.some(prefix => prefix.endsWith(":") ? id.startsWith(prefix) : id === prefix)
    }
    function glassOf(shape: var): int {
        const code = root.rawGlassOf(shape)
        return code === 2 && !root.rests(shape) ? 1 : code
    }
    function rawGlassOf(shape: var): int {
        if (!shape) return 0
        const g = shape.glass
        if (g === undefined || g === null || g === "inherit") return root.glassCode
        if (g === "compositor") return Appearance.compositorBlurActive && root.compositorAllowed ? 2 : 1
        if (g === "wallpaper" || g === true) return 1
        return 0
    }
    readonly property bool wantsBackdrop: root.frameGlass === 1 || (root.shapes ?? []).some(shape => root.glassOf(shape) === 1)

    Loader {
        id: backdropLoader
        active: root.wantsBackdrop
        sourceComponent: IrisGlassSource {
            width: root.width
            height: root.height
            screen: root.QsWindow.window?.screen ?? null
        }
    }
    Item {
        id: noBackdrop
        visible: false
        width: 1
        height: 1
        layer.enabled: true
    }

    readonly property rect bounds: {
        if (root.framed) return Qt.rect(0, 0, root.width, root.height)
        const list = root.shapes ?? []
        if (list.length === 0) return Qt.rect(0, 0, 0, 0)
        let left = Infinity;
        let top = Infinity;
        let right = -Infinity;
        let bottom = -Infinity;
        for (const s of list) {
            left = Math.min(left, s.x - root.reach)
            top = Math.min(top, s.y - root.reach)
            right = Math.max(right, s.x + s.width + root.reach)
            bottom = Math.max(bottom, s.y + s.height + root.reach)
        }
        const x = Math.max(0, Math.floor(left));
        const y = Math.max(0, Math.floor(top))
        return Qt.rect(x, y, Math.ceil(Math.min(root.width, right)) - x,
            Math.ceil(Math.min(root.height, bottom)) - y)
    }

    // Fixed pool: a model Repeater rebuilds every delegate whenever a body moves.
    component Shade: RectangularShadow {
        id: shade
        required property int index
        readonly property var shape: root.shapes[shade.index] ?? null
        visible: shade.shape !== null && !shade.shape.paints
        x: shade.shape ? shade.shape.x : 0
        y: shade.shape ? shade.shape.y : 0
        width: shade.shape ? shade.shape.width : 0
        height: shade.shape ? shade.shape.height : 0
        radius: shade.shape ? (shade.shape.radius ?? 0) : 0
        offset.y: 3 * IrisStyle.density
        blur: 16 * IrisStyle.density
        color: IrisStyle.shadow
    }
    Repeater {
        model: root.shadowSlots
        delegate: Shade {
            required property int modelData
            index: modelData
        }
    }

    ShaderEffect {
        id: pass
        visible: root.bounds.width > 0 && root.bounds.height > 0
        x: root.bounds.x
        y: root.bounds.y
        width: root.bounds.width
        height: root.bounds.height
        fragmentShader: Qt.resolvedUrl("IrisField.frag.qsb")
        blending: true

        function shapeAt(i: int): var {
            const s = root.shapes[i]
            return s ? Qt.vector4d(s.x + s.width / 2, s.y + s.height / 2, s.width / 2, s.height / 2)
                : Qt.vector4d(0, 0, 0, 0)
        }
        function radiusBlock(block: int): var {
            const r = i => {
                const s = root.shapes[block * 4 + i]
                return s ? Number(s.radius ?? 0) : 0
            }
            return Qt.vector4d(r(0), r(1), r(2), r(3))
        }
        function fuseBlock(block: int): var {
            const k = i => {
                const s = root.shapes[block * 4 + i]
                return s ? Number(s.fuse ?? root.smoothing) : 0
            }
            return Qt.vector4d(k(0), k(1), k(2), k(3))
        }
        readonly property var indexOf: {
            const map = {}
            const list = root.shapes ?? []
            for (let i = 0; i < Math.min(list.length, root.capacity); i++)
                if (list[i]?.id) map[list[i].id] = i
            return map
        }
        function joinBlock(block: int, which: int): var {
            const j = i => {
                const s = root.shapes[block * 4 + i]
                const list = !s || !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
                const name = list[which]
                if (!name) return 0
                if (name === "frame") return root.framed ? -1 : 0
                const index = pass.indexOf[name]
                return index === undefined ? 0 : index + 1
            }
            return Qt.vector4d(j(0), j(1), j(2), j(3))
        }
        function paintsBlock(block: int): var {
            const f = i => {
                const s = root.shapes[block * 4 + i]
                return s && s.paints ? 1 : 0
            }
            return Qt.vector4d(f(0), f(1), f(2), f(3))
        }

        readonly property vector4d viewport: Qt.vector4d(pass.x, pass.y,
            Math.max(1, pass.width), Math.max(1, pass.height))
        readonly property vector2d screen: Qt.vector2d(Math.max(1, root.width), Math.max(1, root.height))
        readonly property vector4d field: Qt.vector4d(root.smoothing, root.framed ? 1 : 0,
            root.band, root.cornerRadius)
        readonly property color tint: root.tint
        readonly property color rim: root.rim
        readonly property vector4d edge: Qt.vector4d(root.rimWidth, root.rim.a > 0 ? 1 : 0, 0, 0)
        readonly property vector4d shape0: pass.shapeAt(0)
        readonly property vector4d shape1: pass.shapeAt(1)
        readonly property vector4d shape2: pass.shapeAt(2)
        readonly property vector4d shape3: pass.shapeAt(3)
        readonly property vector4d shape4: pass.shapeAt(4)
        readonly property vector4d shape5: pass.shapeAt(5)
        readonly property vector4d shape6: pass.shapeAt(6)
        readonly property vector4d shape7: pass.shapeAt(7)
        readonly property vector4d shape8: pass.shapeAt(8)
        readonly property vector4d shape9: pass.shapeAt(9)
        readonly property vector4d shape10: pass.shapeAt(10)
        readonly property vector4d shape11: pass.shapeAt(11)
        readonly property vector4d shape12: pass.shapeAt(12)
        readonly property vector4d shape13: pass.shapeAt(13)
        readonly property vector4d shape14: pass.shapeAt(14)
        readonly property vector4d shape15: pass.shapeAt(15)
        readonly property vector4d shape16: pass.shapeAt(16)
        readonly property vector4d shape17: pass.shapeAt(17)
        readonly property vector4d shape18: pass.shapeAt(18)
        readonly property vector4d shape19: pass.shapeAt(19)
        readonly property vector4d radiiA: pass.radiusBlock(0)
        readonly property vector4d radiiB: pass.radiusBlock(1)
        readonly property vector4d radiiC: pass.radiusBlock(2)
        readonly property vector4d radiiD: pass.radiusBlock(3)
        readonly property vector4d radiiE: pass.radiusBlock(4)
        readonly property vector4d fuseA: pass.fuseBlock(0)
        readonly property vector4d fuseB: pass.fuseBlock(1)
        readonly property vector4d fuseC: pass.fuseBlock(2)
        readonly property vector4d fuseD: pass.fuseBlock(3)
        readonly property vector4d fuseE: pass.fuseBlock(4)
        readonly property vector4d joinA: pass.joinBlock(0, 0)
        readonly property vector4d alsoA: pass.joinBlock(0, 1)
        readonly property vector4d joinB: pass.joinBlock(1, 0)
        readonly property vector4d alsoB: pass.joinBlock(1, 1)
        readonly property vector4d joinC: pass.joinBlock(2, 0)
        readonly property vector4d alsoC: pass.joinBlock(2, 1)
        readonly property vector4d joinD: pass.joinBlock(3, 0)
        readonly property vector4d alsoD: pass.joinBlock(3, 1)
        readonly property vector4d joinE: pass.joinBlock(4, 0)
        readonly property vector4d alsoE: pass.joinBlock(4, 1)
        readonly property vector4d paintsA: pass.paintsBlock(0)
        readonly property vector4d paintsB: pass.paintsBlock(1)
        readonly property vector4d paintsC: pass.paintsBlock(2)
        readonly property vector4d paintsD: pass.paintsBlock(3)
        readonly property vector4d paintsE: pass.paintsBlock(4)
        function glassBlock(block: int): var {
            const g = i => root.glassOf(root.shapes[block * 4 + i])
            return Qt.vector4d(g(0), g(1), g(2), g(3))
        }
        readonly property vector4d glassA: pass.glassBlock(0)
        readonly property vector4d glassB: pass.glassBlock(1)
        readonly property vector4d glassC: pass.glassBlock(2)
        readonly property vector4d glassD: pass.glassBlock(3)
        readonly property vector4d glassE: pass.glassBlock(4)
        readonly property bool backdropReady: backdropLoader.item?.ready ?? false
        readonly property vector4d glass: Qt.vector4d(pass.backdropReady ? 1 : 0, root.framed ? root.frameGlass : 0,
            IrisStyle.glassTint, IrisStyle.glassLip)
        readonly property vector4d edgeWave: root.edgeWave
        readonly property vector4d waveClock: Qt.vector4d(root.waveClock, 0, 0, 0)
        readonly property Item backdrop: pass.backdropReady ? backdropLoader.item.texture : noBackdrop
    }
}
