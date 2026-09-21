package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"

	wm "ryoku-wm"
)

// One neutral action id in, one niri request out. The only file allowed to
// spell a niri action name, which is what keeps the Hyprland provider a sibling
// file rather than a second shell.
//
// niri takes actions over the same socket as its queries, so an action is a
// struct here rather than a command string. The field names are niri's own and
// are checked by the compositor: an unknown action or a mistyped field comes
// back as an error rather than being ignored, which is why act_test pins them.
//
// Arity is checked rather than trusted: an action arrives from a keybind or a
// script, and a niri window action with a null id silently applies to the
// focused window.

// action wraps one niri action in the request envelope.
func action(name string, args any) map[string]any {
	return map[string]any{"Action": map[string]any{name: args}}
}

// niri resolves a workspace by stable id, by index or by name. Ids come back
// from the state frames and survive the renumbering that makes an index
// unreliable on a compositor where workspaces appear and disappear, so a
// numeric handle is always an id here. A non-numeric one is a configured name.
func workspaceRef(id string) map[string]any {
	if n, err := strconv.ParseUint(strings.TrimSpace(id), 10, 64); err == nil {
		return map[string]any{"Id": n}
	}
	return map[string]any{"Name": id}
}

func windowID(id string) (uint64, error) {
	n, err := strconv.ParseUint(strings.TrimSpace(id), 10, 64)
	if err != nil {
		return 0, fmt.Errorf("act: window id must be numeric, got %q", id)
	}
	return n, nil
}

func runAct(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("act: missing action id")
	}
	act := wm.Action(args[0])
	rest := args[1:]
	if !live() {
		return fmt.Errorf("act %s: no live niri session", act)
	}

	switch act {
	case wm.ActionWindowFocus:
		id, err := argID(rest, 0, "window id")
		if err != nil {
			return err
		}
		return perform(action("FocusWindow", map[string]any{"id": id}))

	case wm.ActionWindowClose:
		id, err := argID(rest, 0, "window id")
		if err != nil {
			return err
		}
		return perform(action("CloseWindow", map[string]any{"id": id}))

	case wm.ActionWindowFullscreen:
		id, err := argID(rest, 0, "window id")
		if err != nil {
			return err
		}
		return perform(action("FullscreenWindow", map[string]any{"id": id}))

	case wm.ActionWindowFloat:
		id, err := argID(rest, 0, "window id")
		if err != nil {
			return err
		}
		return perform(action("ToggleWindowFloating", map[string]any{"id": id}))

	case wm.ActionWindowMoveToWorkspace:
		id, err := argID(rest, 0, "window id")
		if err != nil {
			return err
		}
		ws, err := arg(rest, 1, "workspace id")
		if err != nil {
			return err
		}
		// Follows the window, matching what the same action does on Hyprland.
		return perform(action("MoveWindowToWorkspace", map[string]any{
			"window_id": id,
			"reference": workspaceRef(ws),
			"focus":     true,
		}))

	case wm.ActionAppFocus:
		appID, err := arg(rest, 0, "app id")
		if err != nil {
			return err
		}
		id, err := newestWindowOf(appID)
		if err != nil {
			return err
		}
		return perform(action("FocusWindow", map[string]any{"id": id}))

	case wm.ActionWorkspaceFocus:
		ws, err := arg(rest, 0, "workspace id")
		if err != nil {
			return err
		}
		return perform(action("FocusWorkspace", map[string]any{"reference": workspaceRef(ws)}))

	case wm.ActionWorkspaceCycle:
		delta, err := arg(rest, 0, "delta")
		if err != nil {
			return err
		}
		n, convErr := strconv.Atoi(delta)
		if convErr != nil {
			return fmt.Errorf("act %s: delta must be an integer, got %q", act, delta)
		}
		return cycleWorkspace(n)

	case wm.ActionWorkspaceMoveToOutput:
		ws, err := arg(rest, 0, "workspace id")
		if err != nil {
			return err
		}
		out, err := arg(rest, 1, "output name")
		if err != nil {
			return err
		}
		return perform(action("MoveWorkspaceToMonitor", map[string]any{
			"output":    out,
			"reference": workspaceRef(ws),
		}))

	case wm.ActionSessionExit:
		// The confirmation prompt is niri's own overlay; the desktop already
		// asked before calling this.
		return perform(action("Quit", map[string]any{"skip_confirmation": true}))

	case wm.ActionOutputPower:
		state, err := arg(rest, 0, "on|off")
		if err != nil {
			return err
		}
		if state != "on" && state != "off" {
			return fmt.Errorf("act %s: state must be on or off, got %q", act, state)
		}
		// niri powers every output together. Refuse a named one rather than
		// blanking more screens than the caller asked for.
		if len(rest) > 1 && strings.TrimSpace(rest[1]) != "" {
			return fmt.Errorf("act %s: niri powers all outputs together, so %q cannot be targeted alone", act, rest[1])
		}
		if state == "on" {
			return perform(action("PowerOnMonitors", map[string]any{}))
		}
		return perform(action("PowerOffMonitors", map[string]any{}))

	case wm.ActionKeyboardCycleLayout:
		return perform(action("SwitchLayout", map[string]any{"layout": "Next"}))

	case wm.ActionOverviewToggle:
		return perform(action("ToggleOverview", map[string]any{}))

	case wm.ActionNightLightOn:
		return nightlightStart("gammastep", "-m", "wayland", "-O", strconv.Itoa(nightlightTemp(rest)))

	case wm.ActionNightLightOff:
		nightlightStop("gammastep")
		return nil
	}

	// A known action this compositor cannot perform names the capability, so a
	// caller that skipped the gate gets told which one to check.
	if capability := act.Capability(); capability != "" {
		return fmt.Errorf("act %s: niri does not support %s", act, capability)
	}
	return fmt.Errorf("act: unknown action %q", act)
}

func perform(req any) error {
	_, err := request(req)
	return err
}

// cycleWorkspace walks niri's vertical workspace order one step at a time.
// There is no relative reference to pass, and stepping is what niri's own binds
// do, so the loop is the action rather than a workaround.
func cycleWorkspace(delta int) error {
	name := "FocusWorkspaceDown"
	if delta < 0 {
		name, delta = "FocusWorkspaceUp", -delta
	}
	for range delta {
		if err := perform(action(name, map[string]any{})); err != nil {
			return err
		}
	}
	return nil
}

// newestWindowOf resolves an app id to a window, because niri focuses by id
// only. The most recently focused match wins, which is what a caller that knows
// only what it launched means by "focus it".
func newestWindowOf(appID string) (uint64, error) {
	wins, err := readWindows()
	if err != nil {
		return 0, err
	}
	best := niriWindow{}
	found := false
	for _, w := range wins {
		if !strings.EqualFold(w.AppID, appID) {
			continue
		}
		if !found || w.FocusTimestamp.after(best.FocusTimestamp) {
			best, found = w, true
		}
	}
	if !found {
		return 0, fmt.Errorf("act %s: no window with app id %q", wm.ActionAppFocus, appID)
	}
	return best.ID, nil
}

// arg names the missing value, so a bad keybind reports it instead of an index.
func arg(args []string, i int, name string) (string, error) {
	if i >= len(args) || strings.TrimSpace(args[i]) == "" {
		return "", fmt.Errorf("act: missing %s", name)
	}
	return args[i], nil
}

func argID(args []string, i int, name string) (uint64, error) {
	s, err := arg(args, i, name)
	if err != nil {
		return 0, err
	}
	return windowID(s)
}

// decode unwraps one query payload, which niri nests under the request name.
func decode(raw json.RawMessage, key string, dst any) error {
	var envelope map[string]json.RawMessage
	if err := json.Unmarshal(raw, &envelope); err != nil {
		return fmt.Errorf("niri %s: %w", key, err)
	}
	body, ok := envelope[key]
	if !ok {
		return fmt.Errorf("niri %s: missing from reply", key)
	}
	return json.Unmarshal(body, dst)
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
// temperature. gammastep -m wayland -O sets the temperature over
// wlr-gamma-control and pauses until killed, so it is detached (its own session,
// stdio to /dev/null, released) to outlive this short-lived invocation; niri
// restores the gamma when it goes away.
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
