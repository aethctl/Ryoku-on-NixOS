package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestKbLayoutsUseConfiguredRulesDir(t *testing.T) {
	dir := t.TempDir()

	rules := `! layout
  us  English (US)
  gb  English (UK)

! variant
  intl  us: English (US, intl.)
`

	if err := os.WriteFile(filepath.Join(dir, "base.lst"), []byte(rules), 0o644); err != nil {
		t.Fatal(err)
	}

	t.Setenv("RYOKU_XKB_RULES_DIR", dir)
	t.Setenv("XKB_CONFIG_ROOT", "")

	layouts := listKbLayouts()
	if len(layouts) < 2 || layouts[0]["code"] != "us" || layouts[0]["name"] != "English (US)" {
		t.Fatalf("unexpected layouts: %#v", layouts)
	}

	variants := listKbVariants("us")
	if len(variants) != 1 || variants[0]["code"] != "intl" {
		t.Fatalf("unexpected variants: %#v", variants)
	}
}

func TestCursorThemesFollowSymlinkedNixProfileEntries(t *testing.T) {
	home := t.TempDir()
	real := filepath.Join(t.TempDir(), "Bibata")
	if err := os.MkdirAll(filepath.Join(real, "cursors"), 0o755); err != nil {
		t.Fatal(err)
	}

	icons := filepath.Join(home, ".icons")
	if err := os.MkdirAll(icons, 0o755); err != nil {
		t.Fatal(err)
	}

	if err := os.Symlink(real, filepath.Join(icons, "Bibata")); err != nil {
		t.Fatal(err)
	}

	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	t.Setenv("XDG_DATA_DIRS", "")

	got := listCursorThemes()
	for _, name := range got {
		if name == "Bibata" {
			return
		}
	}

	t.Fatalf("symlinked cursor theme missing from %v", got)
}
