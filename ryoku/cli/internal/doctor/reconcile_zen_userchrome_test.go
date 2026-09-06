package doctor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestReconcileZenUserChrome(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", "")

	if r := reconcileZenUserChrome(false); r.status != recOK {
		t.Fatalf("no zen: status=%s want ok", r.status.label())
	}

	prof := filepath.Join(home, ".config", "zen", "abc.Default (release)")
	chromeDir := filepath.Join(prof, "chrome")
	if err := os.MkdirAll(chromeDir, 0o755); err != nil {
		t.Fatal(err)
	}
	userCSS := filepath.Join(chromeDir, "userChrome.css")
	if err := os.WriteFile(userCSS, []byte("#nav-bar { opacity: 1; }\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// No prefs.js yet: not a launched profile, so nothing installs.
	if r := reconcileZenUserChrome(false); r.status != recOK {
		t.Fatalf("no profile: status=%s want ok", r.status.label())
	}

	if err := os.WriteFile(filepath.Join(prof, "prefs.js"), []byte("// prefs\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	if r := reconcileZenUserChrome(false); r.status != recFixed {
		t.Fatalf("install: status=%s want fixed", r.status.label())
	}

	sheet, err := os.ReadFile(filepath.Join(chromeDir, "ryoku-animations.css"))
	if err != nil || !strings.Contains(string(sheet), "ryoku-loadbar") {
		t.Fatalf("animation sheet missing or incomplete: %v", err)
	}
	uc, _ := os.ReadFile(userCSS)
	if !strings.Contains(string(uc), `@import "ryoku-animations.css";`) {
		t.Fatalf("userChrome.css missing import: %q", uc)
	}
	if !strings.Contains(string(uc), "#nav-bar") {
		t.Fatalf("userChrome.css dropped the user's rules: %q", uc)
	}

	if r := reconcileZenUserChrome(false); r.status != recOK {
		t.Fatalf("second run: status=%s want ok (idempotent)", r.status.label())
	}
}
