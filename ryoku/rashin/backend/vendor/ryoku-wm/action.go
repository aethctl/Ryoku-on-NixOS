package wm

// Actions are semantic ("close this window"), not a dispatcher passthrough. A
// passthrough would re-export one compositor's command language through a
// neutral door and callers would be writing Hyprland dispatchers again.
//
// Renaming an action breaks user keybinds and scripts; treat these as public.

type Action string

const (
	// Window ids are whatever the state frames used; a caller round-trips one
	// and never parses it.
	ActionWindowFocus           Action = "window.focus"
	ActionWindowClose           Action = "window.close"
	ActionWindowFullscreen      Action = "window.fullscreen"
	ActionWindowFloat           Action = "window.float"
	ActionWindowMoveToWorkspace Action = "window.moveToWorkspace"

	// ActionAppFocus is for callers that only know what they launched.
	ActionAppFocus Action = "app.focus"

	ActionWorkspaceFocus         Action = "workspace.focus"
	ActionWorkspaceCycle         Action = "workspace.cycle"
	ActionWorkspaceMoveToOutput  Action = "workspace.moveToOutput"
	ActionWorkspaceToggleSpecial Action = "workspace.toggleSpecial"

	ActionSessionExit Action = "session.exit"
	ActionOutputPower Action = "output.power"

	ActionKeyboardCycleLayout Action = "keyboard.cycleLayout"

	// Submaps back the Hub's keybind recorder: it needs to capture a chord
	// without the session acting on it.
	ActionSubmapEnter Action = "submap.enter"
	ActionSubmapReset Action = "submap.reset"

	// Dispatched only with CapNativeOverview; otherwise the shell draws its own.
	ActionOverviewToggle Action = "overview.toggle"

	// ActionConfigAutoreload brackets a config swap so a half-written tree is
	// never picked up mid-rename.
	ActionConfigReload     Action = "config.reload"
	ActionConfigAutoreload Action = "config.autoreload"

	ActionCursorSet Action = "cursor.set"

	// Transient live overrides, not persisted settings: the launcher suppresses
	// focus-follows-mouse while it is open and restores it on close.
	// ActionFocusFollowsMouse prints the PREVIOUS value so the caller can hand
	// it back, which keeps the restore exact without the provider holding state
	// across two separate invocations.
	ActionScreenShader      Action = "decoration.screenShader"
	ActionFocusFollowsMouse Action = "input.focusFollowsMouse"

	// ActionWorkspaceLayout sets the tiling layout for one workspace.
	ActionWorkspaceLayout Action = "workspace.layout"

	// ActionBorderColors is split from apply because it runs on every wallpaper
	// change, and rewriting plus reloading the config for two colours is slow
	// and visible.
	ActionBorderColors Action = "decoration.borderColors"

	// ActionNightLightOn takes one arg, the colour temperature in Kelvin, and
	// replaces any running backend with one warmed to it. ActionNightLightOff
	// stops the backend; the compositor restores the gamma once the client is
	// gone. Both need CapNightLight.
	ActionNightLightOn  Action = "nightlight.on"
	ActionNightLightOff Action = "nightlight.off"
)

// Capability returns what an action needs, so callers gate on one lookup
// instead of keeping their own table. Focusing and closing a window ride
// foreign-toplevel and need nothing.
func (a Action) Capability() Capability {
	switch a {
	case ActionWindowFloat:
		return CapWindowFloat
	case ActionWindowMoveToWorkspace, ActionWorkspaceFocus, ActionWorkspaceCycle:
		return CapWorkspaces
	case ActionWorkspaceMoveToOutput:
		return CapWorkspaceMoveToOutput
	case ActionWorkspaceToggleSpecial:
		return CapSpecialWorkspace
	case ActionSessionExit:
		return CapSessionExit
	case ActionOutputPower:
		return CapOutputPower
	case ActionKeyboardCycleLayout:
		return CapKeyboardLayoutSwitch
	case ActionSubmapEnter, ActionSubmapReset:
		return CapSubmap
	case ActionOverviewToggle:
		return CapNativeOverview
	case ActionConfigReload, ActionConfigAutoreload:
		return CapConfigReload
	case ActionCursorSet:
		return CapCursorSet
	case ActionBorderColors, ActionFocusFollowsMouse:
		return CapLiveConfigEval
	case ActionScreenShader:
		return CapScreenShader
	case ActionWorkspaceLayout:
		return CapTiledLayout
	case ActionNightLightOn, ActionNightLightOff:
		return CapNightLight
	}
	return ""
}
