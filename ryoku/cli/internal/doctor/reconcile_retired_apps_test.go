package doctor

import (
	"errors"
	"testing"
)

func TestReconcileRetiredApps(t *testing.T) {
	t.Setenv("RYOKU_UPDATE_BACKEND", "pacman")
	oldInstalled := retiredAppInstalled
	oldRemove := removeRetiredApp
	t.Cleanup(func() {
		retiredAppInstalled = oldInstalled
		removeRetiredApp = oldRemove
	})
	retiredAppInstalled = func(pkg string) bool { return pkg == "ryomotion" }

	// Check-only names the exact removal command and changes nothing.
	removeRetiredApp = func(string) error { t.Fatal("check mode removed a package"); return nil }
	want := "sudo pacman -Rns --noconfirm ryomotion"
	if got := reconcileRetiredApps(true); got.status != recWouldFix || got.remedy != want {
		t.Fatalf("check = {%v, %q}, want {%v, %q}", got.status, got.remedy, recWouldFix, want)
	}

	// Apply removes the installed package.
	var removed []string
	removeRetiredApp = func(pkg string) error { removed = append(removed, pkg); return nil }
	if got := reconcileRetiredApps(false); got.status != recFixed {
		t.Fatalf("apply status = %v, want fixed", got.status)
	}
	if len(removed) != 1 || removed[0] != "ryomotion" {
		t.Fatalf("removed = %v, want [ryomotion]", removed)
	}

	// A removal that fails still hands back the command to run by hand.
	removeRetiredApp = func(string) error { return errors.New("blocked") }
	if got := reconcileRetiredApps(false); got.status != recFailed || got.remedy != want {
		t.Fatalf("failure = {%v, %q}, want {%v, %q}", got.status, got.remedy, recFailed, want)
	}
}

func TestReconcileRetiredAppsQuietWhenAbsent(t *testing.T) {
	t.Setenv("RYOKU_UPDATE_BACKEND", "pacman")
	oldInstalled := retiredAppInstalled
	oldRemove := removeRetiredApp
	t.Cleanup(func() {
		retiredAppInstalled = oldInstalled
		removeRetiredApp = oldRemove
	})
	retiredAppInstalled = func(string) bool { return false }
	removeRetiredApp = func(string) error { t.Fatal("removed a package that is not installed"); return nil }

	if got := reconcileRetiredApps(false); got.status != recOK {
		t.Fatalf("status = %v, want ok on a box with no retired apps", got.status)
	}
}

func TestReconcileRetiredAppsPreservesNixOS(t *testing.T) {
	t.Setenv("RYOKU_UPDATE_BACKEND", "nix")

	oldInstalled := retiredAppInstalled
	oldRemove := removeRetiredApp

	t.Cleanup(func() {
		retiredAppInstalled = oldInstalled
		removeRetiredApp = oldRemove
	})

	retiredAppInstalled = func(string) bool {
		t.Fatal("NixOS must not inspect pacman packages")
		return false
	}

	removeRetiredApp = func(string) error {
		t.Fatal("NixOS must never run pacman removal")
		return nil
	}

	for _, checkOnly := range []bool{true, false} {
		if result := reconcileRetiredApps(checkOnly); result.status != recOK {
			t.Fatalf("NixOS reconciliation: %v", result.status)
		}
	}
}
