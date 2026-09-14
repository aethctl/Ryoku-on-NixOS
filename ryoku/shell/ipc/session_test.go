package main

import (
	"reflect"
	"testing"
)

// Reboot and shutdown map to their systemctl commands; logout is no longer an
// argv action (it exits through the wm seam), and suspend/hibernate never exist.
func TestSessionActionArgv(t *testing.T) {
	want := map[string][]string{
		"reboot":   {"systemctl", "reboot"},
		"shutdown": {"systemctl", "poweroff"},
	}
	for action, argv := range want {
		got, ok := sessionActionArgv(action)
		if !ok {
			t.Fatalf("sessionActionArgv(%q) missing", action)
		}
		if !reflect.DeepEqual(got, argv) {
			t.Errorf("sessionActionArgv(%q) = %v, want %v", action, got, argv)
		}
	}
	for _, absent := range []string{"logout", "suspend", "hibernate", "", "poweroff"} {
		if _, ok := sessionActionArgv(absent); ok {
			t.Errorf("sessionActionArgv(%q) exists; only reboot/shutdown are argv actions", absent)
		}
	}
}

// startSession must register exactly the three calls, so QML's confirmation
// dialog can reach each action and nothing else.
func TestStartSessionRegistersCalls(t *testing.T) {
	d := &daemon{}
	d.startSession()
	for _, action := range []string{"logout", "reboot", "shutdown"} {
		if d.callHandler("session."+action) == nil {
			t.Errorf("session.%s call not registered", action)
		}
	}
	if d.callHandler("session.suspend") != nil {
		t.Error("session.suspend registered; no suspend action exists")
	}
}
