pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell

// The Edit widgets session (docs/stage.md, "Session model"): one desktop, one
// monitor, never two. It carries the one selected widget and the drop-down that
// is open, and mirrors the Stage Editor's chrome: the chrome owns the walk-back
// (its undo stack covers every edit, including a slot drag or resize), so
// nothing here is persisted and there is no Save and no Reset: the desktop is
// the document.
Singleton {
    id: root

    // "" | "widgets".
    property string mode: ""
    // The screen the session was opened on (its desktop lifts, its editor shows).
    property string monitor: ""
    // Selected widget id ("clock", "plugin:x"), or "" for none.
    property string selected: ""
    // The drop-down open under a toolbar button: "" | "add".
    property string panel: ""

    readonly property bool active: root.mode !== ""
    readonly property bool widgets: root.mode === "widgets"

    signal left()

    function onMonitor(name) { return root.active && ("" + name) === root.monitor; }

    function enterWidgets(monitor) {
        root.selected = "";
        root.panel = "";
        root.monitor = "" + (monitor || "");
        root.mode = "widgets";
    }
    function leave() {
        if (!root.active)
            return;
        root.mode = "";
        root.selected = "";
        root.panel = "";
        root.left();
    }

    function select(id) { root.selected = "" + id; }
    function deselect() { root.selected = ""; }
    function toggleSelect(id) {
        if (root.selected === ("" + id))
            root.deselect();
        else
            root.select(id);
    }

    function openPanel(kind) { root.panel = "" + kind; }
    function closePanel() { root.panel = ""; }
    function togglePanel(kind) { root.panel = root.panel === ("" + kind) ? "" : ("" + kind); }

    // Escape unwinds one level per press: an open drop-down, then the
    // selection, then the session. Returns what it did.
    function escapeStep() {
        if (root.panel !== "") {
            root.panel = "";
            return "panel";
        }
        if (root.selected !== "") {
            root.selected = "";
            return "selection";
        }
        root.leave();
        return "leave";
    }
}
