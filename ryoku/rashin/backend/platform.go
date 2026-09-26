package main

import (
	"os"
	"strings"
)

// rashinNixBackend reports whether this Rashin instance is running on Ryoku's
// NixOS backend. The marker fallback also covers direct CLI invocations from
// shells that predate the current session environment.
func rashinNixBackend() bool {
	if strings.EqualFold(strings.TrimSpace(os.Getenv("RYOKU_UPDATE_BACKEND")), "nix") {
		return true
	}
	_, err := os.Stat("/etc/ryoku/nix-system-package-count")
	return err == nil
}

func nixSystemPackageCount() string {
	b, err := os.ReadFile("/etc/ryoku/nix-system-package-count")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}
