package main

import (
	"encoding/json"
	"testing"

	wm "ryoku-wm"
)

func swappedLayout() ([]wm.OutputLayout, []wm.Output) {
	layout := []wm.OutputLayout{
		{
			Name:          "DP-1",
			Enabled:       true,
			Make:          "Microstep",
			Model:         "MSI MP251",
			PhysicalWidth: 540,
			Mode:          "1920x1080@60",
			X:             -1920,
		},
		{
			Name:          "DP-2",
			Enabled:       true,
			Make:          "Shenzhen KTC Technology Group",
			Model:         "H27T22C-3",
			PhysicalWidth: 600,
			Mode:          "2560x1440@200",
			X:             0,
		},
	}

	live := []wm.Output{
		{
			Name:          "DP-2",
			Make:          "Microstep",
			Model:         "MSI MP251",
			PhysicalWidth: 540,
		},
		{
			Name:          "DP-1",
			Make:          "Shenzhen KTC Technology Group",
			Model:         "H27T22C-3",
			PhysicalWidth: 600,
		},
	}

	return layout, live
}

func TestResolveLayoutOutputsFollowsPhysicalMonitor(t *testing.T) {
	layout, live := swappedLayout()

	got, err := resolveLayoutOutputs(layout, live)
	if err != nil {
		t.Fatalf("resolve layout: %v", err)
	}

	if got[0].Name != "DP-2" {
		t.Fatalf("MSI resolved to %q, want DP-2", got[0].Name)
	}
	if got[0].Mode != "1920x1080@60" || got[0].X != -1920 {
		t.Fatalf("MSI settings moved: %#v", got[0])
	}
	if got[1].Name != "DP-1" {
		t.Fatalf("KTC resolved to %q, want DP-1", got[1].Name)
	}
	if got[1].Mode != "2560x1440@200" || got[1].X != 0 {
		t.Fatalf("KTC settings moved: %#v", got[1])
	}
}

func TestResolveLayoutOutputsStableWhenConnectorsDoNotChange(t *testing.T) {
	layout, _ := swappedLayout()

	live := []wm.Output{
		{
			Name:          "DP-1",
			Make:          "Microstep",
			Model:         "MSI MP251",
			PhysicalWidth: 540,
		},
		{
			Name:          "DP-2",
			Make:          "Shenzhen KTC Technology Group",
			Model:         "H27T22C-3",
			PhysicalWidth: 600,
		},
	}

	got, err := resolveLayoutOutputs(layout, live)
	if err != nil {
		t.Fatalf("resolve layout: %v", err)
	}

	if got[0].Name != "DP-1" || got[1].Name != "DP-2" {
		t.Fatalf("stable connectors changed: %#v", got)
	}
}

func TestResolveLayoutOutputsIgnoresLiveOrdering(t *testing.T) {
	layout, live := swappedLayout()
	live[0], live[1] = live[1], live[0]

	got, err := resolveLayoutOutputs(layout, live)
	if err != nil {
		t.Fatalf("resolve layout: %v", err)
	}

	if got[0].Name != "DP-2" || got[1].Name != "DP-1" {
		t.Fatalf("ordering changed resolution: %#v", got)
	}
}

func TestResolveLayoutOutputsRemapsMirrorTarget(t *testing.T) {
	layout, live := swappedLayout()
	layout[1].Mirror = "DP-1"

	got, err := resolveLayoutOutputs(layout, live)
	if err != nil {
		t.Fatalf("resolve layout: %v", err)
	}

	if got[1].Name != "DP-1" {
		t.Fatalf("KTC resolved to %q, want DP-1", got[1].Name)
	}
	if got[1].Mirror != "DP-2" {
		t.Fatalf("mirror resolved to %q, want DP-2", got[1].Mirror)
	}
}

func TestResolveOutputNameKeepsLegacyNameWithoutIdentity(t *testing.T) {
	got, err := resolveOutputName(
		wm.OutputLayout{Name: "DP-9", Enabled: true},
		[]wm.Output{{Name: "DP-1", Make: "Acme", Model: "Panel"}},
	)
	if err != nil {
		t.Fatalf("resolve legacy output: %v", err)
	}

	if got != "DP-9" {
		t.Fatalf("legacy layout resolved to %q, want DP-9", got)
	}
}

func TestResolveOutputNameRejectsAmbiguousIdentity(t *testing.T) {
	spec := wm.OutputLayout{
		Name:          "DP-7",
		Enabled:       true,
		Make:          "Acme",
		Model:         "Twin",
		PhysicalWidth: 600,
	}

	live := []wm.Output{
		{Name: "DP-1", Make: "Acme", Model: "Twin", PhysicalWidth: 600},
		{Name: "DP-2", Make: "Acme", Model: "Twin", PhysicalWidth: 600},
	}

	if _, err := resolveOutputName(spec, live); err == nil {
		t.Fatal("ambiguous physical identity should be rejected")
	}
}

func TestResolveOutputNameRejectsMissingPhysicalMonitor(t *testing.T) {
	spec := wm.OutputLayout{
		Name:          "DP-1",
		Enabled:       true,
		Make:          "Shenzhen KTC Technology Group",
		Model:         "H27T22C-3",
		PhysicalWidth: 600,
	}

	live := []wm.Output{
		{
			Name:          "DP-1",
			Make:          "Microstep",
			Model:         "MSI MP251",
			PhysicalWidth: 540,
		},
	}

	if _, err := resolveOutputName(spec, live); err == nil {
		t.Fatal("missing physical monitor should not fall back to old connector")
	}
}

func TestResolveLayoutOutputsRejectsDuplicateLiveTarget(t *testing.T) {
	layout := []wm.OutputLayout{
		{Name: "DP-old-1", Make: "Acme", Model: "Panel", PhysicalWidth: 600},
		{Name: "DP-old-2", Make: "Acme", Model: "Panel", PhysicalWidth: 600},
	}
	live := []wm.Output{
		{Name: "DP-1", Make: "Acme", Model: "Panel", PhysicalWidth: 600},
	}

	if _, err := resolveLayoutOutputs(layout, live); err == nil {
		t.Fatal("two saved outputs must not claim the same live output")
	}
}

func TestResolveLayoutOutputsRejectsMirrorSelfReferenceAfterRemap(t *testing.T) {
	layout := []wm.OutputLayout{
		{
			Name:          "DP-old",
			Make:          "Acme",
			Model:         "Panel",
			PhysicalWidth: 600,
			Mirror:        "DP-old",
		},
	}
	live := []wm.Output{
		{Name: "DP-new", Make: "Acme", Model: "Panel", PhysicalWidth: 600},
	}

	if _, err := resolveLayoutOutputs(layout, live); err == nil {
		t.Fatal("mirror self-reference should be rejected")
	}
}

func TestProfileMatchesAcrossConnectorRename(t *testing.T) {
	layout, live := swappedLayout()

	if !profileMatches(layout, live) {
		t.Fatal("physical monitors should match after connector-name swap")
	}
}

func TestProfileDoesNotMatchAmbiguousIdentity(t *testing.T) {
	layout := []wm.OutputLayout{
		{
			Name:          "DP-old",
			Make:          "Acme",
			Model:         "Twin",
			PhysicalWidth: 600,
		},
	}
	live := []wm.Output{
		{Name: "DP-1", Make: "Acme", Model: "Twin", PhysicalWidth: 600},
		{Name: "DP-2", Make: "Acme", Model: "Twin", PhysicalWidth: 600},
	}

	if profileMatches(layout, live) {
		t.Fatal("ambiguous identity must not mark profile as matching")
	}
}

func TestLegacyProfileStillMatchesByName(t *testing.T) {
	layout := []wm.OutputLayout{
		{Name: "DP-1", Enabled: true},
	}
	live := []wm.Output{
		{Name: "DP-1", Make: "Acme", Model: "Panel"},
	}

	if !profileMatches(layout, live) {
		t.Fatal("legacy name-only profile should still match")
	}
}

func TestOutputIdentitySurvivesJSONRoundTrip(t *testing.T) {
	want := []wm.OutputLayout{
		{
			Name:          "DP-2",
			Enabled:       true,
			Make:          "Shenzhen KTC Technology Group",
			Model:         "H27T22C-3",
			PhysicalWidth: 600,
			Mode:          "2560x1440@200",
			X:             0,
			Y:             0,
			Scale:         1,
		},
	}

	raw, err := json.Marshal(want)
	if err != nil {
		t.Fatalf("marshal layout: %v", err)
	}

	got, err := parseLayout(string(raw))
	if err != nil {
		t.Fatalf("parse layout: %v", err)
	}

	if len(got) != 1 {
		t.Fatalf("got %d outputs, want 1", len(got))
	}

	if got[0].Make != want[0].Make {
		t.Fatalf("make = %q, want %q", got[0].Make, want[0].Make)
	}
	if got[0].Model != want[0].Model {
		t.Fatalf("model = %q, want %q", got[0].Model, want[0].Model)
	}
	if got[0].PhysicalWidth != want[0].PhysicalWidth {
		t.Fatalf(
			"physicalWidth = %d, want %d",
			got[0].PhysicalWidth,
			want[0].PhysicalWidth,
		)
	}
}
