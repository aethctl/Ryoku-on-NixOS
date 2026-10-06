// Ryoku Stage Editor: the illogical-impulse Appearance tokens (colours, rounding,
// fonts, sizes, animation) verbatim, with the Material palette sourced from Ryoku's
// live theme and the compositor-writing border/blur/gap handlers dropped. See docs/stage.md.
pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import stage.modules.common.functions
import stage.services
import shell.services as RTheme
import Ryoku.Ui.Singletons


Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property string syntaxHighlightingTheme

    readonly property int windowRounding: {
        let rv = Config.options.appearance.roundingValue;
        if (rv <= 0)
            return 0;
        return Math.round(18 * rv / 24.0);
    }
    // Transparency. The quadratic functions were derived from analysis of hand-picked transparency values.
    ColorQuantizer {
        id: wallColorQuant
        property string wallpaperPath: Config.options?.background?.wallpaperPath ?? ""
        property bool wallpaperIsVideo: wallpaperPath !== "" && (wallpaperPath.endsWith(".mp4") || wallpaperPath.endsWith(".webm") || wallpaperPath.endsWith(".mkv") || wallpaperPath.endsWith(".avi") || wallpaperPath.endsWith(".mov"))
        source: wallpaperPath !== "" ? Qt.resolvedUrl(wallpaperIsVideo ? Config.options?.background?.thumbnailPath ?? "" : wallpaperPath) : ""
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }
    property real wallpaperVibrancy: (wallColorQuant.colors[0]?.hslSaturation + wallColorQuant.colors[0]?.hslLightness) / 2
    property real autoBackgroundTransparency: { // y = 0.5768x^2 - 0.759x + 0.2896
        let x = wallpaperVibrancy;
        let y = 0.5768 * (x * x) - 0.759 * (x) + 0.2896;
        return Math.max(0, Math.min(0.22, y)) - 0.12 * (m3colors.darkmode ? 0 : 1);
    }
    property real autoContentTransparency: 0.9
    property real backgroundTransparency: Config?.options.appearance.transparency.enable ? Config?.options.appearance.transparency.automatic ? autoBackgroundTransparency : Config?.options.appearance.transparency.backgroundTransparency : 0
    property real contentTransparency: Config?.options.appearance.transparency.enable ? (Config?.options.appearance.transparency.automatic ? autoContentTransparency : Config?.options.appearance.transparency.contentTransparency) : 0

    // The Material 3 role palette, sourced from Ryoku's live theme (the same
    // three-layer chain the rest of the desktop paints with: named scheme, then
    // the wallpaper, then the compiled base). The colour derivation below is the
    // reference's verbatim; only this source is Ryoku's, so the editor wears the
    // desktop's palette rather than a second one.
    m3colors: QtObject {
        property bool darkmode: RTheme.Theme.surface.lightness < 0.5
        property bool transparent: false
        property color m3background: RTheme.Theme.surface
        property color m3onBackground: RTheme.Theme.onSurface
        property color m3surface: RTheme.Theme.surface
        property color m3surfaceDim: Qt.darker(RTheme.Theme.surface, 1.1)
        property color m3surfaceBright: Qt.lighter(RTheme.Theme.surface, 1.3)
        property color m3surfaceContainerLowest: RTheme.Theme.surfaceContainerLowest
        property color m3surfaceContainerLow: RTheme.Theme.surfaceContainerLow
        property color m3surfaceContainer: RTheme.Theme.surfaceContainer
        property color m3surfaceContainerHigh: RTheme.Theme.surfaceContainerHigh
        property color m3surfaceContainerHighest: RTheme.Theme.surfaceContainerHighest
        property color m3onSurface: RTheme.Theme.onSurface
        property color m3surfaceVariant: RTheme.Theme.surfaceVariant
        property color m3onSurfaceVariant: RTheme.Theme.onSurfaceVariant
        property color m3inverseSurface: RTheme.Theme.inverseSurface
        property color m3inverseOnSurface: RTheme.Theme.inverseOnSurface
        property color m3outline: RTheme.Theme.outline
        property color m3outlineVariant: RTheme.Theme.outlineVariant
        property color m3shadow: RTheme.Theme.shadow
        property color m3scrim: RTheme.Theme.scrim
        property color m3surfaceTint: RTheme.Theme.surfaceTint
        property color m3primary: RTheme.Theme.primary
        property color m3onPrimary: RTheme.Theme.onPrimary
        property color m3primaryContainer: RTheme.Theme.primaryContainer
        property color m3onPrimaryContainer: RTheme.Theme.onPrimaryContainer
        property color m3inversePrimary: RTheme.Theme.primary
        property color m3secondary: RTheme.Theme.secondary
        property color m3onSecondary: RTheme.Theme.onSecondary
        property color m3secondaryContainer: RTheme.Theme.secondaryContainer
        property color m3onSecondaryContainer: RTheme.Theme.onSecondaryContainer
        property color m3tertiary: RTheme.Theme.tertiary
        property color m3onTertiary: RTheme.Theme.onTertiary
        property color m3tertiaryContainer: RTheme.Theme.tertiaryContainer
        property color m3onTertiaryContainer: RTheme.Theme.onTertiaryContainer
        property color m3error: RTheme.Theme.error
        property color m3onError: RTheme.Theme.onError
        property color m3errorContainer: RTheme.Theme.errorContainer
        property color m3onErrorContainer: RTheme.Theme.onErrorContainer
        property color m3primaryFixed: RTheme.Theme.primaryContainer
        property color m3primaryFixedDim: RTheme.Theme.primary
        property color m3onPrimaryFixed: RTheme.Theme.onPrimaryContainer
        property color m3onPrimaryFixedVariant: RTheme.Theme.onPrimaryContainer
        property color m3secondaryFixed: RTheme.Theme.secondaryContainer
        property color m3secondaryFixedDim: RTheme.Theme.secondary
        property color m3onSecondaryFixed: RTheme.Theme.onSecondaryContainer
        property color m3onSecondaryFixedVariant: RTheme.Theme.onSecondaryContainer
        property color m3tertiaryFixed: RTheme.Theme.tertiaryContainer
        property color m3tertiaryFixedDim: RTheme.Theme.tertiary
        property color m3onTertiaryFixed: RTheme.Theme.onTertiaryContainer
        property color m3onTertiaryFixedVariant: RTheme.Theme.onTertiaryContainer
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
    }

    // The two border/blur/gap tokens the reference's compositor writers read are
    // kept as plain values (no compositor write): Ryoku owns the compositor's
    // look through its own config, and the editor only needs the numbers.
    property bool borderless: false
    property int borderWidth: 2

    colors: QtObject {
        property color colSubtext: m3colors.m3outline
        // Layer 0
        property color colLayer0Base: ColorUtils.mix(m3colors.m3background, m3colors.m3primary, Config.options.appearance.extraBackgroundTint ? 0.99 : 1)
        property color colLayer0: ColorUtils.transparentize(colLayer0Base, root.backgroundTransparency)
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.9, root.contentTransparency))
        property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.8, root.contentTransparency))
        property color colLayer0Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        // Layer 1
        property color colLayer1Base: m3colors.m3surfaceContainerLow
        property color colLayer1: ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency)
        property color colOnLayer1: m3colors.m3onSurfaceVariant
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45)
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency)
        // Layer 2
        property color colLayer2Base: m3colors.m3surfaceContainer
        property color colLayer2: ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency)
        property color colLayer2Disabled: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency)
        property color colOnLayer2: m3colors.m3onSurface
        property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4)
        // Layer 3
        property color colLayer3Base: m3colors.m3surfaceContainerHigh
        property color colLayer3: ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency)
        property color colOnLayer3: m3colors.m3onSurface
        // Layer 4
        property color colLayer4Base: m3colors.m3surfaceContainerHighest
        property color colLayer4: ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency)
        property color colOnLayer4: m3colors.m3onSurface
        // Primary
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryHover: ColorUtils.mix(colors.colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: ColorUtils.mix(colors.colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.8)
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        // Secondary
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryHover: ColorUtils.mix(m3colors.m3secondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: ColorUtils.mix(m3colors.m3secondary, colLayer1Active, 0.4)
        property color colOnSecondary: m3colors.m3onSecondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.54)
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        // Tertiary
        property color colTertiary: m3colors.m3tertiary
        property color colTertiaryHover: ColorUtils.mix(m3colors.m3tertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: ColorUtils.mix(m3colors.m3tertiary, colLayer1Active, 0.4)
        property color colTertiaryContainer: m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: ColorUtils.mix(m3colors.m3tertiaryContainer, m3colors.m3onTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: ColorUtils.mix(m3colors.m3tertiaryContainer, colLayer1Active, 0.54)
        property color colOnTertiary: m3colors.m3onTertiary
        property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer
        // Surface
        property color colBackgroundSurfaceContainer: ColorUtils.transparentize(m3colors.m3surfaceContainer, root.backgroundTransparency)
        property color colBackgroundSurfaceContainerAccent: ColorUtils.transparentize(
            ColorUtils.mix(m3colors.m3surfaceContainer, m3colors.m3primaryContainer,
                           1.0 - (Config.options.search.appearance.accentPanels ? Config.options.search.appearance.accentStrength : 0.0)),
            root.backgroundTransparency)
        property color colSurfaceContainerLow: ColorUtils.solveOverlayColor(m3colors.m3background, m3colors.m3surfaceContainerLow, 1 - root.contentTransparency)
        property color colSurfaceContainer: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerLow, m3colors.m3surfaceContainer, 1 - root.contentTransparency)
        property color colSurfaceContainerHigh: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainer, m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency)
        property color colSurfaceContainerHighest: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerHigh, m3colors.m3surfaceContainerHighest, 1 - root.contentTransparency)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.85)
        property color colOnSurface: m3colors.m3onSurface
        property color colOnSurfaceVariant: m3colors.m3onSurfaceVariant
        // Misc
        property color colTooltip: m3colors.m3surfaceContainerHigh
        property color colOnTooltip: m3colors.m3onSurface
        property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: m3colors.m3outline
        property color colOutlineVariant: m3colors.m3outlineVariant
        property color colError: m3colors.m3error
        property color colErrorHover: ColorUtils.mix(m3colors.m3error, colLayer1Hover, 0.85)
        property color colErrorActive: ColorUtils.mix(m3colors.m3error, colLayer1Active, 0.7)
        property color colOnError: m3colors.m3onError
        property color colErrorContainer: m3colors.m3errorContainer
        property color colErrorContainerHover: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.90)
        property color colErrorContainerActive: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.70)
        property color colOnErrorContainer: m3colors.m3onErrorContainer
    }

    rounding: QtObject {
        property real scale: {
            let rv = Config.options.appearance.roundingValue;
            if (rv > 0)
                return rv / 24.0;
            if (rv < 0)
                return 1.0; // not yet migrated, default to large
            return 0.0; // roundingValue === 0 → sharp
        }

        property int unsharpen: Math.round(2 * scale)
        property int unsharpenmore: Math.round(6 * scale)
        property int verysmall: Math.round(8 * scale)
        property int small: Math.round(12 * scale)
        property int normal: Math.round(17 * scale)
        property int large: Math.round(24 * scale)
        property int verylarge: Math.round(32 * scale)
        property int full: scale === 0 ? 0 : 9999
        property int screenRounding: {
            if (scale === 0)
                return 0;

            // Harmonious concentric screen rounding (UI/UX concentric radius rule):
            // Outer Screen Radius = Bar Radius + Margins between bar and screen edge
            if (BarInteraction.cornerStyle === 1 || BarInteraction.cornerStyle === 3 || BarInteraction.cornerStyle === 0) {
                const isVertical = BarPlacement.vertical;
                const barDim = isVertical
                    ? (root.sizes?.baseVerticalBarWidth ?? Config.options?.bar?.sizes?.width ?? 44)
                    : (root.sizes?.baseBarHeight ?? Config.options?.bar?.sizes?.height ?? 40);
                const barRadius = Math.round(barDim / 2);
                const barMargin = (BarInteraction.cornerStyle === 1)
                    ? (root.sizes?.hyprlandGapsOut ?? Config.options?.appearance?.gapsOut ?? 5)
                    : 0;
                return barRadius + barMargin;
            }

            return large;
        }
        property int windowRounding: root.windowRounding
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: Config.options.appearance.fonts.main
            property string numbers: Config.options.appearance.fonts.numbers
            property string title: Config.options.appearance.fonts.title
            property string iconMaterial: "Material Symbols Rounded"
            property string iconNerd: Config.options.appearance.fonts.iconNerd
            property string monospace: Config.options.appearance.fonts.monospace
            property string reading: Config.options.appearance.fonts.reading
            property string expressive: Config.options.appearance.fonts.expressive
        }
        property QtObject variableAxes: QtObject {
            property var main: ({
                    "wght": 450,
                    "wdth": 100,
                    "ROND": Config.options.appearance.fonts.roundnessFull ? 100 : 0
                })
            property var numbers: ({
                    "wght": 450,
                    "ROND": Config.options.appearance.fonts.roundnessFull ? 100 : 0
                })
            property var title: ({ // Slightly bold weight for title
                    "wght": 550 // Weight (Lowered to compensate for increased grade)
                    ,
                    "ROND": Config.options.appearance.fonts.roundnessFull ? 100 : 0
                })
            property var rounded: ({
                    "wght": 450,
                    "wdth": 100,
                    "ROND": 100
                })
            property var titleRounded: ({
                    "wght": 550,
                    "ROND": 100
                })
        }
        property QtObject pixelSize: QtObject {
            property int smallest: 10
            property int smaller: 12
            property int smallie: 13
            property int small: 15
            property int normal: 16
            property int large: 17
            property int larger: 19
            property int huge: 22
            property int hugeass: 23
            property int title: huge
        }
    }

    // Global animation speed multiplier — driven by Config.options.appearance.animationMultiplier
    readonly property real animMultiplier: Config.options?.appearance?.animationMultiplier ?? 1.0
    // Below this the shell skips animations outright rather than running them absurdly fast (the
    // sidebars' own convention); Edit Mode reads it as one flag instead of repeating the test.
    readonly property bool reducedMotion: root.animMultiplier <= 0.25

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // Default, 350ms
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // Default, 500ms
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // Default, 650ms
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // Default, 200ms
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: Math.round(animationCurves.expressiveDefaultSpatialDuration * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveSmall: QtObject {
            property int duration: Math.round(animationCurves.expressiveFastSpatialDuration * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSmall.duration
                    easing.type: root.animation.elementMoveSmall.type
                    easing.bezierCurve: root.animation.elementMoveSmall.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: Math.round(400 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveExit: QtObject {
            property int duration: Math.round(200 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }

        // Context menus and popups opening under the cursor: the WINDOW the
        // cascade lives in. The reveal scalar runs LINEAR and every slice
        // eases its own arrival — the sidebar's rhythm (StaggeredEntrance:
        // 26 ms stagger, ~400 ms fade per row). Two clocks, strictly
        // separate: the card body + plate land in the first ~22% (the menu
        // pops in and STANDS STILL), and the rows wave in inside it from
        // there to 100%. One global curve over the scalar was the blink
        // (emphasizedDecel is ~85% done at 30% of its time — every row
        // flashed at once); a body that grows across the whole window makes
        // the menu itself perform as a cascade item and hides the rows'
        // wave behind its drift. The exit stays short and flat: a menu
        // waving away, not a page leaving.
        // Duration only: the scalar runs Linear and the slices carry the
        // easing, so there is no curve to hand out. Kept short: 640 ms read
        // well once, then made a menu opened many times a day feel stuck.
        property QtObject popupEnter: QtObject {
            property int duration: Math.round(280 * root.animMultiplier)
        }

        property QtObject popupExit: QtObject {
            property int duration: Math.round(150 * root.animMultiplier)
        }

        property QtObject elementMoveSlow: QtObject {
            property int duration: Math.round(animationCurves.expressiveEffectsDuration * 2.5 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMoveSlow.duration
                    easing.type: root.animation.elementMoveSlow.type
                    easing.bezierCurve: root.animation.elementMoveSlow.bezierCurve
                }
            }
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveSlow.duration
                    easing.type: root.animation.elementMoveSlow.type
                    easing.bezierCurve: root.animation.elementMoveSlow.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: Math.round(animationCurves.expressiveEffectsDuration * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
        }

        /**
         * A selection that follows the keyboard (Alt+Tab's highlight). Shorter than
         * elementMoveFast so a held key reads as one motion, and deliberately without
         * `alwaysRunToEnd`: a Behavior retargets from wherever the value is, and running
         * each leg to its end would queue every press behind the last one.
         */
        property QtObject elementMoveSnap: QtObject {
            property int duration: Math.round(150 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSnap.duration
                    easing.type: root.animation.elementMoveSnap.type
                    easing.bezierCurve: root.animation.elementMoveSnap.bezierCurve
                }
            }
        }

        property QtObject elementResize: QtObject {
            property int duration: Math.round(300 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasized
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementResize.duration
                    easing.type: root.animation.elementResize.type
                    easing.bezierCurve: root.animation.elementResize.bezierCurve
                }
            }
        }

        // Every size change that happens *inside* the bar reads from here: the
        // widgets and the island backgrounds that wrap them have to reach their
        // new size at the same instant, and they only do that if they share one
        // duration and one curve. A widget that animates its own implicitWidth
        // faster than the island around it makes the island look like it is
        // chasing the content (and vice versa).
        // 280ms is the duration the Dynamic Island already used; the fast
        // spatial curve keeps its slight overshoot without the OutBack tail.
        property QtObject barResize: QtObject {
            property int duration: Math.round(280 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.barResize.duration
                    easing.type: root.animation.barResize.type
                    easing.bezierCurve: root.animation.barResize.bezierCurve
                }
            }
        }

        // Dashboard indicators use a staged transition: the slot changes size
        // before/after the icon pop. Keep these slower and softer than the
        // global barResize clock without slowing every other responsive widget.
        property QtObject dashboardIndicatorResize: QtObject {
            property int duration: Math.round(420 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.standard
        }

        property QtObject dashboardIndicatorPop: QtObject {
            property int enterDuration: Math.round(360 * root.animMultiplier)
            property int exitDuration: Math.round(280 * root.animMultiplier)
            property int cueDelay: Math.round(90 * root.animMultiplier)
            property int exitHoldDuration: Math.round(220 * root.animMultiplier)
            property int enterType: Easing.OutBack
            property real enterOvershoot: 1.18
            property int exitType: Easing.BezierSpline
            property list<real> exitCurve: animationCurves.emphasizedAccel
        }

        // The bar and the wrapped frame leaving the screen together: a
        // fullscreen window taking over, media mode, or a placement swap. The
        // exit accelerates away and the entrance decelerates in, so a swap does
        // not read as two halves of the same easing.
        property QtObject shellEdgeSlide: QtObject {
            property int exitDuration: Math.round(260 * root.animMultiplier)
            property int enterDuration: Math.round(420 * root.animMultiplier)
            property int swapHold: Math.round(90 * root.animMultiplier)
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.shellEdgeSlide.enterDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.animationCurves.emphasized
                }
            }
        }

        // Sidebars sliding in and out, and the wallpaper parallax that follows them.
        // No overshoot anywhere: expressive spatial curves kick off at ~3x linear speed and
        // bounce the wallpaper past its rest, which reads as hard. The sidebar enters on M3
        // emphasized (gentle start, long settle) and leaves accelerating, like end4's layer
        // animations; the wallpaper runs its own, longer emphasized clock in both directions,
        // since an accelerating exit is invisible for a sidebar but stops the wallpaper dead.
        property QtObject sidebarSlide: QtObject {
            property int enterDuration: Math.round(500 * root.animMultiplier)
            property int exitDuration: Math.round(500 * root.animMultiplier)
            property list<real> enterCurve: root.animationCurves.emphasized
            property list<real> exitCurve: root.animationCurves.emphasized
            property int parallaxDuration: Math.round(700 * root.animMultiplier)
            property list<real> parallaxCurve: root.animationCurves.emphasized
        }

        property QtObject clickBounce: QtObject {
            property int duration: Math.round(400 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 850
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.clickBounce.duration
                    easing.type: root.animation.clickBounce.type
                    easing.bezierCurve: root.animation.clickBounce.bezierCurve
                }
            }
        }

        // One lens shared by every dock icon. pointerLag smooths the pointer the
        // lens follows (critically damped, never overshoots); strengthDuration
        // is how long the lens takes to grow in on enter. Past the window edge
        // there are no pointer samples, so the exit is timed: exitDuration, on
        // a curve that starts and ends gently.
        property QtObject dockMagnificationScale: QtObject {
            property QtObject fast: QtObject {
                property real pointerLag: 0
                property int strengthDuration: Math.round(90 * root.animMultiplier)
                property int exitDuration: Math.round(220 * root.animMultiplier)
            }
            property QtObject balanced: QtObject {
                property real pointerLag: 28
                property int strengthDuration: Math.round(150 * root.animMultiplier)
                property int exitDuration: Math.round(280 * root.animMultiplier)
            }
            property QtObject smooth: QtObject {
                property real pointerLag: 60
                property int strengthDuration: Math.round(220 * root.animMultiplier)
                property int exitDuration: Math.round(340 * root.animMultiplier)
            }
            property int hoverExitGrace: 90
        }

        // Retained for discrete magnification feedback in secondary popups.
        property QtObject dockMagnification: QtObject {
            property int duration: Math.round(220 * root.animMultiplier)
            property int type: Easing.OutBack
            property real overshoot: 1.35
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.dockMagnification.duration
                    easing.type: root.animation.dockMagnification.type
                    easing.overshoot: root.animation.dockMagnification.overshoot
                }
            }
        }

        property QtObject scroll: QtObject {
            property int duration: Math.round(200 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: root.animationCurves.standardDecel
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.scroll.duration
                    easing.type: root.animation.scroll.type
                    easing.bezierCurve: root.animation.scroll.bezierCurve
                }
            }
        }

        property QtObject menuDecel: QtObject {
            property int duration: Math.round(350 * root.animMultiplier)
            property int type: Easing.OutExpo
        }
    }

    sizes: QtObject {
        // A finger needs a bigger target than a cursor. A touch-first family raises the
        // bar's FLOOR rather than replacing the value: a bar the user configured taller
        // than this stays taller, and the stored preference is never rewritten.
        //
        // This is deliberately here and not a per-window scale. Scaling the bar window was
        // tried and reverted — every widget inside sizes itself off barHeight, so the window
        // grew while the content did not, and backgrounds, hit targets and popup anchors all
        // measured against a bar that was not the one on screen.
        // Material's minimum touch target, and the Pixel Tablet's status bar height.
        property real minimumTouchTarget: 48

        // Snap step for desktop widgets and icons on the wallpaper canvas.
        //
        // Ten pixels is a fine-positioning aid for a mouse: it takes the jitter out of a
        // drag without really constraining where something lands. A finger cannot place
        // anything that precisely, and a home screen is supposed to look laid out on a
        // grid rather than merely tidy — so a touch-first family snaps to a step coarse
        // enough to read as cells, the way Android's home screen does.
        // What this family wants when nothing is configured. Kept separate from the
        // resolved value below so a settings control can offer it as the fallback without
        // reading a property that depends on the very key it writes — that was a binding
        // loop, and the page it was on rendered empty.
        readonly property real familyWidgetGridStep: PanelFamily.touchFirst ? 40 : 10

        property real widgetGridStep: {
            const configured = Config.options?.background?.widgets?.gridStep ?? 0;
            return configured > 0 ? configured : root.sizes.familyWidgetGridStep;
        }
        property real baseBarHeight: PanelFamily.touchFirst
            ? Math.max(root.sizes.minimumTouchTarget, Config.options.bar.sizes.height)
            : Config.options.bar.sizes.height
        property real barHeight: BarInteraction.cornerStyle === 1 ? (baseBarHeight + root.sizes.hyprlandGapsOut * 2) : baseBarHeight
        // Bar widgets were drawn against a 40px horizontal bar and a 44px vertical one, and
        // most of them size their outer plate off the bar while leaving the glyph inside at
        // the number it was drawn with. On a touch-first family the bar is taller than that
        // by definition, so those widgets became big plates around small icons. Scaling the
        // insides by the same ratio is a no-op at the default and correct everywhere else.
        readonly property real barReferenceHeight: 40
        readonly property real barReferenceWidth: 44
        readonly property real barContentScale: root.sizes.baseBarHeight / root.sizes.barReferenceHeight
        readonly property real verticalBarContentScale: root.sizes.verticalBarWidth / root.sizes.barReferenceWidth

        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real elevationMargin: 10
        // The M3 toolbar's height: one number the toolbar and the band Edit Mode reserves for it
        // both read.
        property real toolbarHeight: 46
        // Edit Mode's viewport: the gap between the shrunk desktop and what surrounds it, the
        // tighter gap between the chrome and the usable area's edge, and the width the widget
        // drawer opens into (reserved from the first frame so the desktop never resizes mid-edit).
        property real editModeMargin: 24
        property real editModeEdgeMargin: 12
        property real editModeDrawerWidth: 380
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real mediaControlsWidth: 440
        property real mediaControlsHeight: 160
        property real notificationPopupWidth: 410
        property real osdWidth: 200
        property real searchWidthCollapsed: 350
        property real searchWidth: 500
        property real sidebarWidth: 460
        property real sidebarWidthExtended: 750
        property real baseVerticalBarWidth: Config.options.bar.sizes.width
        property real verticalBarWidth: baseVerticalBarWidth
        property real verticalBarWindowWidth: BarInteraction.cornerStyle === 1 ? (baseVerticalBarWidth + root.sizes.hyprlandGapsOut * 2) : baseVerticalBarWidth
        property real wallpaperSelectorWidth: 1200
        property real wallpaperSelectorHeight: 690
        property real wallpaperSelectorSidebarWidth: 180
        property real wallpaperSelectorSidebarButtonHeight: 48
        property real wallpaperSelectorSidebarHorizontalPadding: 6
        property real wallpaperSelectorSidebarButtonSpacing: 3
        property real wallpaperSelectorSidebarGroupSpacing: 10
        property real wallpaperSelectorSearchWidth: 300
        property real wallpaperSelectorSortDialogWidth: 280
        property real wallpaperSelectorItemMargins: 8
        property real wallpaperSelectorItemPadding: 6
        property int dockButtonSize: Math.round((Config.options?.dock.height ?? 60) * 0.85)
    }

    syntaxHighlightingTheme: root.m3colors.darkmode ? "Monokai" : "ayu Light"
}
