pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../Singletons"

// Window Manager (COMPOSITOR). The active compositor's exclusive settings, drawn
// from the rows the provider ships (ProviderSchema), so a new compositor's knobs
// arrive with its package and never a Hub edit. It shows only the running
// provider: settings apply at the next login and the other compositor's store is
// unreachable from here, so there is nothing to edit for it. The head names the
// compositor; the switch to another lives here too, beside the honest list of
// what this compositor cannot do (the losses `apply --preview` reports, the same
// reasons that keep a hidden row from reading as a bug). Every setting rides the
// shared store (hub.hyprVal/hyprEdit) and the shared schema renderer, so the two
// compositors are one page by construction, not two files kept in step.
Item {
    id: pg
    property var hub

    function cap(s) { s = String(s || ""); return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
    readonly property string providerName: Settings.provider
    readonly property string pTitle: pg.providerName !== "" ? pg.cap(pg.providerName) : I18n.tr("Window Manager")
    readonly property string pEyebrow: I18n.tr("COMPOSITOR")
    readonly property string pBlurb: I18n.tr("Settings only this compositor has. Changes apply at your next login.")

    function hv(path) { return pg.hub ? pg.hub.hyprVal(path) : undefined }
    function cv(path) { return pg.hub ? pg.hub.hyprCommittedVal(path) : undefined }

    // the provider's rows for the shared page. ProviderSchema.revision is read so
    // the list rebuilds when the fetch lands.
    readonly property var rows: { ProviderSchema.revision; return ProviderSchema.rowsFor("windowmanager"); }

    // draft/committed are flat maps off the store (dotted keys), the shape the
    // settings sheet reads. draft depends on hyprVal, so an edit rebuilds it.
    readonly property var draft: {
        var d = {};
        if (pg.hub)
            for (var i = 0; i < pg.rows.length; i++) { var k = pg.rows[i].key; if (k) d[k] = pg.hv(k); }
        return d;
    }
    readonly property var committed: {
        var d = {};
        if (pg.hub)
            for (var i = 0; i < pg.rows.length; i++) { var k = pg.rows[i].key; if (k) d[k] = pg.cv(k); }
        return d;
    }

    // the cannot-do lines: the provider's unhonored reasons, deduped (many
    // keybinds collapse to one "no scratchpad" reason) and shown verbatim.
    readonly property var cannotDo: {
        ProviderSchema.revision;
        var seen = {}, out = [];
        var u = ProviderSchema.unhonored || [];
        for (var i = 0; i < u.length; i++) {
            var r = u[i] ? u[i].reason : "";
            if (r && !seen[r]) { seen[r] = true; out.push(r); }
        }
        return out;
    }

    function focusKey(k) { sp.focusKey(k) }
    SchemaPage {
        id: sp
        anchors.fill: parent
        schema: pg.rows
        draft: pg.draft
        defaults: pg.committed
        advanced: pg.hub ? pg.hub.advanced : false
        title: pg.pTitle
        eyebrow: pg.pEyebrow
        blurb: pg.pBlurb
        query: pg.hub ? pg.hub.query : ""
        onEdited: (k, v) => { if (pg.hub) pg.hub.hyprEdit(k, v); }
        onPickRequested: (r) => { if (pg.hub) pg.hub.openPick(r); }

        // extras sit full width above the settings sheet: the switch to another
        // compositor, and the honest cannot-do list.
        Column {
            width: parent.width
            spacing: Tokens.s5

            CompositorControl {
                id: wmPicker
                width: parent.width
                onChose: (target, current) => wmSheet.open(target, current)
            }

            Section {
                id: cannotSec
                width: parent.width
                visible: pg.cannotDo.length > 0
                title: I18n.tr("WHAT %1 CANNOT DO").arg(pg.pTitle.toUpperCase())

                Column {
                    width: cannotSec.width
                    spacing: Tokens.s2

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: I18n.tr("These settings have no equivalent here. They stay in your store and return if you switch back.")
                        color: Tokens.inkFaint
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                        lineHeight: 1.3
                    }
                    Repeater {
                        model: pg.cannotDo
                        Row {
                            required property var modelData
                            width: cannotSec.width
                            spacing: Tokens.s2
                            Text {
                                text: "\u00b7"
                                color: Tokens.inkFaint
                                font.family: Tokens.mono
                                font.pixelSize: Tokens.fSmall
                            }
                            Text {
                                width: cannotSec.width - Tokens.s3
                                wrapMode: Text.WordWrap
                                text: parent.modelData
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall
                                lineHeight: 1.3
                            }
                        }
                    }
                }
            }
        }
    }

    // the destructive switch confirmation, a full-page overlay; reload the picker
    // when it closes so the active row is fresh.
    CompositorSwitchSheet {
        id: wmSheet
        anchors.fill: parent
        onClosed: wmPicker.reload()
    }
}
