pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: bootstrap

    readonly property bool ready: _done
    property bool _done: false

    readonly property string _configDir: Config.configDir
    readonly property string _configFile: _configDir + "/config.json"
    // The daemon hands the install dir through RYOGAMI_WALL_INSTALL, so this is
    // /usr/share/ryogami/data/config.json.example on a packaged box.
    readonly property string _exampleFile: Config.installDir + "/data/config.json.example"

    // First run seeds ~/.config/ryogami-wall from the shipped example. Nothing
    // else on the system creates it, and until config.json exists Config never
    // loads: the picker never builds (Super+W does nothing) and the daemon has
    // no config. Gating on config.json (not a marker) also makes "delete
    // config.json and reopen" a clean reset, and self-heals a half-written state.
    property var _seedProc: Process {
        id: seedProc
        onExited: bootstrap._done = true
    }

    function _seed() {
        seedProc.command = ["bash", "-c",
            'set -e; d=' + JSON.stringify(_configDir) + '; mkdir -p "$d"; '
          + 'cp ' + JSON.stringify(_exampleFile) + ' "$d/config.json" 2>/dev/null '
          + '|| printf "{}\\n" > "$d/config.json"; '
          + 'touch "$d/.bootstrapped"']
        seedProc.running = true
    }

    property var _configCheck: Process {
        id: configCheck
        onExited: function(code, status) {
            if (code === 0)
                bootstrap._done = true
            else
                bootstrap._seed()
        }
    }

    function _check() {
        configCheck.command = ["test", "-f", _configFile]
        configCheck.running = true
    }

    Component.onCompleted: _check()
}
