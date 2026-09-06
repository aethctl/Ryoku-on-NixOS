import QtQuick
import Quickshell
import Quickshell.Io
import "services"

// The wall-ui's colour source, retuned to Ryoku's paper-and-ink resolution
// (see ryoku/ui/Singletons/Tokens.qml). Reads the SAME palette the Hub and
// shell use (~/.cache/ryoku/colors.json), so the picker retints with the whole
// desktop on any wallpaper or theme change. skwd's Material role names are kept
// so every component keeps reading one source; they now collapse onto Ryoku's
// monochrome surface + one live sun accent, instead of a full colour palette.
QtObject {
    id: colors

    property string colorFilePath: Quickshell.env("HOME") + "/.cache/ryoku/colors.json"

    property var colorFileView: FileView {
        path: BootstrapService.ready ? colors.colorFilePath : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: colors._applyColors()
    }

    function _tint(hex, a) { var c = Qt.color(hex); return Qt.rgba(c.r, c.g, c.b, a); }

    function _applyColors() {
        var text = colorFileView.text().trim()
        if (!text) return
        try {
            var d = JSON.parse(text)
            // Ryoku resolution: paper = surface, ink = onSurface, lift =
            // surfaceContainerLow, bone = inverseSurface, sun = primary.
            // Everything else collapses onto these, so the picker reads
            // paper-and-ink with one live accent.
            var paper  = d.surface ?? "#000000"
            var lift   = d.surfaceContainerLow ?? d.surfaceContainer ?? "#0a0a0a"
            var ink    = d.onSurface ?? "#cdc4ba"
            var inkDim = d.onSurfaceVariant ?? "#b0a9a0"
            var boneC  = d.inverseSurface ?? ink
            var onBone = d.inverseOnSurface ?? "#000000"
            var sun    = d.primary ?? "#e2342a"
            var onSun  = d.onPrimary ?? paper

            colors.background = paper
            colors.backgroundText = ink
            colors.surface = paper
            colors.surfaceText = ink
            colors.surfaceVariant = lift
            colors.surfaceVariantText = inkDim
            colors.surfaceContainer = lift

            colors.primary = sun
            colors.primaryText = onSun
            colors.primaryContainer = boneC            // active pill = bone plate
            colors.primaryContainerText = onBone
            colors.primaryForeground = onSun

            colors.secondary = sun
            colors.secondaryText = onSun
            colors.secondaryContainer = lift
            colors.secondaryContainerText = ink

            colors.tertiary = inkDim
            colors.tertiaryText = paper
            colors.tertiaryContainer = lift
            colors.tertiaryContainerText = ink

            colors.error = "#e2342a"
            colors.errorText = "#ffffff"
            colors.errorContainer = _tint("#e2342a", 0.22)
            colors.errorContainerText = "#ffdad6"

            colors.outline = _tint(ink, 0.26)
            colors.shadow = "#000000"
            colors.inverseSurface = boneC
            colors.inverseSurfaceText = onBone
            colors.inversePrimary = sun
            console.log("Colors: applied Ryoku paper-and-ink palette")
        } catch (e) {
            console.log("Colors: Error parsing colors.json:", e)
        }
    }

    // paper-and-ink defaults (file absent / mid-write)
    property color primary: "#e2342a"
    property color primaryText: "#000000"
    property color primaryContainer: "#cdc4ba"
    property color primaryContainerText: "#000000"
    property color primaryForeground: "#000000"

    property color secondary: "#e2342a"
    property color secondaryText: "#000000"
    property color secondaryContainer: "#0a0a0a"
    property color secondaryContainerText: "#cdc4ba"

    property color tertiary: "#b0a9a0"
    property color tertiaryText: "#000000"
    property color tertiaryContainer: "#0a0a0a"
    property color tertiaryContainerText: "#cdc4ba"

    property color background: "#000000"
    property color backgroundText: "#cdc4ba"
    property color surface: "#000000"
    property color surfaceText: "#cdc4ba"
    property color surfaceVariant: "#0a0a0a"
    property color surfaceVariantText: "#b0a9a0"
    property color surfaceContainer: "#0a0a0a"

    property color error: "#e2342a"
    property color errorText: "#ffffff"
    property color errorContainer: "#3a0d0b"
    property color errorContainerText: "#ffdad6"

    property color outline: Qt.rgba(0.803, 0.768, 0.729, 0.26)   // ink @ 0.26
    property color shadow: "#000000"
    property color inverseSurface: "#cdc4ba"
    property color inverseSurfaceText: "#000000"
    property color inversePrimary: "#e2342a"
}
