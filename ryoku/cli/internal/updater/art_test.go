package updater

import (
	"os"
	"strings"
	"testing"
)

func TestEveryNamedLineHasArt(t *testing.T) {
	names, err := os.ReadFile("../../../../release/names.md")
	if err != nil {
		t.Skip("release/names.md not beside the checkout")
	}
	for _, ln := range strings.Split(string(names), "\n") {
		if !strings.HasPrefix(ln, "## ") {
			continue
		}
		name := strings.TrimSpace(strings.TrimPrefix(ln, "## "))
		if releaseArt(name) == "" {
			t.Errorf("%s has a story but no art (internal/updater/art/%s.txt)", name, strings.ToLower(name))
		}
	}
	if releaseArt("nobody") != "" {
		t.Fatal("an unnamed line must have no art")
	}
}
