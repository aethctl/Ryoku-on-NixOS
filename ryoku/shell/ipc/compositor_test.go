package main

import "testing"

func TestSelectCompositor(t *testing.T) {
	tests := []struct {
		name      string
		desktop   string
		hyprAlive bool
		niriAlive bool
		want      string
	}{
		{"hypr hint", "Hyprland", true, true, compositorHyprland},
		{"niri hint", "niri", true, true, compositorNiri},
		{"hypr only", "", true, false, compositorHyprland},
		{"niri only", "", false, true, compositorNiri},
		{"none", "", false, false, ""},
		{"ambiguous", "", true, true, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := selectCompositor(tt.desktop, tt.hyprAlive, tt.niriAlive); got != tt.want {
				t.Fatalf("selectCompositor(%q, %v, %v) = %q, want %q", tt.desktop, tt.hyprAlive, tt.niriAlive, got, tt.want)
			}
		})
	}
}
