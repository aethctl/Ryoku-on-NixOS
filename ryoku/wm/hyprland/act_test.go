package main

import (
	"os"
	"strings"
	"testing"
)

// Every action is pinned to the exact hyprctl argv it emits, because the dialect
// is the contract with the compositor and getting it wrong fails silently. The
// classic `dispatch workspace 9` form shipped once and Hyprland's Lua config
// provider rejected all of it: dispatch evaluates its argument as
// hl.dispatch(<expr>), and hyprctl keyword refuses outright under that parser.
func TestActEmitsLuaDialect(t *testing.T) {
	const addr = "0xdeadbeef"
	cases := []struct {
		name string
		args []string
		want []string
	}{
		{"window focus", []string{"window.focus", addr},
			[]string{"dispatch", `hl.dsp.focus({ window = "address:0xdeadbeef" })`}},
		{"window close", []string{"window.close", addr},
			[]string{"dispatch", `hl.dsp.window.close({ window = "address:0xdeadbeef" })`}},
		{"window float", []string{"window.float", addr},
			[]string{"dispatch", `hl.dsp.window.float({ action = "toggle", window = "address:0xdeadbeef" })`}},
		{"window to workspace", []string{"window.moveToWorkspace", addr, "3"},
			[]string{"dispatch", `hl.dsp.window.move({ workspace = "3", window = "address:0xdeadbeef" })`}},
		{"app focus", []string{"app.focus", "org.quickshell"},
			[]string{"dispatch", `hl.dsp.focus({ window = "class:org.quickshell" })`}},
		{"workspace focus", []string{"workspace.focus", "9"},
			[]string{"dispatch", `hl.dsp.focus({ workspace = "9" })`}},
		{"workspace cycle forward", []string{"workspace.cycle", "1"},
			[]string{"dispatch", `hl.dsp.focus({ workspace = "r+1" })`}},
		{"workspace cycle back", []string{"workspace.cycle", "-2"},
			[]string{"dispatch", `hl.dsp.focus({ workspace = "r-2" })`}},
		{"workspace to output", []string{"workspace.moveToOutput", "9", "eDP-2"},
			[]string{"dispatch", `hl.dsp.workspace.move({ workspace = "9", monitor = "eDP-2" })`}},
		{"special workspace", []string{"workspace.toggleSpecial", "sharebar"},
			[]string{"dispatch", `hl.dsp.workspace.toggle_special("sharebar")`}},
		{"session exit", []string{"session.exit"},
			[]string{"dispatch", `hl.dsp.exit()`}},
		{"output power", []string{"output.power", "off", "eDP-2"},
			[]string{"dispatch", `hl.dsp.dpms({ state = "off", monitor = "eDP-2" })`}},
		{"submap enter", []string{"submap.enter", "resize"},
			[]string{"dispatch", `hl.dsp.submap("resize")`}},
		{"submap reset", []string{"submap.reset"},
			[]string{"dispatch", `hl.dsp.submap("reset")`}},
		// keyword is rejected by the Lua parser, so live config changes are eval.
		{"autoreload off", []string{"config.autoreload", "off"},
			[]string{"eval", `hl.config({ misc = { disable_autoreload = true } })`}},
		{"workspace layout", []string{"workspace.layout", "9", "master"},
			[]string{"eval", `hl.workspace_rule({ workspace = "9", layout = "master" })`}},
		{"border colours", []string{"decoration.borderColors", "#f3701e", "#0e0d0b"},
			[]string{"eval", `hl.config({general={["col.active_border"]="rgb(f3701e)",["col.inactive_border"]="rgb(0e0d0b)"}})`}},
		{"clear shader", []string{"decoration.screenShader"},
			[]string{"eval", `hl.config({ decoration = { screen_shader = "" } })`}},
		// Top-level hyprctl commands are not keywords and work unchanged.
		{"cursor", []string{"cursor.set", "Bibata-Modern-Ice", "24"},
			[]string{"setcursor", "Bibata-Modern-Ice", "24"}},
		{"keyboard layout", []string{"keyboard.cycleLayout"},
			[]string{"switchxkblayout", "all", "next"}},
		{"reload config only", []string{"config.reload", "config-only"},
			[]string{"reload", "config-only"}},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var got []string
			restore := stubCtl(t, func(args ...string) ([]byte, error) {
				got = args
				return nil, nil
			})
			defer restore()
			if err := runAct(tc.args); err != nil {
				t.Fatalf("runAct(%v): %v", tc.args, err)
			}
			if strings.Join(got, "\x00") != strings.Join(tc.want, "\x00") {
				t.Errorf("argv mismatch\n got: %q\nwant: %q", got, tc.want)
			}
		})
	}
}

// A missing argument must name the value, so a bad keybind is diagnosable, and
// must never reach the compositor with an empty selector (which Hyprland applies
// to the focused window).
func TestActRejectsMissingArgs(t *testing.T) {
	for _, args := range [][]string{
		{"window.focus"},
		{"window.moveToWorkspace", "0xabc"},
		{"workspace.focus"},
		{"workspace.moveToOutput", "9"},
		{"cursor.set", "Bibata"},
		{"output.power"},
	} {
		called := false
		restore := stubCtl(t, func(...string) ([]byte, error) {
			called = true
			return nil, nil
		})
		err := runAct(args)
		restore()
		if err == nil {
			t.Errorf("runAct(%v): expected an error", args)
		}
		if called {
			t.Errorf("runAct(%v): reached the compositor despite a missing argument", args)
		}
	}
}

func TestActRejectsUnknownAction(t *testing.T) {
	restore := stubCtl(t, func(...string) ([]byte, error) { return nil, nil })
	defer restore()
	if err := runAct([]string{"window.teleport"}); err == nil {
		t.Fatal("expected an error for an unknown action")
	}
}

// stubCtl swaps the compositor call and satisfies live(), which every action
// checks before dispatching.
func stubCtl(t *testing.T, fn func(...string) ([]byte, error)) func() {
	t.Helper()
	prevCtl := ctl
	prevSig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	prevAlive := aliveCheck
	ctl = fn
	aliveCheck = func(string) bool { return true }
	os.Setenv("HYPRLAND_INSTANCE_SIGNATURE", "test")
	return func() {
		ctl = prevCtl
		aliveCheck = prevAlive
		os.Setenv("HYPRLAND_INSTANCE_SIGNATURE", prevSig)
	}
}

// The colour temperature is clamped to the range the gamma client accepts and a
// missing or unparseable argument falls back to the default, so a stray keybind
// argument can never ask hyprsunset for a value it would reject or for 0 K.
func TestNightlightTempClamps(t *testing.T) {
	for _, tc := range []struct {
		args []string
		want int
	}{
		{nil, 4000},
		{[]string{""}, 4000},
		{[]string{"not-a-temp"}, 4000},
		{[]string{"4500"}, 4500},
		{[]string{"500"}, 1000},
		{[]string{"99999"}, 25000},
	} {
		if got := nightlightTemp(tc.args); got != tc.want {
			t.Errorf("nightlightTemp(%q) = %d, want %d", tc.args, got, tc.want)
		}
	}
}
