import QtQuick
import shell.services

// CHROMA used a seven-colour neon palette. On Ryoku those slots are derived from
// the active Material palette instead of being owned by a second theme engine,
// so both named themes and Matugen wallpaper palettes recolour the bar live.
QtObject {
    id: root

    property real surfaceOpacity: 1

    readonly property color background: alpha(Theme.surface, surfaceOpacity)
    readonly property color backgroundAlt: alpha(Theme.surfaceContainerLow, surfaceOpacity)
    readonly property color surface: alpha(Theme.surfaceContainer, surfaceOpacity)
    readonly property color surfaceAlt: alpha(Theme.surfaceContainerHigh, surfaceOpacity)
    readonly property color surfaceHover: alpha(Theme.surfaceContainerHighest, surfaceOpacity)
    readonly property color border: Theme.outlineVariant
    readonly property color borderStrong: Theme.outline
    readonly property color text: Theme.onSurface
    readonly property color textStrong: Theme.onSurface
    readonly property color muted: Theme.onSurfaceVariant

    // CHROMA keeps its multi-slot visual rhythm, but every slot is now a tone
    // of the wallpaper's PRIMARY Matugen hue. Material secondary/tertiary roles
    // can intentionally wander into complementary hues (pink/purple on blue
    // wallpapers), which looked disconnected in a compact bar.
    readonly property var accentFactors: [1.22, 1.12, 1.05, 1.0, 0.92, 0.82, 0.72]

    function accent(index) {
        const n = root.accentFactors.length
        const i = ((index % n) + n) % n
        const factor = root.accentFactors[i]
        return factor >= 1.0
            ? Qt.lighter(Theme.primary, factor)
            : Qt.darker(Theme.primary, 1.0 / factor)
    }

    function inkOn(fill) {
        return Theme.ink(fill, 4.5)
    }

    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity)
    }
}
