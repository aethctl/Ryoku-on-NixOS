import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/DesktopPage.js" as DesktopSchema
import "../Singletons"

// Desktop: what sits on the desktop itself. The brand mark, the weather source
// the widgets and bar read, the widget board, and the audio visualiser.
// Rendered through the shared SchemaPage; the ledger and action bar belong to
// the shell.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Desktop")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("What sits on your desktop: the brand mark, the pickers, and the audio visualiser.")
    function focusKey(k) { sp.focusKey(k) }

    // ── Pickers ───────────────────────────────────────────────────────────────
    // The theme/wallpaper/media picker layout lives at qsbar.pickerStyle, a nested
    // leaf under the bar's own map. Read and write it through the daemon settings
    // seam so a write patches only that key and never rebuilds the whole qsbar
    // object, which would clobber the bar layout and widgets the panel writes; it
    // applies live like every daemon-backed key.
    readonly property var pickerOptions: ["tanzaku", "hearthstone", "carousel"]
    readonly property string pickerStyle: {
        Settings.revision;
        const v = Settings.get("qsbar.pickerStyle");
        return (v === undefined || v === null || v === "") ? "tanzaku" : v;
    }
    function setPickerStyle(k) {
        if (k) Settings.patch("qsbar.pickerStyle", k);
    }

    SchemaPage {
        id: sp
        anchors.fill: parent
        schema: DesktopSchema.rows
        draft: pg.hub ? pg.hub.draft : null
        defaults: pg.hub ? pg.hub.committed : ({})
        advanced: pg.hub ? pg.hub.advanced : false
        title: pg.pTitle
        eyebrow: pg.pEyebrow
        blurb: pg.pBlurb
        query: pg.hub ? pg.hub.query : ""
        externalReloadCoverError: pg.hub ? pg.hub.reloadCoverCleanupError : ""
        onEdited: (k, v) => { if (pg.hub) pg.hub.edit(k, v); }
        onPickRequested: (r) => { if (pg.hub) pg.hub.openPick(r); }

        // A live, self-contained preview of the desktop visualiser. It rides the
        // shared `extras` slot, so it sits full width between the tabs and the
        // STYLE/SPECTRUM/MOTION cards -- shown only on the Visualizer subtab and
        // folded flat (height 0) elsewhere, so the General tab is untouched.
        VizPreview {
            hub: pg.hub
            anchors.left: parent.left
            anchors.right: parent.right
            visible: sp.tab === "Visualizer"
        }

        // ── PICKERS: how the theme, wallpaper and media pickers are laid out.
        // Folded flat off the General subtab so the shared extras slot leaves no
        // gap on Visualizer, the way the visualiser preview folds off General.
        SettingCard {
            id: pickersCard
            anchors.left: parent.left
            anchors.right: parent.right
            title: I18n.tr("PICKERS")
            kana: "選"
            visible: sp.tab === "General"
            height: visible ? implicitHeight : 0

            SettingRow {
                anchors.left: parent.left
                anchors.right: parent.right
                block: true
                label: I18n.tr("Picker style")
                desc: I18n.tr("How the theme, wallpaper and media pickers are laid out.")
                source: "shell.json"
                Seg {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    options: pg.pickerOptions
                    current: pg.pickerStyle
                    onChose: key => pg.setPickerStyle(key)
                }
            }
        }
    }

    Connections {
        target: pg.hub
        function onInvalidatePageWork() {
            sp.invalidateReloadCoverImport();
        }
    }
}
