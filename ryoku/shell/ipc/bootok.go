package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// bootOKDir is where a session records that the desktop came up in this boot:
// a sticky, world-writable directory the ryoku package ships through
// tmpfiles, so an unprivileged session can write its own marker and the
// root-side boot guard (ryoku boot-guard, ryoku-boot-guard.service) can read
// it on the next boot. One file per uid; the content is the boot id.
const bootOKDir = "/var/lib/ryoku/boot"

// bootOKSettle is how long the shell must stay up before the boot counts as
// good: past the supervisor's crash window with margin, short enough that a
// login followed by a quick logout still records it.
const bootOKSettle = 45 * time.Second

// recordBootOK waits for the shell to prove itself and writes the marker for
// this boot. Best effort: a missing directory (an older package) or an
// unwritable one leaves the guard without a signal, which it treats as an
// unproven boot, never as a failure of its own.
func recordBootOK(exited <-chan struct{}) {
	select {
	case <-exited:
		return // died inside the window; not a good boot
	case <-time.After(bootOKSettle):
	}
	id, err := os.ReadFile("/proc/sys/kernel/random/boot_id")
	if err != nil {
		return
	}
	if st, err := os.Stat(bootOKDir); err != nil || !st.IsDir() {
		return
	}
	path := filepath.Join(bootOKDir, fmt.Sprintf("ok-%d", os.Getuid()))
	_ = os.WriteFile(path, []byte(strings.TrimSpace(string(id))+"\n"), 0o644)
}
