package main

import (
	"strings"
	"testing"
)

// desktop.md must carry the GUI map so an agent answers "how do I" questions
// GUI-first: the Ryoku Hub deep link, a compositor-neutral page name like
// Graphics & Power, and the picker and bar-settings commands behind the surfaces.
func TestDesktopBodyGUIMap(t *testing.T) {
	body := desktopBody()
	for _, want := range []string{
		"## GUI map",
		"hub open",
		"Graphics & Power",
		"ryogami wallpaper ui",
		"ryoku-shell bar settings",
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("desktop.md GUI map missing %q", want)
		}
	}
}
