package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	wm "ryoku-wm"
)

// The keybind legend: the shared binds parsed from binds.lua (the live
// ryoku/hyprland/modules/binds.lua), struck against what the active provider
// says it cannot honour, then followed by that provider's own
// compositor-exclusive binds as one section under the compositor's name. Each
// part reads its single source at request time so none drifts: the shared set
// from the file the desktop loads, the honesty pass and the exclusives both from
// the provider that owns them, so the sheet never claims a chord the running
// compositor does not perform.

type bind struct {
	Keys       []string `json:"keys"`
	Combo      string   `json:"combo"`
	Desc       string   `json:"desc"`
	Rebindable bool     `json:"rebindable"`
}

type category struct {
	Name  string `json:"name"`
	Binds []bind `json:"binds"`
}

type legend struct {
	Categories []category `json:"categories"`
}

func bindsPath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "hypr", "modules", "binds.lua")
}

func keybinds() legend {
	l := legend{Categories: []category{}}
	if b, err := os.ReadFile(bindsPath()); err == nil {
		l = parseBinds(string(b))
	}
	filterLegend(&l, unhonoredChords())
	appendCompositorBinds(&l)
	return l
}

// reUnhonoredChord pulls the chord out of the key the provider stamps on a
// shared bind it cannot honour: "desktop.keybinds (default SUPER + SHIFT + P)".
// The chord it carries is the legend's own combo, so a match strikes the row.
var reUnhonoredChord = regexp.MustCompile(`^desktop\.keybinds \(default (.+)\)$`)

// unhonoredChords maps each shared chord the active provider cannot honour to
// its reason, off the same dry-run report the window-manager page's cannot-do
// section renders. Empty for a provider that honours every shared bind (Hyprland
// over its own config answers an empty list), or when no provider answers, so
// the legend then passes through untouched.
func unhonoredChords() map[string]string {
	c := desktopClient()
	if !c.Available() {
		return nil
	}
	rep, err := c.DryRun(desktopStorePath())
	if err != nil {
		return nil
	}
	out := map[string]string{}
	for _, u := range rep.Unhonored {
		if m := reUnhonoredChord.FindStringSubmatch(u.Key); m != nil {
			out[m[1]] = u.Reason
		}
	}
	return out
}

// filterLegend strikes the shared legend against the chords the running
// compositor cannot honour, so the sheet never advertises a bind that does
// nothing. A keyboard chord the compositor has no concept of (pin, scratchpad)
// leaves the sheet outright. A pointer gesture stays: holding the modifier and
// dragging is the compositor's own interaction rather than a rebindable key, so
// the row keeps its caps but reads the provider's reason instead of an action it
// no longer fires. A category emptied by the strike is dropped, never left as a
// bare header.
func filterLegend(l *legend, reasons map[string]string) {
	if len(reasons) == 0 {
		return
	}
	var cats []category
	for _, cat := range l.Categories {
		var kept []bind
		for _, b := range cat.Binds {
			reason, ok := reasons[b.Combo]
			if !ok {
				kept = append(kept, b)
				continue
			}
			if !strings.Contains(b.Combo, "mouse") {
				continue
			}
			b.Desc = capitalize(reason)
			b.Rebindable = false
			kept = append(kept, b)
		}
		if len(kept) > 0 {
			cats = append(cats, category{Name: cat.Name, Binds: kept})
		}
	}
	if cats == nil {
		cats = []category{}
	}
	l.Categories = cats
}

// appendCompositorBinds folds the active provider's compositor-exclusive binds
// into the legend as one section titled with the compositor's own name, read from
// the same provider name the Hub's window-manager page titles itself from. It
// carries only the binds the shared legend above does not already document, so a
// chord never reads twice; the provider resolves them against the store, so a
// bind a user displaced is already gone. The section is left off when the provider
// adds none, so a compositor whose binds are all shared shows no empty group.
func appendCompositorBinds(l *legend) {
	c := wm.Open()
	if !c.Available() {
		return
	}
	rows, err := c.Binds(desktopStorePath())
	if err != nil || len(rows) == 0 {
		return
	}
	if cat, ok := compositorSection(rows, capitalize(c.Detection().Name), l); ok {
		l.Categories = append(l.Categories, cat)
	}
}

// compositorSection turns the provider's own rows into one named legend section.
// A chord the shared legend already carries keeps its place in its own group and
// takes the provider's description instead: the shared text comes from one
// compositor's config, so on another it can name a mechanic that does not exist
// there (a resize submap where the chord actually cycles preset widths). Only a
// chord the shared legend has no row for lands in the named section, so a chord
// still never reads twice. ok is false when nothing survives, so the caller adds
// no empty group.
func compositorSection(rows []json.RawMessage, name string, base *legend) (category, bool) {
	shared := map[string]*bind{}
	for ci := range base.Categories {
		for bi := range base.Categories[ci].Binds {
			b := &base.Categories[ci].Binds[bi]
			shared[b.Combo] = b
		}
	}
	var binds []bind
	for _, raw := range rows {
		var e struct {
			Chord string `json:"chord"`
			Desc  string `json:"desc"`
		}
		if json.Unmarshal(raw, &e) != nil || e.Chord == "" {
			continue
		}
		if b, ok := shared[e.Chord]; ok {
			if b != nil && e.Desc != "" {
				b.Desc = capitalize(e.Desc)
			}
			continue
		}
		shared[e.Chord] = nil
		binds = append(binds, bind{
			Keys:       splitCombo(e.Chord),
			Combo:      e.Chord,
			Desc:       capitalize(e.Desc),
			Rebindable: rebindable(e.Chord),
		})
	}
	if len(binds) == 0 {
		return category{}, false
	}
	return category{Name: name, Binds: binds}, true
}

var (
	reHeader = regexp.MustCompile(`^--\s+(.+?)\s*$`)
	reBind   = regexp.MustCompile(`hl\.bind\((.*?),\s*(.+)$`)
	reTrail  = regexp.MustCompile(`\s--\s+(.+?)\s*$`)
	reExec   = regexp.MustCompile(`exec_cmd\("([^"]*)"`)
)

// sectionName titles a category from its section comment, cut at the first
// sentence so a header that goes on to explain itself ("Workspaces. Super+N
// focuses...") still reads as "Workspaces".
func sectionName(s string) string {
	if i := strings.Index(s, ". "); i > 0 {
		return s[:i]
	}
	return strings.TrimSuffix(s, ".")
}

// parseBinds walks binds.lua a line at a time. A section comment (`-- Apps`) set
// off by a blank line above it opens a category; each hl.bind adds an entry,
// description = the trailing comment if present, else derived from the
// dispatcher. the 1..0 workspace loop collapses into two range entries.
func parseBinds(src string) legend {
	var cats []category
	cur := -1
	inLoop := false
	prevComment := false
	prevBlank := true

	add := func(b bind) {
		if cur < 0 {
			cats = append(cats, category{Name: "General"})
			cur = 0
		}
		cats[cur].Binds = append(cats[cur].Binds, b)
	}

	for _, line := range strings.Split(src, "\n") {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "for ") {
			inLoop = true
			prevComment, prevBlank = false, false
			continue
		}
		if inLoop && trimmed == "end" {
			inLoop = false
			prevComment, prevBlank = false, false
			continue
		}

		if !strings.Contains(trimmed, "hl.bind(") {
			m := reHeader.FindStringSubmatch(trimmed)
			// A real section header opens a category; a comment that is prose
			// does not. Two prose shapes fooled the parser here: the continuation
			// lines of a multi-line header (caught by prevComment), and an
			// explanatory note dropped between two binds. A header always sits at
			// the top of its block, one blank line below the binds above it, so a
			// comment that follows code with no gap is that note, not a header.
			if m != nil && !prevComment && prevBlank {
				cats = append(cats, category{Name: sectionName(m[1])})
				cur = len(cats) - 1
			}
			prevComment = m != nil
			prevBlank = trimmed == ""
			continue
		}
		prevComment = false
		prevBlank = false

		comment := ""
		if m := reTrail.FindStringSubmatch(line); m != nil {
			comment = m[1]
		}
		m := reBind.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		loopVar := ""
		if inLoop {
			loopVar = "1\u20260" // 1…0
		}
		keys, combo := resolveKeys(m[1], loopVar)
		add(bind{
			Keys:       keys,
			Combo:      combo,
			Desc:       describe(comment, m[2]),
			Rebindable: rebindable(combo),
		})
	}

	if cats == nil {
		cats = []category{}
	}
	return legend{Categories: cats}
}

// resolveKeys: first hl.bind arg -> (display tokens, raw combo). the arg may be
// wrapped in the K() rebind helper (K(mod .. " + Q")); unwrap it first. then it
// is either a quoted key literal ("XF86AudioRaiseVolume") or a Lua concat
// (mod .. " + SHIFT + A"); inside the workspace loop the key/i identifier becomes
// the 1…0 range. the raw combo is what K() keys on at runtime, i.e. the rebind id.
func resolveKeys(arg, loopVar string) ([]string, string) {
	arg = strings.TrimSpace(arg)
	if strings.HasPrefix(arg, "K(") && strings.HasSuffix(arg, ")") {
		arg = strings.TrimSpace(arg[2 : len(arg)-1])
	}
	if strings.HasPrefix(arg, "\"") {
		s := unquote(arg)
		return splitCombo(s), s
	}
	var sb strings.Builder
	for _, p := range strings.Split(arg, "..") {
		p = strings.TrimSpace(p)
		switch {
		case p == "mod":
			sb.WriteString("SUPER")
		case strings.HasPrefix(p, "\""):
			sb.WriteString(unquote(p))
		case p == "key" || p == "i":
			sb.WriteString(loopVar)
		default:
			sb.WriteString(p)
		}
	}
	raw := sb.String()
	return splitCombo(raw), raw
}

// rebindable: only a single literal combo can be recorded over. the workspace
// loop (its combo carries the 1…0 range) and the pointer binds cannot.
func rebindable(combo string) bool {
	return combo != "" && !strings.Contains(combo, "\u2026") && !strings.Contains(combo, "mouse")
}

func splitCombo(s string) []string {
	var out []string
	for _, p := range strings.Split(s, "+") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, prettyKey(p))
		}
	}
	return out
}

func unquote(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 && strings.HasPrefix(s, "\"") && strings.HasSuffix(s, "\"") {
		return s[1 : len(s)-1]
	}
	return s
}

var keyNames = map[string]string{
	"SUPER":   "Super",
	"SHIFT":   "Shift",
	"ALT":     "Alt",
	"CTRL":    "Ctrl",
	"CONTROL": "Ctrl",
	"Return":  "Enter",
	"comma":   ",",
	"grave":   "\u0060",
	"Left":    "\u2190",
	"Right":   "\u2192",
	"Up":      "\u2191",
	"Down":    "\u2193",

	"mouse:272":  "LMB",
	"mouse:273":  "RMB",
	"mouse_up":   "Scroll \u2191",
	"mouse_down": "Scroll \u2193",

	"XF86AudioRaiseVolume": "Vol +",
	"XF86AudioLowerVolume": "Vol \u2212",
	"XF86AudioMute":        "Mute",
	"XF86AudioPlay":        "Play",
	"XF86AudioNext":        "Next",
	"XF86AudioPrev":        "Prev",
	"XF86TouchpadToggle":   "Touchpad",
	"XF86TouchpadOn":       "Touchpad On",
	"XF86TouchpadOff":      "Touchpad Off",
}

func prettyKey(tok string) string {
	if v, ok := keyNames[tok]; ok {
		return v
	}
	return tok
}

func describe(comment, dispatcher string) string {
	if comment != "" {
		return capitalize(comment)
	}
	return capitalize(describeDispatcher(dispatcher))
}

func describeDispatcher(d string) string {
	if m := reExec.FindStringSubmatch(d); m != nil {
		return describeExec(m[1])
	}
	switch {
	case strings.Contains(d, "window.close"):
		return "close window"
	case strings.Contains(d, "window.fullscreen"):
		return "fullscreen"
	case strings.Contains(d, "window.float") && strings.Contains(d, "enable"):
		return "float window"
	case strings.Contains(d, "window.float") && strings.Contains(d, "disable"):
		return "tile window"
	case strings.Contains(d, "window.drag"):
		return "move window"
	case strings.Contains(d, "window.resize"):
		return "resize window"
	case strings.Contains(d, "window.move"):
		return "move window to workspace"
	case strings.Contains(d, "focus"):
		switch {
		case strings.Contains(d, "r-1"):
			return "previous workspace"
		case strings.Contains(d, "r+1"):
			return "next workspace"
		}
		return "focus workspace"
	}
	return d
}

func describeExec(cmd string) string {
	if strings.HasPrefix(cmd, "ryoku-app ") {
		return strings.TrimPrefix(cmd, "ryoku-app ")
	}
	switch {
	case cmd == "kitty":
		return "terminal"
	case cmd == "nautilus":
		return "files"
	case cmd == "chromium":
		return "browser"
	case strings.Contains(cmd, "hyprpicker"):
		return "pick a color"
	case strings.Contains(cmd, "set-volume") && strings.Contains(cmd, "%+"):
		return "volume up"
	case strings.Contains(cmd, "set-volume"):
		return "volume down"
	case strings.Contains(cmd, "set-mute"):
		return "mute toggle"
	case strings.Contains(cmd, "play-pause"):
		return "play / pause"
	case strings.Contains(cmd, "playerctl next"):
		return "next track"
	case strings.Contains(cmd, "playerctl previous"):
		return "previous track"
	}
	return cmd
}

func capitalize(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	r[0] = []rune(strings.ToUpper(string(r[0])))[0]
	return string(r)
}
