package main

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	wm "ryoku-wm"
)

// Every action is pinned to the exact request it emits, because the shape is the
// contract with the compositor. niri rejects an unknown action name or a
// mistyped field with "error parsing request" rather than ignoring it, so a
// wrong shape fails loudly at runtime and these cases catch it at build time.
func TestActEmitsNiriRequests(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want string
	}{
		{"window focus", []string{"window.focus", "7"},
			`{"Action":{"FocusWindow":{"id":7}}}`},
		{"window close", []string{"window.close", "7"},
			`{"Action":{"CloseWindow":{"id":7}}}`},
		{"window fullscreen", []string{"window.fullscreen", "7"},
			`{"Action":{"FullscreenWindow":{"id":7}}}`},
		{"window float", []string{"window.float", "7"},
			`{"Action":{"ToggleWindowFloating":{"id":7}}}`},
		{"window to workspace", []string{"window.moveToWorkspace", "7", "3"},
			`{"Action":{"MoveWindowToWorkspace":{"focus":true,"reference":{"Id":3},"window_id":7}}}`},
		// A numeric handle is the stable id the state frames hand out, never the
		// index, which renumbers as workspaces come and go.
		{"workspace focus by id", []string{"workspace.focus", "3"},
			`{"Action":{"FocusWorkspace":{"reference":{"Id":3}}}}`},
		{"workspace focus by name", []string{"workspace.focus", "chat"},
			`{"Action":{"FocusWorkspace":{"reference":{"Name":"chat"}}}}`},
		{"workspace to output", []string{"workspace.moveToOutput", "3", "eDP-2"},
			`{"Action":{"MoveWorkspaceToMonitor":{"output":"eDP-2","reference":{"Id":3}}}}`},
		{"session exit", []string{"session.exit"},
			`{"Action":{"Quit":{"skip_confirmation":true}}}`},
		{"output power off", []string{"output.power", "off"},
			`{"Action":{"PowerOffMonitors":{}}}`},
		{"output power on", []string{"output.power", "on"},
			`{"Action":{"PowerOnMonitors":{}}}`},
		{"keyboard layout", []string{"keyboard.cycleLayout"},
			`{"Action":{"SwitchLayout":{"layout":"Next"}}}`},
		{"overview toggle", []string{"overview.toggle"},
			`{"Action":{"ToggleOverview":{}}}`},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var got []string
			restore := stubRequest(t, func(req any) (json.RawMessage, error) {
				body, err := json.Marshal(req)
				if err != nil {
					return nil, err
				}
				got = append(got, string(body))
				return nil, nil
			})
			defer restore()
			if err := runAct(tc.args); err != nil {
				t.Fatalf("runAct(%v): %v", tc.args, err)
			}
			if len(got) != 1 || got[0] != tc.want {
				t.Errorf("request mismatch\n got: %q\nwant: %q", got, tc.want)
			}
		})
	}
}

// niri has no relative workspace reference, so a cycle is one step per unit and
// the direction has to come out as the right action.
func TestActCyclesOneStepPerUnit(t *testing.T) {
	for _, tc := range []struct {
		delta string
		want  []string
	}{
		{"1", []string{`{"Action":{"FocusWorkspaceDown":{}}}`}},
		{"-2", []string{
			`{"Action":{"FocusWorkspaceUp":{}}}`,
			`{"Action":{"FocusWorkspaceUp":{}}}`,
		}},
	} {
		var got []string
		restore := stubRequest(t, func(req any) (json.RawMessage, error) {
			body, _ := json.Marshal(req)
			got = append(got, string(body))
			return nil, nil
		})
		err := runAct([]string{"workspace.cycle", tc.delta})
		restore()
		if err != nil {
			t.Fatalf("cycle %s: %v", tc.delta, err)
		}
		if len(got) != len(tc.want) {
			t.Fatalf("cycle %s: got %d requests, want %d: %q", tc.delta, len(got), len(tc.want), got)
		}
		for i := range got {
			if got[i] != tc.want[i] {
				t.Errorf("cycle %s step %d: got %s want %s", tc.delta, i, got[i], tc.want[i])
			}
		}
	}
}

// A missing argument must name the value, so a bad keybind is diagnosable, and
// must never reach the compositor: a niri window action with a null id applies
// to the focused window, which is not what the caller asked for.
func TestActRejectsMissingArgs(t *testing.T) {
	for _, args := range [][]string{
		{"window.focus"},
		{"window.moveToWorkspace", "7"},
		{"workspace.focus"},
		{"workspace.moveToOutput", "3"},
		{"output.power"},
		{"app.focus"},
	} {
		called := false
		restore := stubRequest(t, func(any) (json.RawMessage, error) {
			called = true
			return nil, nil
		})
		err := runAct(args)
		restore()
		if err == nil {
			t.Errorf("runAct(%v): expected an error", args)
		}
		if called {
			t.Errorf("runAct(%v): reached the compositor despite a missing argument", args)
		}
	}
}

// A window id that is not a number would marshal as a string and niri would
// reject the request, so it is refused here where the message can say why.
func TestActRejectsNonNumericWindowID(t *testing.T) {
	called := false
	restore := stubRequest(t, func(any) (json.RawMessage, error) {
		called = true
		return nil, nil
	})
	defer restore()
	if err := runAct([]string{"window.close", "0xdeadbeef"}); err == nil {
		t.Fatal("expected an error for a non-numeric window id")
	}
	if called {
		t.Fatal("reached the compositor with a non-numeric window id")
	}
}

// niri powers every output together, so a request to blank one output alone is
// refused rather than blanking the others too.
func TestActRefusesPerOutputPower(t *testing.T) {
	called := false
	restore := stubRequest(t, func(any) (json.RawMessage, error) {
		called = true
		return nil, nil
	})
	defer restore()
	if err := runAct([]string{"output.power", "off", "eDP-2"}); err == nil {
		t.Fatal("expected an error for a per-output power request")
	}
	if called {
		t.Fatal("powered outputs despite a target niri cannot honour")
	}
}

// An action this compositor cannot perform names the capability, so a caller
// that skipped the gate is told which one to check instead of getting a silent
// no-op or an unknown-action error.
func TestActNamesTheMissingCapability(t *testing.T) {
	restore := stubRequest(t, func(any) (json.RawMessage, error) { return nil, nil })
	defer restore()
	for _, args := range [][]string{
		{"submap.enter", "resize"},
		{"workspace.toggleSpecial", "sharebar"},
		{"cursor.set", "Bibata", "24"},
		{"decoration.screenShader", "halftone"},
		{"config.reload"},
	} {
		err := runAct(args)
		if err == nil {
			t.Fatalf("runAct(%v): expected an unsupported error", args)
		}
		capability := wm.Action(args[0]).Capability()
		if capability == "" {
			t.Fatalf("runAct(%v): action has no capability to name", args)
		}
		if !strings.Contains(err.Error(), string(capability)) {
			t.Errorf("runAct(%v): error %q does not name %q", args, err, capability)
		}
	}
}

func TestActRejectsUnknownAction(t *testing.T) {
	restore := stubRequest(t, func(any) (json.RawMessage, error) { return nil, nil })
	defer restore()
	if err := runAct([]string{"window.teleport"}); err == nil {
		t.Fatal("expected an error for an unknown action")
	}
}

// stubRequest swaps the compositor call and satisfies live(), which every action
// checks before dispatching.
func stubRequest(t *testing.T, fn func(any) (json.RawMessage, error)) func() {
	t.Helper()
	prevRequest := request
	prevAlive := aliveCheck
	prevSocket := os.Getenv("NIRI_SOCKET")
	request = fn
	aliveCheck = func(string) bool { return true }
	os.Setenv("NIRI_SOCKET", "/nonexistent/test.sock")
	return func() {
		request = prevRequest
		aliveCheck = prevAlive
		os.Setenv("NIRI_SOCKET", prevSocket)
	}
}

// The colour temperature is clamped to the range the gamma client accepts and a
// missing or unparseable argument falls back to the default, so a stray keybind
// argument can never ask gammastep for a value it would reject or for 0 K.
func TestNightlightTempClamps(t *testing.T) {
	for _, tc := range []struct {
		args []string
		want int
	}{
		{nil, 4000},
		{[]string{""}, 4000},
		{[]string{"not-a-temp"}, 4000},
		{[]string{"4500"}, 4500},
		{[]string{"500"}, 1000},
		{[]string{"99999"}, 25000},
	} {
		if got := nightlightTemp(tc.args); got != tc.want {
			t.Errorf("nightlightTemp(%q) = %d, want %d", tc.args, got, tc.want)
		}
	}
}
