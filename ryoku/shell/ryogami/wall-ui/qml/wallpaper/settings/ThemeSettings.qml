import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"

Column {
    id: root
    property var colors
    property var saveConfigKey
    property var notifyThemeChanged
    property var _theme: ({ themeApps: true, gtkTheme: "adw", gnomeAccent: false })
    property string _reveal: "random"
    property var _mat: ({ lightnessDark: 0, lightnessLight: 0, prefer: "saturation", sourceColorIndex: 0 })
    readonly property var _revealModel: [
        "random", "silk_fade", "diagonal_silk", "dream_curtain", "liquid_ribbon",
        "iris_open", "corner_bloom", "spotlight_rise", "wander_iris", "vignette_close",
        "celeste_veil", "comet_streak", "aurora_ripple", "starfall_bloom",
        "mosaic_swell", "ember_burn", "pond_wake", "glass_scatter", "signal_tear",
        "cathode_wink", "shutter_sweep", "wax_descent", "page_turn"
    ].map(function(p) {
        return { mode: p, label: p === "random" ? "Random"
            : p.replace(/_/g, " ").replace(/^./, function(c) { return c.toUpperCase() }) }
    })

    function _runHub(args) { Quickshell.execDetached(["ryoku-hub"].concat(args)) }
    function _matugenSet(patch) { Quickshell.execDetached(["ryoku-hub", "hypr", "matugen", "set", JSON.stringify(patch)]) }

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/ryoku/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(themeFile.text())
                root._theme = { themeApps: d.themeApps !== false, gtkTheme: d.gtkTheme || "adw", gnomeAccent: !!d.gnomeAccent }
            } catch (e) {}
        }
    }

    FileView {
        id: shellFile
        path: Quickshell.env("HOME") + "/.config/ryoku/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(shellFile.text())
                var v = (d.wallpaper && d.wallpaper.transition_preset) || "random"
                root._reveal = ("" + v).length ? ("" + v) : "random"
            } catch (e) {}
        }
    }

    FileView {
        id: matugenFile
        path: Quickshell.env("HOME") + "/.config/ryoku/matugen.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var d = JSON.parse(matugenFile.text())
                root._mat = {
                    lightnessDark: typeof d.lightnessDark === "number" ? d.lightnessDark : 0,
                    lightnessLight: typeof d.lightnessLight === "number" ? d.lightnessLight : 0,
                    prefer: d.prefer || "saturation",
                    sourceColorIndex: typeof d.sourceColorIndex === "number" ? (d.sourceColorIndex | 0) : 0
                }
            } catch (e) {}
        }
    }

    width: parent ? parent.width : 0
    spacing: 8

    SettingsCard {
        colors: root.colors
        title: "Theme"
        width: parent.width

        RowDropdown {
            colors: root.colors
            title: "Scheme type"
            description: "Material 3 colour-generation algorithm."
            value: Config.matugenScheme.replace("scheme-", "")
            model: [
                { mode: "content",     label: "Content" },
                { mode: "expressive",  label: "Expressive" },
                { mode: "fidelity",    label: "Fidelity" },
                { mode: "fruit-salad", label: "Fruit salad" },
                { mode: "monochrome",  label: "Monochrome" },
                { mode: "neutral",     label: "Neutral" },
                { mode: "rainbow",     label: "Rainbow" },
                { mode: "tonal-spot",  label: "Tonal spot" },
                { mode: "vibrant",     label: "Vibrant" }
            ]
            onSelect: function(v) {
                var full = "scheme-" + v
                if (root.saveConfigKey) root.saveConfigKey("matugen.schemeType", full)
                if (root.notifyThemeChanged) root.notifyThemeChanged(full, Config.matugenMode, root._mat.sourceColorIndex)
            }
        }

        RowTextInput {
            colors: root.colors
            title: "Contrast"
            description: "Matugen contrast. Range -1.0 to 1.0 (0 = standard, higher = more contrast)."
            value: Config.matugenContrast.toFixed(2)
            placeholder: "0.00"
            onCommit: function(v) {
                var n = parseFloat(v)
                if (isNaN(n)) n = 0
                n = Math.max(-1, Math.min(1, n))
                if (root.saveConfigKey) root.saveConfigKey("matugen.contrast", n)
                if (root.notifyThemeChanged) root.notifyThemeChanged(Config.matugenScheme, Config.matugenMode, root._mat.sourceColorIndex)
            }
        }
    }

    SettingsCard {
        colors: root.colors
        title: "Colour generation"
        kana: "生成"
        width: parent.width

        Column {
            width: parent.width
            spacing: 12 * Config.uiScale
            topPadding: 4 * Config.uiScale

            Row {
                id: genGrid1
                width: parent.width
                spacing: 12 * Config.uiScale
                z: 5
                readonly property real cellW: (width - spacing * 2) / 3

                SettingsDropdown {
                    width: genGrid1.cellW
                    colors: root.colors
                    label: "Mode"
                    value: Config.matugenMode
                    model: [
                        { mode: "dark",  label: "Dark" },
                        { mode: "light", label: "Light" },
                        { mode: "smart", label: "Smart" }
                    ]
                    onSelect: function(v) {
                        if (root.saveConfigKey) root.saveConfigKey("matugen.mode", v)
                        if (root.notifyThemeChanged) root.notifyThemeChanged(Config.matugenScheme, v, root._mat.sourceColorIndex)
                    }
                }

                SettingsDropdown {
                    width: genGrid1.cellW
                    colors: root.colors
                    label: "Source index"
                    value: String(root._mat.sourceColorIndex)
                    model: [
                        { mode: "0", label: "0 (Primary)" },
                        { mode: "1", label: "1" },
                        { mode: "2", label: "2" },
                        { mode: "3", label: "3" },
                        { mode: "4", label: "4" }
                    ]
                    onSelect: function(v) {
                        var idx = parseInt(v, 10) | 0
                        if (root.saveConfigKey) root.saveConfigKey("matugen.colorIndex", idx)
                        if (root.notifyThemeChanged) root.notifyThemeChanged(Config.matugenScheme, Config.matugenMode, idx)
                    }
                }

                SettingsDropdown {
                    width: genGrid1.cellW
                    colors: root.colors
                    label: "Preference"
                    value: root._mat.prefer
                    model: [
                        { mode: "darkness",            label: "Darkness" },
                        { mode: "lightness",           label: "Lightness" },
                        { mode: "saturation",          label: "Saturation" },
                        { mode: "less-saturation",     label: "Less saturation" },
                        { mode: "value",               label: "Value" },
                        { mode: "closest-to-fallback", label: "Closest to fallback" }
                    ]
                    onSelect: function(v) { root._matugenSet({ prefer: v }) }
                }
            }

            Row {
                id: genGrid2
                width: parent.width
                spacing: 12 * Config.uiScale
                readonly property real cellW: (width - spacing) / 2

                SettingsSlider {
                    width: genGrid2.cellW
                    colors: root.colors
                    label: "Lightness (dark)"
                    min: -100; max: 100
                    resettable: true; defaultValue: 0
                    value: Math.round(root._mat.lightnessDark * 100)
                    onCommit: function(v) { root._matugenSet({ lightnessDark: v / 100 }) }
                }

                SettingsSlider {
                    width: genGrid2.cellW
                    colors: root.colors
                    label: "Lightness (light)"
                    min: -100; max: 100
                    resettable: true; defaultValue: 0
                    value: Math.round(root._mat.lightnessLight * 100)
                    onCommit: function(v) { root._matugenSet({ lightnessLight: v / 100 }) }
                }
            }
        }
    }

    SettingsCard {
        colors: root.colors
        title: "App theming"
        kana: "配色"
        width: parent.width

        RowToggle {
            colors: root.colors
            title: "Theme apps"
            description: "Recolour GTK and app themes to match the scheme."
            checked: root._theme.themeApps
            onToggle: function(v) { root._theme.themeApps = v; root._runHub(["hypr", "theme-apps", v ? "on" : "off"]) }
        }

        RowDropdown {
            colors: root.colors
            title: "GTK theme"
            description: "Base GTK theme that apps build on."
            value: root._theme.gtkTheme
            model: [ { mode: "adw", label: "Adw" }, { mode: "adwaita", label: "Adwaita" }, { mode: "system", label: "System" } ]
            onSelect: function(v) { root._theme.gtkTheme = v; root._runHub(["hypr", "gtk-theme", v]) }
        }

        RowToggle {
            colors: root.colors
            title: "GNOME accent"
            description: "Sync the GNOME accent colour to the scheme."
            checked: root._theme.gnomeAccent
            onToggle: function(v) { root._theme.gnomeAccent = v; root._runHub(["hypr", "gnome-accent", v ? "on" : "off"]) }
        }

        RowAction {
            colors: root.colors
            title: "Ryoku signature"
            description: "Apply the Ryoku theme: frame bars, zero roundness, mono scheme."
            valueLabel: "APPLY"
            onClicked: root._runHub(["hypr", "ryoku-theme"])
        }
    }

    SettingsCard {
        colors: root.colors
        title: "Wallpaper"
        kana: "壁"
        width: parent.width

        RowDropdown {
            colors: root.colors
            title: "Reveal"
            description: "The transition played when the wallpaper changes."
            value: root._reveal
            model: root._revealModel
            onSelect: function(v) {
                root._reveal = v
                Quickshell.execDetached(["ryoku-shell", "call", "settings.patch",
                    JSON.stringify({ path: "wallpaper.transition_preset", value: v })])
            }
        }
    }
}
