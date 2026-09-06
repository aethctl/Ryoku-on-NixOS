package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// restoreDaemon builds a daemon whose cache/config/state all point at temp
// dirs, so restoreOutputs runs against a controlled outputs.json without
// touching the real home.
func restoreDaemon(t *testing.T) (*daemon, string) {
	t.Helper()
	root := t.TempDir()
	cache := filepath.Join(root, "cache")
	if err := os.MkdirAll(cache, 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(root, "config"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(root, "state"))
	d := &daemon{surface: newWallSurface()}
	d.cfg.Paths.Cache = cache
	return d, cache
}

// A stored static choice whose file is not present yet must be reported as
// unapplied (the login-race signal the startup retry keys on) and must never
// publish a bogus frame; once the file lands the same choice applies and the
// frame carries it. This is the regression: restoreOutputs used to give up on
// the missing file with no way for the caller to know it had to retry, leaving
// the desktop on the empty grey frame until a manual wallpaper set.
func TestRestoreRetriesUntilFilePresent(t *testing.T) {
	d, cache := restoreDaemon(t)
	pic := filepath.Join(t.TempDir(), "wall.png")
	if err := os.WriteFile(filepath.Join(cache, "outputs.json"),
		[]byte(`{"*":{"type":"static","path":"`+pic+`"}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	if want, applied := d.restoreOutputs(); want != 1 || applied != 0 {
		t.Fatalf("missing file: want/applied = %d/%d, expected 1/0", want, applied)
	}
	if got := d.surface.snapshot().Default.Path; got != "" {
		t.Fatalf("a missing file must not publish a frame, got %q", got)
	}

	writeE2EPNG(t, pic)
	if want, applied := d.restoreOutputs(); want != 1 || applied != 1 {
		t.Fatalf("present file: want/applied = %d/%d, expected 1/1", want, applied)
	}
	if got := d.surface.snapshot().Default.Path; got != pic {
		t.Fatalf("restored frame path = %q, want %q", got, pic)
	}
}

// No stored choice is not a failure: want is zero, so the caller neither
// retries nor treats the empty frame as a login race (first run, restore off).
func TestRestoreNoChoiceIsNotPending(t *testing.T) {
	d, _ := restoreDaemon(t)
	if want, applied := d.restoreOutputs(); want != 0 || applied != 0 {
		t.Fatalf("no outputs.json: want/applied = %d/%d, expected 0/0", want, applied)
	}
}

// A box upgraded across the Ryogami split has the pre-split state file but an
// empty outputs.json; the daemon seeds outputs.json from it once so the
// wallpaper survives the upgrade, and never overwrites a choice already set
// through Ryogami.
func TestMigrateLegacyOutputs(t *testing.T) {
	d, cache := restoreDaemon(t)
	pic := filepath.Join(t.TempDir(), "old.png")
	writeE2EPNG(t, pic)
	state := filepath.Join(os.Getenv("XDG_STATE_HOME"))
	if err := os.MkdirAll(state, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(state, "ryoku-wallpaper.json"),
		[]byte(`{"default":"`+pic+`","outputs":{}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	d.migrateLegacyOutputs()
	if want, applied := d.restoreOutputs(); want != 1 || applied != 1 {
		t.Fatalf("after migration: want/applied = %d/%d, expected 1/1", want, applied)
	}
	if got := d.surface.snapshot().Default.Path; got != pic {
		t.Fatalf("migrated wallpaper path = %q, want %q", got, pic)
	}

	// A real Ryogami choice already present is never clobbered by the seed.
	newer := filepath.Join(t.TempDir(), "new.png")
	writeE2EPNG(t, newer)
	if err := os.WriteFile(filepath.Join(cache, "outputs.json"),
		[]byte(`{"*":{"type":"static","path":"`+newer+`"}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	d.migrateLegacyOutputs()
	if want, applied := d.restoreOutputs(); want != 1 || applied != 1 {
		t.Fatalf("post-clobber-guard: want/applied = %d/%d, expected 1/1", want, applied)
	}
	if got := d.surface.snapshot().Default.Path; got != newer {
		t.Fatalf("migration overwrote a live choice: path = %q, want %q", got, newer)
	}
}

// hyprEventSocket returns the newest instance's .socket2.sock and "" when no
// compositor socket has landed, so the watcher targets the live session and
// backs off cleanly during a login-time race.
func TestHyprEventSocketPicksNewest(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)

	if got := hyprEventSocket(); strings.HasPrefix(got, rt) {
		t.Fatalf("no instance under the runtime dir yet, but got %q", got)
	}

	older := filepath.Join(rt, "hypr", "sig-old")
	newer := filepath.Join(rt, "hypr", "sig-new")
	for _, d := range []string{older, newer} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(d, ".socket2.sock"), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	// Push both far into the future so a real /tmp/hypr socket on the host can
	// never outrank them, and make sig-new the newest.
	future := time.Now().Add(48 * time.Hour)
	if err := os.Chtimes(filepath.Join(older, ".socket2.sock"), future, future); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(filepath.Join(newer, ".socket2.sock"), future.Add(time.Hour), future.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if got, want := hyprEventSocket(), filepath.Join(newer, ".socket2.sock"); got != want {
		t.Fatalf("hyprEventSocket() = %q, want the newest %q", got, want)
	}
}
