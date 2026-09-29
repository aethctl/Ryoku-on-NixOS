package main

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestBuildWeApplyManifest(t *testing.T) {
	d := &daemon{}
	props := map[string]interface{}{"tint": "1 0 0"}
	policy := map[string]interface{}{"scene": map[string]interface{}{"fps": 60}}
	req := d.buildWeApply("/we/123", "fit", []string{"DP-1"}, map[string]bool{"DP-1": true}, map[string]int{"DP-1": 40}, props, policy)
	if len(req.Assignments) != 1 {
		t.Fatalf("assignments=%d", len(req.Assignments))
	}
	a := req.Assignments[0]
	if a.Source.Kind != "we" {
		t.Fatalf("kind=%q want we", a.Source.Kind)
	}
	if a.Source.Path != "/we/123" {
		t.Fatalf("path=%q", a.Source.Path)
	}
	if a.Layer != "background" {
		t.Fatalf("layer=%q want background", a.Layer)
	}
	if a.FillMode != "fit" {
		t.Fatalf("fill=%q", a.FillMode)
	}
	if !a.Mute || a.Volume != 40 {
		t.Fatalf("audio mute=%v vol=%d", a.Mute, a.Volume)
	}
	if a.Source.Properties["tint"] != "1 0 0" {
		t.Fatalf("properties not carried: %#v", a.Source.Properties)
	}
	if req.Policy == nil {
		t.Fatalf("policy not carried: %#v", req.Policy)
	}

	b, err := json.Marshal(req)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`"kind":"we"`, `"layer":"background"`, `"path":"/we/123"`, `"properties"`, `"fill_mode":"fit"`, `"policy"`, `"fps":60`} {
		if !strings.Contains(string(b), want) {
			t.Fatalf("manifest %s missing %q", b, want)
		}
	}
}

func TestBuildWeApplyBroadcast(t *testing.T) {
	d := &daemon{}
	req := d.buildWeApply("/we/9", "fill", nil, nil, nil, nil, nil)
	if len(req.Assignments) != 1 {
		t.Fatalf("assignments=%d", len(req.Assignments))
	}
	if got := req.Assignments[0].Outputs; len(got) != 1 || got[0] != "*" {
		t.Fatalf("broadcast outputs=%v want [*]", got)
	}
	if req.Policy != nil {
		t.Fatal("nil policy should be left unset")
	}
	if req.Assignments[0].Source.Properties != nil {
		t.Fatal("empty properties should be omitted")
	}
}

func TestStopTargets(t *testing.T) {
	if stopTargets(nil) != nil {
		t.Fatal("empty outputs should stop all (nil filter)")
	}
	if stopTargets([]string{"*"}) != nil {
		t.Fatal("wildcard should stop all (nil filter)")
	}
	got := stopTargets([]string{"DP-1", "DP-2"})
	if len(got) != 2 || got[0] != "DP-1" || got[1] != "DP-2" {
		t.Fatalf("named outputs=%v", got)
	}
}

func TestWeFillMode(t *testing.T) {
	if weFillMode("cover") != "fill" {
		t.Fatal("unknown fit should map to fill")
	}
	for _, m := range []string{"fill", "fit", "stretch", "center", "tile", "span"} {
		if weFillMode(m) != m {
			t.Fatalf("fit %q not passed through", m)
		}
	}
}
