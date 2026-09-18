package wm

// State covers only what Wayland protocols do not carry. Workspaces come from
// ext-workspace-v1 and windows from foreign-toplevel through Quickshell;
// mirroring those here would mean two models of the same thing drifting.
//
// The residue: the focused output (resolved on every keypress, so it must not
// cost a fork), which workspace a window is on, focus order, window geometry,
// and output geometry for the wallpaper pipeline.

type FrameKind string

const (
	FrameFocus      FrameKind = "focus"
	FrameKeyboard   FrameKind = "keyboard"
	FrameOutputs    FrameKind = "outputs"
	FrameWorkspaces FrameKind = "workspaces"
	FrameWindows    FrameKind = "windows"
	// FrameReady marks the first full sync, so a consumer can tell "nothing
	// yet" from "genuinely empty".
	FrameReady FrameKind = "ready"
)

type Output struct {
	Name            string  `json:"name"`
	Width           int     `json:"width"`
	Height          int     `json:"height"`
	Scale           float64 `json:"scale"`
	Focused         bool    `json:"focused,omitempty"`
	ActiveWorkspace string  `json:"activeWorkspace,omitempty"`
	// EDID identity and physical size. Zero make, model and width together mean
	// no EDID, which is how doctor spots a phantom output.
	Make          string `json:"make,omitempty"`
	Model         string `json:"model,omitempty"`
	PhysicalWidth int    `json:"physicalWidth,omitempty"`
	Disabled      bool   `json:"disabled,omitempty"`
	// Editor detail, filled only by a full state read (runState) for the display
	// page, never by a watch frame: the panel's current and advertised modes, its
	// logical position, wayland transform and VRR state. Mode is the physical
	// "WxH@Hz" the editor sizes tiles from, since Width and Height above are the
	// logical rectangle on a fractional-scale compositor. All omitempty, so a lean
	// watch output stays byte-identical to before.
	X         int      `json:"x,omitempty"`
	Y         int      `json:"y,omitempty"`
	Transform int      `json:"transform,omitempty"`
	VRR       bool     `json:"vrr,omitempty"`
	Mode      string   `json:"mode,omitempty"`
	Modes     []string `json:"modes,omitempty"`
	// Mirror, ColorMode and SdrBrightness are the mirror-and-colour readback the
	// editor pre-fills from, present only where the provider supports the
	// CapOutputMirror / CapOutputHdr behaviours (empty otherwise), so opening the
	// page never clobbers a live HDR or mirror on the next Apply.
	Mirror        string  `json:"mirror,omitempty"`
	ColorMode     string  `json:"colorMode,omitempty"`
	SdrBrightness float64 `json:"sdrBrightness,omitempty"`
}

type Workspace struct {
	// ID is the provider's handle and the only value an action accepts back.
	ID     string `json:"id"`
	Name   string `json:"name"`
	Output string `json:"output,omitempty"`
	Active bool   `json:"active,omitempty"`
	// Windows is a count, which is all the wallpaper occupancy gate needs.
	Windows    int  `json:"windows"`
	Fullscreen bool `json:"fullscreen,omitempty"`
	// Special is always false without CapSpecialWorkspace.
	Special bool `json:"special,omitempty"`
	// Layout is the tiling layout in effect here, empty without CapTiledLayout.
	Layout string `json:"layout,omitempty"`
}

type Window struct {
	ID        string `json:"id"`
	AppID     string `json:"appId,omitempty"`
	Title     string `json:"title,omitempty"`
	Workspace string `json:"workspace,omitempty"`
	Output    string `json:"output,omitempty"`
	// FocusOrder is 0 for the focused window, counting back through history.
	// Meaningful only with CapFocusHistory.
	FocusOrder int  `json:"focusOrder"`
	Floating   bool `json:"floating,omitempty"`
	// Output-logical geometry, present only with CapWindowGeometry. The shell's
	// overview and the screenshot picker draw windows where they are.
	X      int `json:"x,omitempty"`
	Y      int `json:"y,omitempty"`
	Width  int `json:"width,omitempty"`
	Height int `json:"height,omitempty"`
}

// Frame is one line of watch output. Exactly one payload field is set, so a full
// resync and an empty list stay distinguishable.
type Frame struct {
	Kind          FrameKind   `json:"kind"`
	FocusedOutput string      `json:"focusedOutput,omitempty"`
	Outputs       []Output    `json:"outputs,omitempty"`
	Workspaces    []Workspace `json:"workspaces,omitempty"`
	Windows       []Window    `json:"windows,omitempty"`
	// Keyboard layout in effect, and the loaded set, for the bar indicator.
	KeyboardLayout  string   `json:"keyboardLayout,omitempty"`
	KeyboardLayouts []string `json:"keyboardLayouts,omitempty"`
}

// Snapshot is one full read, for the one-shot callers (doctor, the CLI) that
// would otherwise have to run a stream to ask a single question.
type Snapshot struct {
	FocusedOutput   string      `json:"focusedOutput,omitempty"`
	Outputs         []Output    `json:"outputs,omitempty"`
	Workspaces      []Workspace `json:"workspaces,omitempty"`
	Windows         []Window    `json:"windows,omitempty"`
	KeyboardLayout  string      `json:"keyboardLayout,omitempty"`
	KeyboardLayouts []string    `json:"keyboardLayouts,omitempty"`
}

// ApplyReport is what apply prints. Unhonored names every setting the running
// compositor cannot express, so the Hub can mark it, doctor can report it and a
// switch can be previewed before it happens.
type ApplyReport struct {
	Provider  string      `json:"provider"`
	Written   []string    `json:"written,omitempty"`
	Unhonored []Unhonored `json:"unhonored,omitempty"`
	// ReloadNeeded is false on a compositor that watches its own config file.
	ReloadNeeded bool `json:"reloadNeeded,omitempty"`
}

// Unhonored.Reason is user copy, shown verbatim.
type Unhonored struct {
	Key    string `json:"key"`
	Reason string `json:"reason"`
}

// OutputLayout is one output's requested configuration for ApplyOutputs. Only
// the fields both compositors can express live here; a provider still reports
// anything it cannot honour through the ApplyReport, exactly as store apply does.
type OutputLayout struct {
	Name    string `json:"name"`
	Enabled bool   `json:"enabled"`
	// Physical identity survives compositor switches where the same monitor can
	// receive a different connector name. Empty fields keep old name-only layouts
	// and profiles backward compatible.
	Make          string `json:"make,omitempty"`
	Model         string `json:"model,omitempty"`
	PhysicalWidth int    `json:"physicalWidth,omitempty"`
	// Mode is "WxH@Hz"; empty asks for the panel's preferred (automatic) mode.
	Mode string `json:"mode,omitempty"`
	// Scale 0 asks the compositor to choose the scale itself.
	Scale     float64 `json:"scale,omitempty"`
	X         int     `json:"x,omitempty"`
	Y         int     `json:"y,omitempty"`
	Transform int     `json:"transform,omitempty"`
	VRR       bool    `json:"vrr,omitempty"`
	// Mirror is another output's name to clone this one onto, governed by
	// CapOutputMirror. ColorMode ("srgb"|"wide"|"hdr") and SdrBrightness are the
	// colour pipeline, governed by CapOutputHdr. A provider without the behaviour
	// reports the field unhonored rather than dropping it silently, so a profile
	// carried across a compositor switch says what it could not keep.
	Mirror        string  `json:"mirror,omitempty"`
	ColorMode     string  `json:"colorMode,omitempty"`
	SdrBrightness float64 `json:"sdrBrightness,omitempty"`
}
