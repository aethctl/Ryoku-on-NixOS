pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"
import Ryoku.FrameBars as FrameModels

Item {
    id: root

    property string side: "left"
    property var confirmed: null
    property var raw: ({})
    property var pending: null
    property int serial: 0
    property string error: ""
    readonly property bool busy: pending !== null

    width: 0
    height: 0

    signal saved(string path, var value)

    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function stable(value) {
        if (Array.isArray(value)) return value.map(root.stable);
        if (value && typeof value === "object") {
            var out = {}, keys = Object.keys(value).sort();
            for (var i = 0; i < keys.length; ++i) out[keys[i]] = root.stable(value[keys[i]]);
            return out;
        }
        return value;
    }
    function same(a, b) { return JSON.stringify(root.stable(a)) === JSON.stringify(root.stable(b)); }
    function valueAt(value, path) {
        var cur = value, parts = String(path).split(".");
        for (var i = 0; i < parts.length; ++i) {
            if (cur === null || cur === undefined || typeof cur !== "object") return undefined;
            cur = cur[parts[i]];
        }
        return cur;
    }
    function absolutePath(path) {
        var clean = String(path || "");
        if (clean === "sidebars" || clean.indexOf("sidebars.") === 0) return clean;
        return "sidebars." + root.side + "." + clean;
    }
    function refresh() {
        if (!Settings.ready)
            return;
        var value = Settings.get("sidebars");
        root.raw = value && typeof value === "object" && !Array.isArray(value) ? root.clone(value) : ({});
        root.confirmed = FrameModels.Sidebars.normalize(value);
        root.finishIfConfirmed();
    }
    function issue(path, wireValue, expectedValue) {
        if (root.busy) {
            root.error = qsTr("Wait for the current change to finish.");
            return false;
        }
        var fullPath = root.absolutePath(path);
        if (!fullPath || fullPath === "sidebars.") {
            root.error = qsTr("This setting could not be saved.");
            return false;
        }
        root.error = "";
        root.pending = { id: ++root.serial, path: fullPath, value: root.clone(expectedValue), wireValue: root.clone(wireValue), acknowledged: false };
        timeout.restart();
        ctl.send(root.pending);
        return true;
    }
    function patch(path, value) { return root.issue(path, value, value); }
    function merged(value) {
        var clean = FrameModels.Sidebars.normalize(value);
        var out = root.raw && typeof root.raw === "object" && !Array.isArray(root.raw) ? root.clone(root.raw) : ({});
        out.motion = clean.motion;
        var fields = ["enabled", "cards", "width", "height", "heightMode", "maxHeight", "position", "pinned", "presentations"];
        for (var i = 0; i < 2; ++i) {
            var name = i === 0 ? "left" : "right";
            var target = out[name] && typeof out[name] === "object" && !Array.isArray(out[name]) ? root.clone(out[name]) : ({});
            for (var j = 0; j < fields.length; ++j) target[fields[j]] = root.clone(clean[name][fields[j]]);
            delete target.geometry;
            out[name] = target;
        }
        delete out.width;
        delete out.depth;
        delete out.push;
        delete out.parallax;
        delete out.wallpaperSlide;
        return out;
    }
    function patchAll(value) {
        var clean = FrameModels.Sidebars.normalize(value);
        return root.issue("sidebars", root.merged(clean), clean);
    }
    function finishIfConfirmed() {
        if (!root.pending || !root.pending.acknowledged) return;
        var relative = root.pending.path === "sidebars" ? "" : root.pending.path.substring("sidebars.".length);
        var actual = relative === "" ? root.confirmed : root.valueAt(root.confirmed, relative);
        if (!root.same(actual, root.pending.value)) return;
        var done = root.pending;
        root.pending = null;
        timeout.stop();
        root.error = "";
        root.saved(done.path, done.value);
    }
    function acceptReply(line) {
        var reply;
        try { reply = JSON.parse(line); } catch (e) { return; }
        if (!root.pending) return;
        if (reply.ok !== true) {
            root.error = String(reply.error || qsTr("The sidebar change was not saved."));
            root.pending = null;
            timeout.stop();
            return;
        }
        var next = root.clone(root.pending);
        next.acknowledged = true;
        root.pending = next;
        root.finishIfConfirmed();
    }

    Component.onCompleted: root.refresh()
    Connections { target: Settings; function onRevisionChanged() { root.refresh(); } }

    Timer {
        id: timeout
        interval: 5000
        onTriggered: {
            root.pending = null;
            root.error = qsTr("The sidebar service did not confirm the change.");
        }
    }
    Socket {
        id: ctl
        path: Settings.sockPath
        parser: SplitParser { onRead: line => root.acceptReply(line) }
        property string queued: ""
        function send(request) {
            queued += "call settings.patch " + JSON.stringify({ id: request.id, path: request.path, value: request.wireValue }) + "\n";
            if (connected) flushQueued(); else connected = true;
        }
        function flushQueued() {
            if (!queued.length) return;
            write(queued);
            flush();
            queued = "";
        }
        onConnectionStateChanged: if (connected) flushQueued()
    }
}
