package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRunStateRoundtrip(t *testing.T) {
	home := t.TempDir()
	if loadState(home) != nil {
		t.Fatal("no file must mean no state")
	}
	e := &engine{f: &facts{homeDir: home}, p: &plan{}}
	e.markStepDone("legacy")
	e.backupDir = "/tmp/backup-x"
	e.markStepDone("backup")
	e.markStepDone("backup") // idempotent

	s := loadState(home)
	if s == nil || len(s.Completed) != 2 || !s.has("legacy") || !s.has("backup") || s.has("verify") {
		t.Fatalf("state wrong: %+v", s)
	}
	if s.BackupDir != "/tmp/backup-x" {
		t.Fatalf("backup dir not recorded: %+v", s)
	}

	e.clearState()
	if loadState(home) != nil {
		t.Fatal("clearState must remove the resume file")
	}
}

func TestRunStateIgnoresGarbage(t *testing.T) {
	home := t.TempDir()
	p := statePath(home)
	os.MkdirAll(home+"/.local/state/ryoku", 0o755)
	os.WriteFile(p, []byte("not json"), 0o644)
	if loadState(home) != nil {
		t.Fatal("garbage state must be ignored")
	}
	os.WriteFile(p, []byte(`{"completed":[]}`), 0o644)
	if loadState(home) != nil {
		t.Fatal("empty completed list is not a resumable run")
	}
}

func TestDryRunWritesNoState(t *testing.T) {
	home := t.TempDir()
	e := &engine{f: &facts{homeDir: home}, p: &plan{}, dry: true}
	e.markStepDone("legacy")
	if loadState(home) != nil {
		t.Fatal("dry runs must not write state")
	}
}

// A resume skips the payload step, so every later step must still find the
// checkout by absolute path: the session step joined an empty payload into
// "bash ryoku/lockscreen/sddm/setup", relative to wherever the installer was
// invoked from, and failed with 127 on every resumed run.
func TestNewEngineAnchorsPayloadOnResume(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", "")
	f := &facts{homeDir: home, prevRun: &runState{Completed: []string{"payload"}}}
	e := newEngine(f, defaultPlan(f), true, "main", "")
	want := filepath.Join(home, ".cache", "ryoku-shell-install", "repo")
	if e.payload != want {
		t.Fatalf("resume payload = %q, want %q", e.payload, want)
	}
	// The override wins over the cache path.
	e2 := newEngine(f, defaultPlan(f), true, "main", "/srv/checkout")
	if e2.payload != "/srv/checkout" {
		t.Fatalf("override payload = %q, want /srv/checkout", e2.payload)
	}
}
