import QtQuick
import Quickshell.Io
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

    // Only a compositor that can lift a layer surface into its overview backdrop
    // has anywhere to put this, so ask before offering it.
    property bool supported: false

    Process {
        running: true
        command: ["ryoku-hub", "wm", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var wms = JSON.parse(this.text) || [];
                    for (var i = 0; i < wms.length; i++) {
                        if (!wms[i].active)
                            continue;
                        var s = (wms[i].caps && wms[i].caps.supports) || [];
                        root.supported = s.indexOf("overviewBackdrop") >= 0;
                        return;
                    }
                } catch (e) {
                    root.supported = false;
                }
            }
        }
    }

    SettingsCard {
        colors: root.colors
        title: I18n.tr("Overview backdrop")
        subtitle: I18n.tr("Render the current wallpaper (optionally blurred) as the backdrop visible in the compositor's overview.")
        width: parent.width
        visible: root.supported

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

        RowInput {
            colors: root.colors
            title: I18n.tr("Backdrop dimming")
            description: I18n.tr("Darken the overview backdrop. 0 = none, 100 = black.")
            value: Config.overviewBackdropDim
            min: 0; max: 100; suffix: "%"
            enabled: Config.overviewBackdropEnabled
            onCommit: function(v) { if (root.saveConfigKey) root.saveConfigKey("overviewBackdrop.dim", v) }
        }
    }
}
