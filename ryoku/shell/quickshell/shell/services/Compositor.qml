pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string name: ""
    property string focusedOutput: ""
    property string focusedWorkspaceId: ""
    property string focusedWindowId: ""
    property var workspaces: []
    property var windows: []

    readonly property bool isHyprland: name === "hyprland"
    readonly property bool isNiri: name === "niri"

    readonly property var focusedWorkspace: {
        for (let i = 0; i < workspaces.length; ++i) {
            const workspace = workspaces[i]
            if (workspace && String(workspace.id) === focusedWorkspaceId)
                return workspace
        }
        return null
    }

    readonly property var focusedWindow: {
        for (let i = 0; i < windows.length; ++i) {
            const window = windows[i]
            if (window && String(window.id) === focusedWindowId)
                return window
        }
        return null
    }

    readonly property int activeWorkspaceIndex:
        focusedWorkspace && Number(focusedWorkspace.index) > 0
            ? Number(focusedWorkspace.index)
            : -1

    readonly property string sockPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function apply(line) {
        try {
            const frame = JSON.parse(line)
            root.name = frame.compositor || ""
            root.focusedOutput = frame.focusedOutput || ""
            root.focusedWorkspaceId = frame.focusedWorkspaceId || ""
            root.focusedWindowId = frame.focusedWindowId || ""
            root.workspaces = Array.isArray(frame.workspaces) ? frame.workspaces : []
            root.windows = Array.isArray(frame.windows) ? frame.windows : []
        } catch (e) {
        }
    }

    function workspaceByIndex(index, output) {
        const wanted = Number(index)
        for (let i = 0; i < workspaces.length; ++i) {
            const workspace = workspaces[i]
            if (!workspace || Number(workspace.index) !== wanted)
                continue
            if (!output || workspace.output === output)
                return workspace
        }
        return null
    }

    function workspaceHasWindows(index, output) {
        const workspace = workspaceByIndex(index, output)
        if (!workspace)
            return false
        const id = String(workspace.id)
        for (let i = 0; i < windows.length; ++i) {
            const window = windows[i]
            if (window && String(window.workspaceId) === id)
                return true
        }
        return false
    }

    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe compositor\n")
                flush()
            } else {
                retry.restart()
            }
        }
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }
}
