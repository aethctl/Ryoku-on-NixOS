package updater

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// What the run prints reaches the curated view only in the few shapes a person
// must see; the rest stays in the log.
func TestClassifyCapturedKeepsSignalOnly(t *testing.T) {
	type want struct {
		kind noteKind
		text string
		ok   bool
	}
	cases := []struct {
		step, line string
		want       want
	}{
		{"packages", "error: failed to commit transaction (conflicting files)", want{noteErr, "failed to commit transaction (conflicting files)", true}},
		{"packages", "warning: /etc/foo.conf installed as /etc/foo.conf.pacnew", want{noteWarn, "/etc/foo.conf installed as /etc/foo.conf.pacnew", true}},
		{"packages", "warning: zstd: local (1.5.7-3) is newer than cachyos-v3 (1.5.7-2)", want{}},
		{"snapshot", "note: snapper not installed; skipping pre-update snapshot", want{noteInfo, "snapper not installed; skipping pre-update snapshot", true}},
		{"deploy", "CMake Warning at /usr/lib/cmake/Qt6/QtPublicDependencyHelpers.cmake:339 (message):", want{}},
		{"deploy", "installed /home/u/.local/bin/ryoku-shell", want{}},
		{"packages", "core is up to date", want{}},
		{"doctor", "! orphaned packages", want{noteWarn, "orphaned packages", true}},
		{"doctor", "✓ stale pacman lock (fixed)", want{noteOK, "stale pacman lock (fixed)", true}},
		{"doctor", "✓ all checks passed", want{noteOK, "all checks passed", true}},
		{"doctor", "✓ swap is out of snapshots", want{}},
		{"deploy", "! not a doctor finding", want{}},
		// a doctor finding about .pacnew files is one warning, not two
		{"doctor", "! pending config (.pacnew)", want{noteWarn, "pending config (.pacnew)", true}},
		{"doctor", "2 pending config update(s) (.pacnew) need review", want{}},
	}
	for _, c := range cases {
		kind, text, ok := classifyCaptured(c.step, c.line)
		if ok != c.want.ok || (ok && (kind != c.want.kind || text != c.want.text)) {
			t.Errorf("classifyCaptured(%q, %q) = (%v, %q, %v), want (%v, %q, %v)",
				c.step, c.line, kind, text, ok, c.want.kind, c.want.text, c.want.ok)
		}
	}
}

func TestVerdictThresholds(t *testing.T) {
	cases := []struct {
		quiet time.Duration
		want  string
	}{
		{0, "working"},
		{quietAfter - time.Second, "working"},
		{quietAfter, "quiet"},
		{stallAfter - time.Second, "quiet"},
		{stallAfter, "stalled"},
	}
	for _, c := range cases {
		if got := verdict(c.quiet, "pacman", true); got.State != c.want || !got.Pkg || got.Current != "pacman" {
			t.Errorf("verdict(%v) = %+v, want state %s", c.quiet, got, c.want)
		}
	}
}

// The watchdog names the work a child is doing, not the wrapper around it, and
// flags a package manager in the tree.
func TestWatchdogNamesTheWorkInItsTree(t *testing.T) {
	dir := t.TempDir()
	pacman := filepath.Join(dir, "pacman")
	// Arch's test symlinks /usr/bin/sleep to a file named pacman. NixOS
	// coreutils is a multicall binary and rejects that argv[0], so keep a real
	// pacman-named process alive with a tiny script instead. The kernel reports
	// the script name as comm, which is exactly what the watchdog classifies.
	if err := os.WriteFile(pacman, []byte("#!/bin/sh\nsleep \"${1:-5}\"\n"), 0o755); err != nil {
		t.Skip(err)
	}
	cmd := exec.Command(pacman, "5")
	if err := cmd.Start(); err != nil {
		t.Skip(err)
	}
	t.Cleanup(func() { _ = cmd.Process.Kill(); _ = cmd.Wait() })
	deadline := time.Now().Add(2 * time.Second)
	var ws watchState
	for time.Now().Before(deadline) {
		ws = newWatchdog(os.Getpid()).sample(nowMs())
		if ws.Pkg {
			break
		}
		time.Sleep(50 * time.Millisecond)
	}
	if !ws.Pkg || !strings.Contains(ws.Current, "pacman 5") {
		t.Errorf("sample = %+v, want the pacman child named and flagged", ws)
	}
	if ws.State != "working" {
		t.Errorf("fresh activity read as %q", ws.State)
	}
}

// Under capture a child's stdout and stderr land in the log and reach the tail
// line by line, and release gives the descriptors back.
func TestCaptureRoutesChildOutputToTheLog(t *testing.T) {
	logf, err := os.OpenFile(filepath.Join(t.TempDir(), "update-log.txt"), os.O_CREATE|os.O_RDWR|os.O_APPEND, 0o644)
	if err != nil {
		t.Fatal(err)
	}
	defer logf.Close()
	before, _ := os.Readlink("/proc/self/fd/1")

	var mu sync.Mutex
	var seen []string
	c := startCapture(logf, func(s string) { mu.Lock(); seen = append(seen, s); mu.Unlock() })
	if c == nil {
		t.Skip("descriptors cannot be redirected here")
	}
	run := exec.Command("sh", "-c", `printf 'out line\r\n'; printf 'err \033[1mline\033[0m\n' >&2`)
	run.Stdout, run.Stderr = os.Stdout, os.Stderr
	runErr := run.Run()
	c.release()
	after, _ := os.Readlink("/proc/self/fd/1")
	if runErr != nil {
		t.Fatal(runErr)
	}

	b, _ := os.ReadFile(logf.Name())
	if !strings.Contains(string(b), "out line") || !strings.Contains(string(b), "err") {
		t.Errorf("log = %q, want both streams", b)
	}
	mu.Lock()
	defer mu.Unlock()
	if strings.Join(seen, "|") != "out line|err line" {
		t.Errorf("tail = %q, want each line once, escapes stripped", seen)
	}
	if after != before {
		t.Errorf("fd 1 after release = %q, want %q back", after, before)
	}
}
