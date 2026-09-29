package main

import (
	"os/exec"
	"strings"
	"syscall"
)

// record is the one control surface for the screen recorder: `ryoku-shell record
// start|stop|status|info` (start also takes --fullscreen|--region|--monitor, an
// optional --geometry, and the two audio flags), all handed to ryoku-cmd-record.
// A start is spawned detached in its own session so the recorder outlives a
// daemon reload; stop/status/info run synchronously and return the reply. A bare
// `record` toggles: stop when a capture is live, else start a fullscreen one.
func (d *daemon) record(args []string) string {
	if len(args) == 0 {
		if recorderRunning() {
			return runRecord([]string{"stop"})
		}
		spawnRecord([]string{"start"})
		return "ok"
	}

	switch args[0] {
	case "stop", "--stop":
		return runRecord([]string{"stop"})
	case "status", "--status":
		return runRecord([]string{"status"})
	case "info", "--info":
		return runRecord([]string{"info"})
	case "start", "--fullscreen", "--region", "-r", "--monitor",
		"--with-desktop-audio", "--with-microphone-audio":
		// a start: hand the flags straight to the recorder, prefixing the start
		// verb so `record --region ...` and `record start --region ...` behave the
		// same. The tokens are already split by the socket transport and reach the
		// script as a plain argv (no shell), so nothing here can be re-parsed.
		rest := args
		if args[0] == "start" {
			rest = args[1:]
		}
		spawnRecord(append([]string{"start"}, rest...))
		return "ok"
	default:
		return "err record: expected start|stop|status|info"
	}
}

// recorderRunning reports whether wf-recorder is capturing, matching the shell
// service's own detection.
func recorderRunning() bool {
	return exec.Command("pgrep", "-f", `(^|/)wf-recorder( |$)`).Run() == nil
}

// runRecord invokes ryoku-cmd-record and returns its trimmed stdout, or "ok" for
// a silent success. Used for the fast, non-blocking verbs (stop/status/info).
func runRecord(args []string) string {
	out, err := exec.Command("ryoku-cmd-record", args...).Output()
	text := strings.TrimSpace(string(out))
	if err != nil && text == "" {
		return "err record: " + err.Error()
	}
	if text == "" {
		return "ok"
	}
	return text
}

// spawnRecord starts ryoku-cmd-record detached in its own session. The recorder
// backgrounds wf-recorder and waits on it, so it must not be a supervised child:
// setsid frees it from the daemon's process group so a reload cannot take the
// capture down with it.
func spawnRecord(args []string) {
	cmd := exec.Command("ryoku-cmd-record", args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err == nil {
		go func() { _ = cmd.Wait() }()
	}
}
