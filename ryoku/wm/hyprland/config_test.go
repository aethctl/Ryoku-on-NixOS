package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	wm "ryoku-wm"
)

// A custom keybind with release mode on must emit the Hyprland release flag, and
// a press keybind must not carry it: this is written into settings.lua, so a
// regression would silently change when shortcuts fire.
func TestGenKeybindReleaseFlag(t *testing.T) {
	press := genKeybind(Keybind{Keys: "SUPER + M", Action: "exec", Value: "kitty"})
	if got, want := press, "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"kitty\"))\n"; got != want {
		t.Fatalf("press bind:\n got %q\nwant %q", got, want)
	}
	release := genKeybind(Keybind{Keys: "SUPER + M", Action: "exec", Value: "kitty", Release: true})
	if got, want := release, "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"kitty\"), { release = true })\n"; got != want {
		t.Fatalf("release bind:\n got %q\nwant %q", got, want)
	}
}

// The shipped input.lua detaches keyboard focus from the pointer, and the
// diff-based config must not re-emit that default, or settings.lua would override
// the shipped module with the same value for no reason.
func TestDefaultFollowMouseMatchesShippedInput(t *testing.T) {
	const detachedFocus = 2
	if got := defaultOverrides().Input.FollowMouse; got != detachedFocus {
		t.Fatalf("default input.follow_mouse = %d, want %d", got, detachedFocus)
	}
	inputConfig, err := os.ReadFile(filepath.Join("..", "..", "hyprland", "modules", "input.lua"))
	if err != nil {
		t.Fatalf("read shipped input config: %v", err)
	}
	if !regexp.MustCompile(`(?m)^[[:space:]]*follow_mouse[[:space:]]*=[[:space:]]*2,[[:space:]]*$`).Match(inputConfig) {
		t.Fatal("shipped input.lua must detach keyboard focus from pointer focus")
	}
	if config := genConfig(defaultOverrides(), false); strings.Contains(config, "follow_mouse =") {
		t.Fatalf("default settings.lua overrides input.lua:\n%s", config)
	}
}

// Hyprland tames a maximise-on-open by refusing the client's request outright, a
// catch-all suppress_event rule. This is the whole of the Hyprland side, so it
// is pinned by the exact line and by its presence in the full config when the
// setting is on and its absence when off.
func TestGenTameMaximizeOnOpen(t *testing.T) {
	on := defaultOverrides() // TameMaximizeOnOpen defaults on
	want := `hl.window_rule({ name = "ryoku-tame-maximize-on-open", match = { class = ".*" }, suppress_event = "maximize" })` + "\n"
	if got := genTameMaximizeOnOpen(on); got != want {
		t.Fatalf("rule on:\n got %q\nwant %q", got, want)
	}
	if !strings.Contains(genLua(on, false), "ryoku-tame-maximize-on-open") {
		t.Fatal("the full config must carry the tame rule when the setting is on")
	}

	off := defaultOverrides()
	off.Windows.TameMaximizeOnOpen = false
	if got := genTameMaximizeOnOpen(off); got != "" {
		t.Fatalf("rule off must emit nothing, got %q", got)
	}
	if strings.Contains(genLua(off, false), "suppress_event") {
		t.Fatalf("the full config must carry no suppress rule when the setting is off:\n%s", genLua(off, false))
	}
}

// "DYNAMIC" is a store role, not a theme on disk: the loaded overrides must
// carry the concrete wallpaper-following theme, or settings.lua exports an
// XCURSOR_THEME no loader can open and the pointer falls back to a bitmap.
func TestLoadStoreResolvesDynamicCursor(t *testing.T) {
	dir := t.TempDir()
	store := filepath.Join(dir, "desktop.json")
	body := `{"desktop":{"cursor":{"theme":"DYNAMIC","size":18}}}`
	if err := os.WriteFile(store, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	o := loadStore(store)
	if o.Cursor.Theme != wm.CursorThemeMaterial {
		t.Fatalf("loaded theme = %q, want %q", o.Cursor.Theme, wm.CursorThemeMaterial)
	}
	if cfg := genLua(o, false); !strings.Contains(cfg, `hl.env("XCURSOR_THEME", "`+wm.CursorThemeMaterial+`")`) {
		t.Fatalf("settings.lua does not export the resolved theme:\n%s", cfg)
	}
}
