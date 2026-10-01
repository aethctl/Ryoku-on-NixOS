pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../Singletons"
import Ryoku.Ui.Singletons
import "PythonOpts.js" as PythonOpts

// Options for the Python music face. Upstream hides the art, time, artist and
// spectrum automatically below size thresholds; this panel lets the user pin
// each part on or off (the first pin turns auto-fit off) through the widget's
// <prefix>Opts JSON, which the provider writes into the live face.
Column {
    id: opts

    property string widget: ""
    width: parent ? parent.width : 0
    spacing: Theme.s1

    readonly property var store: PythonOpts.read(Config, opts.widget)
    readonly property bool autoFit: opts.store.autoFit !== false
    function on(key, dflt) { return opts.store[key] === undefined ? dflt : opts.store[key] === true; }
    function pin(key, cur) {
        const next = { };
        next[key] = !cur;
        if (opts.autoFit)
            next.autoFit = false;
        PythonOpts.putMany(Config, opts.widget, next);
    }

    MenuSection { label: I18n.tr("Player"); gloss: "音楽" }
    MenuRow {
        label: I18n.tr("Album art")
        value: opts.on("showArt", true) ? I18n.tr("On") : I18n.tr("Off")
        on: opts.on("showArt", true)
        closeOnTrigger: false
        onTriggered: opts.pin("showArt", opts.on("showArt", true))
    }
    MenuRow {
        label: I18n.tr("Track time")
        value: opts.on("showTime", true) ? I18n.tr("On") : I18n.tr("Off")
        on: opts.on("showTime", true)
        closeOnTrigger: false
        onTriggered: opts.pin("showTime", opts.on("showTime", true))
    }
    MenuRow {
        label: I18n.tr("Artist")
        value: opts.on("showArtist", true) ? I18n.tr("On") : I18n.tr("Off")
        on: opts.on("showArtist", true)
        closeOnTrigger: false
        onTriggered: opts.pin("showArtist", opts.on("showArtist", true))
    }
    MenuRow {
        label: I18n.tr("Spectrum")
        value: opts.on("showBars", true) ? I18n.tr("On") : I18n.tr("Off")
        on: opts.on("showBars", true)
        closeOnTrigger: false
        onTriggered: opts.pin("showBars", opts.on("showBars", true))
    }
    MenuRow {
        label: I18n.tr("Auto-fit")
        value: opts.autoFit ? I18n.tr("On") : I18n.tr("Off")
        on: opts.autoFit
        closeOnTrigger: false
        onTriggered: PythonOpts.put(Config, opts.widget, "autoFit", !opts.autoFit)
    }
}
