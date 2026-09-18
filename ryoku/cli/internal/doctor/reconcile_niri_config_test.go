package doctor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The niri config reconciler runs the real parser, so these tests put a stub
// `niri` on PATH that reports a failure whenever the config still carries the
// "broken" marker, and a stub provider whose apply re-authors that file the way
// the real provider re-authors its config from the neutral store. That makes the
// broken -> repaired -> clean walk deterministic and hermetic: no session, no
// niri, no provider binary from the machine.

func writeStub(t *testing.T, path, body string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(body), 0o755); err != nil {
		t.Fatal(err)
	}
}

func niriStubHome(t *testing.T, config string) (home, entry string) {
	t.Helper()
	home = t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("RYOKU_WM", "niri")
	bin := filepath.Join(home, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	entry = filepath.Join(home, ".config", "niri", "config.kdl")
	if err := os.MkdirAll(filepath.Dir(entry), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(entry, []byte(config+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("NIRI_TEST_CONFIG", entry)

	// niri stub: fails while the config still says broken, like the parser would.
	// built-ins only: PATH holds the stubs alone, so no external tool resolves.
	writeStub(t, filepath.Join(bin, "niri"), "#!/bin/sh\n"+
		"while IFS= read -r line || [ -n \"$line\" ]; do\n"+
		"  case \"$line\" in *broken*) echo 'error: config.kdl: include settings.kdl does not exist' >&2; exit 1 ;; esac\n"+
		"done < \"$NIRI_TEST_CONFIG\"\n"+
		"exit 0\n")

	// provider stub: caps declare niri's portal backend, apply re-authors the
	// config from the store, everything else answers an empty report.
	writeStub(t, filepath.Join(bin, "ryoku-wm-niri"), "#!/bin/sh\n"+
		"case \"$1\" in\n"+
		"  caps) echo '{\"name\":\"niri\",\"portalBackend\":\"gnome\",\"supports\":[],\"workspaceModel\":\"dynamic\"}' ;;\n"+
		"  apply) printf 'include \"settings.kdl\"\\n' > \"$NIRI_TEST_CONFIG\"; echo '{}' ;;\n"+
		"  *) echo '{}' ;;\n"+
		"esac\n"+
		"exit 0\n")
	t.Setenv("PATH", bin)
	return home, entry
}

// Another compositor owns the session: the check must stand down rather than
// report on files that session never reads.
func TestReconcileNiriConfigSkipsUnderAnotherProvider(t *testing.T) {
	home, _ := niriStubHome(t, "include broken")
	t.Setenv("RYOKU_WM", "hyprland")
	if r := reconcileNiriConfig(false); r.status != recOK {
		t.Fatalf("under hyprland: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
	_ = home
}

// Check-only reports a config niri cannot load, and writes nothing.
func TestReconcileNiriConfigCheckOnlyReportsAndWritesNothing(t *testing.T) {
	_, entry := niriStubHome(t, "include broken")
	before, err := os.ReadFile(entry)
	if err != nil {
		t.Fatal(err)
	}
	r := reconcileNiriConfig(true)
	if r.status != recWarn {
		t.Fatalf("check: status=%s detail=%q, want warn", r.status.label(), r.detail)
	}
	if !strings.Contains(r.detail, "does not load") {
		t.Fatalf("check detail should name the failure, got %q", r.detail)
	}
	after, err := os.ReadFile(entry)
	if err != nil {
		t.Fatal(err)
	}
	if string(before) != string(after) {
		t.Fatal("check-only must not rewrite the config")
	}
}

// Repair re-authors the provider config from the store and re-validates, so a
// config that becomes loadable is reported fixed.
func TestReconcileNiriConfigRepairReverifies(t *testing.T) {
	_, entry := niriStubHome(t, "include broken")
	r := reconcileNiriConfig(false)
	if r.status != recFixed {
		t.Fatalf("repair: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	after, err := os.ReadFile(entry)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(after), "broken") {
		t.Fatalf("repair should have re-authored the config, still %q", string(after))
	}
}

// A repair that does not fix the config must fail loudly, never report ok.
func TestReconcileNiriConfigRepairThatFailsIsReported(t *testing.T) {
	home, entry := niriStubHome(t, "include broken")
	// A provider whose apply does nothing: the second validate still fails.
	writeStub(t, filepath.Join(home, "bin", "ryoku-wm-niri"), "#!/bin/sh\n"+
		"case \"$1\" in\n"+
		"  caps) echo '{\"name\":\"niri\",\"portalBackend\":\"gnome\",\"supports\":[],\"workspaceModel\":\"dynamic\"}' ;;\n"+
		"  *) echo '{}' ;;\n"+
		"esac\n"+
		"exit 0\n")
	r := reconcileNiriConfig(false)
	if r.status != recFailed {
		t.Fatalf("unrepairable: status=%s detail=%q, want failed", r.status.label(), r.detail)
	}
	if _, err := os.ReadFile(entry); err != nil {
		t.Fatal(err)
	}
}

// A clean config is simply ok.
func TestReconcileNiriConfigCleanIsOK(t *testing.T) {
	niriStubHome(t, "include \"settings.kdl\"\n")
	if r := reconcileNiriConfig(true); r.status != recOK {
		t.Fatalf("clean: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
}

// A config whose generated include has not been written yet is not a fault: the
// provider writes it on apply. Check-only must say so without warning, and the
// repair must apply (which writes it) rather than bail.
func TestReconcileNiriConfigNotAppliedYet(t *testing.T) {
	home, entry := niriStubHome(t, "include broken")
	// model the fresh box: niri reports a missing include, then the provider's
	// apply writes a complete config.
	writeStub(t, filepath.Join(home, "bin", "niri"), "#!/bin/sh\n"+
		"while IFS= read -r line || [ -n \"$line\" ]; do\n"+
		"  case \"$line\" in *broken*) echo 'Error: failed to read included config from \"/x/settings.kdl\": No such file or directory (os error 2)' >&2; exit 1 ;; esac\n"+
		"done < \"$NIRI_TEST_CONFIG\"\n"+
		"exit 0\n")
	if r := reconcileNiriConfig(true); r.status != recNote {
		t.Fatalf("check on a fresh box: status=%s detail=%q, want note", r.status.label(), r.detail)
	}
	if r := reconcileNiriConfig(false); r.status != recFixed {
		t.Fatalf("repair on a fresh box: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	if _, err := os.ReadFile(entry); err != nil {
		t.Fatal(err)
	}
}
