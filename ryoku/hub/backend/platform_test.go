package main

import "testing"

func TestNixManagedHost(t *testing.T) {
	t.Setenv("RYOKU_UPDATE_BACKEND", "nix")
	if !nixManagedHost() {
		t.Fatal("nixManagedHost() = false, want true")
	}

	t.Setenv("RYOKU_UPDATE_BACKEND", "pacman")
	if nixManagedHost() {
		t.Fatal("nixManagedHost() = true for non-Nix backend")
	}
}
