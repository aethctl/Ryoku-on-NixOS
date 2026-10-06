pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import stage
import stage.modules.common as StageIsland
import "Singletons" as StageCfg
import "../desktop/Singletons" as WidgetStore
import "../visualizer/Singletons" as VizCfg

// The Stage Editor's store bridge: Ryoku's real desktop widgets, seen through
// the ported chrome's own widget API. The chrome (stage.modules.common.Config)
// reads its catalogue, counts and placements through this object instead of
// its island store, so the toolbar edits the desktop the user actually has:
// widgets.json for the built-ins and hosted faces, plugins.json (through the
// place tool) for plugin tiles, and the visualizer's own config for the bar.
//
// One per editing screen, owned by that screen's Desktop; the chrome installs
// it while the mode frames that monitor and drops it on the way out.
Scope {
    id: root

    // The screen this provider speaks for (kept for diagnostics; Ryoku's
    // widget store is not per-monitor forked the way the island's is).
    property string monitor: ""
    // The roster rows, in the chrome's row shape: {id, label, icon, enabled,
    // group}. Fed from Desktop.addItems, so the catalogue is exactly what the
    // desktop can place, and stays reactive with it.
    property var rows: []
    // The plugin place tool (dev checkout or installed path).
    property string placeTool: "ryoku-plugins-place"
    // Ryoku's live wallpaper, mirrored into the chrome's read path so the
    // folder browser and the colour previews start from what the desktop
    // actually shows (the picks themselves flow back through the shim).
    property string wallpaperPath: ""

    // ── The chrome's view ────────────────────────────────────────────────────

    // The catalogue, in the drawer's row shape.
    readonly property var catalogue: {
        const out = [];
        for (const r of root.rows)
            out.push({ widgetId: r.id, name: r.label, icon: r.icon,
                category: r.group === "" ? "Ryoku" : r.group, description: "" });
        return out;
    }

    // The placed widgets, in the island's entry shape (Ryoku widgets are
    // singletons: one entry, id == widgetId).
    readonly property var activeWidgets: {
        const out = [];
        for (const r of root.rows)
            if (r.enabled)
                out.push({ id: r.id, widgetId: r.id });
        return out;
    }

    // The drop grid, from Ryoku's own stage settings.
    readonly property bool snapEnabled: StageCfg.Config.editGridSnap
    readonly property real gridSize: StageCfg.Config.editGridSize
    function toggleSnap() {
        StageCfg.Config.toggleEditGridSnap();
    }

    function count(widgetId) {
        for (const r of root.rows)
            if (r.id === widgetId)
                return r.enabled ? 1 : 0;
        return 0;
    }

    // ── Writers ──────────────────────────────────────────────────────────────

    // Enable a widget, optionally at a drop point, and record the walk-back:
    // the undo of an add is the state before it (a disable, or the old
    // placement a re-add moved), the redo is the same write again. Ryoku's
    // built-ins and hosted faces place through widgets.json (anchor "free" +
    // x/y); plugin tiles through the place tool; the visualizer owns its own
    // placement and is only switched on here.
    function addWidget(widgetId, x, y, monitorName) {
        const before = root.snapshot(widgetId);
        root._applyAdd(widgetId, x, y);
        GlobalStates.editHistoryPush({
            "undo": () => root.restore(widgetId, before),
            "redo": () => root._applyAdd(widgetId, x, y)
        });
        return widgetId;
    }

    function _applyAdd(widgetId, x, y) {
        const store = WidgetStore.Config;
        if (widgetId.indexOf("plugin:") === 0) {
            const pid = widgetId.slice(7);
            root.enqueue([root.placeTool, pid, "enabled", "true"]);
            if (x !== undefined && y !== undefined)
                root.enqueue([root.placeTool, pid, "desktopWidget", "" + Math.round(x), "" + Math.round(y)]);
            return;
        }
        if (widgetId === "visualizer") {
            VizCfg.Config.setEnabled(true);
            return;
        }
        if (x === undefined || y === undefined) {
            store.set(widgetId + "Enabled", true);
            return;
        }
        const patch = {};
        patch[widgetId + "Enabled"] = true;
        patch[widgetId + "Anchor"] = "free";
        patch[widgetId + "X"] = Math.round(x);
        patch[widgetId + "Y"] = Math.round(y);
        store.setMany(patch);
    }

    function removeWidget(instanceId) {
        root.restore(instanceId, null);
    }

    // The state a restore needs, or null when the widget is not on the
    // desktop (the undo of an add is then a plain disable). For a
    // built-in/face: its placement keys; for a plugin: its whole plugins.json
    // entry (through Registry's merged placement); for the visualizer, a
    // marker (only the flag matters).
    function snapshot(instanceId) {
        const store = WidgetStore.Config;
        if (instanceId.indexOf("plugin:") === 0) {
            const pid = instanceId.slice(7);
            const e = (WidgetStore.Registry.allPlugins || []).find(p => p.id === pid) || null;
            if (!e || !(e.placement && e.placement.enabled === true))
                return null;
            return { plugin: pid, entry: JSON.parse(JSON.stringify(e.placement)) };
        }
        if (instanceId === "visualizer")
            return VizCfg.Config.enabled ? { viz: true } : null;
        if (store[instanceId + "Enabled"] !== true)
            return null;
        return { key: instanceId,
            anchor: store[instanceId + "Anchor"],
            x: store[instanceId + "X"],
            y: store[instanceId + "Y"] };
    }

    // Put a widget back the way a snapshot found it; `null` means it was not
    // on the desktop, so this is the disable path.
    function restore(instanceId, snap) {
        const store = WidgetStore.Config;
        if (instanceId.indexOf("plugin:") === 0) {
            const pid = instanceId.slice(7);
            if (snap === null || snap === undefined) {
                root.enqueue([root.placeTool, pid, "enabled", "false"]);
                return;
            }
            if (snap.entry && Object.keys(snap.entry).length > 0)
                root.enqueue([root.placeTool, pid, "restore", JSON.stringify(snap.entry), "true"]);
            else
                root.enqueue([root.placeTool, pid, "enabled", "true"]);
            return;
        }
        if (instanceId === "visualizer") {
            VizCfg.Config.setEnabled(snap !== null && snap !== undefined);
            return;
        }
        if (snap === null || snap === undefined) {
            store.set(instanceId + "Enabled", false);
            return;
        }
        const patch = {};
        patch[instanceId + "Enabled"] = true;
        patch[instanceId + "Anchor"] = snap.anchor;
        patch[instanceId + "X"] = snap.x;
        patch[instanceId + "Y"] = snap.y;
        store.setMany(patch);
    }

    // ── The place tool, one command at a time ────────────────────────────────

    // The chrome's store seam is one global; a monitor switch mounts the next
    // screen's provider before this one dies, so only clear the slot when it
    // still holds this provider.
    Component.onCompleted: StageIsland.Config.widgetProvider = root
    Component.onDestruction: if (StageIsland.Config.widgetProvider === root)
        StageIsland.Config.widgetProvider = null

    property var _queue: []
    Process {
        id: placeProc
        onExited: (code, status) => root._runNext()
    }
    // The queue seam: the desktop records a plugin gesture's redo as the same
    // place-tool command, run back through here so it can't trample an
    // in-flight undo.
    function enqueue(cmd) {
        root._queue = root._queue.concat([cmd]);
        if (!placeProc.running)
            root._runNext();
    }
    function _runNext() {
        if (root._queue.length === 0)
            return;
        const cmd = root._queue[0];
        root._queue = root._queue.slice(1);
        placeProc.command = cmd;
        placeProc.running = true;
    }
}
