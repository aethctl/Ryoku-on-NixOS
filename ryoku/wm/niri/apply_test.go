package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	wm "ryoku-wm"
)

// apply is pure store -> KDL, so these exercise the generated files directly: the
// real niri binary validates them (skipped where niri is absent), the switch
// preview writes nothing, and the unhonored list names the losses a user reads.

func niriBin(t *testing.T) string {
	t.Helper()
	p, err := exec.LookPath("niri")
	if err != nil {
		t.Skip("niri not installed; skipping validation")
	}
	return p
}

// niriHome points the provider's config and overlay trees at a temp dir and
// returns the niri config dir apply writes into.
func niriHome(t *testing.T) string {
	t.Helper()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	return niriConfigDir()
}

func writeStore(t *testing.T, body string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "desktop.json")
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return p
}

// capApply runs apply with stdout captured and returns the decoded report.
func capApply(t *testing.T, args ...string) wm.ApplyReport {
	t.Helper()
	var buf bytes.Buffer
	prev := stdout
	stdout = bufio.NewWriter(&buf)
	defer func() { stdout = prev }()
	if err := runApply(args); err != nil {
		t.Fatalf("runApply(%v): %v", args, err)
	}
	stdout.Flush()
	var rep wm.ApplyReport
	if err := json.Unmarshal(buf.Bytes(), &rep); err != nil {
		t.Fatalf("decode report: %v\n%s", err, buf.String())
	}
	return rep
}

func readGen(t *testing.T, dir, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(dir, name))
	if err != nil {
		t.Fatalf("read %s: %v", name, err)
	}
	return string(b)
}

// validateGen writes a tiny includer next to the generated files and runs the
// real niri validate against it, which also proves the missing-include rule
// cannot bite because both files are always present.
func validateGen(t *testing.T, dir string, includes ...string) {
	t.Helper()
	niri := niriBin(t)
	var b strings.Builder
	for _, inc := range includes {
		b.WriteString("include ")
		b.WriteString(kdlStr(inc))
		b.WriteString("\n")
	}
	cfg := filepath.Join(dir, "config.kdl")
	if err := os.WriteFile(cfg, []byte(b.String()), 0o644); err != nil {
		t.Fatal(err)
	}
	if out, err := exec.Command(niri, "validate", "-c", cfg).CombinedOutput(); err != nil {
		t.Fatalf("niri validate failed: %v\n%s", err, out)
	}
}

func TestApplyEmitsValidKDL(t *testing.T) {
	dir := niriHome(t)
	store := writeStore(t, `{"desktop":{
		"appearance":{"gapsOut":10,"borderSize":3,"rounding":8,"activeBorder":"#ff0000","inactiveBorder":"#202020"},
		"input":{"kbLayout":"us","kbVariant":"colemak","kbOptions":"ctrl:nocaps","tapToClick":true,"naturalScroll":true,"sensitivity":0.3,"accelProfile":"flat","repeatRate":30,"repeatDelay":250},
		"cursor":{"theme":"Bibata-Modern-Ice","size":24,"inactiveTimeout":5},
		"env":[{"key":"QT_QPA_PLATFORM","value":"wayland"}],
		"autostart":[{"command":"waybar --config a"}],
		"windowRules":[{"class":"Spotify","action":"float"},{"class":"mpv","action":"opacity","value":"0.9"},{"title":"pip","action":"fullscreen"}],
		"appOverrides":[{"class":"kitty","opacity":0.95,"rounding":6,"borderSize":-1}],
		"keybinds":[{"keys":"SUPER + T","action":"exec","value":"kitty"},{"keys":"SUPER + G","action":"togglefloating"}]
	},"wm":{"niri":{"preferNoCsd":true,"overviewZoom":0.5}}}`)

	rep := capApply(t, store)
	if len(rep.Written) != 2 {
		t.Fatalf("written = %v, want settings.kdl + rebinds.kdl", rep.Written)
	}
	if rep.ReloadNeeded {
		t.Error("niri watches its own config; ReloadNeeded must be false")
	}

	settings := readGen(t, dir, "settings.kdl")
	if !strings.Contains(settings, "geometry-corner-radius 8") {
		t.Errorf("rounding not mapped to geometry-corner-radius\n%s", settings)
	}
	if !strings.Contains(settings, "open-floating true") {
		t.Errorf("float rule not emitted\n%s", settings)
	}
	rebinds := readGen(t, dir, "rebinds.kdl")
	if !strings.Contains(rebinds, `Super+T { spawn-sh "kitty"; }`) {
		t.Errorf("custom exec bind not emitted as spawn-sh\n%s", rebinds)
	}
	if !strings.Contains(rebinds, "Super+G { toggle-window-floating; }") {
		t.Errorf("custom togglefloating bind not emitted\n%s", rebinds)
	}
	validateGen(t, dir, "settings.kdl", "rebinds.kdl")
}

// A near-empty store still boots Ryoku's look: both files are written, carry the
// full baseline, validate, and two applies produce identical bytes.
func TestApplyAlwaysWritesBothAndIsDeterministic(t *testing.T) {
	dir := niriHome(t)
	store := writeStore(t, `{}`)

	capApply(t, store)
	s1 := readGen(t, dir, "settings.kdl")
	r1 := readGen(t, dir, "rebinds.kdl")
	if !strings.Contains(s1, "layout {") || !strings.Contains(s1, "cursor {") {
		t.Errorf("baseline look missing from a default apply\n%s", s1)
	}
	if !strings.Contains(r1, "close-window") {
		t.Errorf("default binds missing from a default apply\n%s", r1)
	}

	capApply(t, store)
	if s2 := readGen(t, dir, "settings.kdl"); s2 != s1 {
		t.Error("settings.kdl not deterministic across two applies")
	}
	if r2 := readGen(t, dir, "rebinds.kdl"); r2 != r1 {
		t.Error("rebinds.kdl not deterministic across two applies")
	}
	validateGen(t, dir, "settings.kdl", "rebinds.kdl")
}

func TestPreviewWritesNothing(t *testing.T) {
	dir := niriHome(t)
	store := writeStore(t, `{"desktop":{"appearance":{"gapsOut":5},"keybinds":[{"keys":"SUPER + Y","action":"exec","value":"foot"}]}}`)

	rep := capApply(t, store, "--preview")
	if len(rep.Written) != 0 {
		t.Fatalf("preview reported Written = %v, want none", rep.Written)
	}
	for _, name := range []string{"settings.kdl", "rebinds.kdl"} {
		if _, err := os.Stat(filepath.Join(dir, name)); !os.IsNotExist(err) {
			t.Errorf("preview wrote %s", name)
		}
	}
}

// The unhonored list is the switch cost: a desktop.* leaf niri cannot express is
// named on its own, and a foreign compositor's whole namespace collapses to one
// aggregated line rather than a per-key dump.
func TestUnhonoredNamesForeignAndSubmap(t *testing.T) {
	niriHome(t)
	store := writeStore(t, `{"desktop":{
		"appearance":{"blurEnabled":true,"gapsOut":8},
		"keybinds":[{"keys":"SUPER + ALT + 5","action":"submap","value":"resize"}]
	},"wm":{"hyprland":{"plugins":{"hyprbars":{"enabled":true}},"dwindle":{"preserveSplit":true},"anim":{"items":[]}}}}`)

	rep := capApply(t, store, "--preview")

	var blur, submap bool
	foreign := 0
	for _, u := range rep.Unhonored {
		if u.Key == "desktop.appearance.blurEnabled" && strings.Contains(u.Reason, "blur") {
			blur = true
		}
		if strings.HasPrefix(u.Key, "wm.hyprland") {
			foreign++
			if !strings.Contains(u.Reason, "Hyprland") || !strings.Contains(u.Reason, "store") {
				t.Errorf("foreign reason should name Hyprland and the store: %q", u.Reason)
			}
		}
		if strings.Contains(strings.ToLower(u.Reason), "submap") {
			submap = true
		}
	}
	if !blur {
		t.Error("desktop.appearance.blurEnabled must be reported unhonored")
	}
	if !submap {
		t.Error("a submap keybind must be reported unhonored, naming submap")
	}
	if foreign != 1 {
		t.Errorf("wm.hyprland reported %d entries, want exactly one aggregated line", foreign)
	}
}

// A rebind onto another default's chord must resolve to that chord once, with the
// rebind winning, or niri rejects the whole config as a duplicate.
func TestRebindOntoAnotherDefaultKeepsChordOnce(t *testing.T) {
	dir := niriHome(t)
	// Super+Q (close) is rebound onto Super+F, the default fullscreen chord.
	store := writeStore(t, `{"desktop":{"keybindRebinds":{"SUPER + Q":"SUPER + F"}}}`)

	capApply(t, store)
	rebinds := readGen(t, dir, "rebinds.kdl")

	var superF []string
	for _, line := range strings.Split(rebinds, "\n") {
		if strings.Contains(line, "Super+F") {
			superF = append(superF, strings.TrimSpace(line))
		}
	}
	if len(superF) != 1 {
		t.Fatalf("Super+F must appear once, got %d:\n%s", len(superF), rebinds)
	}
	if !strings.Contains(superF[0], "close-window") {
		t.Errorf("rebound close must win Super+F, got %q", superF[0])
	}
	if strings.Contains(rebinds, "fullscreen-window") {
		t.Errorf("the displaced fullscreen default must be dropped, not co-emitted\n%s", rebinds)
	}
	validateGen(t, dir, "rebinds.kdl")
}

// An unbound default chord is gone from the generated block, not left live.
func TestUnbindDropsDefault(t *testing.T) {
	dir := niriHome(t)
	store := writeStore(t, `{"desktop":{"unbinds":["SUPER + Q"]}}`)

	capApply(t, store)
	rebinds := readGen(t, dir, "rebinds.kdl")
	if strings.Contains(rebinds, "Super+Q") {
		t.Errorf("unbound Super+Q must not be emitted\n%s", rebinds)
	}
	validateGen(t, dir, "rebinds.kdl")
}

// runDefaults must carry the niri exclusives under wm.niri, or SettingDomains
// advertises a namespace the Hub finds empty and gates rows with nothing behind.
func TestDefaultsCarryNiriNamespace(t *testing.T) {
	prev := aliveCheck
	aliveCheck = func(string) bool { return false } // offline, deterministic
	defer func() { aliveCheck = prev }()

	var buf bytes.Buffer
	prevOut := stdout
	stdout = bufio.NewWriter(&buf)
	defer func() { stdout = prevOut }()
	if err := runDefaults(); err != nil {
		t.Fatalf("runDefaults: %v", err)
	}
	stdout.Flush()

	var tree struct {
		Desktop map[string]json.RawMessage `json:"desktop"`
		WM      struct {
			Niri map[string]json.RawMessage `json:"niri"`
		} `json:"wm"`
	}
	if err := json.Unmarshal(buf.Bytes(), &tree); err != nil {
		t.Fatalf("decode defaults: %v\n%s", err, buf.String())
	}
	for _, k := range []string{"appearance", "input", "cursor"} {
		if _, ok := tree.Desktop[k]; !ok {
			t.Errorf("defaults missing desktop.%s", k)
		}
	}
	if len(tree.WM.Niri) == 0 {
		t.Fatal("wm.niri must carry the exclusive sections")
	}
	if _, ok := tree.WM.Niri["preferNoCsd"]; !ok {
		t.Error("wm.niri must include preferNoCsd")
	}
}
