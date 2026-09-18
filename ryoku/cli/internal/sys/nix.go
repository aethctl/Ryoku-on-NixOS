package sys

import (
	"os"
	"strings"
)

// NixBackend reports whether this Ryoku binary is running under the
// declarative NixOS integration.
//
// The Nix package wrapper sets RYOKU_UPDATE_BACKEND=nix, which is a better
// signal than probing /etc/NIXOS: unit tests and upstream development builds
// can still exercise the Arch behaviour even when they happen to run on a
// NixOS development machine.
func NixBackend() bool {
	return strings.EqualFold(
		strings.TrimSpace(os.Getenv("RYOKU_UPDATE_BACKEND")),
		"nix",
	)
}
