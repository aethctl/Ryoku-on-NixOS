package doctor

import (
	"os"
	"path/filepath"
	"testing"
)

// TestReconcileRyowallsRemoval seeds a box that ran the sunset ryowalls app,
// sweeps it, and asserts the leftovers are gone, a second run is a clean no-op,
// and an unrelated ryogami file is never touched.
func TestReconcileRyowallsRemoval(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))

	// clean box: nothing to sweep.
	if r := reconcileRyowallsRemoval(false); r.status != recOK {
		t.Fatalf("clean box: status=%s want ok (detail=%s)", r.status.label(), r.detail)
	}

	leftovers := ryowallsLeftovers()
	for _, p := range leftovers {
		seedFile(t, p)
	}
	// a ryogami artifact the sweep must never touch.
	ryogami := filepath.Join(home, ".config", "quickshell", "ryogami", "shell.qml")
	seedFile(t, ryogami)

	r := reconcileRyowallsRemoval(false)
	if r.status != recFixed {
		t.Fatalf("sweep: status=%s want fixed (detail=%s)", r.status.label(), r.detail)
	}
	for _, p := range leftovers {
		if _, err := os.Lstat(p); !os.IsNotExist(err) {
			t.Fatalf("leftover %s still present after sweep (err=%v)", p, err)
		}
	}
	if _, err := os.Stat(ryogami); err != nil {
		t.Fatalf("ryogami artifact was disturbed: %v", err)
	}

	if r2 := reconcileRyowallsRemoval(false); r2.status != recOK {
		t.Fatalf("second run: status=%s want ok (detail=%s)", r2.status.label(), r2.detail)
	}
}

func seedFile(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
}
