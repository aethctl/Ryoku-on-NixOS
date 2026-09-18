package main

import (
	"os"
	"testing"
)

// Hub tests must not inherit the active desktop's update backend. Tests for
// Nix-specific policy explicitly set RYOKU_UPDATE_BACKEND themselves.
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
