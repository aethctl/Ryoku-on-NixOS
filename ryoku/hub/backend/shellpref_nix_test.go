package main

import "testing"

func TestShellManagedByNix(t *testing.T) {
	t.Setenv("RYOKU_UPDATE_BACKEND", "nix")

	if !shellManagedByNix() {
		t.Fatal("shellManagedByNix() = false, want true")
	}

	t.Setenv("RYOKU_UPDATE_BACKEND", "pacman")

	if shellManagedByNix() {
		t.Fatal("shellManagedByNix() = true for non-Nix backend")
	}
}
