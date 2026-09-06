pragma Singleton
import QtQuick

// The wall-ui's shape/type/motion source, retuned to Ryoku's design language
// (see ryoku/ui/Singletons/Tokens.qml). Property names are unchanged so every
// component keeps reading one source; only the values move onto Ryoku's:
// Fraunces display, Space Grotesk body, SpaceMono mono, Ryoku's radius/spacing
// scale and the sun accent. Colour lives in Colors.qml.
QtObject {
    id: style

    // ── type: Ryoku's families ───────────────────────────────────────────
    readonly property string fontFamily: "Space Grotesk"          // body / ui
    readonly property string fontFamilyHeading: "Fraunces"         // display
    readonly property string fontFamilyMono: "SpaceMono Nerd Font"
    readonly property string fontFamilyCode: "SpaceMono Nerd Font"
    readonly property string fontFamilyJp: "Noto Sans CJK JP"      // kanji seals
    readonly property string fontFamilyIcons: "Material Design Icons"
    readonly property string fontFamilyNerdIcons: "Symbols Nerd Font"

    readonly property int fontTiny: 9
    readonly property int fontCaption: 11
    readonly property int fontBody: 13
    readonly property int fontBodyLarge: 14
    readonly property int fontSubtitle: 15
    readonly property int fontTitle: 17
    readonly property int fontTitleLarge: 20
    readonly property int fontHeadline: 26
    readonly property int fontDisplay: 34
    readonly property int fontDisplayLarge: 46
    readonly property int fontClock: 200
    readonly property int fontClockDate: 120

    // ── shape: Ryoku is tight (base radius 6), softened one step up the scale ─
    readonly property int radiusTiny: 2
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 6
    readonly property int radiusLarge: 10
    readonly property int radiusXLarge: 14
    readonly property int radiusRound: 18
    readonly property int radiusCircle: 40

    // ── space: Ryoku's 4/8/12/16/24 scale ────────────────────────────────
    readonly property int spacingTiny: 2
    readonly property int spacingSmall: 4
    readonly property int spacingMedium: 8
    readonly property int spacingLarge: 12
    readonly property int spacingXLarge: 16
    readonly property int spacingXXLarge: 24

    // ── motion: Ryoku timings ────────────────────────────────────────────
    readonly property int animVeryFast: 90
    readonly property int animFast: 150
    readonly property int animNormal: 200
    readonly property int animEnter: 210
    readonly property int animMedium: 260
    readonly property int animExpand: 300
    readonly property int animSlow: 400
    readonly property int animSpin: 1000

    readonly property int tooltipDelay: 500

    readonly property color fallbackAccent: "#e2342a"   // Ryoku sun default
    readonly property int borderThin: 1
    readonly property int borderMedium: 2
    readonly property int borderThick: 3
    readonly property real opacityDim: 0.35
    readonly property real opacityMuted: 0.5
    readonly property real opacitySubtle: 0.6
}
