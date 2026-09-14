package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func seedTree(t *testing.T, root string, files map[string]string) {
	t.Helper()
	for rel, content := range files {
		p := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func TestDiffUserConfig(t *testing.T) {
	t.Setenv("RYOKU_WM", "hyprland")
	base, cfg := t.TempDir(), t.TempDir()
	seedTree(t, base, map[string]string{
		"hypr/hyprland.lua": "shipped",
		"kitty/kitty.conf":  "shipped",
		"fish/config.fish":  "shipped",
	})
	seedTree(t, cfg, map[string]string{
		"hypr/hyprland.lua": "user edited", // modified
		"kitty/kitty.conf":  "shipped",     // untouched
		"hypr/user.lua":     "user override",
		// fish/config.fish deleted
	})

	d, err := diffUserConfig(base, cfg, "")
	if err != nil {
		t.Fatal(err)
	}
	if len(d.Modified) != 1 || d.Modified[0] != "hypr/hyprland.lua" {
		t.Fatalf("modified = %v", d.Modified)
	}
	if len(d.Missing) != 1 || d.Missing[0] != "fish/config.fish" {
		t.Fatalf("missing = %v", d.Missing)
	}
	if len(d.Overrides) != 1 || d.Overrides[0] != "hypr/user.lua" {
		t.Fatalf("overrides = %v", d.Overrides)
	}
}

func TestUserDocBodyWithoutBase(t *testing.T) {
	t.Setenv("RYOKU_CONFIG_BASE", filepath.Join(t.TempDir(), "absent"))
	t.Setenv("RYOKU_RASHIN_REPO", "")
	t.Setenv("XDG_STATE_HOME", t.TempDir()) // no recorded dev checkout
	body := userDocBody()
	if !strings.Contains(body, "No shipped baseline found") {
		t.Fatalf("expected no-baseline note, got:\n%s", body)
	}
}

func TestUserDocBodyCleanBaseline(t *testing.T) {
	base := t.TempDir()
	cfg := t.TempDir()
	seedTree(t, base, map[string]string{"kitty/kitty.conf": "same"})
	seedTree(t, cfg, map[string]string{"kitty/kitty.conf": "same"})
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", cfg)
	if body := userDocBody(); !strings.Contains(body, "matches the shipped Ryoku baseline") {
		t.Fatalf("expected clean baseline note, got:\n%s", body)
	}
}

// dev checkout: no packaged base, but ryoku deploy recorded a checkout, so the
// hyprland tree is the baseline and hypr divergences are reported.
func TestUserDocBodyDevBaseline(t *testing.T) {
	checkout := t.TempDir()
	seedTree(t, checkout, map[string]string{
		"ryoku/hyprland/modules/binds.lua": "shipped binds",
		"ryoku/hyprland/hyprland.lua":      "entry",
	})
	cfg := t.TempDir()
	seedTree(t, cfg, map[string]string{
		"hypr/modules/binds.lua": "user edited binds", // modified
		"hypr/hyprland.lua":      "entry",             // untouched
		"hypr/user.lua":          "override",          // override present
	})
	state := t.TempDir()
	seedTree(t, state, map[string]string{"ryoku/repo": checkout + "\n"})
	t.Setenv("RYOKU_CONFIG_BASE", filepath.Join(t.TempDir(), "absent"))
	t.Setenv("RYOKU_RASHIN_REPO", "")
	t.Setenv("XDG_STATE_HOME", state)
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("RYOKU_WM", "hyprland")
	body := userDocBody()
	if !strings.Contains(body, "dev checkout") {
		t.Fatalf("expected dev-baseline note, got:\n%s", body)
	}
	if !strings.Contains(body, "hypr/modules/binds.lua") {
		t.Fatalf("expected modified bind listed, got:\n%s", body)
	}
	if !strings.Contains(body, "hypr/user.lua") {
		t.Fatalf("expected override listed, got:\n%s", body)
	}
}
