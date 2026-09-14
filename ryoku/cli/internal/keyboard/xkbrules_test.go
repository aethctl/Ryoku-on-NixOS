package keyboard

import (
	"os"
	"path/filepath"
	"testing"
)

// xkbFixture writes a tiny rules .lst in the real base format and points the
// package at it, so the catalog is exercised without the system file.
func xkbFixture(t *testing.T) {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "base.lst")
	body := "" +
		"! model\n" +
		"  pc105          Generic 105-key PC\n" +
		"\n" +
		"! layout\n" +
		"  us              English (US)\n" +
		"  fr              French\n" +
		"  de              German\n" +
		"\n" +
		"! variant\n" +
		"  azerty          fr: French (AZERTY)\n" +
		"  oss             fr: French (alt.)\n" +
		"  dvorak          us: English (Dvorak)\n"
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	saved := XkbRulesPaths
	XkbRulesPaths = []string{path}
	t.Cleanup(func() { XkbRulesPaths = saved })
}

func TestXkbCatalogResolvesLayoutNameToCode(t *testing.T) {
	xkbFixture(t)
	c := LoadXkbCatalog()
	if c.Empty() {
		t.Fatal("catalog is empty; the fixture did not parse")
	}
	if !c.IsLayout("us") || !c.IsLayout("fr") {
		t.Errorf("us/fr should be known layout codes")
	}
	if c.IsLayout("English (US)") {
		t.Errorf("a description must not read as a layout code")
	}
	if code, ok := c.LayoutByName("English (US)"); !ok || code != "us" {
		t.Errorf("LayoutByName(English (US)) = %q,%v, want us,true", code, ok)
	}
	// case and surrounding space must not defeat the match.
	if code, ok := c.LayoutByName("  french  "); !ok || code != "fr" {
		t.Errorf("LayoutByName(french) = %q,%v, want fr,true", code, ok)
	}
}

func TestXkbCatalogResolvesVariantWithinLayout(t *testing.T) {
	xkbFixture(t)
	c := LoadXkbCatalog()
	if !c.IsVariant("fr", "azerty") {
		t.Errorf("azerty should be a known fr variant")
	}
	if code, ok := c.VariantByName("fr", "French (AZERTY)"); !ok || code != "azerty" {
		t.Errorf("VariantByName(fr, French (AZERTY)) = %q,%v, want azerty,true", code, ok)
	}
	// the variant belongs to fr, so it must not resolve under us.
	if _, ok := c.VariantByName("us", "French (AZERTY)"); ok {
		t.Errorf("French (AZERTY) must not resolve as a us variant")
	}
}

func TestXkbCatalogEmptyWhenBaseAbsent(t *testing.T) {
	saved := XkbRulesPaths
	XkbRulesPaths = []string{filepath.Join(t.TempDir(), "does-not-exist.lst")}
	t.Cleanup(func() { XkbRulesPaths = saved })
	if !LoadXkbCatalog().Empty() {
		t.Errorf("a missing base must yield an empty catalog")
	}
}
