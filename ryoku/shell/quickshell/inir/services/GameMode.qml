pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import inir
import inir.modules.common
import inir.services

/**
 * GameMode service - detects fullscreen windows and disables effects for performance.
 * 
 * Two activation modes:
 * - Manual: user toggle via toggle()/activate()/deactivate(). Persists to file.
 * - Auto-detect: activates when focused window is fullscreen, deactivates
 *   immediately when leaving fullscreen. Applies the same performance
 *   optimizations as manual mode (no panel/background hiding).
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // Public API
    // Visible fullscreen state is already maintained reactively by WorkspaceService.
    // Keep one automatic source of truth here; the old debounced _autoActive
    // cache could remain true after Niri had already reported fullscreen exit.
    readonly property bool _reactiveAutoActive: autoDetect && hasVisibleFullscreenWindow
    readonly property bool active: _manualActive || _reactiveAutoActive
    readonly property bool autoDetect: Config.options?.gameMode?.autoDetect ?? true
    property bool manuallyActivated: _manualActive
    readonly property bool autoActivated: !_manualActive && _reactiveAutoActive

    // Surface mapping caused native crash loops; GameMode only suppresses work.
    
    // True if ANY window in ANY workspace is fullscreen (for toast suppression)
    readonly property bool hasAnyFullscreenWindow: checkAnyFullscreenWindow()

    // True only when a fullscreen window actually owns an active viewport.
    // `window.is_focused` is global and therefore insufficient on multi-output
    // sessions: a fullscreen tile can remain the active tile on an unfocused
    // monitor. WorkspaceService tracks `active_window_id` per workspace, which is the
    // correct per-output owner signal.
    readonly property bool hasVisibleFullscreenWindow: {
        if (!CompositorService.nativeOverview) return hasAnyFullscreenWindow
        return hasFullscreenOnOutput("")
    }
    
    // Suppress niri reload toast briefly after GameMode changes

    // Internal state
    property bool _manualActive: false
    property bool _initialized: false

    // Config-driven behavior (reactive bindings - re-evaluated when Config changes)
    readonly property bool disableAnimations: Config.options?.gameMode?.disableAnimations ?? true
    readonly property bool disableEffects: Config.options?.gameMode?.disableEffects ?? true
    readonly property bool disableVisualizers: Config.options?.gameMode?.disableVisualizers ?? true
    readonly property bool disableReloadToasts: Config.options?.gameMode?.disableReloadToasts ?? true
    readonly property bool minimalMode: Config.options?.gameMode?.minimalMode ?? true
    readonly property bool visualizersSuppressed: active && disableVisualizers
    // Compositor-wide animation control belongs to the window manager's own
    // game mode, not the frame: the frame suppresses its effects and motion
    // through Appearance while this is active.

    // External process control (optional)
    readonly property bool disableDiscoverOverlay: Config.options?.gameMode?.disableDiscoverOverlay ?? true
    readonly property bool suppressNotifications: Config.options?.gameMode?.suppressNotifications ?? true
    readonly property string _discoverOverlayServiceName: "discover-overlay.service"

    // State file path
    readonly property string _stateFile: Directories.stateUserPath + "/gamemode_active"

    // IPC handler for external control
    IpcHandler {
        target: "gamemode"
        function toggle(): void { root.toggle() }
        function activate(): void { root.activate() }
        function deactivate(): void { root.deactivate() }
        function status(): string {
            const state = root.active ? "active" : "inactive";
            const detail = root._manualActive ? "manual" : root.autoActivated ? "auto" : "off";
            return state + " (" + detail + ")";
        }
    }

    function toggle() {
        _manualActive = !_manualActive
        _saveState()
        root._log("[GameMode] Toggled manually:", _manualActive)
    }

    function activate() {
        _manualActive = true
        _saveState()
        root._log("[GameMode] Activated manually")
    }

    function deactivate() {
        _manualActive = false
        _saveState()
        root._log("[GameMode] Deactivated manually")
    }

    function _saveState() {
        saveProcess.running = true
    }

    function _loadState() {
        stateReader.reload()
    }

    // Check if a window is fullscreen. Current Niri snapshots do not expose a
    // dependable is_fullscreen field, so derive it from Niri's own window layout.
    // Do not use foreign-toplevel fullscreen here: those handles can outlive a
    // Niri fullscreen transition and report stale state after the window exited.
    function isWindowFullscreen(window) {
        if (!window) return false
        if (!CompositorService.nativeOverview) return false

        if (window.is_fullscreen === true) return true

        // Fallback: compare window size to output logical size
        const winSize = window.layout?.window_size
        if (!winSize || winSize.length < 2) return false

        const ws = WorkspaceService.workspaces[window.workspace_id]
        let output = ws ? WorkspaceService.outputs[ws.output] : null
        // Niri can deliver WindowLayoutsChanged before the matching workspace
        // snapshot reaches the service. On a single-output session the target
        // is unambiguous, so do not miss that fullscreen transition.
        if (!output) {
            const availableOutputs = Object.values(WorkspaceService.outputs ?? {})
            if (availableOutputs.length === 1) output = availableOutputs[0]
        }
        if (!output?.logical) return false

        const tolerance = 2
        return Math.abs(winSize[0] - output.logical.width) <= tolerance
            && Math.abs(winSize[1] - output.logical.height) <= tolerance
    }
    
    // True when a fullscreen window covers the given output (empty name = any
    // output). Callers gating a per-monitor surface MUST pass their output
    // name: a game on one monitor must not unmap the wallpaper on the other.
    // Goes through isWindowFullscreen because reading `window.is_fullscreen`
    // directly never fires on current niri (see above) — it silently reports
    // "no fullscreen" forever.
    function hasFullscreenOnOutput(outputName: string): bool {
        if (!CompositorService.nativeOverview) return false
        const windows = WorkspaceService.liveWindows
        if (!Array.isArray(windows)) return false

        for (let i = 0; i < windows.length; i++) {
            const w = windows[i]
            const ws = WorkspaceService.workspaces?.[w.workspace_id]
            if (!(ws?.is_active ?? false)) continue
            if (outputName.length > 0 && ws.output !== outputName) continue
            // Prefer the workspace-local active tile. Fall back to global focus
            // only while WorkspaceService has not received an active-window event
            // for this workspace yet.
            const activeWindowId = ws.active_window_id
            if (activeWindowId !== undefined && activeWindowId !== null) {
                if (activeWindowId !== w.id) continue
            } else if (!w.is_focused) {
                continue
            }
            if (isWindowFullscreen(w)) return true
        }
        return false
    }

    // Check if ANY window across all workspaces is fullscreen
    function checkAnyFullscreenWindow(): bool {
        if (!CompositorService.nativeOverview) return false
        const windows = WorkspaceService.liveWindows
        if (!windows || !Array.isArray(windows)) return false
        
        for (let i = 0; i < windows.length; i++) {
            if (isWindowFullscreen(windows[i])) return true
        }
        return false
    }

    // State persistence - read
    FileView {
        id: stateReader
        path: root._stateFile

        onLoaded: {
            const content = stateReader.text()
            root._manualActive = (content.trim() === "1")
            root._initialized = true
            root._log("[GameMode] Initialized, manual:", root._manualActive)
        }

        onLoadFailed: (error) => {
            // File doesn't exist yet, that's fine
            root._manualActive = false
            root._initialized = true
            root._log("[GameMode] Initialized (no saved state)")
        }
    }

    // State persistence - write via process
    Process {
        id: saveProcess
        command: [
            "/usr/bin/bash",
            "-c",
            "mkdir -p '" + Directories.stateUserPath + "'\n" +
            "echo " + (root._manualActive ? "1" : "0") + " > " + root._stateFile
        ]
        onExited: root._log("[GameMode] State saved:", root._manualActive)
    }

    // Initial setup
    Component.onCompleted: {
        root._log("[GameMode] Service starting...")
        Quickshell.execDetached(["/usr/bin/mkdir", "-p", Directories.stateUserPath])
        initTimer.restart()
    }

    Timer {
        id: initTimer
        interval: 200
        onTriggered: root._loadState()
    }


    onActiveChanged: {
        root._log("[GameMode] Active:", active, "(manual:", _manualActive, "auto:", _reactiveAutoActive, ")")

        // External processes control
        if (root.disableDiscoverOverlay) {
            discoverOverlayDebounce.restart()
        }
    }

    // Track last applied state for discover-overlay control
    property bool _lastDiscoverOverlayGameState: false

    Timer {
        id: discoverOverlayDebounce
        interval: 800
        repeat: false
        onTriggered: {
            if (!root.disableDiscoverOverlay)
                return

            const shouldStop = root.active
            if (shouldStop === root._lastDiscoverOverlayGameState)
                return
            root._lastDiscoverOverlayGameState = shouldStop

            if (shouldStop) {
                root._log("[GameMode] Stopping", root._discoverOverlayServiceName)
                discoverOverlayStopProc.running = true
            } else {
                root._log("[GameMode] Starting", root._discoverOverlayServiceName)
                discoverOverlayStartProc.running = true
            }
        }
    }

    Process {
        id: discoverOverlayStopProc
        command: [
            "/usr/bin/bash",
            "-c",
            "systemctl --user stop " + root._discoverOverlayServiceName + " 2>/dev/null; " +
            "pkill -x discover-overlay 2>/dev/null; true"
        ]
        onExited: (code, status) => {
            root._log("[GameMode] discover-overlay stop exited:", code)
        }
    }

    Process {
        id: discoverOverlayStartProc
        command: [
            "/usr/bin/systemctl",
            "--user",
            "start",
            root._discoverOverlayServiceName
        ]
        onExited: (code, status) => {
            root._log("[GameMode] systemctl start exited:", code)
        }
    }
}
