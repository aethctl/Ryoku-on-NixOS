pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Discovery for store-installed plugins that can ride the bar. Runs the shared
// discover.sh in --all mode (every installed plugin, enabled or not) so it can
// answer two questions at once:
//   - `barCapable`: every installed plugin whose manifest declares topbarGlyph,
//     for the add-widget picker and the barCatalog (installed != on the bar).
//   - `pluginIds` / `plugins`: the ones actually enabled AND hosted on the bar,
//     which are the layout entries the slot machinery renders.
// Enabled state and per-plugin settings come from the same plugins.json every
// other host reads, so a placement change here retunes the bar live.
Item {
    id: root

    // Every installed plugin (enabled or not), raw discover.sh --all output.
    property var all: []
    // Installed plugins whose manifest lists topbarGlyph in hosts.
    property var barCapable: []
    // Enabled plugins currently hosted on the bar (host === "topbarGlyph").
    property var plugins: []
    property var pluginIds: []

    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _script: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
            + "/quickshell/plugins/discover.sh"
    readonly property string _stateHome: Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")

    width: 0
    height: 0

    function reload() {
        discoverProc.running = false
        discoverProc.running = true
    }

    // Entry for any installed plugin id (searches the full --all set so the
    // catalogue and the render host resolve the same manifest/dir).
    function entryFor(id) {
        for (var i = 0; i < root.all.length; i++)
            if (root.all[i].id === id) return root.all[i]
        return null
    }

    function isEnabledBar(id) { return root.pluginIds.indexOf(id) >= 0 }

    function _manifestHostsBar(p) {
        var hosts = p && p.manifest ? p.manifest.hosts : null
        return Array.isArray(hosts) && hosts.indexOf("topbarGlyph") >= 0
    }

    function syncPlugins(list) {
        root.all = list

        var capable = []
        for (var i = 0; i < list.length; i++)
            if (root._manifestHostsBar(list[i])) capable.push(list[i])
        root.barCapable = capable

        var enabled = []
        for (var k = 0; k < list.length; k++) {
            var p = list[k]
            if (p && p.placement && p.placement.enabled === true
                    && p.placement.host === "topbarGlyph") enabled.push(p)
        }
        root.plugins = enabled

        var ids = []
        for (var j = 0; j < enabled.length; j++) ids.push(enabled[j].id)
        var same = ids.length === root.pluginIds.length
        if (same) {
            for (var m = 0; m < ids.length; m++)
                if (ids[m] !== root.pluginIds[m]) { same = false; break }
        }
        if (!same) root.pluginIds = ids
    }

    Process {
        id: discoverProc
        command: ["bash", root._script, "--all"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var list = []
                try { list = JSON.parse(this.text || "[]") } catch (e) { list = [] }
                root.syncPlugins(Array.isArray(list) ? list : [])
            }
        }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
            + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }

    // A store install/remove bumps the revision; re-scan so a freshly installed
    // bar plugin appears without a shell restart.
    FileView {
        path: root._stateHome + "/ryoku/store/revision.json"
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: root.reload()
    }
}
