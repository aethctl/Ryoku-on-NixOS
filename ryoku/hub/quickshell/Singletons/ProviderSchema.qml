pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The active window-manager provider's exclusive settings rows and its cannot-do
// list, read once from `ryoku-hub desktop schema` and `desktop unhonored`. The
// provider owns these rows -- they are its data, migrated out of the Hub -- so
// the window-manager page and the rail gates read them here rather than from a
// compositor named in QML. rowsFor(page) is the routing seam: each row's `page`
// tag names the surface that draws it, defaulting to the shared window-manager
// page, so a bespoke page (plugins, layerrules) asks for its own rows by key and
// the shared page takes the rest.
Singleton {
    id: root

    property var rows: []
    property var unhonored: []
    property bool ready: false
    // ticks on every (re)load so a binding that walks rows/unhonored through a
    // helper re-runs when a fresh fetch lands.
    property int revision: 0

    // Rows a surface draws: those tagged with its page key, an untagged row
    // belonging to the shared window-manager page. Always an array, so a concat
    // against it is safe before the fetch returns.
    function rowsFor(page) {
        var out = [];
        var rs = root.rows || [];
        for (var i = 0; i < rs.length; i++) {
            var p = rs[i].page || "windowmanager";
            if (p === page)
                out.push(rs[i]);
        }
        return out;
    }

    function reload() {
        schemaProc.running = false;
        schemaProc.running = true;
        unhonoredProc.running = false;
        unhonoredProc.running = true;
    }

    Component.onCompleted: root.reload()

    // schema is fixed for the provider's life; unhonored tracks the saved store,
    // so a page may reload() after a save to refresh the cannot-do list.
    Process {
        id: schemaProc
        command: ["ryoku-hub", "desktop", "schema"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var r = JSON.parse(this.text);
                    root.rows = Array.isArray(r) ? r : [];
                } catch (e) {
                    root.rows = [];
                }
                root.ready = true;
                root.revision++;
            }
        }
    }

    Process {
        id: unhonoredProc
        command: ["ryoku-hub", "desktop", "unhonored"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var u = JSON.parse(this.text);
                    root.unhonored = Array.isArray(u) ? u : [];
                } catch (e) {
                    root.unhonored = [];
                }
                root.revision++;
            }
        }
    }
}
