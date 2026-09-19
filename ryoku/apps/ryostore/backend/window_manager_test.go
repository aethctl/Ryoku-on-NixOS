package main

import (
	"strings"
	"sync"
	"testing"
)

// The gate compares whatever the seam reports with whatever the catalogue
// declared, so these tests use stand-in provider names: nothing here depends on
// which window managers exist, only on the two sides agreeing or not.
const (
	declaredManager = "wm-one"
	runningManager  = "wm-two"
)

// stubWindowManager pins the detected provider for one test, since the real one
// asks the running session.
func stubWindowManager(t *testing.T, name string) {
	t.Helper()
	previous := runningWindowManager
	runningWindowManager = sync.OnceValue(func() string { return name })
	t.Cleanup(func() { runningWindowManager = previous })
}

func TestParseWindowManager(t *testing.T) {
	cases := map[string]string{
		"Provider: wm-one\nLive: true\n":  "wm-one",
		"Provider: (none)\nLive: false\n": "",
		"Live: true\n":                    "",
		"":                                "",
		"Provider:   wm-two  \nWorkspace model: dynamic\n": "wm-two",
	}
	for raw, want := range cases {
		if got := parseWindowManager(raw); got != want {
			t.Errorf("parseWindowManager(%q) = %q, want %q", raw, got, want)
		}
	}
}

func TestProductWindowManagerGate(t *testing.T) {
	stubWindowManager(t, runningManager)

	if ok, _ := productWindowManagerGate(""); !ok {
		t.Error("a product that declares no window manager must run anywhere")
	}
	if ok, _ := productWindowManagerGate(declaredManager); ok {
		t.Error("a product declaring another window manager must not run here")
	}
	if ok, running := productWindowManagerGate(declaredManager); ok || running != runningManager {
		t.Errorf("gate = %v/%q, want false/%q", ok, running, runningManager)
	}
	if ok, _ := productWindowManagerGate(runningManager); !ok {
		t.Error("a product declaring the running window manager must run here")
	}

	// Nothing to compare against: content stays installable rather than vanishing
	// on a machine whose provider cannot be read.
	stubWindowManager(t, "")
	if ok, _ := productWindowManagerGate(declaredManager); !ok {
		t.Error("an undetectable window manager must not gate content")
	}
}

func TestProductEntryItemMarksForeignWindowManager(t *testing.T) {
	stubWindowManager(t, runningManager)

	entry := ProductEntry{ID: "demo", Name: "Demo", WindowManager: declaredManager}
	item, err := productEntryItem("", "barstyles", entry)
	if err != nil {
		t.Fatalf("productEntryItem: %v", err)
	}
	if !item.Unavailable {
		t.Fatal("item for a foreign window manager is not marked unavailable")
	}
	if item.RequiredWindowManager != declaredManager {
		t.Errorf("requiredWindowManager = %q, want %q", item.RequiredWindowManager, declaredManager)
	}
	if !strings.Contains(item.UnavailableReason, runningManager) {
		t.Errorf("reason = %q, want it to name the running window manager", item.UnavailableReason)
	}

	// A catalogue sentence, when one is written, is carried through verbatim.
	written := "Built against another window manager."
	entry.WindowManagerReason = written
	item, err = productEntryItem("", "barstyles", entry)
	if err != nil {
		t.Fatalf("productEntryItem: %v", err)
	}
	if item.UnavailableReason != written {
		t.Errorf("reason = %q, want the catalogue's own %q", item.UnavailableReason, written)
	}

	// The same product on the manager it declares is an ordinary item.
	entry.WindowManager = runningManager
	item, err = productEntryItem("", "barstyles", entry)
	if err != nil {
		t.Fatalf("productEntryItem: %v", err)
	}
	if item.Unavailable {
		t.Error("item is unavailable on the window manager it declares")
	}
	if item.RequiredWindowManager != runningManager {
		t.Errorf("requiredWindowManager = %q, want %q", item.RequiredWindowManager, runningManager)
	}
}

// A product newly declaring (or dropping) the window manager it is written for
// changes what the catalogue offers, so the store must notice it the same way it
// notices a pause. Without this the change reaches nobody whose store has a
// cached catalogue.
func TestCatalogRevisionTracksRequiredWindowManager(t *testing.T) {
	anywhere := catalogRevision(Catalog{Items: []Item{
		{Category: "barstyles", ID: "demo", Version: "1.0.0", ManifestSHA256: "x"},
	}})
	declared := catalogRevision(Catalog{Items: []Item{
		{Category: "barstyles", ID: "demo", Version: "1.0.0", ManifestSHA256: "x",
			RequiredWindowManager: declaredManager},
	}})
	if anywhere == declared {
		t.Fatal("declaring a window manager must change the revision")
	}
	other := catalogRevision(Catalog{Items: []Item{
		{Category: "barstyles", ID: "demo", Version: "1.0.0", ManifestSHA256: "x",
			RequiredWindowManager: runningManager},
	}})
	if other == declared {
		t.Fatal("changing which window manager a product declares must change the revision")
	}
}

// A snapshot is only good for the desktop it was built on: its per-item
// availability answers are computed from the running window manager.
func TestSnapshotForeignWindowManager(t *testing.T) {
	stubWindowManager(t, runningManager)

	same := []byte(`{"windowManager":"` + runningManager + `","items":[]}`)
	if snapshotForeignWindowManager(same) {
		t.Error("a snapshot built here reads as foreign")
	}
	other := []byte(`{"windowManager":"` + declaredManager + `","items":[]}`)
	if !snapshotForeignWindowManager(other) {
		t.Error("a snapshot built under another window manager must be rebuilt")
	}
	if snapshotForeignWindowManager([]byte(`{"items":[]}`)) {
		t.Error("a snapshot with no recorded window manager must be served")
	}
	if snapshotForeignWindowManager([]byte(`not json`)) {
		t.Error("an unreadable snapshot must not be treated as foreign")
	}

	stubWindowManager(t, "")
	if snapshotForeignWindowManager(other) {
		t.Error("an undetectable window manager must not invalidate a snapshot")
	}
}
