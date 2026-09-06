import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import "qml"
import "qml/services"

ShellRoot {
    id: root

    property bool configLoaded: Config.configLoaded
    onConfigLoadedChanged: {
        if (configLoaded && (root._pendingShow || root._startVisible))
            Qt.callLater(root._load)
    }

    property double selectorOpenRequestedMs: 0
    property bool selectorTimingPending: false
    property string selectorTimingLogFile: Config.cacheDir + "/wallpaper/selector-timing.log"
    property var _timingLogQueue: []

    function _enqueueTimingLine(message) {
        root._timingLogQueue.push(Date.now() + " " + message)
        root._flushTimingLogQueue()
    }

    function _flushTimingLogQueue() {
        if (_timingLogProcess.running || _timingLogQueue.length === 0)
            return

        var line = _timingLogQueue.shift()
        _timingLogProcess.command = [
            "bash", "-lc",
            "mkdir -p " + JSON.stringify(Config.cacheDir + "/wallpaper")
                + " && printf '%s\\n' " + JSON.stringify(line)
                + " >> " + JSON.stringify(selectorTimingLogFile)
        ]
        _timingLogProcess.running = true
    }

    function _beginSelectorTiming() {
        root.selectorOpenRequestedMs = Date.now()
        root.selectorTimingPending = true
        _logWithRam("open requested")
    }

    function _logWithRam(label) {
        _ramProbeLabel = label
        _ramProbe.command = ["bash", "-c",
            "awk '/^(VmSize|VmRSS):/{print $2}' /proc/$PPID/status; " +
            "awk '/^Pss:/{s+=$2} END{print s}' /proc/$PPID/smaps_rollup"
        ]
        _ramProbe.running = true
    }
    property string _ramProbeLabel: ""
    property var _ramProbe: Process {
        id: ramProbe
        property string _stdout: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => ramProbe._stdout += data
        }
        onExited: {
            var lines = ramProbe._stdout.trim().split("\n")
            var vssMb = (parseInt(lines[0]) / 1024).toFixed(1)
            var rssMb = (parseInt(lines[1]) / 1024).toFixed(1)
            var pssMb = (parseInt(lines[2]) / 1024).toFixed(1)
            var msg = "wallpaper-selector timing: " + root._ramProbeLabel
                + " (rss: " + rssMb + " MB, pss: " + pssMb + " MB, vss: " + vssMb + " MB)"
            console.log(msg)
            root._enqueueTimingLine(msg)
            ramProbe._stdout = ""
        }
    }

    Colors {
        id: colors
    }

    // The process stays resident so Super+W never pays a quickshell boot, but
    // the picker's QML tree (thumbnails, browsers, previews: several hundred
    // MB) is built on show and torn down once the hide animation is over. A
    // rebuild costs about a quarter of a second; holding it costs that memory
    // all day. A crashed instance relaunched by the verb starts visible
    // (RYOGAMI_START_VISIBLE).
    property bool _startVisible: Quickshell.env("RYOGAMI_START_VISIBLE") === "1"
    property bool _pendingShow: false

    function _load() {
        if (wallpaperSelectorLoader.active || !Config.configLoaded)
            return
        root._beginSelectorTiming()
        wallpaperSelectorLoader.active = true
    }

    function _setShowing(on) {
        if (on) {
            unloadTimer.stop()
            root._pendingShow = true
            if (wallpaperSelectorLoader.item) {
                wallpaperSelectorLoader.item.showing = true
                root._pendingShow = false
            } else {
                root._load()
            }
            return
        }
        root._pendingShow = false
        if (wallpaperSelectorLoader.item) {
            wallpaperSelectorLoader.item.showing = false
            unloadTimer.restart()
        }
    }

    function _toggleShowing() {
        var item = wallpaperSelectorLoader.item
        root._setShowing(!(item && item.showing))
    }

    Timer {
        id: unloadTimer
        interval: 900
        onTriggered: {
            var item = wallpaperSelectorLoader.item
            if (item && !item.showing)
                wallpaperSelectorLoader.active = false
        }
    }

    Connections {
        target: DaemonClient
        function onWallpaperToggle() { root._toggleShowing() }
        function onWallpaperShow() { root._setShowing(true) }
        function onWallpaperHide() { root._setShowing(false) }
    }

    Loader {
        id: wallpaperSelectorLoader
        active: false
        source: "qml/wallpaper/WallpaperSelector.qml"
        onLoaded: {
            if (root.selectorTimingPending) {
                var qmlLoadMs = Date.now() - root.selectorOpenRequestedMs
                root._logWithRam("qml loaded in " + qmlLoadMs + " ms")
            }
            item.colors = Qt.binding(() => colors)
            item.showing = root._startVisible || root._pendingShow
            root._startVisible = false
            root._pendingShow = false
            item.showingChanged.connect(function() {
                if (!item.showing)
                    unloadTimer.restart()
            })
            item.uiReady.connect(function() {
                if (!root.selectorTimingPending) return
                var elapsed = Date.now() - root.selectorOpenRequestedMs
                var count = item.selectorService ? item.selectorService.filteredModel.count : 0
                root._logWithRam("ready in " + elapsed + " ms (items: " + count + ")")
                root.selectorTimingPending = false
            })
        }
    }

    property var _timingLogProcess: Process {
        id: timingLogProcess
        command: ["bash", "-lc", "true"]
        onExited: root._flushTimingLogQueue()
    }

    IpcHandler {
        target: "wallpaper-ui"

        function refresh() {
            if (wallpaperSelectorLoader.item && wallpaperSelectorLoader.item.selectorService)
                wallpaperSelectorLoader.item.selectorService.refreshFromDb()
        }

        function steamUpdate() {
            if (wallpaperSelectorLoader.item && wallpaperSelectorLoader.item.swService)
                wallpaperSelectorLoader.item.swService.refreshDownloadStatus()
        }
    }
}
