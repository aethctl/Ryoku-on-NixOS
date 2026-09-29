pragma Singleton

import QtQuick
import inir.modules.common
import inir.modules.common.functions
import Ryoku.Ui.Singletons

QtObject {
    id: root

    readonly property var options: Config.options?.iris ?? ({})
    readonly property var appearance: root.options?.appearance ?? ({})

    // Two frontends for the whole iRiS family: "inir" keeps the upstream look
    // byte-for-byte (ready to cherry-pick upstream into), "ryoku" resolves every
    // token to Ryoku's paper-and-ink language. Slices bind to this flag; the
    // structural differences (a monochrome glyph instead of a coloured squircle
    // tile) switch on it inside their component.
    readonly property bool ryokuFrontend: (Config.options?.iris?.appearance?.frontend ?? "ryoku") === "ryoku"

    readonly property bool island: true

    // --- Recompose: one clock for structural change -------------------------
    // An option that changes what a surface is *made of* (the Island's
    // composition, its clock, its bubbles, a panel's sections) is never applied
    // while the shapes are visible: every such value is published here, latched,
    // and swapped at the bottom of one shared dip. Consumers read the latched
    // value and multiply their content by `recompose`, so a recomposition is one
    // transition for the whole family instead of one animation per part racing
    // the others. Geometry still springs across the swap: the silhouette is
    // continuous, its contents are replaced (DESIGN §0.4).
    readonly property var structuralPaths: ["bar.composition", "bar.clockStyle", "bar.trailing",
        "bar.auxiliary", "bar.pieces", "bar.fullStart", "bar.fullCenter", "bar.fullEnd", "bar.navItems", "bar.desktopBlocks", "bar.mediaBlocks",
        "controlCenter.sections", "controlCenter.controls"]
    function readPath(path: string): var {
        let node = root.options
        for (const part of path.split(".")) {
            if (node === undefined || node === null) return undefined
            node = node[part]
        }
        return node
    }
    readonly property var structuralSource: {
        const out = {}
        for (const path of root.structuralPaths) {
            const value = root.readPath(path)
            out[path] = value === undefined ? null : (Array.isArray(value) ? Array.from(value) : value)
        }
        return out
    }
    readonly property string structuralKey: JSON.stringify(root.structuralSource)
    property var structure: root.structuralSource
    property real recomposeValue: 1
    readonly property real recompose: root.recomposeValue
    readonly property bool recomposing: root.recomposeValue < 0.999
    function structuralValue(path: string, fallback: var): var {
        const value = root.structure?.[path]
        return value === undefined || value === null ? fallback : value
    }
    onStructuralKeyChanged: {
        if (!root.motionEnabled) { root.structure = root.structuralSource; return }
        root.recomposeIn.stop()
        root.recomposeOut.restart()
    }
    readonly property NumberAnimation recomposeOut: NumberAnimation {
        target: root; property: "recomposeValue"; to: 0
        duration: root.duration(80); easing.type: Easing.OutQuad
        onFinished: {
            root.structure = root.structuralSource
            root.recomposeIn.restart()
        }
    }
    readonly property NumberAnimation recomposeIn: NumberAnimation {
        target: root; property: "recomposeValue"; to: 1
        duration: root.duration(200); easing.type: Easing.BezierSpline; easing.bezierCurve: root.emergeCurve
    }

    readonly property bool cluster: String(root.structuralValue("bar.composition", "unified")) === "cluster"

    readonly property real density: Math.max(0.8, Math.min(1.35, Number(root.appearance?.density ?? 1.0)))
    // Density scales geometry only; type has its own scale.
    readonly property real typeScale: Math.max(0.75, Math.min(1.6, (Appearance.fontSizeScale ?? 1.0) * root.tweak("text", 0.85, 1.25)))

    readonly property var theme: root.appearance?.theme ?? ({})
    function hueOf(name: string, fallback: int): real {
        const value = Number(root.theme?.[name] ?? fallback)
        return (((isNaN(value) ? fallback : value) % 360) + 360) % 360 / 360
    }
    function tweak(name: string, low: real, high: real): real {
        const value = Number(root.theme?.[name] ?? 100)
        return Math.max(low, Math.min(high, (isNaN(value) ? 100 : value) / 100 * IrisMood.factor(name)))
    }
    function surfaceRadius(id: string, fallback: int): int {
        const radius = Number(root.appearance?.surfaces?.[id]?.radius ?? 0)
        return radius > 0 ? Math.round(radius * root.density) : fallback
    }
    function surfaceLight(id: string, light: color): color {
        const mode = String(root.appearance?.surfaces?.[id]?.light ?? "inherit")
        return mode === "off" ? Qt.color("transparent") : mode === "wallpaper" ? root.wallpaperLight : light
    }
    readonly property int radius: Math.round(Math.max(16, Math.min(40, Number(root.appearance?.expandedRadius ?? 28))) * root.density)
    readonly property int radiusSmall: Math.max(4, Math.round(root.radius * 0.58))
    readonly property int radiusTiny: Math.max(3, Math.round(root.radius * 0.36))
    readonly property int gap: Math.max(4, Math.round(8 * root.density))
    readonly property int gapLarge: Math.max(8, Math.round(14 * root.density))
    readonly property int spaceSmall: Math.max(4, Math.round(6 * root.density))
    readonly property int spaceMedium: Math.max(6, Math.round(10 * root.density))
    readonly property int spaceLarge: Math.max(10, Math.round(16 * root.density))

    readonly property var presets: ({
        iris: { fill: 1.0, shape: 1.0, textStrong: 0.82, textSecondary: 0.62, textTertiary: 0.40,
            subtext: "#aeaeb2", muted: "#8e8e93", hairline: "#262628", hairlineStrong: "#48484a" },
        soft: { fill: 0.78, shape: 1.22, textStrong: 0.78, textSecondary: 0.58, textTertiary: 0.36,
            subtext: "#a1a1a6", muted: "#838388", hairline: "#1f1f21", hairlineStrong: "#3a3a3c" },
        crisp: { fill: 1.12, shape: 0.7, textStrong: 0.86, textSecondary: 0.66, textTertiary: 0.42,
            subtext: "#b4b4b9", muted: "#929297", hairline: "#2c2c2e", hairlineStrong: "#545456" },
        round: { fill: 0.9, shape: 1.5, textStrong: 0.8, textSecondary: 0.6, textTertiary: 0.38,
            subtext: "#a8a8ad", muted: "#8a8a8f", hairline: "#222224", hairlineStrong: "#404042" },
        angular: { fill: 1.08, shape: 0.42, textStrong: 0.86, textSecondary: 0.64, textTertiary: 0.42,
            subtext: "#b0b0b5", muted: "#909095", hairline: "#2a2a2c", hairlineStrong: "#505052" },
        contrast: { fill: 1.6, shape: 1.0, textStrong: 0.94, textSecondary: 0.8, textTertiary: 0.6,
            subtext: "#d1d1d6", muted: "#aeaeb2", hairline: "#3a3a3c", hairlineStrong: "#6c6c70" }
    })
    readonly property string presetName: root.presets[root.appearance?.preset ?? ""] ? root.appearance.preset : "iris"
    readonly property var preset: root.presets[root.presetName]

    readonly property string fontMain: {
        const configured = String(root.appearance?.fontFamily ?? "")
        return configured.length > 0 ? configured : (root.ryokuFrontend ? Tokens.ui : "Noto Sans")
    }
    readonly property string fontTitle: {
        const configured = String(root.appearance?.titleFontFamily ?? "")
        return configured.length > 0 ? configured : (root.ryokuFrontend ? Tokens.display : "Readex Pro")
    }
    readonly property int figureWeight: ({ light: Font.Light, regular: Font.Normal })[root.appearance?.figureWeight ?? "bold"] ?? Font.Bold
    readonly property string fontNumbers: {
        const configured = String(root.appearance?.numbersFontFamily ?? "")
        return configured.length > 0 ? configured : (root.ryokuFrontend ? Tokens.mono : "Rubik")
    }

    readonly property color canvas: root.ryokuFrontend ? Tokens.paper : Appearance.colors.colLayer0Base
    readonly property var materials: ({ black: "#000000", graphite: "#141416", midnight: "#0a0d17" })
    function materialOf(seed, fallback): color {
        const c = Qt.color(seed)
        if (!c.valid || c.hslHue < 0 || c.hslSaturation < 0.08) return fallback
        return Qt.hsla(c.hslHue, Math.max(0.28, Math.min(0.55, c.hslSaturation)), 0.09, 1)
    }
    readonly property color wallpaperMaterial: root.materialOf(Appearance.wallpaperDominantColor,
        root.materialOf(Appearance.colors.colPrimary, root.materials.graphite))
    readonly property color themeMaterial: {
        const background = Qt.color(Appearance.m3colors.m3background)
        return background.hslLightness <= 0.2 ? Qt.rgba(background.r, background.g, background.b, 1)
            : root.materialOf(Appearance.colors.colPrimary, root.materials.graphite)
    }
    function materialSwatch(name: string): color {
        if (name === "theme") return root.themeMaterial
        return name === "wallpaper" ? root.wallpaperMaterial : (root.materials[name] ?? root.materials.black)
    }
    readonly property color surfaceOpaque: root.ryokuFrontend ? Tokens.paper : root.materialSwatch(root.theme?.surface ?? "black")
    readonly property bool plainBlack: (root.theme?.surface ?? "black") === "black"
    function raise(base: color, amount: real): color {
        if (base.hslHue < 0 || base.hslSaturation < 0.05) return ColorUtils.mix(root.text, base, amount)
        return Qt.hsla(base.hslHue, Math.min(1, base.hslSaturation * 0.9), Math.min(1, base.hslLightness + amount * 0.62), 1)
    }
    readonly property color surfaceHighOpaque: root.ryokuFrontend ? Tokens.paperLift : (root.plainBlack ? "#1c1c1e" : root.raise(root.surfaceOpaque, 0.1))
    readonly property color surfaceHighestOpaque: root.ryokuFrontend ? ColorUtils.mix(Tokens.paper, Tokens.ink, 0.08) : (root.plainBlack ? "#2c2c2e" : root.raise(root.surfaceOpaque, 0.17))
    readonly property real tintAmount: root.ryokuFrontend ? 0 : Math.max(0, Math.min(1, Number(root.appearance?.tint ?? 0) / 100))
    readonly property color tintSeed: root.legibleAccent(Appearance.wallpaperDominantColor, root.accent)
    function tinted(base: color, strength: real): color {
        return root.tintAmount <= 0 ? base : ColorUtils.mix(base, root.tintSeed, 1 - strength * root.tintAmount)
    }
    readonly property color surface: root.surfaceOpaque
    readonly property color bodySurface: root.surfaceOpaque

    readonly property var glassOptions: root.appearance?.glass ?? ({})
    readonly property string glassRequested: ["wallpaper", "compositor"].includes(String(root.glassOptions?.mode ?? ""))
        ? root.glassOptions.mode : "off"
    readonly property bool glassy: root.glassRequested !== "off" && Appearance.effectsEnabled
    readonly property bool glassCompositor: root.glassy && root.glassRequested === "compositor" && Appearance.compositorBlurActive
    readonly property bool glassWallpaper: root.glassy && !root.glassCompositor
    readonly property real glassBlurAmount: Math.max(0, Math.min(1, Number(root.glassOptions?.blur ?? 100) / 100))
    readonly property real glassTint: {
        const chosen = Math.max(0.12, Math.min(0.96, Number(root.glassOptions?.tint ?? 58) / 100))
        const needed = IrisMood.sampled ? root.legibleVeil("glass", IrisMood.luminance, IrisMood.contrast * 0.5, 1) : 0
        return Math.max(chosen, Math.min(0.9, needed))
    }
    readonly property color bodyTint: root.glassy ? ColorUtils.applyAlpha(root.surfaceOpaque, root.glassTint) : root.bodySurface
    readonly property color bodyFill: root.glassy ? Qt.color("transparent") : root.bodySurface
    readonly property color bodyScrim: root.bodyTint
    // iris-literal: a clipping chassis stops painting its children when fully transparent
    readonly property color bodyClip: root.glassy ? Qt.rgba(0, 0, 0, 0.004) : root.bodySurface
    readonly property color placeSurface: root.glassy ? ColorUtils.applyAlpha(root.surfaceOpaque, root.glassTint) : root.surface
    readonly property real glassLip: 0
    readonly property real wallpaperVeil: IrisMood.sampled
        ? Math.max(0.22, Math.min(0.72, root.legibleVeil("glass", IrisMood.luminance, IrisMood.contrast * 0.5, 0.6))) : 0.22
    readonly property color surfaceHigh: root.glassy ? ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.07))
        : root.tinted(root.surfaceHighOpaque, 0.16)
    readonly property color surfaceHighest: root.glassy ? ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.12))
        : root.tinted(root.surfaceHighestOpaque, 0.2)
    readonly property color field: root.surfaceHighestOpaque
    readonly property color text: root.ryokuFrontend ? Tokens.ink : "#f5f5f7"
    // Secondary ink carries a whisper of the accent, so quiet text belongs to the theme instead of a stock grey.
    readonly property color quietInk: root.ryokuFrontend ? Tokens.ink : ColorUtils.mix(root.accent, root.text, 0.14)
    readonly property color subtext: root.ryokuFrontend ? Tokens.inkDim : ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.78, root.preset.textStrong - 0.02), 0.9))
    readonly property color muted: root.ryokuFrontend ? Tokens.inkMuted : ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.64, root.preset.textSecondary + 0.04), 0.8))
    readonly property color label: root.ryokuFrontend ? Tokens.inkDim : ColorUtils.mix(root.accent, root.text, 0.62)
    function legibleAccent(seed, fallback): color {
        const c = Qt.color(seed)
        if (!c.valid || c.hslHue < 0 || c.hslSaturation < 0.12) return fallback
        return Qt.hsla(c.hslHue, Math.max(0.42, Math.min(0.8, c.hslSaturation)),
            Math.max(0.72, Math.min(0.82, c.hslLightness)), 1)
    }
    readonly property color themeAccent: root.ryokuFrontend ? Tokens.ink : root.legibleAccent(Appearance.colors.colPrimary, "#a8c7fa")
    readonly property var accents: ({ blue: "#a8c7fa", mint: "#8de0bd", rose: "#ffb2c4", lilac: "#d2baff" })
    readonly property var highlights: ({ orange: "#ff9f0a", yellow: "#ffd60a", red: "#ff6961", pink: "#ff6482", green: "#30d158" })
    // Ryoku's wallpaper accent is the native matugen primary (Tokens.sun, resolved
    // from ~/.cache/ryoku/colors.json); iNiR lifts the dominant wallpaper colour.
    readonly property color accentWallpaper: root.ryokuFrontend ? Tokens.sun
        : root.legibleAccent(Appearance.wallpaperDominantColor, root.themeAccent)
    readonly property color accent: {
        if (root.ryokuFrontend) {
            // Paper-and-ink stays monochrome by default (Ink); the wallpaper's
            // matugen primary or a chosen hue is the opt-in colour.
            const pick = root.appearance?.accent ?? "ink"
            if (pick === "wallpaper") return root.accentWallpaper
            if (pick === "custom") return Qt.hsla(root.hueOf("accentHue", 212), 0.62, Tokens.light ? 0.45 : 0.72, 1)
            return Tokens.ink
        }
        const choice = root.appearance?.accent ?? "blue"
        if (choice === "theme") return root.themeAccent
        if (choice === "wallpaper") return root.legibleAccent(Appearance.wallpaperDominantColor, root.themeAccent)
        if (choice === "custom") return Qt.hsla(root.hueOf("accentHue", 212), 0.7, 0.78, 1)
        return root.accents[choice] ?? root.accents.blue
    }
    readonly property color onAccent: root.ryokuFrontend
        ? (root.accent.hslLightness > 0.62 ? Tokens.inkOnBone : Tokens.bone)
        : Qt.color("#101318")
    readonly property color accentContainer: root.ryokuFrontend ? Tokens.bone : ColorUtils.mix(root.surface, root.accent, 0.78)
    readonly property color onAccentContainer: root.ryokuFrontend ? Tokens.inkOnBone : ColorUtils.mix(root.accent, root.text, 0.65)
    function vividHighlight(seed, fallback): color {
        const c = Qt.color(seed)
        if (!c.valid || c.hslHue < 0 || c.hslSaturation < 0.1) return fallback
        return Qt.hsla(c.hslHue, Math.max(0.62, Math.min(0.95, c.hslSaturation + 0.2)),
            Math.max(0.54, Math.min(0.66, c.hslLightness)), 1)
    }
    readonly property color secondaryAccent: {
        if (root.ryokuFrontend) {
            // The glanced detail (timers, badges, activity rings): Ink by default,
            // the wallpaper's matugen primary or a chosen hue when asked.
            const pick = root.appearance?.highlight ?? "ink"
            if (pick === "accent") return root.accent
            if (pick === "wallpaper") return root.accentWallpaper
            if (pick === "custom") return Qt.hsla(root.hueOf("highlightHue", 32), 0.85, Tokens.light ? 0.48 : 0.6, 1)
            return Tokens.ink
        }
        const choice = root.appearance?.highlight ?? "orange"
        if (choice === "accent") return root.accent
        if (choice === "theme") return root.vividHighlight(Appearance.colors.colTertiary, root.highlights.orange)
        if (choice === "custom") return Qt.hsla(root.hueOf("highlightHue", 32), 0.92, 0.58, 1)
        if (choice === "wallpaper") return root.vividHighlight(Appearance.colors.colSecondary,
            root.vividHighlight(Appearance.wallpaperDominantColor, root.highlights.orange))
        return root.highlights[choice] ?? root.highlights.orange
    }
    // The one accent spark on the always-present frame (the resting Island's
    // clock separator and day number). Content stays monochrome; this is the
    // single place the sun is allowed to land inside the family (DESIGN: accent
    // lives on the frame, not the content).
    readonly property color frameAccent: root.ryokuFrontend ? Tokens.sun : root.secondaryAccent
    readonly property string auraName: ["off", "subtle", "vivid"].includes(root.appearance?.aura ?? "")
        ? root.appearance.aura : "subtle"
    readonly property real auraStrength: ({ off: 0, subtle: 0.2, vivid: 0.36 })[root.auraName]
    readonly property color wallpaperLight: root.ryokuFrontend ? Tokens.ink : root.vividHighlight(Appearance.wallpaperDominantColor,
        root.vividHighlight(Appearance.colors.colPrimary, root.accent))
    function surfaceWidth(id: string, fallback: int): int {
        const width = Number(root.appearance?.surfaces?.[id]?.width ?? 0)
        return width > 0 ? Math.round(width * root.density) : fallback
    }
    readonly property int lightContour: Math.max(4, Math.round(6 * root.density))
    readonly property int lightJoinContour: root.lightContour + Math.round(Math.min(root.fuseDeep, 30 * root.density) / 3)
    readonly property int lightReach: Math.round(92 * root.density * root.tweak("lightReach", 0.5, 3))
    function aura(light: color): color { return ColorUtils.applyAlpha(light, root.auraStrength * light.a) }
    function auraFading(light: color): color { return ColorUtils.applyAlpha(light, root.auraStrength * light.a * 0.35) }
    function skyLight(glyph: string): color {
        switch (glyph) {
        case "clear_day": return root.identity.orange
        case "partly_cloudy_day": return root.identity.sky
        case "cloud": case "foggy": return root.identity.gray
        case "rainy": return root.identity.blue
        case "thunderstorm": return root.identity.purple
        case "weather_snowy": case "cloudy_snowing": case "weather_hail": return root.identity.sky
        case "bedtime": case "partly_cloudy_night": return root.identity.indigo
        default: return root.wallpaperLight
        }
    }
    readonly property string badgeStyle: String(root.theme?.badge ?? "alert")
    readonly property color badge: root.ryokuFrontend
        ? (root.badgeStyle === "accent" ? root.accent
            : root.badgeStyle === "highlight" ? root.secondaryAccent
            : root.badgeStyle === "neutral" ? root.surfaceHighestOpaque
            : Tokens.alert)
        : root.badgeStyle === "accent" ? root.accent
        : root.badgeStyle === "highlight" ? root.secondaryAccent
        : root.badgeStyle === "neutral" ? root.surfaceHighestOpaque
        : root.identity.red
    readonly property color onBadge: root.ryokuFrontend
        ? (root.badgeStyle === "accent" ? root.onAccent
            : root.badgeStyle === "highlight" ? root.onTintFor(root.secondaryAccent)
            : root.badgeStyle === "neutral" ? root.text
            : Qt.color("#ffffff"))
        : root.badgeStyle === "alert" ? root.onTint
        : root.badgeStyle === "neutral" ? root.text
        : root.badgeStyle === "highlight" ? root.onTintFor(root.secondaryAccent) : root.onAccent
    readonly property color badgeInk: root.ryokuFrontend
        ? (root.badgeStyle === "accent" ? root.accent
            : root.badgeStyle === "highlight" ? root.secondaryAccent
            : root.badgeStyle === "neutral" ? root.text
            : Tokens.alert)
        : root.badgeStyle === "alert" ? root.danger
        : root.badgeStyle === "neutral" ? root.text : root.badge
    readonly property color success: root.ryokuFrontend ? Tokens.ink : "#8de0a3"
    readonly property color danger: root.ryokuFrontend ? Tokens.alert : "#ff6961"
    readonly property color onDanger: root.ryokuFrontend ? Qt.color("#ffffff") : Qt.color("#160000")
    function line(base: color): color {
        const t = root.tweak("lines", 0, 2)
        return t <= 1 ? ColorUtils.mix(base, root.surfaceOpaque, t) : ColorUtils.mix(root.text, base, (t - 1) * 0.35)
    }
    function ruleOf(reference: color): color {
        const k = Math.max(0, Math.min(1, (reference.r + reference.g + reference.b) / 3 / 0.96))
        return ColorUtils.mix(root.text, root.surfaceOpaque, k)
    }
    readonly property color hairline: root.ryokuFrontend ? Tokens.line
        : root.glassy ? ColorUtils.applyAlpha(root.text, Math.min(0.3, 0.07 * root.tweak("lines", 0, 2)))
        : root.line(root.ruleOf(Qt.color(root.preset.hairline)))
    readonly property color hairlineStrong: root.ryokuFrontend ? Tokens.lineStrong
        : root.glassy ? ColorUtils.applyAlpha(root.text, Math.min(0.45, 0.14 * root.tweak("lines", 0, 2)))
        : root.line(root.ruleOf(Qt.color(root.preset.hairlineStrong)))
    readonly property color selection: root.ryokuFrontend ? Tokens.tint16 : "#303034"
    readonly property color selectionHover: root.ryokuFrontend ? ColorUtils.applyAlpha(Tokens.ink, 0.22) : "#404044"
    readonly property color selectionText: root.ryokuFrontend ? Tokens.ink : "#ffffff"
    readonly property color scrim: Appearance.colors.colScrim

    function fillAlpha(level: real): real { return Math.min(0.5, level * root.preset.fill * root.tweak("fill", 0.3, 2)) }
    readonly property color fillInk: root.ryokuFrontend ? Tokens.ink : root.tinted(root.text, 0.22)
    readonly property color fillQuiet: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.08))
    readonly property color fill: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.12))
    readonly property color fillHover: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.18))
    readonly property color fillActive: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.26))
    readonly property color fillStrong: ColorUtils.applyAlpha(root.fillInk, Math.min(0.9, 0.6 * root.preset.fill * root.tweak("fill", 0.3, 2)))
    function tintFill(tint: color): color { return ColorUtils.applyAlpha(tint, root.fillAlpha(0.18)) }
    function tintFillHover(tint: color): color { return ColorUtils.applyAlpha(tint, root.fillAlpha(0.28)) }
    function tintBorder(tint: color): color { return ColorUtils.applyAlpha(tint, 0.7) }

    function textLevel(level: real): real { return Math.min(1, level * root.tweak("contrast", 0.6, 1.5)) }
    function inkLevel(level: real, glassFloor: real): real { return Math.max(root.textLevel(level), root.glassy ? glassFloor : 0) }
    readonly property color textStrong: ColorUtils.applyAlpha(root.text, root.textLevel(root.preset.textStrong))
    readonly property color textSecondary: ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.66, root.preset.textSecondary), 0.8))
    readonly property color textTertiary: ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.5, root.preset.textTertiary), 0.6))
    function strongOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.textLevel(root.preset.textStrong)) }
    function secondaryOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.inkLevel(Math.max(0.66, root.preset.textSecondary), 0.8)) }
    function tertiaryOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.inkLevel(Math.max(0.5, root.preset.textTertiary), 0.6)) }
    readonly property color border: root.ryokuFrontend ? Tokens.line : ColorUtils.applyAlpha(root.text, Math.min(0.5, 0.12 * root.preset.fill * root.tweak("lines", 0, 2)))
    readonly property color borderStrong: root.ryokuFrontend ? Tokens.lineStrong : ColorUtils.applyAlpha(root.text, Math.min(0.6, 0.28 * root.preset.fill * root.tweak("lines", 0, 2)))
    readonly property string rimTint: String(root.theme?.rimTint ?? "neutral")
    readonly property color rim: !(root.theme?.rim ?? true) ? Qt.color("transparent")
        : root.ryokuFrontend ? Tokens.line
        : root.rimTint === "accent" ? ColorUtils.applyAlpha(root.accent, Math.min(0.9, 0.3 + 0.3 * root.tweak("lines", 0, 2)))
        : root.rimTint === "highlight" ? ColorUtils.applyAlpha(root.secondaryAccent, Math.min(0.9, 0.3 + 0.3 * root.tweak("lines", 0, 2)))
        : root.border
    readonly property int rimWidth: Math.max(1, Math.round(Math.max(1, Math.min(3, Number(root.theme?.rimWidth ?? 1))) * root.density))
    readonly property real glow: Math.max(0, Math.min(1, Number(root.theme?.glow ?? 0) / 100))
    readonly property color onTint: root.ryokuFrontend ? Tokens.inkOnBone : "#ffffff"
    function onTintFor(tint: color): color { return tint.hslLightness > 0.6 ? root.onAccent : root.onTint }

    readonly property color veilLight: ColorUtils.applyAlpha(root.surface, 0.22)
    readonly property color veil: ColorUtils.applyAlpha(root.surface, 0.42)
    readonly property color veilStrong: ColorUtils.applyAlpha(root.surface, 0.62)
    readonly property color veilHeavy: ColorUtils.applyAlpha(root.surface, 0.76)
    function glowing(alpha: real): color {
        const ink = ColorUtils.mix(root.accent, Qt.color("black"), root.glow)
        return ColorUtils.applyAlpha(ink, Math.min(0.9, alpha * (1 + 0.4 * root.glow)))
    }
    readonly property real shadowThrough: root.glassy ? 0.4 : 1
    readonly property color shadow: root.glowing(Math.min(0.9, 0.55 * root.tweak("shadow", 0, 1.6)) * root.shadowThrough)
    readonly property color material: ColorUtils.applyAlpha(root.surfaceHigh, 0.68)
    readonly property color onMedia: "#ffffff"
    readonly property color onMediaSecondary: ColorUtils.applyAlpha(root.onMedia, 0.72)
    readonly property color onMediaFill: ColorUtils.applyAlpha(root.onMedia, 0.2)
    readonly property color onMediaFillHover: ColorUtils.applyAlpha(root.onMedia, 0.3)
    readonly property color mediaScrim: Qt.rgba(0, 0, 0, 0.34)
    readonly property color plateShadow: root.glowing(Math.min(0.9, 0.36 * root.tweak("shadow", 0, 1.6)))
    function skyWash(light: color): color { return ColorUtils.applyAlpha(light, 0.46) }
    function skyWashFade(light: color): color { return ColorUtils.applyAlpha(light, 0.05) }
    readonly property color glassShadow: Qt.rgba(0, 0, 0, Math.min(0.6, 0.22 * root.tweak("shadow", 0, 1.6)))
    readonly property real glassBlur: 1
    readonly property real glassWash: 0.55
    readonly property color clearRim: ColorUtils.applyAlpha(root.text, 0.07)
    readonly property int glassBlurMax: 48
    readonly property real glassSaturation: 0.3
    readonly property var materialVeil: ({ glass: 0.3, clear: 0.04 })
    readonly property var materialContrast: ({ glass: 4.5, clear: 3 })
    readonly property var materialSpread: ({ glass: 1.0, clear: 1.2 })
    function legibleVeil(material: string, level: real, spread: real, strength: real): real {
        const floor = (root.materialVeil[material] ?? 0.3) * strength
        if (level < 0)
            return Math.max(floor, 0.42)
        const worst = Math.min(1, level + spread * (root.materialSpread[material] ?? 1))
        const region = Math.pow(worst, 2.2)
        const base = ColorUtils.relativeLuminance(root.surfaceOpaque)
        const allowed = (ColorUtils.relativeLuminance(root.text) + 0.05) / (root.materialContrast[material] ?? 4.5) - 0.05
        const needed = region > allowed ? (region - allowed) / Math.max(0.001, region - base) : 0
        return Math.max(floor, Math.min(0.86, needed))
    }

    readonly property QtObject identity: QtObject {
        readonly property color blue: root.ryokuFrontend ? root.text : "#0a84ff"
        readonly property color sky: root.ryokuFrontend ? root.text : "#64d2ff"
        readonly property color teal: root.ryokuFrontend ? root.text : "#30b0c7"
        readonly property color green: root.ryokuFrontend ? root.text : "#34c759"
        readonly property color yellow: root.ryokuFrontend ? root.text : "#e0a800"
        readonly property color orange: root.ryokuFrontend ? root.text : "#ff9f0a"
        readonly property color red: root.ryokuFrontend ? root.text : "#ff453a"
        readonly property color pink: root.ryokuFrontend ? root.text : "#ff375f"
        readonly property color indigo: root.ryokuFrontend ? root.text : "#5e5ce6"
        readonly property color purple: root.ryokuFrontend ? root.text : "#bf5af2"
        readonly property color lavender: root.ryokuFrontend ? root.text : "#b4a0ff"
        readonly property color gray: root.ryokuFrontend ? root.text : "#8e8e93"
    }

    function identityColor(name: string): color { return root.identity[name] ?? root.identity.lavender }

    readonly property real shapeScale: root.preset.shape * root.tweak("shape", 0.3, 1.6)
    // Large containers stop growing well before a pill, so content keeps a concentric margin.
    function corner(px: real): int {
        const cap = px >= 18 ? 1.3 : px >= 10 ? 1.4 : 1.6
        return Math.max(2, Math.round(px * Math.min(root.shapeScale, cap) * root.density))
    }
    function concentricPad(outerRadius: real, floor: real): int {
        return Math.max(Math.round(floor), Math.round(outerRadius * 0.3 + 7 * root.density))
    }
    readonly property int radiusPanel: root.corner(30)   // Control Center, Settings frame
    readonly property int radiusSheet: root.corner(26)   // Spotlight, media card, wallpaper picker
    readonly property int radiusPlate: root.corner(22)   // widget and lock plates, dialogs, blocks
    readonly property int radiusCard: root.corner(18)    // side-panel sections, menus
    readonly property int radiusTile: root.corner(14)    // grouped cards, tiles, results
    readonly property int radiusRow: root.corner(10)     // list rows, menu items, small buttons
    readonly property int radiusChip: root.corner(7)     // chips, thumbnails, small marks
    readonly property int radiusMicro: root.corner(4)    // bars inside skeletons, swatches
    readonly property real meltDepth: {
        const t = root.tweak("melt", 0, 2)
        return t <= 1 ? t : 1 + (t - 1) * 0.5
    }
    readonly property int fuse: Math.max(2, Math.round(8 * root.density * root.meltDepth))
    readonly property int fuseDeep: Math.max(4, Math.round(30 * root.density * root.meltDepth))
    readonly property real islandBandScale: Math.max(32, Math.min(64, Number(root.options?.bar?.height ?? 42))) / 42
    readonly property int fuseEdge: Math.max(8, Math.round(56 * root.density * root.islandBandScale
        * Math.max(0.2, Math.min(2, Number(root.options?.bar?.notchCurve ?? 100) / 100))))
    readonly property int weld: Math.max(2, Math.round(3 * root.density))
    function edgeFuseFor(size: real, curve: real): int {
        const scale = Math.max(32, Math.min(64, size / root.density)) / 42
        return Math.max(8, Math.round(56 * root.density * scale * Math.max(0.2, Math.min(2, curve / 100))))
    }
    readonly property string pieceShape: String(root.theme?.pieceShape ?? "circle")
    function pieceRadius(size: real): real {
        const half = size / 2
        if (root.pieceShape === "squircle") return Math.min(half, size * 0.34 * Math.max(0.6, root.shapeScale))
        if (root.pieceShape === "square") return Math.min(half, size * 0.22 * Math.max(0.6, root.shapeScale))
        return half
    }
    function iconRadius(size: real): int { return Math.round(size * 0.26 * Math.min(1.2, root.shapeScale)) }

    readonly property real panelPadding: Math.round(24 * root.density)
    readonly property real sectionGap: Math.round(24 * root.density)
    readonly property real controlHeight: Math.round(38 * root.density)
    readonly property real compactControlHeight: Math.round(32 * root.density)
    readonly property real headerHeight: Math.round(54 * root.typeScale)
    readonly property real accentRuleWidth: Math.round(24 * root.density)
    readonly property real accentRuleHeight: Math.max(2, Math.round(3 * root.density))

    readonly property bool motionEnabled: (root.appearance?.motion ?? true) && Appearance.animationsEnabled
        && root.appearance?.morph !== "instant"
    function duration(ms: int): int {
        return root.motionEnabled ? Appearance.calcEffectiveDuration(ms) : 0
    }

    readonly property var curves: ({ expressive: [0.16, 1, 0.3, 1], standard: [0.2, 0, 0, 1], gentle: [0.4, 0, 0.2, 1], swift: [0.3, 0.9, 0.2, 1], fold: [0.3, 0, 0.2, 1] })
    readonly property var directCurve: {
        const name = String(root.theme?.curve ?? "expressive")
        if (name !== "custom") return root.curves[name] ?? root.curves.expressive
        const p = root.theme?.curvePoints ?? []
        const at = (i, low, high, fallback) => Math.max(low, Math.min(high, Number(p[i] ?? fallback)))
        return [at(0, 0, 1, 0.16), at(1, -0.5, 1.5, 1), at(2, 0, 1, 0.3), at(3, -0.5, 1.5, 1)]
    }
    readonly property var morphStyles: ({
        direct: { curve: true, emerge: { response: 1.8 }, recede: { response: 1.2, curve: "fold" }, move: { response: 1 },
            rise: 0.3, span: 0.35, fall: 0.12, reveal: "drop" },
        liquid: { emerge: { response: 1.9, bounce: 0.22 }, recede: { response: 1.3, bounce: 0 }, move: { response: 1.15, bounce: 0.08 },
            rise: 0.34, span: 0.42, fall: 0.24, reveal: "drop" },
        glide: { emerge: { response: 2.1, bounce: 0 }, recede: { response: 1.5, bounce: 0 }, move: { response: 1.35, bounce: 0 },
            rise: 0.3, span: 0.5, fall: 0.28, reveal: "drop" },
        snap: { emerge: { response: 1.25, bounce: 0.06 }, recede: { response: 0.95, bounce: 0 }, move: { response: 0.85, bounce: 0 },
            rise: 0.18, span: 0.34, fall: 0.2, reveal: "fade" },
        elastic: { emerge: { response: 2.2, bounce: 0.34 }, recede: { response: 1.4, bounce: 0 }, move: { response: 1.5, bounce: 0.24 },
            rise: 0.36, span: 0.4, fall: 0.28, reveal: "inflate" },
        instant: { emerge: { response: 1, bounce: 0 }, recede: { response: 1, bounce: 0 }, move: { response: 1, bounce: 0 },
            rise: 0.01, span: 0.01, fall: 0.01, reveal: "fade" }
    })
    readonly property string morphName: root.morphStyles[root.appearance?.morph ?? ""] ? root.appearance.morph : "direct"
    readonly property var morph: root.morphStyles[root.morphName]

    readonly property string revealName: String(root.morph?.reveal ?? "curtain")
    readonly property real absorbShare: 0.55
    readonly property real pullLag: 1.8
    readonly property real dropRise: Math.max(0, Math.min(0.7, 0.06 + 0.4 * (root.tweak("contentTiming", 0.3, 1.7) - 1)))
    readonly property real dropSpan: 0.3
    readonly property bool revealDrops: root.revealName === "drop" && root.motionEnabled
    readonly property bool revealInflates: root.revealName === "inflate" && root.motionEnabled
    readonly property bool revealFades: root.revealName === "fade" || !root.motionEnabled

    readonly property int baseDuration: Math.max(100, Math.min(400, Number(root.appearance?.motionDuration ?? 220)))
    function resolveSpring(entry: var, fallbackResponse: real, timeTweak: string): var {
        const response = Math.round(root.baseDuration * Math.max(0.2, Number(entry?.response ?? fallbackResponse)) * root.tweak(timeTweak, 0.4, 2.5))
        const bounce = Number(entry?.bounce ?? 0) * root.tweak("bounce", 0, 2)
        const curve = !root.morph?.curve ? null : entry?.curve ? root.curves[entry.curve] : root.directCurve
        return { response: root.duration(response), bounce: curve ? 0 : Math.max(0, Math.min(0.6, bounce)), curve: curve }
    }
    readonly property var emergeSpring: root.resolveSpring(root.morph?.emerge, 1.9, "openTime")
    readonly property var recedeSpring: root.resolveSpring(root.morph?.recede, 1.3, "openTime")
    readonly property var moveSpring: root.resolveSpring(root.morph?.move, 1.15, "moveTime")
    function surfaceSpeed(id: string): real {
        return id.length === 0 ? 1 : Math.max(0.4, Math.min(2.5, Number(root.appearance?.surfaces?.[id]?.speed ?? 100) / 100))
    }
    function springFor(intent: string, surface: string): var {
        const base = intent === "move" ? root.moveSpring : intent === "emerge" ? root.emergeSpring : root.recedeSpring
        const speed = root.surfaceSpeed(surface)
        return speed === 1 ? base : Object.assign({}, base, { response: Math.round(base.response / speed) })
    }
    function pressScale(base: real): real { return 1 - (1 - base) * root.tweak("press", 0, 2) }

    function springState(t: real, bounce: real): var {
        const w = 2 * Math.PI
        const zeta = 1 - bounce
        if (zeta < 0.9999) {
            const wd = w * Math.sqrt(1 - zeta * zeta)
            const e = Math.exp(-zeta * w * t)
            const b = -zeta * w / wd
            const c = Math.cos(wd * t), s = Math.sin(wd * t)
            const d = e * (-c + b * s)
            return { y: 1 + d, v: -zeta * w * d + e * (wd * s + b * wd * c) }
        }
        const e = Math.exp(-w * t)
        return { y: 1 - (1 + w * t) * e, v: w * w * t * e }
    }
    function springSettle(bounce: real): real {
        let last = 0
        for (let t = 0; t < 4; t += 0.004)
            if (Math.abs(root.springState(t, bounce).y - 1) >= 0.002) last = t
        return Math.max(0.4, last)
    }
    // At most ten segments: Qt 6.11 segfaults on a 12-segment BezierSpline.
    function springCurve(bounce: real): var {
        const segments = 8
        const settle = root.springSettle(bounce)
        const points = []
        for (let i = 0; i < segments; ++i) {
            const u0 = i / segments, u1 = (i + 1) / segments, h = 1 / segments
            const a = root.springState(u0 * settle, bounce)
            const last = i === segments - 1
            const b = last ? { y: 1, v: 0 } : root.springState(u1 * settle, bounce)
            points.push(u0 + h / 3, a.y + a.v * settle * h / 3, u1 - h / 3, b.y - b.v * settle * h / 3, u1, b.y)
        }
        return points
    }
    function curveOf(spring: var): var {
        return spring.curve ? spring.curve.concat([1, 1]) : root.springCurve(spring.bounce)
    }
    function durationOf(spring: var): int {
        return spring.curve ? spring.response : Math.round(spring.response * root.springSettle(spring.bounce))
    }
    function cubicBezier(curve: var, x: real): real {
        if (x <= 0) return 0
        if (x >= 1) return 1
        const cx = 3 * curve[0], bx = 3 * (curve[2] - curve[0]) - cx, ax = 1 - cx - bx
        const cy = 3 * curve[1], by = 3 * (curve[3] - curve[1]) - cy, ay = 1 - cy - by
        let t = x
        for (let i = 0; i < 8; ++i) {
            const fx = ((ax * t + bx) * t + cx) * t - x
            const d = (3 * ax * t + 2 * bx) * t + cx
            if (Math.abs(fx) < 1e-5 || Math.abs(d) < 1e-6) break
            t = Math.max(0, Math.min(1, t - fx / d))
        }
        return ((ay * t + by) * t + cy) * t
    }
    readonly property var emergeCurve: root.curveOf(root.emergeSpring)
    readonly property var recedeCurve: root.curveOf(root.recedeSpring)
    readonly property var moveCurve: root.curveOf(root.moveSpring)
    readonly property int emergeDuration: root.durationOf(root.emergeSpring)
    readonly property int recedeDuration: root.durationOf(root.recedeSpring)
    readonly property int moveDuration: root.durationOf(root.moveSpring)
    readonly property real contentRise: Math.min(0.95, Number(root.morph?.rise ?? 0.34) * root.tweak("contentTiming", 0.3, 1.7))
    readonly property real contentSpan: Math.max(0.01, Number(root.morph?.span ?? 0.42))
    readonly property real contentFall: Math.max(0.02, Number(root.morph?.fall ?? 0.24))
    function ramp(t: real, rise: real, span: real): real {
        return Math.max(0, Math.min(1, (t - rise) / Math.max(0.01, span)))
    }
    function contentAt(t: real): real { return root.ramp(t, root.contentRise, root.contentSpan) }
    // A floating body's shadow arrives with its settle, never under a shape that is still growing.
    function shadowAt(t: real): real { return Math.pow(Math.max(0, Math.min(1, t)), 4) }

    readonly property int morphDuration: root.moveDuration
    readonly property int settleDuration: root.emergeDuration
    readonly property int revealDuration: duration(140)
    readonly property int feedbackDuration: duration(100)
    readonly property int feedbackEasing: Easing.OutCubic
    readonly property var morphCurve: root.moveCurve
}
