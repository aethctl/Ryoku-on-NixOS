package main

import (
	"encoding/json"
	"os"
	"strings"

	wm "ryoku-wm"
)

// Every entry here must actually be honoured in act, apply or plugins. Claiming
// one this provider cannot perform is worse than omitting it: the desktop would
// offer a control that does nothing.
//
// CapNativeOverview is absent because Hyprland ships no overview, so the shell
// draws its own.
var capsManifest = []wm.Capability{
	wm.CapWorkspaces,
	wm.CapSpecialWorkspace,
	wm.CapWorkspaceMoveToOutput,
	wm.CapWindowWorkspaceMap,
	wm.CapWindowGeometry,
	wm.CapFocusHistory,
	wm.CapWindowRules,
	wm.CapLayerRules,
	wm.CapSubmap,
	wm.CapGlobalShortcuts,
	wm.CapFocusGrab,
	wm.CapScreenShader,
	wm.CapPlugins,
	wm.CapLiveConfigEval,
	wm.CapConfigReload,
	wm.CapAnimations,
	wm.CapCursorSet,
	wm.CapOutputPower,
	wm.CapKeyboardLayoutSwitch,
	wm.CapMonitorConfig,
	wm.CapOutputMirror,
	wm.CapOutputHdr,
	wm.CapWindowFloat,
	wm.CapTiledLayout,
	wm.CapSessionExit,
}

// The packages ryoku-desktop-hyprland installs for the compositor: Hyprland
// itself, its plugins, its portal and its satellites. Kept in step with that
// package's depends (release/packages/ryoku-desktop-hyprland/PKGBUILD); this is
// the list a switch away from Hyprland reclaims, minus ryoku-desktop, which is
// shared with the compositor that replaces it.
var compositorPackages = []string{
	"hyprland",
	"hypr-dynamic-cursors",
	"ryoku-hypr-plugins",
	"hyprglass",
	"imgborders",
	"ryoku-keysounds",
	"hyprpolkitagent",
	"xdg-desktop-portal-hyprland",
	"hyprland-preview-share-picker",
	"hypridle",
	"hyprpicker",
}

// The manifest is fixed, not probed: Hyprland does not gain features while
// running, and caps is read during startup.
func runCaps() error {
	caps := wm.Caps{
		Name:           wm.ProviderHyprland,
		Version:        probeVersion(),
		Instance:       instanceHandle(),
		Supports:       capsManifest,
		WorkspaceModel: wm.WorkspaceModelFixed,
		// wm.hyprland.* keys stay in the store untouched while another
		// compositor is active, so they are still there on the way back.
		SettingDomains: []string{"desktop", "wm." + wm.ProviderHyprland},
		ConfigFiles:    wm.ConfigFiles(wm.ProviderHyprland),
		GeneratedFiles: wm.GeneratedConfig(wm.ProviderHyprland),
		PortalBackend:  "hyprland",
		Packages:       compositorPackages,
	}
	enc := json.NewEncoder(stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(caps)
}

// instanceHandle is opaque to consumers, which only string-compare it.
func instanceHandle() string {
	if !live() {
		return ""
	}
	return os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
}

// Probed best-effort: the installer and doctor need a manifest before any
// compositor is running.
func probeVersion() string {
	if !live() {
		return ""
	}
	out, err := ctl("version", "-j")
	if err != nil {
		return ""
	}
	var v struct {
		Tag string `json:"tag"`
	}
	if json.Unmarshal(out, &v) != nil {
		return ""
	}
	return strings.TrimSpace(v.Tag)
}
