package updater

import (
	"os"
	"testing"
)

// Do not let the developer's live Musubi session choose the backend for unit
// tests. Nix-specific tests opt in explicitly with t.Setenv.
func TestMain(m *testing.M) {
	old, had := os.LookupEnv("RYOKU_UPDATE_BACKEND")
	_ = os.Unsetenv("RYOKU_UPDATE_BACKEND")

	code := m.Run()

	if had {
		_ = os.Setenv("RYOKU_UPDATE_BACKEND", old)
	} else {
		_ = os.Unsetenv("RYOKU_UPDATE_BACKEND")
	}

	os.Exit(code)
}
