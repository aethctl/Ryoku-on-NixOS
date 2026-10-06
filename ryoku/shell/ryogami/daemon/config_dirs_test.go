package main

import (
	"os"
	"path/filepath"
	"testing"
)

// The wallpaper dir follows a localized Pictures folder, keeps working for
// users whose library still sits in the English default beside an empty
// localized one, and always loses to an explicitly configured path.
func TestWallpaperDirXdgResolution(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	// No XDG variable: the English default.
	t.Setenv("XDG_PICTURES_DIR", "")
	if got, want := (config{}).wallpaperDir(), filepath.Join(home, "Pictures", "Wallpapers"); got != want {
		t.Fatalf("unset XDG: got %q, want %q", got, want)
	}

	// Localized folder that holds the library wins.
	localized := filepath.Join(home, "Imagens")
	if err := os.MkdirAll(filepath.Join(localized, "Wallpapers"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_PICTURES_DIR", localized)
	if got, want := (config{}).wallpaperDir(), filepath.Join(localized, "Wallpapers"); got != want {
		t.Fatalf("localized: got %q, want %q", got, want)
	}

	// Localized folder exists but is empty while the English one has the
	// files (xdg-user-dirs generated it after the fact): the library wins.
	english := filepath.Join(home, "Pictures")
	if err := os.MkdirAll(filepath.Join(english, "Wallpapers"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(filepath.Join(localized, "Wallpapers")); err != nil {
		t.Fatal(err)
	}
	if got, want := (config{}).wallpaperDir(), filepath.Join(english, "Wallpapers"); got != want {
		t.Fatalf("empty localized, english library: got %q, want %q", got, want)
	}

	// Neither exists: the localized path is the answer so a fresh library
	// grows in the right folder.
	if err := os.RemoveAll(english); err != nil {
		t.Fatal(err)
	}
	if got, want := (config{}).wallpaperDir(), filepath.Join(localized, "Wallpapers"); got != want {
		t.Fatalf("neither exists: got %q, want %q", got, want)
	}

	// An explicit configured path beats all of it.
	c := config{}
	c.Paths.Wallpaper = filepath.Join(home, "custom")
	if got, want := c.wallpaperDir(), filepath.Join(home, "custom"); got != want {
		t.Fatalf("explicit: got %q, want %q", got, want)
	}
}
