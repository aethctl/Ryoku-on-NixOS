package doctor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// kmHome writes a desktop.json carrying the given kbLayout.
func kmHome(t *testing.T, layout string) {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	dir := filepath.Join(home, ".config", "ryoku")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	body := `{"desktop":{"input":{"kbLayout":"` + layout + `","kbVariant":"","followMouse":1}}}`
	if err := os.WriteFile(filepath.Join(dir, "desktop.json"), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

// A login screen and a boot prompt cannot switch layouts, so the primary of a
// "fr,us" pair is the one that matters to them.
func TestKeymapReadsPrimaryLayout(t *testing.T) {
	kmHome(t, "fr,us")
	if got := configuredKbLayout(); got != "fr" {
		t.Errorf("configuredKbLayout() = %q, want fr", got)
	}
}

func TestKeymapNoLayoutRecorded(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	if got := reconcileKeymap(true); got.status != recOK {
		t.Errorf("a box with no desktop.json should be ok, got %v (%s)", got.status, got.detail)
	}
}

// The adoption only ever overwrites the untouched shipped default, and a
// rewrite must not disturb any other key in the store.
func TestKbLayoutRoundTripLeavesOtherKeysAlone(t *testing.T) {
	raw := `{"desktop":{"input":{"kbLayout":"us","kbVariant":"","numlockByDefault":false},"cursor":{"theme":"Bibata"}}}`
	got, ok := hyprGetKbLayout(raw)
	if !ok || got != "us" {
		t.Fatalf("read = %q ok=%v, want us true", got, ok)
	}
	out, err := hyprSetKbLayout(raw, "fr")
	if err != nil {
		t.Fatal(err)
	}
	after, _ := hyprGetKbLayout(out)
	if after != "fr" {
		t.Errorf("after write = %q, want fr", after)
	}
	for _, keep := range []string{`"kbVariant"`, `"numlockByDefault"`, `"Bibata"`} {
		if !strings.Contains(out, keep) {
			t.Errorf("write dropped %s: %s", keep, out)
		}
	}
}
