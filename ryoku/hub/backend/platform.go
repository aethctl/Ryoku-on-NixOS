package main

import (
	"os"
	"strings"
)

func nixManagedHost() bool {
	return strings.EqualFold(
		strings.TrimSpace(os.Getenv("RYOKU_UPDATE_BACKEND")),
		"nix",
	)
}
