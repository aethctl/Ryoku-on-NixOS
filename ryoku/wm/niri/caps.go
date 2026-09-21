package main

import (
	"encoding/json"
	"strings"

	wm "ryoku-wm"
)

// Every entry here must actually be honoured in act or apply. Claiming one this
// provider cannot perform is worse than omitting it: the desktop would offer a
// control that does nothing.
//
// The absences are niri's design, not gaps to fill later:
//
// CapWindowGeometry: a window reports its tile size but no on-screen position,
// so the shell cannot draw windows where they are. It does not need to, because
// CapNativeOverview is present and niri's own overview takes that job.
//
// CapSubmap, CapGlobalShortcuts, CapFocusGrab, CapScreenShader, CapPlugins:
// niri implements none of these protocols or subsystems.
//
// CapLiveConfigEval and CapConfigReload: the config is file-only and niri
// watches it, so there is nothing to evaluate and nothing to trigger.
//
// CapCursorSet: the cursor is a config block, so apply sets it and niri picks
// it up. There is no imperative call to re-assert it after a reload.
//
// CapTiledLayout: the layout is scrollable tiling, with no per-workspace choice
// to make.
//
// CapSpecialWorkspace: niri has no scratchpad workspace.
var capsManifest = []wm.Capability{
	wm.CapWorkspaces,
	wm.CapWorkspaceMoveToOutput,
	wm.CapWindowWorkspaceMap,
	wm.CapFocusHistory,
	wm.CapWindowRules,
	wm.CapLayerRules,
	wm.CapAnimations,
	wm.CapNativeOverview,
	wm.CapOverviewBackdrop,
	wm.CapOutputPower,
	wm.CapKeyboardLayoutSwitch,
	wm.CapMonitorConfig,
	wm.CapWindowFloat,
	wm.CapSessionExit,
	wm.CapNightLight,
}

// The packages ryoku-desktop-niri installs for the compositor: niri, the
// xwayland-satellite X11 bridge, and the GNOME portal backend its caps report.
// Kept in step with that package's depends
// (release/packages/ryoku-desktop-niri/PKGBUILD); this is the list a switch
// away from niri reclaims, minus ryoku-desktop, which is shared with the
// compositor that replaces it.
var compositorPackages = []string{
	"niri",
	"xwayland-satellite",
	"xdg-desktop-portal-gnome",
	"gammastep",
}

// The manifest is fixed, not probed: niri does not gain features while running,
// and caps is read during startup.
func runCaps() error {
	caps := wm.Caps{
		Name:     wm.ProviderNiri,
		Version:  probeVersion(),
		Instance: instanceHandle(),
		Supports: capsManifest,
		// Workspaces are created and removed per output as windows come and
		// go, so presenting them as numbered slots would be a lie.
		WorkspaceModel: wm.WorkspaceModelDynamic,
		// wm.niri.* keys stay in the store untouched while another compositor
		// is active, so they are still there on the way back.
		SettingDomains: []string{"desktop", "wm." + wm.ProviderNiri},
		ConfigFiles:    wm.ConfigFiles(wm.ProviderNiri),
		GeneratedFiles: wm.GeneratedConfig(wm.ProviderNiri),
		PortalBackend:  "gnome",
		NightLightProcess: "gammastep",
		Packages:       compositorPackages,
	}
	enc := json.NewEncoder(stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(caps)
}

// Probed best-effort: the installer and doctor need a manifest before any
// compositor is running.
func probeVersion() string {
	if !live() {
		return ""
	}
	raw, err := request("Version")
	if err != nil {
		return ""
	}
	var v struct {
		Version string `json:"Version"`
	}
	if json.Unmarshal(raw, &v) != nil {
		return ""
	}
	return strings.TrimSpace(v.Version)
}
