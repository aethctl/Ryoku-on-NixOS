package main

import (
	"strings"
	"testing"
)

// niri's border block starts off and only merges on when the block carries an
// explicit on flag, so these pin that flag directly on the emitter output: a
// bare width would validate yet draw no frame. The layout block and the per-app
// override both resolve through the same BorderRule merge, so both must carry it.

// layoutBorderBlock returns the border sub-block inside the top-level layout
// block, so an assertion sees only the frame the user sized, not a per-app rule.
func layoutBorderBlock(t *testing.T, out string) string {
	t.Helper()
	li := strings.Index(out, "layout {")
	if li < 0 {
		t.Fatalf("no layout block\n%s", out)
	}
	rest := out[li:]
	bi := strings.Index(rest, "    border {\n")
	if bi < 0 {
		t.Fatalf("no border block in layout\n%s", out)
	}
	body := rest[bi:]
	end := strings.Index(body, "\n    }\n")
	if end < 0 {
		t.Fatalf("border block not closed\n%s", out)
	}
	return body[:end+len("\n    }\n")]
}

func TestLayoutBorderOnFlag(t *testing.T) {
	sized := layoutBorderBlock(t, string(genSettings(defaultStore())))
	if !strings.Contains(sized, "\n        on\n") {
		t.Errorf("a sized border must carry a bare on flag; niri leaves it off without one\n%s", sized)
	}
	if !strings.Contains(sized, "width 4") {
		t.Errorf("a sized border must keep its width\n%s", sized)
	}
	if strings.Contains(sized, "\n        off\n") {
		t.Errorf("a sized border must not be off\n%s", sized)
	}

	s := defaultStore()
	s.Appearance.BorderSize = 0
	off := layoutBorderBlock(t, string(genSettings(s)))
	if !strings.Contains(off, "\n        off\n") {
		t.Errorf("a zero border must be off\n%s", off)
	}
	if strings.Contains(off, "\n        on\n") || strings.Contains(off, "width") {
		t.Errorf("a zero border must carry neither on nor width\n%s", off)
	}
}

func TestLayoutBorderAppOverrideFlag(t *testing.T) {
	s := defaultStore()
	s.AppOverrides = []AppOverride{
		{Class: "kitty", Opacity: -1, Rounding: -1, BorderSize: 7},
		{Class: "mpv", Opacity: -1, Rounding: -1, BorderSize: 0},
		{Class: "foot", Opacity: -1, Rounding: -1, BorderSize: -1},
	}
	out := string(genSettings(s))

	if !strings.Contains(out, "    border {\n        on\n        width 7\n    }\n") {
		t.Errorf("a per-app sized border must carry on and its width\n%s", out)
	}
	if !strings.Contains(out, "    border {\n        off\n    }\n") {
		t.Errorf("a per-app zero border must be off\n%s", out)
	}
	if strings.Contains(out, `app-id="foot"`) {
		t.Errorf("an inherit-only override must emit no rule at all\n%s", out)
	}
}
