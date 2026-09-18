package doctor

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLockscreenInstallerRunsForLegacyTapeUpgrade(t *testing.T) {
	for _, test := range []struct {
		name          string
		lockerPresent bool
		legacyTape    bool
		want          bool
	}{
		{name: "missing locker", want: true},
		{name: "current install", lockerPresent: true, want: false},
		{name: "legacy Tape on existing install", lockerPresent: true, legacyTape: true, want: true},
	} {
		t.Run(test.name, func(t *testing.T) {
			if got := needsLockscreenInstaller(test.lockerPresent, test.legacyTape); got != test.want {
				t.Fatalf("needsLockscreenInstaller() = %v, want %v", got, test.want)
			}
		})
	}
}

// greeterScriptStale is the decision that carries greeter fixes (the NVIDIA
// software-cursor renderer) to a box the package never touched. It must fire on
// a missing or drifted script and stay quiet when the installed copy already
// matches or when there is no shipped source to reconcile from (a package box).
func TestGreeterScriptStale(t *testing.T) {
	saved := greeterCompositorBin
	defer func() { greeterCompositorBin = saved }()

	dir := t.TempDir()
	src := filepath.Join(dir, "src")
	if err := os.WriteFile(src, []byte("#!/bin/sh\n--renderer=pixman\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	greeterCompositorBin = filepath.Join(dir, "installed")

	if greeterScriptStale("") {
		t.Error("no shipped source (package box) must not report drift")
	}
	if !greeterScriptStale(src) {
		t.Error("a missing installed script must report stale")
	}
	if err := os.WriteFile(greeterCompositorBin, []byte("#!/bin/sh\nold\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if !greeterScriptStale(src) {
		t.Error("a drifted installed script must report stale")
	}
	if err := os.WriteFile(greeterCompositorBin, []byte("#!/bin/sh\n--renderer=pixman\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if greeterScriptStale(src) {
		t.Error("an up-to-date installed script must not report stale")
	}
}
