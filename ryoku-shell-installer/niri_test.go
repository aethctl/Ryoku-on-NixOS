package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const niriSample = `
input {
    keyboard {
        xkb {
            layout "us,de"
            options "grp:alt_shift_toggle,caps:escape"
        }
    }
}
output "DP-1" {
    mode "2560x1440@165.004"
    scale 1.5
    transform "90"
    position x=1280 y=0
    variable-refresh-rate
}
output "eDP-1" {
    off
}
/- output "DP-9" {
    scale 2
}
output "HDMI-A-1" {
    // just a comment, nothing set
}
output "Some Co CoolMonitor 1234" {
    transform "180"
}
`

func TestParseNiriXkb(t *testing.T) {
	layout, variant, options, hasFile := parseNiriXkb(niriSample)
	if hasFile || layout != "us,de" || variant != "" || options != "grp:alt_shift_toggle,caps:escape" {
		t.Fatalf("got %q %q %q file=%v", layout, variant, options, hasFile)
	}
	_, _, _, hasFile = parseNiriXkb("xkb {\n    file \"~/.config/keymap.xkb\"\n}\n")
	if !hasFile {
		t.Fatal("keymap file must disable field salvage")
	}
}

func TestParseNiriOutputs(t *testing.T) {
	outs := parseNiriOutputs(niriSample)
	if len(outs) != 3 {
		t.Fatalf("want DP-1, eDP-1 and the desc name, got %+v", outs)
	}
	dp := outs[0]
	if dp.name != "DP-1" || dp.mode != "2560x1440@165.004" || dp.scale != "1.5" ||
		dp.transform != 1 || dp.position != "1280x0" || dp.vrr != 1 || dp.off {
		t.Fatalf("DP-1 parsed wrong: %+v", dp)
	}
	if !outs[1].off || outs[1].name != "eDP-1" {
		t.Fatalf("eDP-1 off missed: %+v", outs[1])
	}
	// later block for the same name wins
	dup := parseNiriOutputs("output \"DP-1\" { scale 1 }\noutput \"DP-1\" { scale 2 }\n")
	if len(dup) != 1 || dup[0].scale != "2" {
		t.Fatalf("last-wins failed: %+v", dup)
	}
}

func TestRenderNiriPins(t *testing.T) {
	pins, skipped := renderNiriPins(parseNiriOutputs(niriSample))
	if len(skipped) != 1 || skipped[0] != "Some Co CoolMonitor 1234" {
		t.Fatalf("desc name not skipped: %v", skipped)
	}
	want := `hl.monitor({ output = "DP-1", mode = "2560x1440@165.004", position = "1280x0", scale = 1.5, transform = 1, vrr = 1 })`
	if !strings.Contains(pins, want) {
		t.Fatalf("missing pin %q in:\n%s", want, pins)
	}
	if !strings.Contains(pins, `hl.monitor({ output = "eDP-1", disabled = true })`) {
		t.Fatalf("missing disabled pin:\n%s", pins)
	}
}

func TestReadNiriTreeIncludes(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config/niri")
	if err := os.MkdirAll(filepath.Join(root, "cfg"), 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(root, "config.kdl"), []byte("include \"./cfg/*.kdl\"\n"), 0o644)
	os.WriteFile(filepath.Join(root, "cfg/display.kdl"), []byte("output \"DP-2\" { scale 2 }\n"), 0o644)
	outs := parseNiriOutputs(loadNiriConfig(home))
	if len(outs) != 1 || outs[0].name != "DP-2" || outs[0].scale != "2" {
		t.Fatalf("include glob not followed: %+v", outs)
	}
}

// The KDL pins are what a niri install carries the user's display layout in, so
// the emitted file has to be config niri will actually load. A wrong block is
// not a cosmetic bug: the pins ride into monitors_user.kdl, which config.kdl
// includes, and a parse error there costs the session.
func TestRenderKdlPinsValidates(t *testing.T) {
	outs := []niriOutput{
		{name: "eDP-1", mode: "2560x1600@165.001", position: "0x0", scale: "1.6", transform: 1},
		{name: "HDMI-A-1", off: true},
		// highrr and auto have no niri spelling, so both are left out and niri
		// picks: the block must still be valid with neither.
		{name: "DP-2", mode: "highrr", position: "auto", vrr: 1},
		{name: "Some Vendor Panel 123", mode: "1920x1080"},
	}
	pins, skipped := renderKdlPins(outs, false, "niri")
	if len(skipped) != 1 || skipped[0] != "Some Vendor Panel 123" {
		t.Fatalf("description-style name must be skipped, got %v", skipped)
	}
	for _, want := range []string{
		`output "eDP-1" {`, `mode "2560x1600@165.001"`, `scale 1.6`,
		`position x=0 y=0`, `transform "90"`, `off`, `variable-refresh-rate`,
	} {
		if !strings.Contains(pins, want) {
			t.Errorf("pins missing %q\n%s", want, pins)
		}
	}
	if strings.Contains(pins, "highrr") || strings.Contains(pins, `position x=auto`) {
		t.Errorf("emitted a value niri cannot express:\n%s", pins)
	}

	if _, err := exec.LookPath("niri"); err != nil {
		t.Skip("niri not installed; format assertions above still ran")
	}
	dir := t.TempDir()
	path := filepath.Join(dir, "monitors_user.kdl")
	if err := os.WriteFile(path, []byte(pins), 0o644); err != nil {
		t.Fatal(err)
	}
	if out, err := exec.Command("niri", "validate", "-c", path).CombinedOutput(); err != nil {
		t.Fatalf("niri rejected the emitted pins: %v\n%s\n%s", err, out, pins)
	}
}
