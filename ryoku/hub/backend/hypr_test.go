package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// A custom keybind with release mode on must emit the Hyprland release flag, and
// a normal (press) keybind must not carry it. The Hub writes this into
// settings.lua, so a regression would silently change when shortcuts fire.
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

func TestDefaultFollowMouseMatchesShippedInput(t *testing.T) {
	const detachedFocus = 2
	if got := defaultOverrides().Input.FollowMouse; got != detachedFocus {
		t.Fatalf("Hub default input.follow_mouse = %d, want %d", got, detachedFocus)
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
