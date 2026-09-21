package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"

	wm "ryoku-wm"
)

// One neutral action id in, one Hyprland dispatcher out. The only file allowed
// to spell a dispatcher name, which is what makes the niri provider a sibling
// file rather than a second shell.
//
// Everything speaks the Lua config provider's API, because that is the only
// parser Ryoku ships: `hyprctl dispatch <expr>` evaluates as hl.dispatch(<expr>),
// so a classic `dispatch workspace 9` is a Lua syntax error, and `hyprctl
// keyword` refuses outright ("keyword can't work with non-legacy parsers"). Live
// config changes therefore go through eval and hl.config.
//
// Arity is checked rather than trusted: an action arrives from a keybind or a
// script, and a dispatcher called with an empty selector silently applies to the
// focused window.

func runAct(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("act: missing action id")
	}
	action := wm.Action(args[0])
	rest := args[1:]
	if !live() {
		return fmt.Errorf("act %s: no live Hyprland session", action)
	}

	switch action {
	case wm.ActionWindowFocus:
		id, err := arg(rest, 0, "window id")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.focus({ window = ` + luaStr("address:"+id) + ` })`)

	case wm.ActionWindowClose:
		id, err := arg(rest, 0, "window id")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.window.close({ window = ` + luaStr("address:"+id) + ` })`)

	case wm.ActionWindowFullscreen:
		id, err := arg(rest, 0, "window id")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.window.fullscreen({ window = ` + luaStr("address:"+id) + ` })`)

	case wm.ActionWindowFloat:
		id, err := arg(rest, 0, "window id")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.window.float({ action = "toggle", window = ` + luaStr("address:"+id) + ` })`)

	case wm.ActionWindowMoveToWorkspace:
		id, err := arg(rest, 0, "window id")
		if err != nil {
			return err
		}
		ws, err := arg(rest, 1, "workspace id")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.window.move({ workspace = ` + luaStr(ws) + `, window = ` + luaStr("address:"+id) + ` })`)

	case wm.ActionAppFocus:
		class, err := arg(rest, 0, "app id")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.focus({ window = ` + luaStr("class:"+class) + ` })`)

	case wm.ActionWorkspaceFocus:
		ws, err := arg(rest, 0, "workspace id")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.focus({ workspace = ` + luaStr(ws) + ` })`)

	case wm.ActionWorkspaceCycle:
		delta, err := arg(rest, 0, "delta")
		if err != nil {
			return err
		}
		n, convErr := strconv.Atoi(delta)
		if convErr != nil {
			return fmt.Errorf("act %s: delta must be an integer, got %q", action, delta)
		}
		// r+N walks relative to the current workspace, the same selector the
		// shipped scroll binds use.
		sel := "r+" + strconv.Itoa(n)
		if n < 0 {
			sel = "r-" + strconv.Itoa(-n)
		}
		return dispatch(`hl.dsp.focus({ workspace = ` + luaStr(sel) + ` })`)

	case wm.ActionWorkspaceMoveToOutput:
		ws, err := arg(rest, 0, "workspace id")
		if err != nil {
			return err
		}
		out, err := arg(rest, 1, "output name")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.workspace.move({ workspace = ` + luaStr(ws) + `, monitor = ` + luaStr(out) + ` })`)

	case wm.ActionWorkspaceToggleSpecial:
		name, err := arg(rest, 0, "special workspace name")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.workspace.toggle_special(` + luaStr(name) + `)`)

	case wm.ActionSessionExit:
		return dispatch(`hl.dsp.exit()`)

	case wm.ActionOutputPower:
		state, err := arg(rest, 0, "on|off")
		if err != nil {
			return err
		}
		if state != "on" && state != "off" {
			return fmt.Errorf("act %s: state must be on or off, got %q", action, state)
		}
		expr := `hl.dsp.dpms({ state = ` + luaStr(state)
		if len(rest) > 1 && rest[1] != "" {
			expr += `, monitor = ` + luaStr(rest[1])
		}
		return dispatch(expr + ` })`)

	case wm.ActionKeyboardCycleLayout:
		// A top-level hyprctl command, not a keyword, so it works under the Lua
		// parser unchanged. all, so a split or external board cannot drift.
		_, err := ctl("switchxkblayout", "all", "next")
		return err

	case wm.ActionSubmapEnter:
		name, err := arg(rest, 0, "submap name")
		if err != nil {
			return err
		}
		return dispatch(`hl.dsp.submap(` + luaStr(name) + `)`)

	case wm.ActionSubmapReset:
		return dispatch(`hl.dsp.submap("reset")`)

	case wm.ActionConfigReload:
		// config-only leaves monitors alone; a full reload re-applies output
		// config and can black a screen mid-update.
		if len(rest) > 0 && rest[0] == "config-only" {
			_, err := ctl("reload", "config-only")
			return err
		}
		_, err := ctl("reload")
		return err

	case wm.ActionConfigAutoreload:
		state, err := arg(rest, 0, "on|off")
		if err != nil {
			return err
		}
		// The knob is phrased as a disable, so invert here not in every caller.
		disable := "true"
		if state == "on" {
			disable = "false"
		}
		return evalLua(`hl.config({ misc = { disable_autoreload = ` + disable + ` } })`)

	case wm.ActionCursorSet:
		theme, err := arg(rest, 0, "cursor theme")
		if err != nil {
			return err
		}
		size, err := arg(rest, 1, "cursor size")
		if err != nil {
			return err
		}
		_, err = ctl("setcursor", theme, size)
		return err

	case wm.ActionScreenShader:
		// A shader NAME, not a path: callers must not know the config layout.
		// Empty clears.
		name := ""
		if len(rest) > 0 {
			name = strings.TrimSpace(rest[0])
		}
		return evalLua(`hl.config({ decoration = { screen_shader = ` + luaStr(shaderPath(name)) + ` } })`)

	case wm.ActionFocusFollowsMouse:
		mode, err := arg(rest, 0, "follow mode")
		if err != nil {
			return err
		}
		n, convErr := strconv.Atoi(mode)
		if convErr != nil {
			return fmt.Errorf("act %s: mode must be 0..3, got %q", action, mode)
		}
		// Print the previous mode first so the caller restores it exactly;
		// follow_mouse is a mode, not a flag, so a hardcoded restore would
		// overwrite a deliberate non-default.
		if prev := followMouseMode(); prev != "" {
			fmt.Fprintln(stdout, prev)
		}
		return evalLua(`hl.config({ input = { follow_mouse = ` + strconv.Itoa(n) + ` } })`)

	case wm.ActionWorkspaceLayout:
		ws, err := arg(rest, 0, "workspace id")
		if err != nil {
			return err
		}
		layout, err := arg(rest, 1, "layout name")
		if err != nil {
			return err
		}
		return evalLua(`hl.workspace_rule({ workspace = ` + luaStr(ws) + `, layout = ` + luaStr(layout) + ` })`)

	case wm.ActionBorderColors:
		active, err := arg(rest, 0, "active colour")
		if err != nil {
			return err
		}
		inactive, err := arg(rest, 1, "inactive colour")
		if err != nil {
			return err
		}
		return setBorderColors(active, inactive)

	case wm.ActionNightLightOn:
		return nightlightStart("hyprsunset", "-t", strconv.Itoa(nightlightTemp(rest)))

	case wm.ActionNightLightOff:
		nightlightStop("hyprsunset")
		return nil
	}

	return fmt.Errorf("act: unknown action %q", action)
}

// eval, not keyword: under the Lua config provider a reload re-runs
// decoration.lua and reverts col.active_border to the login value.
func setBorderColors(active, inactive string) error {
	var parts []string
	if rgb := hyprRGB(active); rgb != "" {
		parts = append(parts, `["col.active_border"]=`+luaStr(rgb))
	}
	if rgb := hyprRGB(inactive); rgb != "" {
		parts = append(parts, `["col.inactive_border"]=`+luaStr(rgb))
	}
	if len(parts) == 0 {
		return fmt.Errorf("act %s: no usable colour in %q/%q", wm.ActionBorderColors, active, inactive)
	}
	return evalLua("hl.config({general={" + strings.Join(parts, ",") + "}})")
}

// Empty for a non-hex value, so a missing role is skipped not mis-set.
func hyprRGB(hex string) string {
	h := strings.TrimPrefix(strings.TrimSpace(hex), "#")
	if len(h) != 6 {
		return ""
	}
	return "rgb(" + h + ")"
}

// shaderPath turns a shader name into the file the compositor loads. Empty name
// yields an empty string, which clears the shader.
func shaderPath(name string) string {
	if name == "" {
		return ""
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".config", "hypr", "shaders", name+".glsl")
}

// followMouseMode reads the live mode, empty when it cannot be read. getoption
// is a top-level query and works under the Lua parser.
func followMouseMode() string {
	out, err := ctl("getoption", "input:follow_mouse", "-j")
	if err != nil {
		return ""
	}
	var o struct {
		Int int `json:"int"`
	}
	if json.Unmarshal(out, &o) != nil {
		return ""
	}
	return strconv.Itoa(o.Int)
}

// arg names the missing value, so a bad keybind reports it instead of an index.
func arg(args []string, i int, name string) (string, error) {
	if i >= len(args) || strings.TrimSpace(args[i]) == "" {
		return "", fmt.Errorf("act: missing %s", name)
	}
	return args[i], nil
}

// nightlightTemp parses the colour temperature, defaulting to 4000 K and
// clamping to the range the gamma client accepts, so a stray keybind argument
// can never ask for a value it would reject.
func nightlightTemp(args []string) int {
	t := 4000
	if len(args) > 0 {
		if v, err := strconv.Atoi(strings.TrimSpace(args[0])); err == nil {
			t = v
		}
	}
	if t < 1000 {
		t = 1000
	}
	if t > 25000 {
		t = 25000
	}
	return t
}

// nightlightStart replaces any running backend with a fresh one warmed to the
// temperature. The backend is detached (its own session, stdio to /dev/null,
// released) so it outlives this short-lived invocation and holds the gamma
// until it is killed; Hyprland restores the gamma when it goes away.
func nightlightStart(argv ...string) error {
	nightlightStop(argv[0])
	null, err := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	if err != nil {
		return err
	}
	defer null.Close()
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = null, null, null
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}

// nightlightStop signals every process of this uid whose comm is name, which is
// how nightlight.off stops the backend without a pkill fork. comm truncates at
// 15 characters; the backend name fits, so an exact compare is right.
func nightlightStop(name string) {
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return
	}
	for _, e := range ents {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		b, err := os.ReadFile("/proc/" + e.Name() + "/comm")
		if err != nil {
			continue
		}
		if strings.TrimSpace(string(b)) == name {
			_ = syscall.Kill(pid, syscall.SIGTERM)
		}
	}
}
