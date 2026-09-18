package main

import (
	"os"
	"testing"
)

// xkbFromKeymap maps the picker's console keymap to an XKB layout for the
// graphical stack. Console and XKB names coincide for most layouts; a suffix or
// alias needs translating. These cases hold whether or not localectl is present
// (a real layout validates; the alias/suffix resolves to a real base either way).
func TestXkbFromKeymap(t *testing.T) {
	for _, c := range []struct{ in, wantL, wantV string }{
		{"it", "it", ""},
		{"de-latin1", "de", ""},
		{"fr-latin1", "fr", ""},
		{"uk", "gb", ""},
		{"us", "us", ""},
		{"", "us", ""},
	} {
		if l, v := xkbFromKeymap(c.in); l != c.wantL || v != c.wantV {
			t.Errorf("xkbFromKeymap(%q) = (%q,%q), want (%q,%q)", c.in, l, v, c.wantL, c.wantV)
		}
	}
}

// keymapRelaunch is the one thing loadkeys cannot do: on the graphical (cage)
// path it must hand the chosen layout to the session so cage relaunches under it
// and the password is captured in the user's real layout. The console path is a
// no-op (loadkeys reaches the VT), and an already-active layout must not loop.
func TestKeymapRelaunch(t *testing.T) {
	const xkbfile = "/tmp/ryoku-xkb"
	os.Remove(xkbfile)
	t.Cleanup(func() { os.Remove(xkbfile) })

	t.Setenv("RYOKU_SESSION", "console")
	t.Setenv("RYOKU_XKB", "")
	if keymapRelaunch("it") {
		t.Error("console path must not relaunch")
	}
	if _, err := os.Stat(xkbfile); err == nil {
		t.Error("console path must not write the xkb file")
	}

	t.Setenv("RYOKU_SESSION", "graphical")
	t.Setenv("RYOKU_XKB", "")
	if !keymapRelaunch("it") {
		t.Fatal("graphical + non-us layout must relaunch")
	}
	if b, err := os.ReadFile(xkbfile); err != nil {
		t.Fatalf("xkb file not written: %v", err)
	} else if string(b) != "it\nit\n\n" {
		t.Errorf("xkb file = %q, want %q", string(b), "it\nit\n\n")
	}

	t.Setenv("RYOKU_XKB", "it") // already active
	if keymapRelaunch("it") {
		t.Error("must not relaunch when the layout is already active")
	}

	t.Setenv("RYOKU_XKB", "") // cage default us, us pick
	if keymapRelaunch("us") {
		t.Error("us pick under cage-default us must not relaunch")
	}
}

// steps() drops the keyboard step on the graphical relaunch (RYOKU_KB_PRESET),
// so the wizard resumes at locale under the already-chosen layout; the rest of
// the flow is untouched.
func TestStepsOmitKeyboardOnPreset(t *testing.T) {
	t.Setenv("RYOKU_KB_PRESET", "")
	if got := steps()[0].key; got != "keyboard" {
		t.Errorf("without preset, first step = %q, want keyboard", got)
	}
	full := len(steps())

	t.Setenv("RYOKU_KB_PRESET", "it")
	s := steps()
	if s[0].key != "locale" {
		t.Errorf("with preset, first step = %q, want locale (keyboard omitted)", s[0].key)
	}
	if len(s) != full-1 {
		t.Errorf("with preset, step count = %d, want %d (one fewer)", len(s), full-1)
	}
}

// A Belgian keyboard (be-latin1) must float the Belgian locales to the top of the
// picker and never let the Belarusian be_BY -- which shares the "be" prefix and a
// Cyrillic script -- lead or outrank them, which is how a Belgian install ended up
// with a Russian-looking shell.
func TestPromoteKbLocalesFloatsCountry(t *testing.T) {
	items := []item{
		{"en_US.UTF-8", "en_US.UTF-8", ""},
		{"be_BY.UTF-8", "be_BY.UTF-8", ""},
		{"ru_RU.UTF-8", "ru_RU.UTF-8", ""},
		{"fr_BE.UTF-8", "fr_BE.UTF-8", ""},
		{"nl_BE.UTF-8", "nl_BE.UTF-8", ""},
	}
	got := promoteKbLocales(items, "be-latin1")
	if got[0].key != "fr_BE.UTF-8" && got[0].key != "nl_BE.UTF-8" {
		t.Fatalf("first locale = %q, want a *_BE locale on top for a Belgian keyboard", got[0].key)
	}
	pos := map[string]int{}
	for i, it := range got {
		pos[it.key] = i
	}
	if pos["be_BY.UTF-8"] < pos["fr_BE.UTF-8"] || pos["be_BY.UTF-8"] < pos["nl_BE.UTF-8"] {
		t.Errorf("Belarusian be_BY ranked above a Belgian locale (fr_BE=%d nl_BE=%d be_BY=%d)",
			pos["fr_BE.UTF-8"], pos["nl_BE.UTF-8"], pos["be_BY.UTF-8"])
	}
	// a us keyboard has nothing to disambiguate: order is untouched.
	if same := promoteKbLocales(items, "us"); same[0].key != "en_US.UTF-8" {
		t.Errorf("us keyboard reordered the locale list: first = %q", same[0].key)
	}
}

func TestLocaleTerritory(t *testing.T) {
	for in, want := range map[string]string{
		"fr_BE.UTF-8": "BE", "be_BY.UTF-8": "BY", "en_US.UTF-8": "US",
		"pt_BR": "BR", "C": "", "C.UTF-8": "",
	} {
		if got := localeTerritory(in); got != want {
			t.Errorf("localeTerritory(%q) = %q, want %q", in, got, want)
		}
	}
}
