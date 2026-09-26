package main

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// The caps list is documented as "kept in step with that package's depends".
// A satellite added to the PKGBUILD but not to this list could never be
// reclaimed on a packaged box; the variant package itself, missing from the
// list, owns every satellite and blocks all their removal. Both drifts fail
// here, against the real PKGBUILD.
func TestReclaimListMatchesVariantDepends(t *testing.T) {
	raw, err := os.ReadFile("../../../release/packages/ryoku-desktop-niri/PKGBUILD")
	if err != nil {
		t.Skip("no PKGBUILD beside the test")
	}
	m := regexp.MustCompile(`(?ms)^depends=\((.*?)\)`).FindSubmatch(raw)
	if m == nil {
		t.Fatal("no depends array in the PKGBUILD")
	}
	want := map[string]bool{}
	body := regexp.MustCompile(`(?m)^\s*#.*$`).ReplaceAll(m[1], nil)
	for _, line := range strings.Fields(string(body)) {
		pkg := strings.Trim(line, "'\"")
		if i := strings.Index(pkg, "="); i >= 0 {
			pkg = pkg[:i] // a version bound: "niri=26.04" names niri
		}
		if pkg == "" || pkg == "ryoku-desktop" {
			continue // the umbrella is shared with the incoming compositor
		}
		want[pkg] = true
	}
	have := map[string]bool{}
	for _, p := range compositorPackages {
		have[p] = true
	}
	if !have["ryoku-desktop-niri"] {
		t.Error("the variant package must be in its own reclaim list")
	}
	for p := range want {
		if !have[p] {
			t.Errorf("PKGBUILD depends on %s but the reclaim list omits it", p)
		}
	}
}
