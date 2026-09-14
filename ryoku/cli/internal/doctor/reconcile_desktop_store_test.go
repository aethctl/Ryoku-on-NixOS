package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"ryoku-cli/internal/sys"
)

func TestMigrateDesktopStore(t *testing.T) {
	old := `{
		"cursor": {"theme": "Bibata", "size": 24},
		"input": {"kbLayout": "us"},
		"plugins": {"hyprbars": {"enabled": true}},
		"anim": {"items": []},
		"windowRules": ["float,^(pavucontrol)$"]
	}`
	out, err := migrateDesktopStore([]byte(old))
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]map[string]any
	if err := json.Unmarshal(out, &got); err != nil {
		t.Fatalf("migrated store does not parse: %v", err)
	}
	for _, k := range []string{"cursor", "input", "windowRules"} {
		if _, ok := got["desktop"][k]; !ok {
			t.Errorf("%q must re-root under desktop.*", k)
		}
	}
	hypr, _ := got["wm"]["hyprland"].(map[string]any)
	for _, k := range []string{"plugins", "anim"} {
		if _, ok := hypr[k]; !ok {
			t.Errorf("%q must re-root under wm.hyprland.*", k)
		}
		if _, ok := got["desktop"][k]; ok {
			t.Errorf("%q leaked into desktop.*", k)
		}
	}
}

func TestReconcileDesktopStoreMigratesAndRemovesOld(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	ryoku := filepath.Join(home, ".config", "ryoku")
	if err := os.MkdirAll(ryoku, 0o755); err != nil {
		t.Fatal(err)
	}
	old := filepath.Join(ryoku, "hypr.json")
	neu := filepath.Join(ryoku, "desktop.json")
	if err := os.WriteFile(old, []byte(`{"cursor":{"theme":"Bibata"},"plugins":{"hyprbars":{"enabled":true}}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	if r := reconcileDesktopStore(true); r.status != recWouldFix {
		t.Fatalf("check: status=%s, want todo", r.status.label())
	}
	if sys.Exists(neu) {
		t.Fatal("check-only must not write desktop.json")
	}

	if r := reconcileDesktopStore(false); r.status != recFixed {
		t.Fatalf("repair: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	if sys.Exists(old) {
		t.Fatal("old hypr.json must be removed after migration")
	}
	if !sys.Exists(neu) {
		t.Fatal("desktop.json must exist after migration")
	}
	raw, _ := os.ReadFile(neu)
	if th, _ := configuredCursor(raw); th != "Bibata" {
		t.Fatalf("migrated cursor theme reads back %q through the desktop.* reader, want Bibata", th)
	}

	if r := reconcileDesktopStore(true); r.status != recOK {
		t.Fatalf("idempotent second run: status=%s, want ok", r.status.label())
	}
}

// A desktop.json the Hub already wrote must never be clobbered by a re-rooted
// copy of a lingering old file; the stale old file is just dropped.
func TestReconcileDesktopStoreKeepsNewerDesktopJSON(t *testing.T) {
	home := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	ryoku := filepath.Join(home, ".config", "ryoku")
	if err := os.MkdirAll(ryoku, 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(ryoku, "hypr.json"), []byte(`{"cursor":{"theme":"Old"}}`), 0o644)
	os.WriteFile(filepath.Join(ryoku, "desktop.json"), []byte(`{"desktop":{"cursor":{"theme":"New"}}}`), 0o644)

	if r := reconcileDesktopStore(false); r.status != recFixed {
		t.Fatalf("status=%s, want fixed", r.status.label())
	}
	if sys.Exists(filepath.Join(ryoku, "hypr.json")) {
		t.Fatal("stale hypr.json must be removed")
	}
	raw, _ := os.ReadFile(filepath.Join(ryoku, "desktop.json"))
	if th, _ := configuredCursor(raw); th != "New" {
		t.Fatalf("Hub's desktop.json must be preserved (theme=%q, want New)", th)
	}
}
