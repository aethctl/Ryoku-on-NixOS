package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// The neutral settings store as niri reads it: the desktop.* fields niri can
// express, the wm.niri.* exclusives that have no neutral key, the desktop.json
// codec that fills them, the niri defaults the Hub overlays user values on, and
// the settings.kdl generator. Only the leaves niri honours are modelled; apply
// reports everything else in the store as unhonored rather than parsing it.
//
// settings.kdl carries the full effective config, not a diff, because the shipped
// niri tree has no defaults module: config.kdl plus five comment-only seeds, so
// settings.kdl and rebinds.kdl are the only writers of real config. A leaf left
// out here would boot as stock niri, not Ryoku.

// Appearance: the window-frame, gap, shadow and opacity leaves niri can express.
// The rest of the neutral appearance model (blur, glow, per-window dim) has no
// niri setting and is reported unhonored.
type Appearance struct {
	GapsIn          int     `json:"gapsIn"`
	GapsOut         int     `json:"gapsOut"`
	BorderSize      int     `json:"borderSize"`
	Rounding        int     `json:"rounding"`
	ActiveBorder    string  `json:"activeBorder"`
	InactiveBorder  string  `json:"inactiveBorder"`
	Animations      bool    `json:"animations"`
	ActiveOpacity   float64 `json:"activeOpacity"`
	InactiveOpacity float64 `json:"inactiveOpacity"`
	ShadowEnabled   bool    `json:"shadowEnabled"`
	ShadowRange     int     `json:"shadowRange"`
	ShadowColor     string  `json:"shadowColor"`
	ShadowSpread    int     `json:"shadowSpread"`
	ShadowOffsetX   int     `json:"shadowOffsetX"`
	ShadowOffsetY   int     `json:"shadowOffsetY"`
}

// Input: the keyboard, pointer and touchpad leaves niri's input block covers.
type Input struct {
	KbLayout           string  `json:"kbLayout"`
	KbVariant          string  `json:"kbVariant"`
	KbOptions          string  `json:"kbOptions"`
	NumlockByDefault   bool    `json:"numlockByDefault"`
	FollowMouse        int     `json:"followMouse"`
	Sensitivity        float64 `json:"sensitivity"`
	AccelProfile       string  `json:"accelProfile"`
	LeftHanded         bool    `json:"leftHanded"`
	MouseNaturalScroll bool    `json:"mouseNaturalScroll"`
	MouseScrollFactor  float64 `json:"mouseScrollFactor"`
	MiddleClickPaste   bool    `json:"middleClickPaste"`
	NaturalScroll      bool    `json:"naturalScroll"`
	TouchScrollFactor  float64 `json:"touchScrollFactor"`
	TapToClick         bool    `json:"tapToClick"`
	TapAndDrag         bool    `json:"tapAndDrag"`
	Clickfinger        bool    `json:"clickfinger"`
	MiddleEmulation    bool    `json:"middleEmulation"`
	DisableWhileTyping bool    `json:"disableWhileTyping"`
	RepeatRate         int     `json:"repeatRate"`
	RepeatDelay        int     `json:"repeatDelay"`
}

type Cursor struct {
	Theme           string `json:"theme"`
	Size            int    `json:"size"`
	InactiveTimeout int    `json:"inactiveTimeout"`
	HideOnKeyPress  bool   `json:"hideOnKeyPress"`
}

type EnvVar struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

// WindowRule = one user rule: optional app-id/title match + one action.
type WindowRule struct {
	Class  string `json:"class"`
	Title  string `json:"title"`
	Action string `json:"action"`
	Value  string `json:"value"`
}

// AppOverride: per-app appearance. Numeric fields use -1 for "inherit"; niri can
// express opacity, corner radius and border width, nothing else here.
type AppOverride struct {
	Class      string  `json:"class"`
	Title      string  `json:"title"`
	Opacity    float64 `json:"opacity"`
	Rounding   int     `json:"rounding"`
	BorderSize int     `json:"borderSize"`
	Blur       string  `json:"blur"`
	Shadow     string  `json:"shadow"`
	Dim        string  `json:"dim"`
	Anim       string  `json:"anim"`
	Opaque     string  `json:"opaque"`
}

type Autostart struct {
	Command string `json:"command"`
}

// Keybind = a user shortcut. action "exec" runs Value; the window actions take no
// value.
type Keybind struct {
	Keys    string `json:"keys"`
	Action  string `json:"action"`
	Value   string `json:"value"`
	Release bool   `json:"release,omitempty"`
}

type Struts struct {
	Left   int `json:"left"`
	Right  int `json:"right"`
	Top    int `json:"top"`
	Bottom int `json:"bottom"`
}

// Proportions is a list of column-width proportions. It carries as a plain
// comma-separated string ("0.33, 0.5, 0.67") rather than a JSON array so the Hub
// edits it as one text field and compares it as one scalar; niri still gets a
// proportion line per entry. Unmarshal also tolerates the array form and a
// trailing percent, so an older store or a "50%" entry still parses.
type Proportions []float64

func (p Proportions) MarshalJSON() ([]byte, error) {
	parts := make([]string, len(p))
	for i, v := range p {
		parts[i] = kdlNum(v)
	}
	return json.Marshal(strings.Join(parts, ", "))
}

func (p *Proportions) UnmarshalJSON(b []byte) error {
	b = bytes.TrimSpace(b)
	if len(b) == 0 || string(b) == "null" {
		*p = nil
		return nil
	}
	if b[0] == '[' {
		var nums []float64
		if err := json.Unmarshal(b, &nums); err != nil {
			return err
		}
		*p = nums
		return nil
	}
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	*p = parseProportions(s)
	return nil
}

func parseProportions(s string) Proportions {
	var out Proportions
	for _, tok := range strings.FieldsFunc(s, func(r rune) bool { return r == ',' || r == ' ' || r == '\t' }) {
		scale := 1.0
		if strings.HasSuffix(tok, "%") {
			tok = strings.TrimSuffix(tok, "%")
			scale = 0.01
		}
		if v, err := strconv.ParseFloat(tok, 64); err == nil {
			out = append(out, v*scale)
		}
	}
	return out
}

// Niri holds the wm.niri.* exclusives: niri behaviours with no neutral key. This
// is the niri twin of wm.hyprland.*, so the Hub can surface them without every
// other compositor pretending to have them.
type Niri struct {
	PreferNoCSD        bool        `json:"preferNoCsd"`
	HotkeyOverlaySkip  bool        `json:"hotkeyOverlaySkip"`
	ScreenshotPath     string      `json:"screenshotPath"`
	DefaultColumnWidth float64     `json:"defaultColumnWidth"`
	PresetColumnWidths Proportions `json:"presetColumnWidths"`
	CenterFocused      string      `json:"centerFocusedColumn"`
	AlwaysCenterSingle bool        `json:"alwaysCenterSingleColumn"`
	UrgentColor        string      `json:"urgentColor"`
	TabIndicatorWidth  int         `json:"tabIndicatorWidth"`
	TabIndicatorHide   bool        `json:"tabIndicatorHideSingle"`
	InsertHint         bool        `json:"insertHint"`
	AnimationSlowdown  float64     `json:"animationSlowdown"`
	BlockOutApps       string      `json:"blockOutApps"`
	Struts             Struts      `json:"struts"`
	HotCorners         bool        `json:"hotCorners"`
	OverviewZoom       float64     `json:"overviewZoom"`
}

// niriStore is the typed store the generator consumes. Niri stays out of the flat
// desktop marshalling (json:"-") because splitStore routes it under wm.niri.
type niriStore struct {
	Appearance     Appearance        `json:"appearance"`
	Input          Input             `json:"input"`
	Cursor         Cursor            `json:"cursor"`
	Env            []EnvVar          `json:"env"`
	WindowRules    []WindowRule      `json:"windowRules"`
	AppOverrides   []AppOverride     `json:"appOverrides"`
	Autostart      []Autostart       `json:"autostart"`
	Keybinds       []Keybind         `json:"keybinds"`
	Apps           map[string]string `json:"apps,omitempty"`
	KeybindRebinds map[string]string `json:"keybindRebinds,omitempty"`
	Unbinds        []string          `json:"unbinds,omitempty"`
	Niri           Niri              `json:"-"`
}

// neutralStore is desktop.json on disk: { "desktop": {...}, "wm": { "<name>":
// {...} } }. WM is keyed by compositor so apply can see, and preserve, another
// compositor's exclusives without parsing them.
type neutralStore struct {
	Desktop map[string]json.RawMessage `json:"desktop"`
	WM      map[string]json.RawMessage `json:"wm"`
}

// defaultStore is niri's baseline. It differs from Hyprland where niri has its
// own opinion (gaps 16, border width 4, no rounding); the pointer and keyboard
// leaves match the recommended niri session; the wm.niri block is the Ryoku look
// for the settings niri owns alone.
func defaultStore() niriStore {
	return niriStore{
		Appearance: Appearance{
			GapsIn: 16, GapsOut: 16, BorderSize: 4, Rounding: 0,
			ActiveBorder: "#e0563b", InactiveBorder: "#313a4d", Animations: true,
			ActiveOpacity: 1, InactiveOpacity: 1,
			ShadowEnabled: true, ShadowRange: 45, ShadowColor: "#000000",
			ShadowSpread: 0, ShadowOffsetX: 0, ShadowOffsetY: 5,
		},
		Input: Input{
			KbLayout: "us", NumlockByDefault: false, FollowMouse: 0,
			Sensitivity: 0, AccelProfile: "", LeftHanded: false,
			MouseNaturalScroll: false, MouseScrollFactor: 1, MiddleClickPaste: true,
			NaturalScroll: true, TouchScrollFactor: 1,
			TapToClick: true, TapAndDrag: true, Clickfinger: false,
			MiddleEmulation: false, DisableWhileTyping: true,
			RepeatRate: 25, RepeatDelay: 600,
		},
		Cursor:       Cursor{Theme: "Bibata-Modern-Ice", Size: 24, InactiveTimeout: 0, HideOnKeyPress: false},
		Env:          []EnvVar{},
		WindowRules:  []WindowRule{},
		AppOverrides: []AppOverride{},
		Autostart:    []Autostart{},
		Keybinds:     []Keybind{},
		Niri: Niri{
			PreferNoCSD:        true,
			HotkeyOverlaySkip:  true,
			ScreenshotPath:     "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png",
			DefaultColumnWidth: 0.5,
			PresetColumnWidths: []float64{0.33333, 0.5, 0.66667},
			CenterFocused:      "never",
			AlwaysCenterSingle: true,
			UrgentColor:        "#9b0000",
			TabIndicatorWidth:  4,
			TabIndicatorHide:   true,
			InsertHint:         true,
			AnimationSlowdown:  1,
			Struts:             Struts{},
			HotCorners:         false,
			OverviewZoom:       0.5,
		},
	}
}

// readNeutralStore reads desktop.json, false when it is absent or unparseable.
func readNeutralStore(path string) (neutralStore, bool) {
	var ns neutralStore
	b, err := os.ReadFile(path)
	if err != nil {
		return ns, false
	}
	if json.Unmarshal(b, &ns) != nil {
		return ns, false
	}
	return ns, true
}

// loadStore fills the niri defaults, then overlays the store's desktop.* and
// wm.niri.* leaves. An absent leaf keeps its default, so the generated config is
// always the full effective look, not a partial one.
func loadStore(path string) niriStore {
	s := defaultStore()
	ns, ok := readNeutralStore(path)
	if !ok {
		return s
	}
	if b, err := json.Marshal(ns.Desktop); err == nil {
		_ = json.Unmarshal(b, &s)
	}
	if raw, ok := ns.WM["niri"]; ok {
		_ = json.Unmarshal(raw, &s.Niri)
	}
	return s
}

// splitStore renders the store as the namespaced desktop.json tree: desktop.* is
// the flat neutral fields, wm.niri.* is the exclusives, so the Hub learns both
// the namespace name and its sections from the defaults it reads.
func splitStore(s niriStore) (map[string]any, error) {
	db, err := json.Marshal(s)
	if err != nil {
		return nil, err
	}
	var desktop map[string]json.RawMessage
	if err := json.Unmarshal(db, &desktop); err != nil {
		return nil, err
	}
	nb, err := json.Marshal(s.Niri)
	if err != nil {
		return nil, err
	}
	var niri map[string]json.RawMessage
	if err := json.Unmarshal(nb, &niri); err != nil {
		return nil, err
	}
	return map[string]any{
		"desktop": desktop,
		"wm":      map[string]any{"niri": niri},
	}, nil
}

// --- paths ----------------------------------------------------------------

func configHome() string {
	if d := os.Getenv("XDG_CONFIG_HOME"); d != "" {
		return d
	}
	return filepath.Join(os.Getenv("HOME"), ".config")
}

// userEditsNiriDir is the niri slice of the user overlay tree. The generated KDL
// lives here so it survives an update as a user edit; writeOverlayKdl reflects
// the same bytes into the live niri dir so a reload picks them up at once.
func userEditsNiriDir() string {
	return filepath.Join(configHome(), "ryoku", "user_edits", "niri")
}

// --- disk + kdl helpers ---------------------------------------------------

func atomicWrite(path string, b []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if _, err := f.Write(b); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Chmod(mode); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, path)
}

// writeOverlayKdl authors a generated file in the user_edits tree first, then
// reflects the same bytes into the live niri dir. The order matters: if the live
// write fails the overlay still holds the new content, so a materialize re-lays
// it rather than resurrecting the old one.
func writeOverlayKdl(name string, body []byte) error {
	if err := atomicWrite(filepath.Join(userEditsNiriDir(), name), body, 0o644); err != nil {
		return err
	}
	return atomicWrite(filepath.Join(niriConfigDir(), name), body, 0o644)
}

// kdlStr quotes a value as a KDL string with the escapes niri's parser accepts.
func kdlStr(s string) string {
	r := strings.NewReplacer("\\", "\\\\", "\"", "\\\"", "\n", "\\n", "\r", "\\r", "\t", "\\t")
	return "\"" + r.Replace(s) + "\""
}

// kdlNum formats a float without a trailing zero exponent, so accel-speed reads
// 0.3 not 3e-01.
func kdlNum(f float64) string {
	return fmt.Sprintf("%g", f)
}

// kdlColor normalises a stored hex to niri's "#rrggbb" string; empty stays empty
// so the caller omits the line.
func kdlColor(hex string) string {
	h := strings.TrimSpace(hex)
	if h == "" {
		return ""
	}
	if !strings.HasPrefix(h, "#") {
		h = "#" + h
	}
	return kdlStr(h)
}

const kdlHeader = "// Generated by Ryoku Settings (Super + ,). Edit in the GUI, not here.\n\n"

// genSettings renders settings.kdl from the full effective store. The input,
// layout, cursor and niri-exclusive blocks always carry the baseline; env,
// autostart and window rules are additive, so they appear only when the store
// holds them.
func genSettings(s niriStore) []byte {
	var b strings.Builder
	b.WriteString(kdlHeader)
	writeInput(&b, s.Input)
	writeClipboard(&b, s.Input)
	writeLayout(&b, s.Appearance, s.Niri)
	writeAnimations(&b, s.Appearance, s.Niri)
	writeCursor(&b, s.Cursor)
	writeMisc(&b, s.Niri)
	writeEnvironment(&b, s.Env, s.Apps)
	writeAutostart(&b, s.Autostart)
	writeWindowRules(&b, s.Appearance, s.WindowRules, s.AppOverrides)
	writeBlockOut(&b, s.Niri.BlockOutApps)
	writeLayerRules(&b)
	return []byte(b.String())
}

// overviewBackdropNamespace is the layer-shell namespace the shell maps its
// blurred overview-wallpaper surface under. The provider and the shell agree on
// this exact string: the shell names the surface, this rule routes it.
const overviewBackdropNamespace = "ryoku-overview-backdrop"

// writeLayerRules lifts the shell's overview-backdrop surface into niri's
// backdrop, the region the user sees behind the workspaces in the overview, so a
// blurred copy of the wallpaper fills what is otherwise a flat colour. The rule
// is always emitted: it matches nothing until the shell maps that surface (only
// when the overviewBackdrop capability is live and the user turned it on), and a
// rule that matches nothing is inert. Ryoku keeps its wallpaper on a separate
// opaque surface that already paints every workspace, so unlike a shell whose
// wallpaper IS the backdrop this needs no transparent workspace background to be
// seen.
func writeLayerRules(b *strings.Builder) {
	fmt.Fprintf(b, "layer-rule {\n    match namespace=%s\n    place-within-backdrop true\n}\n\n", kdlStr(overviewBackdropNamespace))
}

func writeInput(b *strings.Builder, in Input) {
	b.WriteString("input {\n")
	b.WriteString("    keyboard {\n")
	if in.KbLayout != "" || in.KbVariant != "" || in.KbOptions != "" {
		b.WriteString("        xkb {\n")
		if in.KbLayout != "" {
			fmt.Fprintf(b, "            layout %s\n", kdlStr(in.KbLayout))
		}
		if in.KbVariant != "" {
			fmt.Fprintf(b, "            variant %s\n", kdlStr(in.KbVariant))
		}
		if in.KbOptions != "" {
			fmt.Fprintf(b, "            options %s\n", kdlStr(in.KbOptions))
		}
		b.WriteString("        }\n")
	}
	fmt.Fprintf(b, "        repeat-rate %d\n", in.RepeatRate)
	fmt.Fprintf(b, "        repeat-delay %d\n", in.RepeatDelay)
	if in.NumlockByDefault {
		b.WriteString("        numlock\n")
	}
	b.WriteString("    }\n")

	b.WriteString("    touchpad {\n")
	if in.TapToClick {
		b.WriteString("        tap\n")
	}
	if in.NaturalScroll {
		b.WriteString("        natural-scroll\n")
	}
	if in.TouchScrollFactor > 0 && in.TouchScrollFactor != 1 {
		fmt.Fprintf(b, "        scroll-factor %s\n", kdlNum(in.TouchScrollFactor))
	}
	if in.DisableWhileTyping {
		b.WriteString("        dwt\n")
	}
	if in.TapAndDrag {
		b.WriteString("        drag true\n")
	}
	if in.Clickfinger {
		b.WriteString("        click-method \"clickfinger\"\n")
	}
	if in.MiddleEmulation {
		b.WriteString("        middle-emulation\n")
	}
	if in.LeftHanded {
		b.WriteString("        left-handed\n")
	}
	if in.Sensitivity != 0 {
		fmt.Fprintf(b, "        accel-speed %s\n", kdlNum(in.Sensitivity))
	}
	if p := accelProfile(in.AccelProfile); p != "" {
		fmt.Fprintf(b, "        accel-profile %s\n", kdlStr(p))
	}
	b.WriteString("    }\n")

	b.WriteString("    mouse {\n")
	if in.MouseNaturalScroll {
		b.WriteString("        natural-scroll\n")
	}
	if in.MouseScrollFactor > 0 && in.MouseScrollFactor != 1 {
		fmt.Fprintf(b, "        scroll-factor %s\n", kdlNum(in.MouseScrollFactor))
	}
	if in.LeftHanded {
		b.WriteString("        left-handed\n")
	}
	if in.Sensitivity != 0 {
		fmt.Fprintf(b, "        accel-speed %s\n", kdlNum(in.Sensitivity))
	}
	if p := accelProfile(in.AccelProfile); p != "" {
		fmt.Fprintf(b, "        accel-profile %s\n", kdlStr(p))
	}
	b.WriteString("    }\n")

	if in.FollowMouse != 0 {
		b.WriteString("    focus-follows-mouse\n")
	}
	b.WriteString("}\n\n")
}

// accelProfile maps the neutral profile name onto niri's two accepted values;
// anything else omits the line.
func accelProfile(s string) string {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "flat":
		return "flat"
	case "adaptive":
		return "adaptive"
	}
	return ""
}

// writeLayout maps the neutral border onto niri's always-visible border and turns
// the focus ring off, so the frame the user sized is the one they see, and adds
// the drop shadow when the store asks for one, spread and offset included, since
// those are neutral appearance keys like softness and colour. The default and
// preset widths, the centring rules, the urgent colour, the tab indicator, the
// insert hint and the struts are niri exclusives with no neutral key.
func writeLayout(b *strings.Builder, a Appearance, n Niri) {
	b.WriteString("layout {\n")
	fmt.Fprintf(b, "    gaps %d\n", a.GapsOut)
	if n.DefaultColumnWidth > 0 {
		fmt.Fprintf(b, "    default-column-width { proportion %s; }\n", kdlNum(n.DefaultColumnWidth))
	}
	if c := centerFocused(n.CenterFocused); c != "" {
		fmt.Fprintf(b, "    center-focused-column %s\n", kdlStr(c))
	}
	if n.AlwaysCenterSingle {
		b.WriteString("    always-center-single-column\n")
	}
	if len(n.PresetColumnWidths) > 0 {
		b.WriteString("    preset-column-widths {\n")
		for _, w := range n.PresetColumnWidths {
			fmt.Fprintf(b, "        proportion %s\n", kdlNum(w))
		}
		b.WriteString("    }\n")
	}
	if s := n.Struts; s.Left != 0 || s.Right != 0 || s.Top != 0 || s.Bottom != 0 {
		b.WriteString("    struts {\n")
		fmt.Fprintf(b, "        left %d\n", s.Left)
		fmt.Fprintf(b, "        right %d\n", s.Right)
		fmt.Fprintf(b, "        top %d\n", s.Top)
		fmt.Fprintf(b, "        bottom %d\n", s.Bottom)
		b.WriteString("    }\n")
	}
	b.WriteString("    border {\n")
	if a.BorderSize <= 0 {
		b.WriteString("        off\n")
	} else {
		fmt.Fprintf(b, "        width %d\n", a.BorderSize)
	}
	if c := kdlColor(a.ActiveBorder); c != "" {
		fmt.Fprintf(b, "        active-color %s\n", c)
	}
	if c := kdlColor(a.InactiveBorder); c != "" {
		fmt.Fprintf(b, "        inactive-color %s\n", c)
	}
	if c := kdlColor(n.UrgentColor); c != "" {
		fmt.Fprintf(b, "        urgent-color %s\n", c)
	}
	b.WriteString("    }\n")
	b.WriteString("    focus-ring {\n        off\n    }\n")
	if a.ShadowEnabled {
		b.WriteString("    shadow {\n")
		b.WriteString("        on\n")
		if a.ShadowRange > 0 {
			fmt.Fprintf(b, "        softness %d\n", a.ShadowRange)
		}
		fmt.Fprintf(b, "        spread %d\n", a.ShadowSpread)
		fmt.Fprintf(b, "        offset x=%d y=%d\n", a.ShadowOffsetX, a.ShadowOffsetY)
		if c := kdlColor(a.ShadowColor); c != "" {
			fmt.Fprintf(b, "        color %s\n", c)
		}
		b.WriteString("    }\n")
	}
	if n.TabIndicatorWidth > 0 || n.TabIndicatorHide {
		b.WriteString("    tab-indicator {\n")
		if n.TabIndicatorWidth > 0 {
			fmt.Fprintf(b, "        width %d\n", n.TabIndicatorWidth)
		}
		if n.TabIndicatorHide {
			b.WriteString("        hide-when-single-tab\n")
		}
		b.WriteString("    }\n")
	}
	if !n.InsertHint {
		b.WriteString("    insert-hint {\n        off\n    }\n")
	}
	b.WriteString("}\n\n")
}

// writeAnimations turns animations off, or stretches them by the slowdown factor
// when the user has moved it off 1; niri runs them at full speed by default, so a
// factor of 1 stays silent.
func writeAnimations(b *strings.Builder, a Appearance, n Niri) {
	if !a.Animations {
		b.WriteString("animations {\n    off\n}\n\n")
		return
	}
	if n.AnimationSlowdown > 0 && n.AnimationSlowdown != 1 {
		fmt.Fprintf(b, "animations {\n    slowdown %s\n}\n\n", kdlNum(n.AnimationSlowdown))
	}
}

// writeClipboard turns off niri's primary-selection buffer when the user has
// disabled middle-click paste, the neutral input toggle both providers share.
// niri keeps primary selection unless told otherwise, so the block only appears
// to switch it off.
func writeClipboard(b *strings.Builder, in Input) {
	if in.MiddleClickPaste {
		return
	}
	b.WriteString("clipboard {\n    disable-primary\n}\n\n")
}

// centerFocused guards the stored value against niri's three accepted words; an
// unknown value omits the line so niri keeps its own default.
func centerFocused(s string) string {
	switch v := strings.ToLower(strings.TrimSpace(s)); v {
	case "never", "always", "on-overflow":
		return v
	}
	return ""
}

func writeCursor(b *strings.Builder, c Cursor) {
	b.WriteString("cursor {\n")
	if c.Theme != "" {
		fmt.Fprintf(b, "    xcursor-theme %s\n", kdlStr(c.Theme))
	}
	if c.Size > 0 {
		fmt.Fprintf(b, "    xcursor-size %d\n", c.Size)
	}
	if c.InactiveTimeout > 0 {
		fmt.Fprintf(b, "    hide-after-inactive-ms %d\n", c.InactiveTimeout*1000)
	}
	if c.HideOnKeyPress {
		b.WriteString("    hide-when-typing\n")
	}
	b.WriteString("}\n\n")
}

// writeMisc emits the niri-exclusive top-level settings: server-side decorations,
// the startup hotkey overlay, the screenshot path, the hot-corner gesture and the
// overview zoom.
func writeMisc(b *strings.Builder, n Niri) {
	if n.PreferNoCSD {
		b.WriteString("prefer-no-csd\n\n")
	}
	if n.HotkeyOverlaySkip {
		b.WriteString("hotkey-overlay {\n    skip-at-startup\n}\n\n")
	}
	if strings.TrimSpace(n.ScreenshotPath) != "" {
		fmt.Fprintf(b, "screenshot-path %s\n\n", kdlStr(n.ScreenshotPath))
	}
	if !n.HotCorners {
		b.WriteString("gestures {\n    hot-corners {\n        off\n    }\n}\n\n")
	}
	if n.OverviewZoom > 0 {
		fmt.Fprintf(b, "overview {\n    zoom %s\n}\n\n", kdlNum(n.OverviewZoom))
	}
}

// writeEnvironment folds the user env vars and the browser/terminal app roles into
// one environment block, so the CLI and xdg-open honour the same choice the
// keybinds launch.
func writeEnvironment(b *strings.Builder, env []EnvVar, apps map[string]string) {
	type kv struct{ k, v string }
	var rows []kv
	for _, e := range env {
		if strings.TrimSpace(e.Key) == "" {
			continue
		}
		rows = append(rows, kv{e.Key, e.Value})
	}
	if v := strings.TrimSpace(apps["browser"]); v != "" {
		rows = append(rows, kv{"BROWSER", v})
	}
	if v := strings.TrimSpace(apps["terminal"]); v != "" {
		rows = append(rows, kv{"TERMINAL", v})
	}
	if len(rows) == 0 {
		return
	}
	b.WriteString("environment {\n")
	for _, r := range rows {
		fmt.Fprintf(b, "    %s %s\n", r.k, kdlStr(r.v))
	}
	b.WriteString("}\n\n")
}

// writeAutostart runs each user autostart command through the shell, matching how
// the Hyprland provider execs them.
func writeAutostart(b *strings.Builder, auto []Autostart) {
	wrote := false
	for _, a := range auto {
		if strings.TrimSpace(a.Command) == "" {
			continue
		}
		fmt.Fprintf(b, "spawn-sh-at-startup %s\n", kdlStr(a.Command))
		wrote = true
	}
	if wrote {
		b.WriteString("\n")
	}
}

// writeWindowRules emits the global corner radius and opacity, then each user
// window rule and per-app override niri can express. Rules niri cannot express
// are reported unhonored by apply, not silently dropped here.
func writeWindowRules(b *strings.Builder, a Appearance, rules []WindowRule, apps []AppOverride) {
	if a.Rounding > 0 {
		b.WriteString("window-rule {\n")
		fmt.Fprintf(b, "    geometry-corner-radius %d\n", a.Rounding)
		b.WriteString("    clip-to-geometry true\n")
		b.WriteString("}\n\n")
	}
	writeOpacityRules(b, a)
	for _, r := range rules {
		if props := windowRuleProps(r); len(props) > 0 {
			writeRuleBlock(b, r.Class, r.Title, props)
		}
	}
	for _, ao := range apps {
		if props := appOverrideProps(ao); len(props) > 0 {
			writeRuleBlock(b, ao.Class, ao.Title, props)
		}
	}
}

// writeOpacityRules emits the global opacity as a matchless window-rule and the
// inactive opacity as an is-active=false rule niri re-evaluates on focus change.
// Both carry no app match, so a later per-app opacity override still wins for its
// windows: in niri the last matching rule sets the value.
func writeOpacityRules(b *strings.Builder, a Appearance) {
	if a.ActiveOpacity > 0 && a.ActiveOpacity < 1 {
		b.WriteString("window-rule {\n")
		fmt.Fprintf(b, "    opacity %s\n", kdlNum(a.ActiveOpacity))
		b.WriteString("}\n\n")
	}
	if a.InactiveOpacity > 0 && a.InactiveOpacity < 1 {
		b.WriteString("window-rule {\n")
		b.WriteString("    match is-active=false\n")
		fmt.Fprintf(b, "    opacity %s\n", kdlNum(a.InactiveOpacity))
		b.WriteString("}\n\n")
	}
}

func writeRuleBlock(b *strings.Builder, class, title string, props []string) {
	b.WriteString("window-rule {\n")
	var match []string
	if class != "" {
		match = append(match, fmt.Sprintf("app-id=%s", kdlStr(class)))
	}
	if title != "" {
		match = append(match, fmt.Sprintf("title=%s", kdlStr(title)))
	}
	if len(match) > 0 {
		fmt.Fprintf(b, "    match %s\n", strings.Join(match, " "))
	}
	for _, p := range props {
		fmt.Fprintf(b, "    %s\n", p)
	}
	b.WriteString("}\n\n")
}

// windowRuleProps translates one neutral window-rule action into niri property
// lines, or returns nil when niri has no expression for it.
func windowRuleProps(r WindowRule) []string {
	switch r.Action {
	case "float":
		return []string{"open-floating true"}
	case "tile":
		return []string{"open-floating false"}
	case "fullscreen":
		return []string{"open-fullscreen true"}
	case "maximize":
		return []string{"open-maximized true"}
	case "norounding":
		return []string{"geometry-corner-radius 0"}
	case "opacity":
		return []string{fmt.Sprintf("opacity %s", kdlNum(parseFloat(r.Value, 1)))}
	case "workspace":
		return []string{fmt.Sprintf("open-on-workspace %s", kdlStr(r.Value))}
	case "noborder":
		return []string{"border {", "    off", "}"}
	}
	return nil
}

// appOverrideProps renders the per-app fields niri can express; -1 and "inherit"
// mean leave alone.
func appOverrideProps(a AppOverride) []string {
	var props []string
	if a.Opacity >= 0 && a.Opacity <= 1 {
		props = append(props, fmt.Sprintf("opacity %s", kdlNum(a.Opacity)))
	}
	if a.Rounding >= 0 {
		props = append(props, fmt.Sprintf("geometry-corner-radius %d", a.Rounding))
	}
	if a.BorderSize >= 0 {
		props = append(props, "border {", fmt.Sprintf("    width %d", a.BorderSize), "}")
	}
	return props
}

func parseFloat(s string, fallback float64) float64 {
	var f float64
	if _, err := fmt.Sscanf(strings.TrimSpace(s), "%g", &f); err != nil {
		return fallback
	}
	return f
}

// writeBlockOut hides each named app from screencasts with its own window-rule.
// "screencast" keeps the app out of screen shares and recordings while leaving
// the user's own screenshots working. The list is empty by default, so this is
// never a blanket switch: only the app-ids the user names are ever blanked.
func writeBlockOut(b *strings.Builder, list string) {
	for _, id := range splitList(list) {
		b.WriteString("window-rule {\n")
		fmt.Fprintf(b, "    match app-id=%s\n", kdlStr(id))
		b.WriteString("    block-out-from \"screencast\"\n")
		b.WriteString("}\n\n")
	}
}

// splitList splits a comma-separated field into trimmed, non-empty tokens.
func splitList(s string) []string {
	var out []string
	for _, tok := range strings.Split(s, ",") {
		if t := strings.TrimSpace(tok); t != "" {
			out = append(out, t)
		}
	}
	return out
}
