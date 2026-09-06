import QtQuick
import Quickshell.Io

// The candidate palette for a focused wallpaper, straight from the daemon's
// `ryoku-shell matugen-preview` (the exact scheme, mode and achromatic
// neutralisation Set would write) plus the tonal ramps and the 8x8 L* map, so a
// desktop mock and its cava specimen match the applied look. No ryowalls binary:
// the daemon owns palette generation, same as the eventual sunset path.
Item {
    id: root

    property string source: ""    // local image path (file:// stripped) to sample
    property var palette: []      // 16 base16 colours; col() indexes this
    property var tones: null      // matugen tonal ramps, per role
    property var grid: null       // 8x8 L* map for the cava specimen
    property int cols: 0
    property int rows: 0
    property real lstar: 50
    property bool loading: false

    function col(i, fb) {
        return (palette && palette[i] && ("" + palette[i]).length) ? palette[i] : fb
    }

    onSourceChanged: _debounce.restart()
    Timer { id: _debounce; interval: 180; onTriggered: root._run() }

    function _run() {
        var s = ("" + root.source).replace(/^file:\/\//, "")
        root.palette = []; root.tones = null; root.grid = null
        if (!s.length) { root.loading = false; return }
        root.loading = true
        _buf = ""
        proc.running = false
        proc.command = ["ryoku-shell", "matugen-preview", s]
        proc.running = true
    }

    property string _buf: ""
    property var proc: Process {
        id: proc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root._buf += data
        }
        onExited: code => {
            if (code === 0) {
                try {
                    var j = JSON.parse(root._buf)
                    var c = j.colors || {}
                    var arr = []
                    for (var i = 0; i < 16; i++)
                        arr.push(c["color" + i] || "")
                    root.palette = arr
                    root.tones = j.tones || null
                    root.grid = j.grid || null
                    root.cols = j.cols || 0
                    root.rows = j.rows || 0
                    root.lstar = (typeof j.lstar === "number") ? j.lstar : 50
                } catch (e) {
                    root.palette = []; root.tones = null; root.grid = null
                }
            } else {
                root.palette = []; root.tones = null; root.grid = null
            }
            root.loading = false
        }
    }
}
