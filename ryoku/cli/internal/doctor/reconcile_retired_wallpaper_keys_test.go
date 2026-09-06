package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"testing"
)

// The strip drops wallpaper_dir, apply_theme_filter and theme_filter_strength,
// keeps content_fit and transition_preset (Ryogami reads both from shell.json),
// leaves unrelated top-level keys, reports the removed directory, and no-ops once
// the three are gone.
func TestStripRetiredWallpaperKeys(t *testing.T) {
	full := []byte(`{"wallpaper":{"content_fit":"Cover","transition_preset":"grow","wallpaper_dir":"/x/walls","apply_theme_filter":true,"theme_filter_strength":0.5},"theme":{"theme":"Default"}}`)
	out, dir, changed, err := stripRetiredWallpaperKeys(full)
	if err != nil || !changed {
		t.Fatalf("retired keys must be stripped: changed=%v err=%v", changed, err)
	}
	if dir != "/x/walls" {
		t.Fatalf("removed wallpaper_dir = %q, want /x/walls", dir)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatalf("stripped JSON does not parse: %v", err)
	}
	wp, ok := cfg["wallpaper"].(map[string]any)
	if !ok {
		t.Fatalf("wallpaper namespace lost: %v", cfg)
	}
	for _, retired := range []string{"wallpaper_dir", "apply_theme_filter", "theme_filter_strength"} {
		if _, present := wp[retired]; present {
			t.Errorf("fix did not strip wallpaper.%s", retired)
		}
	}
	for _, kept := range []string{"content_fit", "transition_preset"} {
		if _, present := wp[kept]; !present {
			t.Errorf("live wallpaper key %s was lost: %v", kept, wp)
		}
	}
	if _, present := cfg["theme"]; !present {
		t.Errorf("passthrough key theme was lost: %v", cfg)
	}

	// stripping is idempotent: the cleaned store is now a no-op.
	if _, _, changed, err := stripRetiredWallpaperKeys(out); err != nil || changed {
		t.Errorf("re-stripping a clean store must be a no-op: changed=%v err=%v", changed, err)
	}

	// a wallpaper object with only live keys is untouched, and reports no dir.
	clean := []byte(`{"wallpaper":{"content_fit":"Cover","transition_preset":"random"}}`)
	if _, dir, changed, err := stripRetiredWallpaperKeys(clean); err != nil || changed || dir != "" {
		t.Errorf("a store without retired keys must be untouched: changed=%v dir=%q err=%v", changed, dir, err)
	}

	// a store with no wallpaper namespace is untouched.
	if _, _, changed, err := stripRetiredWallpaperKeys([]byte(`{"bars":{}}`)); err != nil || changed {
		t.Errorf("a store with no wallpaper namespace must be untouched: changed=%v err=%v", changed, err)
	}

	// garbage errors rather than silently rewriting.
	if _, _, _, err := stripRetiredWallpaperKeys([]byte("not json")); err == nil {
		t.Fatal("garbage must error, not silently rewrite")
	}
}

// The reconciler reads the persisted store: check reports the retired keys
// without mutating, fix strips them and moves a custom wallpaper_dir into
// ryogami.json paths.wallpaper, and a clean store is a no-op.
func TestReconcileRetiredWallpaperKeys(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}

	// no shell.json yet: ok, nothing to do.
	if r := reconcileRetiredWallpaperKeys(false); r.status != recOK {
		t.Fatalf("missing shell.json: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	stored := `{"wallpaper":{"content_fit":"Cover","transition_preset":"grow","wallpaper_dir":"/custom/walls","apply_theme_filter":true,"theme_filter_strength":0.5},"theme":{"theme":"Default"}}`
	if err := os.WriteFile(path, []byte(stored), 0o644); err != nil {
		t.Fatal(err)
	}

	// check-only reports the leftovers but leaves the file byte-for-byte.
	if r := reconcileRetiredWallpaperKeys(true); r.status != recWouldFix {
		t.Fatalf("check with retired keys: status=%s detail=%q, want would-fix", r.status.label(), r.detail)
	}
	if got, _ := os.ReadFile(path); string(got) != stored {
		t.Fatalf("check-only mutated the store: %s", got)
	}

	// fix strips the retired keys and reports the change.
	if r := reconcileRetiredWallpaperKeys(false); r.status != recFixed {
		t.Fatalf("fix with retired keys: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		t.Fatalf("rewritten store does not parse: %v", err)
	}
	wp := cfg["wallpaper"].(map[string]any)
	for _, retired := range []string{"wallpaper_dir", "apply_theme_filter", "theme_filter_strength"} {
		if _, present := wp[retired]; present {
			t.Errorf("fix did not strip wallpaper.%s", retired)
		}
	}
	if wp["content_fit"] != "Cover" || wp["transition_preset"] != "grow" {
		t.Errorf("fix dropped a live wallpaper key: %v", wp)
	}

	// the custom directory was migrated into ryogami.json paths.wallpaper.
	ryogami := filepath.Join(sys.ConfigHome(), "ryoku", "ryogami.json")
	rraw, err := os.ReadFile(ryogami)
	if err != nil {
		t.Fatalf("ryogami.json not written: %v", err)
	}
	var rcfg map[string]any
	if err := json.Unmarshal(rraw, &rcfg); err != nil {
		t.Fatalf("ryogami.json does not parse: %v", err)
	}
	paths, ok := rcfg["paths"].(map[string]any)
	if !ok || paths["wallpaper"] != "/custom/walls" {
		t.Fatalf("wallpaper_dir not migrated to ryogami paths.wallpaper: %v", rcfg)
	}

	// second run is a no-op: the store is now clean.
	if r := reconcileRetiredWallpaperKeys(false); r.status != recOK {
		t.Fatalf("clean store: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
}

// migrateWallpaperDir never overrides Ryogami's own paths.wallpaper.
func TestMigrateWallpaperDirKeepsExisting(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	ryogami := filepath.Join(sys.ConfigHome(), "ryoku", "ryogami.json")
	if err := os.MkdirAll(filepath.Dir(ryogami), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(ryogami, []byte(`{"paths":{"wallpaper":"/ryogami/own"},"monitor":"DP-1"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	moved, err := migrateWallpaperDir("/custom/walls")
	if err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if moved {
		t.Fatal("migrate overrode an existing ryogami paths.wallpaper")
	}
	raw, _ := os.ReadFile(ryogami)
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		t.Fatalf("ryogami.json does not parse: %v", err)
	}
	if cfg["paths"].(map[string]any)["wallpaper"] != "/ryogami/own" {
		t.Fatalf("existing wallpaper dir was clobbered: %v", cfg)
	}
	if cfg["monitor"] != "DP-1" {
		t.Fatalf("sibling key monitor was lost: %v", cfg)
	}
}
