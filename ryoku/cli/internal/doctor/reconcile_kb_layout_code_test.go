package doctor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"ryoku-cli/internal/keyboard"
)

// kbcFixture writes a rules .lst in the real base format and points the keyboard
// package at it, so the reconciler resolves against a known catalog, not the
// system file.
func kbcFixture(t *testing.T) {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "base.lst")
	body := "" +
		"! layout\n" +
		"  us              English (US)\n" +
		"  fr              French\n" +
		"  de              German\n" +
		"\n" +
		"! variant\n" +
		"  azerty          fr: French (AZERTY)\n"
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	saved := keyboard.XkbRulesPaths
	keyboard.XkbRulesPaths = []string{path}
	t.Cleanup(func() { keyboard.XkbRulesPaths = saved })
}

// kbcHome writes a desktop.json carrying the given layout/variant and points XDG
// at it, returning the store path.
func kbcHome(t *testing.T, layout, variant string) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	dir := filepath.Join(home, ".config", "ryoku")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	store := filepath.Join(dir, "desktop.json")
	body := `{"desktop":{"input":{"kbLayout":"` + layout + `","kbVariant":"` + variant + `","numlockByDefault":false},"cursor":{"theme":"Bibata"}}}`
	if err := os.WriteFile(store, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return store
}

// A store holding the description "English (US)" is drift the check names by both
// the stored name and the code it means.
func TestKbCodeLabelReported(t *testing.T) {
	kbcFixture(t)
	kbcHome(t, "English (US)", "")
	r := reconcileKbLayoutCode(true)
	if r.status != recWouldFix {
		t.Fatalf("status = %s, want would-fix; detail=%q", r.status.label(), r.detail)
	}
	for _, want := range []string{"English (US)", "us"} {
		if !strings.Contains(r.detail, want) {
			t.Errorf("check copy %q must name %q", r.detail, want)
		}
	}
}

// A store already on a code is clean: nothing to report.
func TestKbCodeAlreadyCodeIsClean(t *testing.T) {
	kbcFixture(t)
	kbcHome(t, "us", "")
	if r := reconcileKbLayoutCode(true); r.status != recOK {
		t.Errorf("a store on us should be ok, got %s (%s)", r.status.label(), r.detail)
	}
}

// Every element of a comma family is resolved on its own.
func TestKbCodeFamilyResolvesEachElement(t *testing.T) {
	kbcFixture(t)
	cat := keyboard.LoadXkbCatalog()
	p := planKbCodes("English (US),French", true, "", false, cat)
	if p.layoutNew != "us,fr" {
		t.Errorf("family layout = %q, want us,fr", p.layoutNew)
	}
	if len(p.unresolved) != 0 {
		t.Errorf("nothing should be unresolved, got %v", p.unresolved)
	}
}

// A value that is neither a code nor a known name is left alone and reported, not
// mangled into a guess.
func TestKbCodeUnresolvableLeftAlone(t *testing.T) {
	kbcFixture(t)
	kbcHome(t, "Klingon (pIqaD)", "")
	r := reconcileKbLayoutCode(true)
	if r.status != recWarn {
		t.Fatalf("status = %s, want warn; detail=%q", r.status.label(), r.detail)
	}
	if !strings.Contains(r.detail, "Klingon (pIqaD)") {
		t.Errorf("warn copy %q must name the value it could not resolve", r.detail)
	}
	// the planner must leave the value in place, unchanged.
	cat := keyboard.LoadXkbCatalog()
	p := planKbCodes("Klingon (pIqaD)", true, "", false, cat)
	if p.changed() {
		t.Errorf("an unresolvable value must not change: %q -> %q", p.layoutOld, p.layoutNew)
	}
}

// The repair sets the code and leaves every other key in the store intact.
func TestKbCodeRewriteLeavesOtherKeysAlone(t *testing.T) {
	kbcFixture(t)
	cat := keyboard.LoadXkbCatalog()
	raw := `{"desktop":{"input":{"kbLayout":"English (US)","kbVariant":"","numlockByDefault":false},"cursor":{"theme":"Bibata"}}}`
	p := planKbCodes("English (US)", true, "", true, cat)
	out, err := rewriteInputCodes(raw, p)
	if err != nil {
		t.Fatal(err)
	}
	after, _ := hyprGetKbLayout(out)
	if after != "us" {
		t.Errorf("after repair kbLayout = %q, want us", after)
	}
	for _, keep := range []string{`"kbVariant"`, `"numlockByDefault"`, `"Bibata"`} {
		if !strings.Contains(out, keep) {
			t.Errorf("repair dropped %s: %s", keep, out)
		}
	}
}
