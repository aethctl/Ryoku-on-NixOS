// Package wm is the seam between the Ryoku desktop and the window manager under
// it. A provider binary implements four verbs (caps, watch, act, apply) and
// nothing else needs to know which compositor is running.
//
// Consumers ask what the compositor can do, never which one it is. A compositor
// name in a conditional means a capability is missing; bin/ryoku-dev-verify-wm-isolation
// enforces that.
package wm

type Capability string

const (
	CapWorkspaces            Capability = "workspaces"
	CapSpecialWorkspace      Capability = "specialWorkspace"
	CapWorkspaceMoveToOutput Capability = "workspaceMoveToOutput"
	CapWindowWorkspaceMap    Capability = "windowWorkspaceMap"
	CapWindowGeometry        Capability = "windowGeometry"
	CapFocusHistory          Capability = "focusHistory"
	CapWindowRules           Capability = "windowRules"
	CapLayerRules            Capability = "layerRules"
	CapSubmap                Capability = "submap"
	CapGlobalShortcuts       Capability = "globalShortcuts"
	CapFocusGrab             Capability = "focusGrab"
	CapScreenShader          Capability = "screenShader"
	CapPlugins               Capability = "plugins"
	CapLiveConfigEval        Capability = "liveConfigEval"
	CapConfigReload          Capability = "configReload"
	CapAnimations            Capability = "animations"
	CapCursorSet             Capability = "cursorSet"
	CapNativeOverview        Capability = "nativeOverview"
	// CapOverviewBackdrop is set when the compositor can lift a layer-shell
	// surface into the backdrop it shows behind the workspaces in its overview,
	// so the shell's blurred wallpaper fills that region instead of a flat
	// colour. Named for what the user gets, not for a compositor: an overview
	// that cannot place a surface in its backdrop leaves this off and the shell
	// maps nothing there.
	CapOverviewBackdrop     Capability = "overviewBackdrop"
	CapOutputPower          Capability = "outputPower"
	CapKeyboardLayoutSwitch Capability = "keyboardLayoutSwitch"
	CapMonitorConfig        Capability = "monitorConfig"
	// CapOutputMirror and CapOutputHdr describe per-output behaviours some
	// compositors offer and others cannot: cloning one output onto another, and
	// an HDR/wide-gamut colour pipeline. Named for the behaviour so the Hub gates
	// the control on the capability, never on which compositor is running.
	CapOutputMirror Capability = "outputMirror"
	CapOutputHdr    Capability = "outputHdr"
	CapWindowFloat  Capability = "windowFloat"
	CapTiledLayout  Capability = "tiledLayout"
	CapSessionExit  Capability = "sessionExit"
)

// All is every capability, so a caps payload can carry an explicit boolean for
// each one and a consumer never has to tell absent from false.
func All() []Capability {
	return []Capability{
		CapWorkspaces, CapSpecialWorkspace, CapWorkspaceMoveToOutput,
		CapWindowWorkspaceMap, CapWindowGeometry, CapFocusHistory,
		CapWindowRules, CapLayerRules, CapSubmap, CapGlobalShortcuts,
		CapFocusGrab,
		CapScreenShader, CapPlugins, CapLiveConfigEval, CapConfigReload,
		CapAnimations, CapCursorSet, CapNativeOverview, CapOverviewBackdrop,
		CapOutputPower,
		CapKeyboardLayoutSwitch, CapMonitorConfig, CapOutputMirror,
		CapOutputHdr, CapWindowFloat,
		CapTiledLayout, CapSessionExit,
	}
}

// WorkspaceModel is how a workspace list should be presented. Fixed means stable
// numbered slots a user thinks of by number; dynamic means the set grows and
// shrinks per output, so numbering them would be a lie.
type WorkspaceModel string

const (
	WorkspaceModelFixed   WorkspaceModel = "fixed"
	WorkspaceModelDynamic WorkspaceModel = "dynamic"
)

type Caps struct {
	// Name and Version are diagnostics only. Branching on Name is the
	// anti-pattern this package prevents.
	Name    string `json:"name"`
	Version string `json:"version,omitempty"`
	// Instance is an opaque per-session handle, string-compared and never
	// parsed. The shell daemon restarts mid-session and has to tell a stale
	// incumbent from a same-session double-start; only the compositor knows its
	// own instance. Empty when nothing is running.
	Instance       string         `json:"instance,omitempty"`
	Supports       []Capability   `json:"supports"`
	WorkspaceModel WorkspaceModel `json:"workspaceModel"`
	// SettingDomains are the setting-key prefixes this provider honours in
	// apply. The Hub gates rows on them so no row is shown with no writer.
	SettingDomains []string `json:"settingDomains"`
	// ConfigFiles are the provider's user-editable config paths, relative to
	// ~/.config, for the Hub to offer as an escape hatch. Provider-owned so the
	// Hub never spells a compositor's file names.
	ConfigFiles []string `json:"configFiles,omitempty"`
	// GeneratedFiles are the config files apply authors, relative to ~/.config.
	// They are a pure function of the store, so a caller that restores a state
	// with no store removes them instead of emitting defaults the user never had.
	GeneratedFiles []string `json:"generatedFiles,omitempty"`
	// PortalBackend is the xdg-desktop-portal backend this compositor needs as
	// the preferred default. Doctor repairs portals.conf against it, so the
	// backend name lives with the compositor rather than in a reconciler.
	PortalBackend string `json:"portalBackend,omitempty"`
}

// Has reports whether the provider can honour want. A zero Caps supports
// nothing, so a failed probe degrades rather than assuming.
func (c Caps) Has(want Capability) bool {
	for _, got := range c.Supports {
		if got == want {
			return true
		}
	}
	return false
}

// OwnsDomain matches on the dotted prefix, so "wm.hyprland" owns
// "wm.hyprland.plugins.enabled" without listing every leaf.
func (c Caps) OwnsDomain(key string) bool {
	for _, d := range c.SettingDomains {
		if key == d {
			return true
		}
		if len(key) > len(d) && key[:len(d)] == d && key[len(d)] == '.' {
			return true
		}
	}
	return false
}
