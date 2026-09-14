package main

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

// slice of binds.lua hitting every parser branch: a header, a modified combo,
// comment vs derived description, a string-literal media key, a mouse bind,
// and the 1..0 workspace loop.
const sampleBinds = `local mod = "SUPER"
local function K(k) return k end

-- Windows
hl.bind(K(mod .. " + Q"),         hl.dsp.window.close())                           -- close active window
hl.bind(K(mod .. " + SHIFT + A"), hl.dsp.window.float({ action = "disable" }))     -- restore: tile it back to normal

-- Apps
hl.bind(K(mod .. " + Return"),    hl.dsp.exec_cmd("kitty"))
hl.bind(K(mod .. " + N"),         hl.dsp.exec_cmd("kitty -e nvim"))                -- neovim

-- Switch workspaces
hl.bind(K(mod .. " + Left"),       hl.dsp.focus({ workspace = "r-1" }))
for i = 1, 10 do
    local key = i % 10 -- 10 maps to the 0 key
    hl.bind(K(mod .. " + " .. key),          hl.dsp.focus({ workspace = i }))
    hl.bind(K(mod .. " + SHIFT + " .. key),  hl.dsp.window.move({ workspace = i }))
end

-- Media and volume keys
hl.bind(K("XF86AudioRaiseVolume"), hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
`

func find(l legend, cat string) *category {
	for i := range l.Categories {
		if l.Categories[i].Name == cat {
			return &l.Categories[i]
		}
	}
	return nil
}

func TestParseCategories(t *testing.T) {
	l := parseBinds(sampleBinds)
	want := []string{"Windows", "Apps", "Switch workspaces", "Media and volume keys"}
	if len(l.Categories) != len(want) {
		t.Fatalf("got %d categories, want %d: %+v", len(l.Categories), len(want), l.Categories)
	}
	for i, n := range want {
		if l.Categories[i].Name != n {
			t.Errorf("category %d = %q, want %q", i, l.Categories[i].Name, n)
		}
	}
}

// A section whose comment runs over several lines is one category, titled from
// its first sentence. Taking every comment line made an empty category per line
// and filed the real binds under the paragraph's closing sentence, which is what
// Ryoku Settings showed for Workspaces and the media keys.
func TestMultiLineSectionHeader(t *testing.T) {
	l := parseBinds(`
-- Workspaces. Super+N focuses the Nth workspace OF THE CURRENT DESKTOP (a
-- desktop is a block of 10 ids; see scripts/ryoku-workspace and the overview).
-- Super+Alt+N sends the active window to that slot, staying on this desktop.
local ws_helper = "/x"

hl.bind(K(mod .. " + H"), hl.dsp.exec_cmd(ws_helper .. " hide")) -- hide the focused window
`)
	if len(l.Categories) != 1 {
		t.Fatalf("got %d categories, want 1: %+v", len(l.Categories), l.Categories)
	}
	if got := l.Categories[0].Name; got != "Workspaces" {
		t.Errorf("category = %q, want %q", got, "Workspaces")
	}
	if n := len(l.Categories[0].Binds); n != 1 {
		t.Fatalf("got %d binds, want 1", n)
	}
	if got := l.Categories[0].Binds[0].Desc; got != "Hide the focused window" {
		t.Errorf("desc = %q", got)
	}
}

func TestModifiedComboKeys(t *testing.T) {
	w := find(parseBinds(sampleBinds), "Windows")
	if w == nil || len(w.Binds) != 2 {
		t.Fatalf("Windows category malformed: %+v", w)
	}
	got := strings.Join(w.Binds[1].Keys, "|")
	if got != "Super|Shift|A" {
		t.Errorf("keys = %q, want Super|Shift|A", got)
	}
	if w.Binds[0].Desc != "Close active window" {
		t.Errorf("desc = %q, want capitalized comment", w.Binds[0].Desc)
	}
}

func TestDerivedDescriptionFromDispatcher(t *testing.T) {
	a := find(parseBinds(sampleBinds), "Apps")
	if a == nil || len(a.Binds) == 0 {
		t.Fatal("Apps category missing")
	}
	// kitty has no trailing comment; description comes from the dispatcher.
	if a.Binds[0].Desc != "Terminal" {
		t.Errorf("derived desc = %q, want Terminal", a.Binds[0].Desc)
	}
}

func TestWorkspaceLoopCollapses(t *testing.T) {
	ws := find(parseBinds(sampleBinds), "Switch workspaces")
	if ws == nil {
		t.Fatal("Switch workspaces category missing")
	}
	// 1 explicit Left bind + 2 loop binds = 3 entries.
	if len(ws.Binds) != 3 {
		t.Fatalf("got %d binds, want 3: %+v", len(ws.Binds), ws.Binds)
	}
	focus := ws.Binds[1]
	if strings.Join(focus.Keys, "|") != "Super|1\u20260" {
		t.Errorf("loop keys = %q, want Super|1…0", strings.Join(focus.Keys, "|"))
	}
	if focus.Desc != "Focus workspace" {
		t.Errorf("loop desc = %q, want Focus workspace", focus.Desc)
	}
	if ws.Binds[2].Desc != "Move window to workspace" {
		t.Errorf("loop move desc = %q", ws.Binds[2].Desc)
	}
}

func TestMediaKeyLiteral(t *testing.T) {
	m := find(parseBinds(sampleBinds), "Media and volume keys")
	if m == nil || len(m.Binds) != 1 {
		t.Fatalf("media category malformed: %+v", m)
	}
	if strings.Join(m.Binds[0].Keys, "|") != "Vol +" {
		t.Errorf("media key = %q, want 'Vol +'", strings.Join(m.Binds[0].Keys, "|"))
	}
	if m.Binds[0].Desc != "Volume up" {
		t.Errorf("media desc = %q, want Volume up", m.Binds[0].Desc)
	}
}

func TestPrettyKeyGrave(t *testing.T) {
	if got := prettyKey("grave"); got != "`" {
		t.Errorf("grave key = %q, want backtick", got)
	}
}

// lambda action (multi-dispatch, e.g. SUPER+A float + centre) isn't an
// hl.dsp expression but it still belongs in the legend. description comes
// from the trailing comment.
func TestLambdaBind(t *testing.T) {
	const src = `-- Windows
hl.bind(mod .. " + A", function() hl.dispatch(hl.dsp.window.float({ action = "toggle" })); hl.dispatch(hl.dsp.window.center()) end) -- float + centre the window
`
	w := find(parseBinds(src), "Windows")
	if w == nil || len(w.Binds) != 1 {
		t.Fatalf("Windows category malformed: %+v", w)
	}
	if got := strings.Join(w.Binds[0].Keys, "|"); got != "Super|A" {
		t.Errorf("keys = %q, want Super|A", got)
	}
	if w.Binds[0].Desc != "Float + centre the window" {
		t.Errorf("desc = %q, want comment-derived description", w.Binds[0].Desc)
	}
}

// K() (the rebind helper) is unwrapped so the raw combo -- the rebind id K() keys
// on at runtime -- is captured, and a single literal chord is rebindable while the
// workspace-loop range and pointer binds are not.
func TestComboAndRebindable(t *testing.T) {
	l := parseBinds(sampleBinds)
	w := find(l, "Windows")
	if w == nil || len(w.Binds) < 1 {
		t.Fatal("Windows category missing")
	}
	if w.Binds[0].Combo != "SUPER + Q" {
		t.Errorf("combo = %q, want SUPER + Q", w.Binds[0].Combo)
	}
	if !w.Binds[0].Rebindable {
		t.Error("SUPER + Q should be rebindable")
	}
	ws := find(l, "Switch workspaces")
	loop := ws.Binds[len(ws.Binds)-1]
	if loop.Rebindable {
		t.Errorf("loop bind %q should not be rebindable", loop.Combo)
	}
	m := find(l, "Media and volume keys")
	if m.Binds[0].Combo != "XF86AudioRaiseVolume" || !m.Binds[0].Rebindable {
		t.Errorf("media combo=%q rebindable=%v", m.Binds[0].Combo, m.Binds[0].Rebindable)
	}
	mouse := parseBinds("-- M\nhl.bind(K(mod .. \" + mouse:272\"), hl.dsp.window.drag(), { mouse = true })\n")
	if mouse.Categories[0].Binds[0].Rebindable {
		t.Error("mouse bind should not be rebindable")
	}
}

func TestDescribeRyokuApp(t *testing.T) {
	if got := describeExec("ryoku-app browser"); got != "browser" {
		t.Errorf("describeExec ryoku-app = %q, want browser", got)
	}
}

// The provider's own binds become one named section, its keycaps prettified and
// its copy capitalised like the shared legend. A chord the shared legend already
// carries stays in its own group and takes the provider's wording, since the
// shared text describes another compositor's mechanic.
func TestCompositorSection(t *testing.T) {
	base := legend{Categories: []category{
		{Name: "Windows", Binds: []bind{{Combo: "SUPER + Q"}, {Combo: "SUPER + F", Desc: "Fullscreen the Hyprland way"}}},
	}}
	rows := []json.RawMessage{
		json.RawMessage(`{"chord":"SUPER + D","desc":"maximise the column"}`),
		json.RawMessage(`{"chord":"SUPER + F","desc":"fullscreen the window"}`),
		json.RawMessage(`{"chord":"SUPER + CTRL + R","desc":"reset the window height"}`),
	}
	cat, ok := compositorSection(rows, "Niri", &base)
	if !ok {
		t.Fatal("expected a section")
	}
	if cat.Name != "Niri" {
		t.Errorf("section name = %q, want Niri", cat.Name)
	}
	if len(cat.Binds) != 2 {
		t.Fatalf("got %d binds, want 2 (the shared SUPER + F chord stays in Windows)", len(cat.Binds))
	}
	if got := base.Categories[0].Binds[1].Desc; got != "Fullscreen the window" {
		t.Errorf("shared row desc = %q, want the provider's wording", got)
	}
	if !reflect.DeepEqual(cat.Binds[0].Keys, []string{"Super", "D"}) {
		t.Errorf("keycaps = %v, want [Super D]", cat.Binds[0].Keys)
	}
	if cat.Binds[0].Desc != "Maximise the column" {
		t.Errorf("desc = %q, want capitalised", cat.Binds[0].Desc)
	}
	if !cat.Binds[0].Rebindable {
		t.Error("a single-literal chord should be rebindable")
	}
}

// When every exclusive chord is one the shared legend already carries, the
// section is absent, not an empty group.
func TestCompositorSectionAbsentWhenAllShared(t *testing.T) {
	base := legend{Categories: []category{{Name: "Windows", Binds: []bind{{Combo: "SUPER + D"}}}}}
	rows := []json.RawMessage{json.RawMessage(`{"chord":"SUPER + D","desc":"x"}`)}
	if _, ok := compositorSection(rows, "Niri", &base); ok {
		t.Error("section must be absent when no exclusive bind survives dedup")
	}
}

// The honesty pass strikes the shared legend against the chords the running
// compositor cannot honour. A keyboard chord it has no concept of (pin,
// scratchpad) leaves the sheet; a pointer gesture stays but reads the provider's
// reason instead of an action it never fires; a chord the provider says nothing
// about is untouched; and a category emptied by the strike is dropped.
func TestFilterLegendStrikesUnhonored(t *testing.T) {
	l := legend{Categories: []category{
		{Name: "Windows", Binds: []bind{
			{Keys: []string{"Super", "Q"}, Combo: "SUPER + Q", Desc: "Close active window"},
			{Keys: []string{"Super", "Shift", "P"}, Combo: "SUPER + SHIFT + P", Desc: "Pin a floating window", Rebindable: true},
		}},
		{Name: "Move/resize with the mouse", Binds: []bind{
			{Keys: []string{"Super", "LMB"}, Combo: "SUPER + mouse:272", Desc: "Move window"},
		}},
		{Name: "Scratch", Binds: []bind{
			{Keys: []string{"Super", "H"}, Combo: "SUPER + H", Desc: "Hide in the scratchpad", Rebindable: true},
		}},
	}}
	filterLegend(&l, map[string]string{
		"SUPER + SHIFT + P": "niri has no pin-window action.",
		"SUPER + mouse:272": "niri moves windows with Mod and drag natively.",
		"SUPER + H":         "niri has no scratchpad workspace.",
	})

	w := find(l, "Windows")
	if w == nil || len(w.Binds) != 1 || w.Binds[0].Combo != "SUPER + Q" {
		t.Fatalf("Windows should keep only SUPER + Q, dropping the pin chord: %+v", w)
	}
	m := find(l, "Move/resize with the mouse")
	if m == nil || len(m.Binds) != 1 {
		t.Fatalf("the pointer gesture must survive the strike: %+v", m)
	}
	if m.Binds[0].Desc != "Niri moves windows with Mod and drag natively." {
		t.Errorf("mouse desc = %q, want the provider's reason", m.Binds[0].Desc)
	}
	if m.Binds[0].Rebindable {
		t.Error("a native gesture is not rebindable")
	}
	if find(l, "Scratch") != nil {
		t.Error("a category emptied by the strike must be dropped, not left as a bare header")
	}
}

// A provider that honours every shared bind reports no keybind losses, so the
// chord map is empty and the whole legend passes through. This is Hyprland over
// its own config: nothing vanishes from its sheet.
func TestFilterLegendKeepsEverythingWhenNothingUnhonored(t *testing.T) {
	l := parseBinds(sampleBinds)
	before := 0
	for _, c := range l.Categories {
		before += len(c.Binds)
	}
	filterLegend(&l, map[string]string{})
	after := 0
	for _, c := range l.Categories {
		after += len(c.Binds)
	}
	if before == 0 || before != after {
		t.Errorf("an empty loss list must not drop a single bind: before=%d after=%d", before, after)
	}
}

// An explanatory note dropped between two binds is prose, not a section header:
// it follows a bind with no blank line above it, so it neither opens a category
// nor siphons the binds below it. Regression for the scratchpad comment that
// became a category titled with its own first line.
func TestInlineCommentIsNotACategory(t *testing.T) {
	l := parseBinds(`-- Workspaces
hl.bind(K(mod .. " + H"), hl.dsp.exec_cmd("x hide")) -- hide the focused window
-- Through the helper, not toggle_special directly: hiding the scratchpad has to
-- hand keyboard focus back to a visible window, or the next bar panel to close
-- refocuses the hidden one and pops the scratchpad open with it.
hl.bind(K(mod .. " + ALT + H"), hl.dsp.exec_cmd("x scratch")) -- show or hide the scratchpad
`)
	if len(l.Categories) != 1 {
		t.Fatalf("the inline note must not open a category: got %d: %+v", len(l.Categories), l.Categories)
	}
	if l.Categories[0].Name != "Workspaces" {
		t.Errorf("category = %q, want Workspaces", l.Categories[0].Name)
	}
	if n := len(l.Categories[0].Binds); n != 2 {
		t.Fatalf("both H binds belong to Workspaces, none siphoned into a prose category: got %d", n)
	}
}
