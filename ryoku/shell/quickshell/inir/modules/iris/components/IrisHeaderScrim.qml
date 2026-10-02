import QtQuick
import inir.modules.common.functions
import inir.modules.iris.style

// The Island desktop page's wallpaper header: how the image meets the body at the top (the join, the navigation
// row) and hands over to it at the bottom. IslandDesktopPage and the Settings preview both draw it from here,
// so the preview cannot drift from the Island. Pair it with IrisHeaderFade as the image's mask.
Rectangle {
    id: root

    // Geometry, in px from the header's top.
    property bool hangs: false // the header starts under a join or the navigation row
    property real solidTop: 0 // the middle of the navigation row: the designed melt starts there
    property real navBand: 0
    property bool topJoin: false // notched on the top edge: the shoulders sit inside the header
    property real joinDepth: 0 // how far down the shoulders reach
    property real unit: IrisStyle.density
    // Settings › Island › Desktop page, 0..1: 1 / 1 / 1 is the header as designed.
    property real meltTop: 1
    property real meltFade: 1
    property real meltVeil: 1

    readonly property real edge: root.hangs ? root.solidTop / Math.max(1, root.height) : 0
    readonly property real topFade: root.hangs ? (root.solidTop + 30 * root.unit + root.navBand * 0.5) / Math.max(1, root.height) : 0.001
    // Veil scales the dimming; Fade moves where the body takes over (lower starts it later).
    readonly property real topAlpha: 0.12 * root.meltVeil // iris-literal: hero fade ramp
    readonly property real midAlpha: IrisStyle.wallpaperVeil * root.meltVeil
    readonly property real midAt: Math.min(0.8, 0.42 + (1 - root.meltFade) * 0.38)
    // The join is left to the body: the mask (IrisHeaderFade) cuts the image there instead of this scrim painting the
    // body's colour over it, which also covered the body's own edge (Appearance › Edges) at the top.
    readonly property real solidAlpha: root.topAlpha
    // Header top: lower lets the wallpaper rise higher. Hanging from its edge it keeps the join the family uses for
    // artwork (IrisMediaBackdrop's edgeTop): the body's own material down past the shoulders, then a ramp as long
    // again, so the end of the shoulder curve sits under the veil and no corner of the image shows beside it.
    readonly property real shoulderEnd: root.topJoin ? Math.min(0.6, root.joinDepth / Math.max(1, root.height)) : 0
    readonly property real solidEnd: root.shoulderEnd + (root.edge - root.shoulderEnd) * root.meltTop
    readonly property real joinRamp: root.topJoin ? Math.min(0.9, root.shoulderEnd / 0.45) : 0.001
    readonly property real rampEnd: Math.max(root.solidEnd + 0.001, root.joinRamp + (root.topFade - root.joinRamp) * root.meltTop)
    // The mask's stops (IrisHeaderFade): glass lets the body show through at the join and at the bottom.
    readonly property real maskSolidEnd: root.hangs ? root.solidEnd : 0
    readonly property real maskRampEnd: root.hangs ? root.rampEnd : 0.001 + 0.08 * root.meltTop

    // The header always ends in the body, whatever Fade and Veil are: its bottom never shows a straight cut.
    gradient: Gradient {
        GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, root.solidAlpha) }
        GradientStop { position: root.solidEnd; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, root.solidAlpha) }
        GradientStop { position: root.rampEnd; color: ColorUtils.applyAlpha(IrisStyle.bodyScrim, root.topAlpha) }
        GradientStop { position: root.midAt; color: ColorUtils.applyAlpha(IrisStyle.surfaceOpaque, root.midAlpha) }
        GradientStop { position: 1; color: IrisStyle.bodyScrim }
    }
}
