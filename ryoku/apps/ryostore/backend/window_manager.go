package main

import (
	"os/exec"
	"strings"
	"sync"
)

// Which window manager is running, and whether a catalogue product is written for
// it.
//
// A catalogue item may name the window manager it was authored against
// (registry `windowManager`, the provider name `ryoku wm use <name>` takes).
// Nothing here decides that by name: the running provider reports itself through
// the seam, and the answer is compared with what the item declared, so a third
// provider needs no change in this file and the store never guesses.
//
// An item whose manager is not the running one stays listed, keeps any installed
// copy removable, and is refused for install and update exactly like a paused
// product, so a control that cannot work is never offered as if it could.

// runningWindowManager is the detected provider's name, cached for the process:
// the store builds one catalogue per launch and every provider asks the same
// question. Empty when nothing can be detected, which gates nothing.
var runningWindowManager = sync.OnceValue(func() string {
	out, err := exec.Command("ryoku", "wm", "status").Output()
	if err != nil {
		return ""
	}
	return parseWindowManager(string(out))
})

// parseWindowManager reads the provider name out of `ryoku wm status`, whose
// first line is "Provider: <name>". A line without a name reads as none.
func parseWindowManager(out string) string {
	for _, line := range strings.Split(out, "\n") {
		rest, ok := strings.CutPrefix(strings.TrimSpace(line), "Provider:")
		if !ok {
			continue
		}
		name := strings.TrimSpace(rest)
		if name == "(none)" {
			return ""
		}
		return name
	}
	return ""
}

// productWindowManagerGate reports whether a product authored for `required`
// runs here. ok is false when the item names a window manager other than the
// running one; running carries that manager's name for the reason line. An item
// that declares nothing runs anywhere.
func productWindowManagerGate(required string) (ok bool, running string) {
	required = strings.TrimSpace(required)
	if required == "" {
		return true, ""
	}
	running = runningWindowManager()
	if running == "" {
		// Nothing to compare against: leave the item installable rather than
		// hiding content on a machine whose provider cannot be read.
		return true, ""
	}
	if strings.EqualFold(required, running) {
		return true, running
	}
	return false, running
}
