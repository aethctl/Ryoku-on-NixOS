package main

import (
	"fmt"
	"strings"

	wm "ryoku-wm"
)

// The niri binds block. niri has no unbind directive and rejects a duplicate
// chord inside one block, so rebinds.kdl cannot subtract from a seeded block the
// way the Hyprland split does: it must be the sole, total source of binds. This
// file owns the shipped default table in niri's own action vocabulary and folds
// the store's rebinds, unbinds and custom binds into it, resolving every chord
// collision to exactly one winner (custom over rebound default over static
// default) so the emitted config never carries a chord twice.

// defBind is one shipped default. chord is the Hub's display form, so it lines up
// with keybindRebinds keys and the unbinds list, which key on that form. action
// is empty when niri has no expression for the behaviour, which makes the bind an
// unhonored entry naming the chord rather than a dropped line.
type defBind struct {
	chord      string
	action     string
	reason     string // set when action == ""
	locked     bool   // allow-when-locked=true
	noRepeat   bool   // repeat=false
	cooldownMs int    // cooldown-ms=N, for wheel binds
}

func spawnArgs(args ...string) string {
	parts := make([]string, 0, len(args)+1)
	parts = append(parts, "spawn")
	for _, a := range args {
		parts = append(parts, kdlStr(a))
	}
	return strings.Join(parts, " ")
}

func spawnSh(cmd string) string { return "spawn-sh " + kdlStr(cmd) }

// defaultBinds is the shipped Ryoku bind set, lifted from
// ryoku/hyprland/modules/binds.lua and translated to niri actions. Compositor
// behaviours map to niri actions; app and shell launches spawn the same commands
// (shell surfaces go through ryoku-shell, whose openSurface bus is compositor
// agnostic); niri's own overview takes the workspace overview. Behaviours niri
// cannot perform (pin, resize submap, the scratchpad, mouse-button drag) carry an
// action-free row so apply reports them instead of hiding them.
func defaultBinds() []defBind {
	binds := []defBind{
		{chord: "SUPER + Q", action: "close-window", noRepeat: true},
		{chord: "SUPER + F", action: "fullscreen-window"},
		{chord: "SUPER + SHIFT + P", reason: "niri has no pin-window action."},
		{chord: "SUPER + A", action: "toggle-window-floating"},
		// Hyprland spends this chord on a resize submap, which niri has no
		// equivalent for. niri's own answer to resizing is stepping the column
		// through preset widths, so the freed chord goes to the thing that
		// makes the preset-widths setting reachable at all.
		{chord: "SUPER + R", action: "switch-preset-column-width"},
		{chord: "SUPER + P", action: spawnArgs("ryoku-monitor", "toggle")},

		{chord: "SUPER + Left", action: "focus-column-left"},
		{chord: "SUPER + Right", action: "focus-column-right"},
		{chord: "SUPER + Up", action: "focus-window-up"},
		{chord: "SUPER + Down", action: "focus-window-down"},
		{chord: "SUPER + SHIFT + Left", action: "move-column-left"},
		{chord: "SUPER + SHIFT + Right", action: "move-column-right"},
		{chord: "SUPER + SHIFT + Up", action: "move-window-up"},
		{chord: "SUPER + SHIFT + Down", action: "move-window-down"},
		{chord: "SUPER + CTRL + Left", action: `set-column-width "-10%"`},
		{chord: "SUPER + CTRL + Right", action: `set-column-width "+10%"`},
		{chord: "SUPER + CTRL + Up", action: `set-window-height "-10%"`},
		{chord: "SUPER + CTRL + Down", action: `set-window-height "+10%"`},

		{chord: "SUPER + Return", action: spawnArgs("ryoku-app", "terminal")},
		{chord: "SUPER + E", action: spawnArgs("ryoku-app", "files")},
		{chord: "SUPER + B", action: spawnArgs("ryoku-app", "browser")},
		{chord: "SUPER + N", action: spawnArgs("ryoku-app", "editor")},
		{chord: "SUPER + O", action: spawnArgs("ryoku-app", "notes")},
		{chord: "SUPER + ALT + E", action: spawnArgs("kitty", "-e", "yazi")},

		{chord: "SUPER + Space", action: spawnArgs("ryoku-shell", "launcher")},
		{chord: "SUPER + K", action: spawnSh("pkill -x -f 'qs -c keys' 2>/dev/null || flock -n -o /tmp/ryoku-keys.lock qs -c keys")},
		{chord: "SUPER + L", action: spawnArgs("ryoku-shell", "lock")},
		{chord: "SUPER + Escape", action: spawnArgs("ryoku-shell", "quicksettings")},
		{chord: "SUPER + W", action: spawnArgs("ryogami", "wallpaper", "ui")},
		{chord: "SUPER + SHIFT + W", action: spawnArgs("ryogami", "wallpaper", "random")},
		{chord: "SUPER + SHIFT + V", action: spawnSh("ryoku-summon ryovm flock -n -o /tmp/ryovm.lock qs -c ryovm")},
		{chord: "SUPER + V", action: spawnArgs("ryoku-shell", "clipboard")},
		{chord: "SUPER + Tab", action: "toggle-overview"},
		{chord: "SUPER + ALT + Tab", action: "toggle-overview"},
		{chord: "SUPER + M", action: spawnArgs("ryoku-shell", "visualizer")},
		{chord: "SUPER + SHIFT + M", action: spawnArgs("ryoku-shell", "visualizer-overlay")},
		{chord: "SUPER + ALT + M", action: spawnArgs("ryoku-shell", "visualizer-place")},
		{chord: "SUPER + grave", action: spawnArgs("ryoku-shell", "voice")},
		{chord: "SUPER + comma", action: spawnArgs("ryoku-shell", "hub", "open")},
		{chord: "SUPER + S", action: spawnArgs("ryoku-shell", "stash")},
		{chord: "SUPER + SHIFT + S", action: spawnSh("flock -n -o /tmp/ryoshot.lock qs -c ryoshot")},
		// Hyprland gives ryoshot three entry points, so niri gets the same
		// three: without Print the key a user reaches for does nothing, and
		// monitor mode would otherwise only be reachable by cycling inside
		// the tool.
		{chord: "Print", action: spawnSh("flock -n -o /tmp/ryoshot.lock qs -c ryoshot")},
		{chord: "SHIFT + Print", action: spawnSh("flock -n -o /tmp/ryoshot.lock env RYOSHOT_MODE=monitor qs -c ryoshot")},
		{chord: "SUPER + SHIFT + C", action: spawnArgs("hyprpicker", "-a")},

		{chord: "SUPER + mouse:272", reason: "niri moves windows with Mod and drag natively."},
		{chord: "SUPER + mouse:273", reason: "niri resizes windows with Mod and drag natively."},

		{chord: "SUPER + H", reason: "niri has no scratchpad workspace."},
		{chord: "SUPER + ALT + H", reason: "niri has no scratchpad workspace."},
		{chord: "SUPER + J", action: spawnArgs("ryotunes")},
		{chord: "SUPER + mouse_up", action: "focus-workspace-up", cooldownMs: 150},
		{chord: "SUPER + mouse_down", action: "focus-workspace-down", cooldownMs: 150},

		{chord: "XF86AudioRaiseVolume", action: spawnArgs("ryoku-volume", "up"), locked: true},
		{chord: "XF86AudioLowerVolume", action: spawnArgs("ryoku-volume", "down"), locked: true},
		{chord: "XF86AudioMute", action: spawnArgs("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"), locked: true},
		{chord: "XF86AudioPlay", action: spawnArgs("playerctl", "play-pause"), locked: true},
		{chord: "XF86AudioNext", action: spawnArgs("playerctl", "next"), locked: true},
		{chord: "XF86AudioPrev", action: spawnArgs("playerctl", "previous"), locked: true},
		{chord: "SUPER + SHIFT + A", action: spawnArgs("ryoku-restart-audio")},

		{chord: "XF86MonBrightnessUp", action: spawnArgs("ryoku-cmd-brightness", "+5"), locked: true},
		{chord: "XF86MonBrightnessDown", action: spawnArgs("ryoku-cmd-brightness", "-5"), locked: true},

		{chord: "XF86TouchpadToggle", action: spawnArgs("ryoku-cmd-touchpad", "toggle"), locked: true},
		{chord: "XF86TouchpadOn", action: spawnArgs("ryoku-cmd-touchpad", "on"), locked: true},
		{chord: "XF86TouchpadOff", action: spawnArgs("ryoku-cmd-touchpad", "off"), locked: true},
	}
	// Super+N focuses the Nth workspace by index, Super+Alt+N sends the window
	// there, Super+Shift+N sends it without following. The Hyprland desktop model
	// (blocks of ten) has no niri analogue, so these are flat index references.
	for i := 1; i <= 10; i++ {
		key := i % 10 // 10 maps to the 0 key
		binds = append(binds,
			defBind{chord: fmt.Sprintf("SUPER + %d", key), action: fmt.Sprintf("focus-workspace %d", i)},
			defBind{chord: fmt.Sprintf("SUPER + ALT + %d", key), action: fmt.Sprintf("move-window-to-workspace %d", i)},
			defBind{chord: fmt.Sprintf("SUPER + SHIFT + %d", key), action: fmt.Sprintf("move-window-to-workspace %d focus=false", i)},
		)
	}
	return binds
}

// genBinds renders rebinds.kdl and returns the binds it could not honour. The
// block is always well formed, empty body included, because a missing include is
// a hard config error that would cost the user their session.
func genBinds(s niriStore) (string, []wm.Unhonored) {
	unbind := map[string]bool{}
	for _, c := range s.Unbinds {
		if c = strings.TrimSpace(c); c != "" {
			unbind[c] = true
		}
	}

	var report []wm.Unhonored
	claimed := map[string]bool{}
	type outBind struct {
		chord, action    string
		locked, noRepeat bool
		cooldownMs       int
	}
	var out []outBind
	emit := func(niriChord, action string, locked, noRepeat bool, cooldownMs int) {
		if niriChord == "" || claimed[niriChord] {
			return
		}
		claimed[niriChord] = true
		out = append(out, outBind{niriChord, action, locked, noRepeat, cooldownMs})
	}

	// Priority 1: user custom binds win every chord they take.
	for i, k := range s.Keybinds {
		action, reason := customAction(k)
		if action == "" {
			if reason != "" {
				report = append(report, wm.Unhonored{Key: fmt.Sprintf("desktop.keybinds[%d]", i), Reason: reason})
			}
			continue
		}
		niriChord, ok := toNiriChord(k.Keys)
		if !ok {
			report = append(report, wm.Unhonored{Key: fmt.Sprintf("desktop.keybinds[%d]", i), Reason: fmt.Sprintf("niri cannot bind the chord %q.", k.Keys)})
			continue
		}
		emit(niriChord, action, false, false, 0)
	}

	defs := defaultBinds()

	// Behaviours niri cannot perform: report each once, unless the user removed it.
	for _, d := range defs {
		if d.action == "" && !unbind[d.chord] {
			report = append(report, wm.Unhonored{Key: fmt.Sprintf("desktop.keybinds (default %s)", d.chord), Reason: d.reason})
		}
	}

	// Priority 2 then 3: rebound defaults claim before static ones, so a rebind
	// onto another default's chord wins and the static default is dropped.
	claimDefaults := func(rebound bool) {
		for _, d := range defs {
			if d.action == "" || unbind[d.chord] {
				continue
			}
			to, isRebound := effectiveChord(d.chord, s.KeybindRebinds)
			if isRebound != rebound {
				continue
			}
			niriChord, ok := toNiriChord(to)
			if !ok {
				continue
			}
			emit(niriChord, d.action, d.locked, d.noRepeat, d.cooldownMs)
		}
	}
	claimDefaults(true)
	claimDefaults(false)

	var b strings.Builder
	b.WriteString("binds {\n")
	for _, o := range out {
		var props []string
		if o.locked {
			props = append(props, "allow-when-locked=true")
		}
		if o.noRepeat {
			props = append(props, "repeat=false")
		}
		if o.cooldownMs > 0 {
			props = append(props, fmt.Sprintf("cooldown-ms=%d", o.cooldownMs))
		}
		head := o.chord
		if len(props) > 0 {
			head += " " + strings.Join(props, " ")
		}
		fmt.Fprintf(&b, "    %s { %s; }\n", head, o.action)
	}
	b.WriteString("}\n")
	return b.String(), report
}

// effectiveChord resolves a default's emitted chord: the user's rebind when set,
// otherwise the shipped chord. The bool reports whether a rebind applied.
func effectiveChord(def string, rebinds map[string]string) (string, bool) {
	if v, ok := rebinds[def]; ok {
		if t := strings.TrimSpace(v); t != "" {
			return t, true
		}
	}
	return def, false
}

// customAction maps a store keybind action onto its niri action. exec runs the
// value through the shell; the window actions take none. An unknown action (a
// submap, a special-workspace or plugin toggle from another compositor) yields a
// reason so the bind is reported, not dropped. An empty exec is degenerate and
// dropped silently.
func customAction(k Keybind) (action, reason string) {
	switch k.Action {
	case "exec", "":
		if strings.TrimSpace(k.Value) == "" {
			return "", ""
		}
		return spawnSh(k.Value), ""
	case "close":
		return "close-window", ""
	case "fullscreen":
		return "fullscreen-window", ""
	case "togglefloating":
		return "toggle-window-floating", ""
	}
	return "", fmt.Sprintf("niri has no bind action for %q.", k.Action)
}

// toNiriChord rewrites a Hub display chord ("SUPER + SHIFT + Left") as a niri
// chord ("Super+Shift+Left"). ok is false for a chord niri cannot bind, such as a
// pointer button, so the caller reports it rather than emitting a broken line.
func toNiriChord(chord string) (string, bool) {
	parts := strings.Split(chord, "+")
	if len(parts) == 0 {
		return "", false
	}
	tokens := make([]string, 0, len(parts))
	for i, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			return "", false
		}
		if i < len(parts)-1 {
			m, ok := niriMod(p)
			if !ok {
				return "", false
			}
			tokens = append(tokens, m)
			continue
		}
		k, ok := niriKey(p)
		if !ok {
			return "", false
		}
		tokens = append(tokens, k)
	}
	return strings.Join(tokens, "+"), true
}

func niriMod(tok string) (string, bool) {
	switch strings.ToUpper(tok) {
	case "SUPER", "SUPERKEY", "MOD", "WIN", "META", "LOGO":
		return "Super", true
	case "CTRL", "CONTROL":
		return "Ctrl", true
	case "ALT":
		return "Alt", true
	case "SHIFT":
		return "Shift", true
	}
	return "", false
}

// niriKey normalises a key token to its XKB name. A lone letter is upper-cased;
// the scroll pseudo-keys become niri's wheel names; a pointer button has no key
// name, so it fails.
func niriKey(tok string) (string, bool) {
	switch tok {
	case "mouse_up":
		return "WheelScrollUp", true
	case "mouse_down":
		return "WheelScrollDown", true
	}
	if strings.HasPrefix(tok, "mouse:") || strings.HasPrefix(tok, "mouse") {
		return "", false
	}
	if len(tok) == 1 {
		r := tok[0]
		if r >= 'a' && r <= 'z' {
			return strings.ToUpper(tok), true
		}
	}
	return tok, true
}
