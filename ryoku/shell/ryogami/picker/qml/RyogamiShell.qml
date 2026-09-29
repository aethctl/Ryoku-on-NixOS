import QtQuick
import Quickshell
import Quickshell.Io

// The Picker unloads after performance.releaseAfterHideSeconds hidden; until then open and close only map and unmap.
Scope {
    id: shell

    readonly property bool _startVisible: Quickshell.env("RYOGAMI_START_VISIBLE") === "1"
    readonly property var _startSettings: Quickshell.env("RYOGAMI_START_SETTINGS")

    property SettingValue _releaseSetting: SettingValue { key: "performance.releaseAfterHideSeconds" }
    readonly property int _releaseSecs: {
        var v = Number(shell._releaseSetting.value)
        return (isNaN(v) || v <= 0) ? 600 : Math.round(v)
    }

    Loader {
        id: pickerLoader
        active: true
        sourceComponent: Picker {}
    }

    function _ensure() {
        if (!pickerLoader.active)
            pickerLoader.active = true
        return pickerLoader.item
    }
    function show() {
        releaseTimer.stop()
        var p = shell._ensure()
        if (p)
            p.show()
    }
    function hide() {
        if (pickerLoader.item)
            pickerLoader.item.hide()
    }
    function toggle() {
        var p = pickerLoader.item
        if (p && p.shown) {
            p.hide()
        } else {
            releaseTimer.stop()
            p = shell._ensure()
            if (p)
                p.show()
        }
    }
    function settings(tab) {
        releaseTimer.stop()
        var p = shell._ensure()
        if (p)
            p.openSettings(tab)
    }

    Timer {
        id: releaseTimer
        interval: shell._releaseSecs * 1000
        onTriggered: if (pickerLoader.item && !pickerLoader.item.shown) pickerLoader.active = false
    }

    Connections {
        target: pickerLoader.item
        ignoreUnknownSignals: true
        function onShownChanged() {
            if (pickerLoader.item && pickerLoader.item.shown) {
                releaseTimer.stop()
            } else {
                releaseTimer.restart()
                // The daemon swaps in a fresh process while hidden when the GPU preference changed.
                Daemon.call("picker.hidden")
            }
        }
    }

    Connections {
        target: Daemon
        function onEvent(name, data) {
            if (name === "ryogami.wall.toggle")
                shell.toggle()
            else if (name === "ryogami.wall.settings")
                shell.settings(data && data.tab ? data.tab : "")
        }
    }

    IpcHandler {
        target: "ryogami"
        function toggle(): void { shell.toggle() }
        function show(): void { shell.show() }
        function hide(): void { shell.hide() }
        function settings(tab: string): void { shell.settings(tab) }
    }

    Component.onCompleted: {
        if (!pickerLoader.item)
            return
        if (typeof shell._startSettings === "string")
            shell.settings(shell._startSettings)
        else if (shell._startVisible)
            pickerLoader.item.show()
    }
}
