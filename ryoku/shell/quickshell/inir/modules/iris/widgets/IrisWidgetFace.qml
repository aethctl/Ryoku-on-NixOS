pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import inir
import inir.services
import inir.modules.common
import inir.modules.common.functions
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
    readonly property bool live: root.widget.powerActive && root.widget.visible

    readonly property string material: root.widget.irisMaterial
    readonly property bool glass: root.material === "glass"
    readonly property bool clear: root.material === "clear"
    readonly property bool opaque: !root.glass && !root.clear
    readonly property real strength: root.widget.irisSurfaceOpacity
    readonly property real veil: root.opaque ? root.strength
        : IrisStyle.legibleVeil(root.material, root.widget.regionBrightness, root.widget.regionBrightnessSpread, root.strength)

    readonly property color accent: root.widget.irisAccent
    readonly property color highlight: root.widget.irisAccent3
    readonly property color ink: root.widget.ryokuInkOverride !== undefined && root.widget.ryokuInkOverride.a > 0
        ? root.widget.ryokuInkOverride : IrisStyle.text
    readonly property color inkSecondary: IrisStyle.secondaryOf(root.ink)
    readonly property color inkTertiary: IrisStyle.tertiaryOf(root.ink)
    readonly property int figureWeight: root.widget.widgetTitleWeight
    readonly property string fontMain: IrisStyle.fontMain
    readonly property string fontNumbers: IrisStyle.fontNumbers
    readonly property bool rimShown: !root.clear || root.widget.irisRim || GlobalStates.widgetEditMode
    readonly property color plateColor: ColorUtils.applyAlpha(root.opaque ? root.widget.irisPlate : IrisStyle.surface, root.veil)
    readonly property color knockout: root.opaque ? root.plateColor : IrisStyle.surface

    function dp(value: real): real { return Math.round(value * root.k) }
    function px(value: real): real { return Math.round(value * root.t) }

    RectangularShadow {
        anchors.fill: parent
        visible: !root.clear && !root.ryokuBare
        radius: root.radius
        blur: root.dp(28)
        spread: -root.dp(4)
        offset.y: root.dp(8)
        color: root.glass ? IrisStyle.glassShadow : IrisStyle.plateShadow
    }

    Loader {
        anchors.fill: parent
        active: root.glass && !root.ryokuBare
        sourceComponent: ClippingRectangle {
            id: glassPane
            visible: wallpaper.status === Image.Ready
            radius: root.radius
            color: "transparent"
            readonly property real margin: root.dp(24)

            Image {
                id: wallpaper
                visible: false
                width: root.widget.screenWidth
                height: root.widget.screenHeight
                source: WallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
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
                sourceItem: wallpaper
                sourceRect: Qt.rect(root.widget.ryokuScreenX - glassPane.margin, root.widget.ryokuScreenY - glassPane.margin, crop.width, crop.height)
                textureSize: Qt.size(Math.max(1, Math.round(crop.width / 2)), Math.max(1, Math.round(crop.height / 2)))
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: IrisStyle.glassBlur
                    blurMax: IrisStyle.glassBlurMax
                    saturation: IrisStyle.glassSaturation
                }
            }
        }
    }

    Rectangle {
        visible: !root.ryokuBare
        anchors.fill: parent
        radius: root.radius
        color: root.plateColor
        border.width: root.rimShown ? 1 : 0
        border.color: root.clear ? IrisStyle.clearRim : IrisStyle.rim
        Behavior on color { ColorAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on border.width { NumberAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: !root.clear && root.light.a > 0 && !root.ryokuBare
        opacity: root.glass ? IrisStyle.glassWash : 1
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: IrisStyle.skyWash(root.light) }
            GradientStop { position: 1; color: IrisStyle.skyWashFade(root.light) }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: root.padding
        layer.enabled: root.clear && !root.ryokuBare
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: IrisStyle.plateShadow
            shadowBlur: 0.5
            shadowVerticalOffset: 1
        }
    }
}
