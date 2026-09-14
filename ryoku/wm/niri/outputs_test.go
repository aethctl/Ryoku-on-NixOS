package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	wm "ryoku-wm"
)

// monitorsKdl is the write half of the display seam, and niri rejects the whole
// config on a bad node, taking the session down with it. So the rendered block is
// pinned by shape and validated by the real niri: an enabled output carries
// mode/scale/position and only the transform and VRR nodes it needs, a disabled
// one is a bare `off`.
func TestMonitorsKdl(t *testing.T) {
	got := string(monitorsKdl([]wm.OutputLayout{
		{Name: "eDP-1", Enabled: true, Mode: "2560x1600@165.002", Scale: 1.5, X: 0, Y: 0, Transform: 1, VRR: true},
		{Name: "DP-2", Enabled: false},
	}))

	for _, want := range []string{
		`output "eDP-1" {`,
		`mode "2560x1600@165.002"`,
		`scale 1.5`,
		`position x=0 y=0`,
		`transform "90"`,
		`variable-refresh-rate`,
		`output "DP-2" {`,
	} {
		if !strings.Contains(got, want) {
			t.Errorf("monitors.kdl missing %q\n%s", want, got)
		}
	}

	dp2 := got[strings.Index(got, `output "DP-2"`):]
	if !strings.Contains(dp2, "off") {
		t.Errorf("a disabled output must be `off`:\n%s", dp2)
	}
	if strings.Contains(dp2, "scale") || strings.Contains(dp2, "mode") {
		t.Errorf("a disabled output must carry no mode or scale:\n%s", dp2)
	}

	dir := niriHome(t)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "monitors.kdl"), []byte(got), 0o644); err != nil {
		t.Fatal(err)
	}
	validateGen(t, dir, "monitors.kdl")
}

// An untransformed, non-VRR output emits neither node, so the block stays minimal
// and a 0 transform never reads back as a rotation.
func TestMonitorsKdlOmitsDefaults(t *testing.T) {
	got := string(monitorsKdl([]wm.OutputLayout{
		{Name: "eDP-1", Enabled: true, Mode: "1920x1080@60", Scale: 1, X: 0, Y: 0},
	}))
	if strings.Contains(got, "transform") {
		t.Errorf("transform 0 must be omitted:\n%s", got)
	}
	if strings.Contains(got, "variable-refresh-rate") {
		t.Errorf("VRR off must be omitted:\n%s", got)
	}
}

// A profile saved on another compositor can carry mirror and HDR; replayed on
// niri, each is reported per leaf so the apply names its losses instead of
// failing or dropping them silently, while a neutral output reports nothing.
func TestOutputsUnhonoredReportsMirrorAndColour(t *testing.T) {
	unh := outputsUnhonored([]wm.OutputLayout{
		{Name: "eDP-1", Enabled: true, Mirror: "DP-1", ColorMode: "hdr", SdrBrightness: 1.5},
		{Name: "DP-1", Enabled: true, ColorMode: "srgb", SdrBrightness: 1},
	})
	got := map[string]bool{}
	for _, u := range unh {
		got[u.Key] = true
	}
	for _, want := range []string{"displays.eDP-1.mirror", "displays.eDP-1.colorMode", "displays.eDP-1.sdrBrightness"} {
		if !got[want] {
			t.Errorf("missing unhonored %q; got %v", want, unh)
		}
	}
	if got["displays.DP-1.mirror"] || got["displays.DP-1.colorMode"] || got["displays.DP-1.sdrBrightness"] {
		t.Errorf("a neutral output must report nothing; got %v", unh)
	}
}
