package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestWallpaperSurvivesCacheCleanup(t *testing.T) {
	d, _ := restoreDaemon(t)
	pic := filepath.Join(t.TempDir(), "wall.png")
	writeE2EPNG(t, pic)
	d.saveOutputs([]string{"DP-1"}, "static", pic, map[string]bool{"DP-1": false}, map[string]int{"DP-1": 37})
	if err := os.RemoveAll(d.config().cacheDir()); err != nil {
		t.Fatal(err)
	}
	restarted := &daemon{cfg: d.config(), surface: newWallSurface()}
	if want, applied := restarted.restoreOutputs(); want != 1 || applied != 1 {
		t.Fatalf("after cache cleanup: restored %d of %d, want 1 of 1", applied, want)
	}
}

func TestStateMigrationPreservesMetadata(t *testing.T) {
	d, _ := restoreDaemon(t)
	cfg := d.config()
	files := map[string]string{
		"outputs.json":                 `{"DP-1":{"type":"static","path":"/wall.png","mute":false,"volume":37}}`,
		"wallpaper/index.json":         `{"wall.png":{"favourite":1}}`,
		"wallpaper/state.json":         `{"last":"wall.png"}`,
		"wallpaper/playlists.json":     `{"playlists":[{"name":"mine"}]}`,
		"wallpaper/we_properties.json": `{"wall":{"fps":30}}`,
	}
	for name, content := range files {
		src := filepath.Join(cfg.cacheDir(), name)
		if err := os.MkdirAll(filepath.Dir(src), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(src, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := cfg.migrateState(); err != nil {
		t.Fatal(err)
	}
	for name, content := range files {
		for _, dir := range []string{cfg.cacheDir(), cfg.stateDir()} {
			got, err := os.ReadFile(filepath.Join(dir, name))
			if err != nil || string(got) != content {
				t.Fatalf("%s: %q, %v", dir, got, err)
			}
		}
	}
	dst := filepath.Join(cfg.stateDir(), "outputs.json")
	if err := os.WriteFile(dst, []byte(`{}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := cfg.migrateState(); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(dst)
	if string(got) != `{}` {
		t.Fatal("migration replaced existing state")
	}
	if err := os.RemoveAll(cfg.cacheDir()); err != nil {
		t.Fatal(err)
	}
	if err := cfg.migrateState(); err != nil {
		t.Fatal(err)
	}
}
