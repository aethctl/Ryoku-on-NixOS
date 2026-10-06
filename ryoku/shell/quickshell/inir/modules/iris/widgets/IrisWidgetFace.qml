pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import inir
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.iris.components
import inir.modules.iris.style

Item {
    id: root

    required property var widget
    property color light: "transparent"
    property real padding: root.dp(16)
    default property alias content: body.data
    // Ryoku host mode: skip the face's own plate/shadow/wash so the hosting Ryoku
    // WidgetSlot owns the backing and the colour-mode ink mask reaches the glyphs.
    // Defaults off, so the iRiS desktop frame is unchanged.
    property bool ryokuBare: false

    readonly property string size: root.widget.irisSize
    readonly property bool small: root.size === "small"
    readonly property bool medium: root.size === "medium"
    readonly property bool large: root.size === "large"
    readonly property real k: IrisStyle.density * root.widget.scaleFactor
    readonly property real t: IrisStyle.typeScale * root.widget.scaleFactor
    readonly property real radius: root.widget.cornerRadiusOverride >= 0
        ? root.widget.cornerRadiusOverride : Math.round(root.widget.widgetCardRadius * root.widget.scaleFactor)
    readonly property real innerRadius: Math.max(root.dp(6), root.radius - root.padding)
    readonly property real gap: root.dp(10)
    readonly property real contentWidth: root.width - root.padding * 2
    // Under Ryoku hosting the widget instance is a deliberately invisible data
    // source and the slot renders the face, so the host itself is the
    // visibility: without this the face reads live=false forever, the clock
    // drops to minute precision and the second hand freezes.
    readonly property bool live: root.widget.powerActive && (root.widget.visible || root.widget.ryokuHosted)

    readonly property string material: root.widget.irisMaterial
    readonly property bool glass: root.material === "glass"
    readonly property bool clear: root.material === "clear"
    readonly property bool opaque: !root.glass && !root.clear
    readonly property real strength: root.widget.irisSurfaceOpacity
    // Glass and transparent faces over a light region turn over: frost and near-black ink instead of
    // a veil darkened until the glass is gone. An opaque plate keeps its own polarity.
    // In the light scheme a plate is light, so its ink is the dark one; a bare widget still follows the wallpaper.
    readonly property bool lightBackdrop: IrisStyle.light && !root.clear ? true : root.opaque ? root.widget.forceDarkInk
        : root.clear ? root.widget.inkOnLight : root.widget.glassInkOnLight
    readonly property bool ownInk: root.lightBackdrop || (IrisStyle.light && root.clear)
    // Transparent is bare: it carries no plate unless Lume on every widget asks for one. Glass is solved as
    // thick as its text needs, then Surface opacity thins it (100 % keeps the solve); Lume on every widget
    // keeps the full solve, since reading first is what that switch asks for.
    // Glass thinned below its solve reads like Transparent: its text carries the same shadow, as strong as
    // the veil it gave up.
    readonly property real textShadow: root.clear ? 1
        : root.glass && !root.widget.legibleAlways ? Math.min(1, (1 - root.strength) * 1.4) : 0
    readonly property real veil: root.opaque ? root.strength
        : root.clear && !root.widget.legibleAlways ? 0
        : (root.lightBackdrop ? IrisStyle.legibleFrost(root.readMaterial, root.frostLevel, root.readSpread, 1)
            : IrisStyle.legibleVeil(root.readMaterial, root.readLevel, root.readSpread, 1))
            * (root.widget.legibleAlways ? 1 : root.strength)
    // Lume on every widget: the veil (light ink) is solved as if the region were bright and busy, the frost
    // (dark ink) as if it were dim and busy.
    readonly property real readLevel: root.widget.legibleAlways ? Math.max(0.72, root.widget.regionBrightness) : root.widget.regionBrightness
    // ...and to the contrast of a reading panel (7:1), so Transparent and Glass both carry a real backing.
    readonly property string readMaterial: root.widget.legibleAlways ? "panel" : root.material
    readonly property real frostLevel: root.widget.legibleAlways ? Math.min(0.5, root.widget.regionBrightness) : root.widget.regionBrightness
    readonly property real readSpread: root.widget.legibleAlways ? Math.max(0.24, root.widget.regionBrightnessSpread) : root.widget.regionBrightnessSpread

    readonly property color accent: root.lightBackdrop ? IrisStyle.deepAccent(root.widget.irisAccent, IrisStyle.inkOnLight) : root.widget.irisAccent
    readonly property color highlight: root.lightBackdrop ? IrisStyle.deepAccent(root.widget.irisAccent3, IrisStyle.inkOnLight) : root.widget.irisAccent3
    readonly property color accent2: root.lightBackdrop ? IrisStyle.deepAccent(root.widget.irisAccent2, IrisStyle.inkOnLight) : root.widget.irisAccent2
    readonly property color warm: root.lightBackdrop ? IrisStyle.deepAccent(IrisStyle.secondaryAccent, IrisStyle.inkOnLight) : IrisStyle.secondaryAccent
    readonly property color danger: root.lightBackdrop ? IrisStyle.deepAccent(IrisStyle.danger, IrisStyle.inkOnLight) : IrisStyle.danger
    readonly property color ink: root.widget.ryokuInkOverride !== undefined && root.widget.ryokuInkOverride.a > 0
        ? root.widget.ryokuInkOverride : (root.lightBackdrop ? IrisStyle.inkOnLight : IrisStyle.light ? IrisStyle.inkOnDark : IrisStyle.text)
    readonly property color inkSecondary: IrisStyle.secondaryOf(root.ink)
    readonly property color inkTertiary: IrisStyle.tertiaryOf(root.ink)
    readonly property color fillQuiet: root.ownInk ? IrisStyle.fillQuietOf(root.ink) : IrisStyle.fillQuiet
    readonly property color fill: root.ownInk ? IrisStyle.fillOf(root.ink) : IrisStyle.fill
    readonly property color fillHover: root.ownInk ? IrisStyle.fillHoverOf(root.ink) : IrisStyle.fillHover
    readonly property color fillActive: root.ownInk ? IrisStyle.fillActiveOf(root.ink) : IrisStyle.fillActive
    readonly property color hairline: root.ownInk ? IrisStyle.hairlineOf(root.ink) : IrisStyle.hairline
    // Ink on a filled accent: light on the deep accents of a light face, the Island's dark otherwise.
    function onFill(tint: color): color { return root.lightBackdrop ? IrisStyle.onTint : IrisStyle.onTintFor(tint) }
    readonly property int figureWeight: root.widget.widgetTitleWeight
    readonly property string fontMain: IrisStyle.fontMain
    readonly property string fontNumbers: IrisStyle.fontNumbers
    // Outline: Auto follows the shell's outline and leaves Transparent bare; while arranging it always shows.
    readonly property bool rimShown: GlobalStates.widgetEditMode || root.widget.irisOutline === "always"
        || (root.widget.irisOutline === "auto" && (!root.clear || root.widget.irisRim))
    // Glass wears the shell's glass edge (Appearance › Glass › Edge light, Edge line, Edge width, Edge colour):
    // lit where it faces up, a line elsewhere. With both at 0 Auto draws no line, like the shell's glass.
    // Appearance › Edges › Light gives every plated widget that edge, whatever its material.
    readonly property bool glassEdge: (root.glass || IrisStyle.edgeLit) && !root.lightBackdrop
        && (IrisStyle.glassEdgeLight > 0 || IrisStyle.glassEdgeLine > 0)
    readonly property bool flatRim: root.rimShown && !root.glassEdge
        && !(root.glass && !root.lightBackdrop && root.widget.irisOutline === "auto" && !GlobalStates.widgetEditMode)
    readonly property color plateColor: ColorUtils.applyAlpha(root.opaque ? root.widget.irisPlate
        : root.lightBackdrop ? IrisStyle.frost : IrisStyle.surface, root.veil)
    readonly property color knockout: root.opaque ? root.plateColor : root.lightBackdrop ? IrisStyle.frost : IrisStyle.surface

    // In a stack the plate stays and the pages' contents slide over it (DesktopWidgetStacks).
    readonly property bool stacked: root.widget.stacked
    readonly property real slide: root.widget.stackPos
    readonly property bool plated: !root.stacked || root.widget.stackShown

    function dp(value: real): real { return Math.round(value * root.k) }
    function px(value: real): real { return Math.round(value * root.t) }

    RectangularShadow {
        anchors.fill: parent
        visible: !root.clear && !root.ryokuBare && root.plated
        radius: root.radius
        blur: root.dp(28)
        spread: -root.dp(4)
        offset.y: root.dp(8)
        color: root.glass ? IrisStyle.glassShadow : IrisStyle.plateShadow
    }

    Loader {
        anchors.fill: parent
        active: root.glass && !root.ryokuBare
        visible: root.plated
        sourceComponent: ClippingRectangle {
            id: glassPane
            // The desktop's own wallpaper layer: live, parallax included, no second decoder.
            readonly property Item desktopLayer: root.QsWindow?.window?.wallpaperLayer ?? null
            readonly property point at: {
                void (root.widget.ryokuScreenX + root.widget.ryokuScreenY + (root.widget.parent?.x ?? 0) + (root.widget.parent?.y ?? 0))
                return glassPane.desktopLayer ? root.mapToItem(glassPane.desktopLayer, 0, 0) : Qt.point(root.widget.ryokuScreenX, root.widget.ryokuScreenY)
            }
            visible: glassPane.desktopLayer !== null || wallpaper.status === Image.Ready
            radius: root.radius
            color: "transparent"
            readonly property real margin: root.dp(24)

            Image {
                id: wallpaper
                visible: false
                width: root.widget.screenWidth
                height: root.widget.screenHeight
                source: glassPane.desktopLayer ? "" : WallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.round(root.widget.screenWidth / 2)
                sourceSize.height: Math.round(root.widget.screenHeight / 2)
            }

            ShaderEffectSource {
                id: crop
                x: -glassPane.margin
                y: -glassPane.margin
                width: root.width + glassPane.margin * 2
                height: root.height + glassPane.margin * 2
                sourceItem: glassPane.desktopLayer ?? wallpaper
                sourceRect: Qt.rect(glassPane.at.x - glassPane.margin, glassPane.at.y - glassPane.margin, crop.width, crop.height)
                textureSize: Qt.size(Math.max(1, Math.round(crop.width / 2)), Math.max(1, Math.round(crop.height / 2)))
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: IrisStyle.glassBlurAmount
                    blurMax: IrisStyle.glassBlurMax
                    saturation: IrisStyle.widgetGlassSaturation
                }
            }
        }
    }

    Rectangle {
        visible: !root.ryokuBare && root.plated
        anchors.fill: parent
        radius: root.radius
        color: root.plateColor
        border.width: root.flatRim ? 1 : 0
        border.color: root.lightBackdrop ? root.hairline : root.clear || IrisStyle.rim.a === 0 ? IrisStyle.clearRim : IrisStyle.rim
        Behavior on color { ColorAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on border.width { NumberAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
    }

    IrisGlassEdge {
        anchors.fill: parent
        visible: root.glassEdge && root.rimShown && root.plated
        radius: root.radius
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: !root.clear && root.light.a > 0 && !root.ryokuBare
        opacity: (root.glass ? IrisStyle.glassWash : 1) * (1 - Math.min(1, Math.abs(root.slide)))
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: IrisStyle.skyWash(root.light) }
            GradientStop { position: 1; color: IrisStyle.skyWashFade(root.light) }
        }
    }

    // Pages slide inside the plate's box and are cut at its edge while they move.
    Item {
        id: viewport
        anchors.fill: parent
        clip: root.stacked && root.slide !== 0

        Item {
            id: slider
            width: viewport.width
            height: viewport.height
            // The page travels half its height while it fades, so two pages cross instead of one pushing the other out.
            y: Math.round(root.slide * root.height * 0.5)
            opacity: 1 - Math.pow(Math.min(1, Math.abs(root.slide)), 1.5)

            ShaderEffectSource {
                id: bodyCopy
                anchors.fill: body
                sourceItem: root.textShadow > 0.05 ? body : null
                hideSource: false
                visible: false
            }
            // The shadow comes from a copy behind the body: a layered body would resample its text.
            MultiEffect {
                x: body.x
                y: body.y + 1
                width: body.width
                height: body.height
                visible: root.textShadow > 0.05
                source: bodyCopy
                brightness: root.lightBackdrop ? 1 : -1
                colorization: IrisStyle.glow > 0 && !root.lightBackdrop ? 1 : 0
                colorizationColor: Qt.rgba(IrisStyle.plateShadow.r, IrisStyle.plateShadow.g, IrisStyle.plateShadow.b, 1)
                blurEnabled: true
                blur: 0.5
                autoPaddingEnabled: true
                opacity: (root.lightBackdrop ? IrisStyle.frostShadow : IrisStyle.plateShadow.a) * root.textShadow
            }

            Item {
                id: body
                anchors.fill: parent
                anchors.margins: root.padding
            }
        }
    }

    // Carried over by another widget: this is where it will land.
    Rectangle {
        z: 140
        anchors.fill: parent
        radius: root.radius
        visible: opacity > 0
        opacity: root.widget.stackDropHint ? 1 : 0
        color: IrisStyle.tintFill(root.accent)
        border.width: 2
        border.color: root.accent
        Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

        Rectangle {
            anchors.centerIn: parent
            width: root.dp(44)
            height: width
            radius: IrisStyle.iconRadius(width)
            scale: root.widget.stackDropHint ? 1 : 0.8
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(root.accent, 1.18) }
                GradientStop { position: 1; color: root.accent }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "stacks"
                fill: 1
                iconSize: root.dp(24)
                color: root.onFill(root.accent)
            }
        }
    }

    Loader {
        active: root.stacked
        z: 150
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: active && root.widget.stackShown
        sourceComponent: IrisStackDots { face: root }
    }

    // Wheel over a stack turns its page, one per gesture: a touchpad's tail is held off until the page has settled.
    property real _wheel: 0
    Timer { id: wheelHold; interval: 360 }
    Timer { id: wheelReset; interval: 260; onTriggered: root._wheel = 0 }
    WheelHandler {
        enabled: root.stacked && root.widget.stackShown
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelHold.running)
                return
            root._wheel += event.angleDelta.y
            wheelReset.restart()
            if (Math.abs(root._wheel) < 120)
                return
            const forward = root._wheel < 0
            root._wheel = 0
            wheelHold.restart()
            DesktopWidgetStacks.step(root.widget.outputName, root.widget.stack.id, forward ? 1 : -1)
        }
    }

    // A stack holds its page while the pointer is on it or the widget is being carried.
    HoverHandler {
        id: stackHover
        enabled: root.stacked
    }
    readonly property bool _holding: root.stacked && root.widget.stackShown && (stackHover.hovered || root.widget.containsPress)
    on_HoldingChanged: if (root.stacked) DesktopWidgetStacks.setHovered(root.widget.stack.id, root._holding)
}
