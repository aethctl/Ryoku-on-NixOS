import QtQuick
import "../.."
import "../../components"
import "../../services"
import Ryoku.Ui.Singletons

Flow {
    id: root
    property var colors
    property var saveConfigKey

    width: parent ? parent.width : 0
    spacing: 12

    property var _backdropThemes: []

    Component.onCompleted: {
        DaemonClient.call("effects.list", {}, function(result, err) {
            if (err || !result || !result.effects) return
            for (var i = 0; i < result.effects.length; i++) {
                var eff = result.effects[i]
                if (eff.id !== "theme" || !eff.params) continue
                for (var j = 0; j < eff.params.length; j++) {
                    if (eff.params[j].id === "theme") {
                        root._backdropThemes = eff.params[j].options || []
                        return
                    }
                }
            }
        })
    }

    SettingsCard {
        colors: root.colors
        title: I18n.tr("Overview backdrop")
        subtitle: I18n.tr("Render the current wallpaper (optionally blurred) as the backdrop visible in the compositor's overview.")
        width: parent.width

        RowToggle {
            colors: root.colors
            title: I18n.tr("Show wallpaper in overview")
            description: I18n.tr("Serve a copy of the wallpaper as a layer-shell surface the compositor places in the overview backdrop.")
            checked: Config.overviewBackdropEnabled
            onToggle: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.enabled", v) }
        }

        RowToggle {
            colors: root.colors
            title: I18n.tr("Blur the backdrop")
            description: I18n.tr("Apply a Gaussian blur to the overview backdrop. Turn off for a sharp backdrop.")
            checked: Config.overviewBackdropBlurEnabled
            enabled: Config.overviewBackdropEnabled
            onToggle: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.blurEnabled", v) }
        }

        RowInput {
            colors: root.colors
            title: I18n.tr("Blur radius")
            description: I18n.tr("Gaussian blur radius applied to the copy. Higher is softer.")
            value: Config.overviewBackdropBlur
            min: 1; max: 200
            enabled: Config.overviewBackdropEnabled && Config.overviewBackdropBlurEnabled
            onCommit: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.blur", v) }
        }

        RowToggle {
            colors: root.colors
            title: I18n.tr("Always use the current wallpaper")
            description: I18n.tr("Force the backdrop to track whatever wallpaper is applied, overriding any per-card backdrop you've set.")
            checked: Config.overviewBackdropFollowWallpaper
            enabled: Config.overviewBackdropEnabled
            onToggle: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.followWallpaper", v) }
        }

        RowToggle {
            colors: root.colors
            title: I18n.tr("Auto-theme the backdrop")
            description: I18n.tr("Recolour the backdrop with a gowall theme palette.")
            checked: Config.overviewBackdropAutoTheme
            enabled: Config.overviewBackdropEnabled
            onToggle: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.autoTheme", v) }
        }

        RowDropdown {
            colors: root.colors
            title: I18n.tr("Backdrop theme")
            description: I18n.tr("Palette used when auto-theming the backdrop.")
            value: Config.overviewBackdropTheme
            model: root._backdropThemes
            enabled: Config.overviewBackdropEnabled && Config.overviewBackdropAutoTheme
            opacity: enabled ? 1.0 : 0.5
            onSelect: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.theme", v) }
        }

        RowInput {
            colors: root.colors
            title: I18n.tr("Backdrop dimming")
            description: I18n.tr("Darken the overview backdrop. 0 = none, 100 = black.")
            value: Config.overviewBackdropDim
            min: 0; max: 100; suffix: "%"
            enabled: Config.overviewBackdropEnabled
            onCommit: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.dim", v) }
        }

        RowAction {
            colors: root.colors
            title: _refreshState._busy ? I18n.tr("Regenerating...") : I18n.tr("Regenerate backdrop now")
            description: I18n.tr("Re-blur the current wallpaper and respawn the backdrop renderer. Use this after toggling the feature on without applying a new wallpaper.")
            enabled: Config.overviewBackdropEnabled && !_refreshState._busy
            opacity: enabled ? 1.0 : 0.5
            onClicked: {
                _refreshState._busy = true
                DaemonClient.call("wall.refresh_overview_backdrop", {}, function(_r, _e) {
                    _refreshResetTimer.restart()
                })
            }

            QtObject {
                id: _refreshState
                property bool _busy: false
            }
            Timer {
                id: _refreshResetTimer
                interval: 3000
                onTriggered: _refreshState._busy = false
            }
        }
    }
}
