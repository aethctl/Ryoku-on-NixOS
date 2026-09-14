package doctor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// widthCycleHome writes a desktop.json whose niri section holds the given raw
// JSON value for the width cycle, and points XDG at it.
func widthCycleHome(t *testing.T, value string) string {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	dir := filepath.Join(home, ".config", "ryoku")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	store := filepath.Join(dir, "desktop.json")
	body := `{"desktop":{"appearance":{"gapsIn":16}},"wm":{"niri":{"presetColumnWidths":` + value + `,"overviewZoom":0.5}}}`
	if err := os.WriteFile(store, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return store
}

// The bug this pins: a cycle of one width applies cleanly and leaves the key
// that steps through it with nowhere to go.
func TestWidthCycleReplacesASingleWidth(t *testing.T) {
	store := widthCycleHome(t, `"0.5"`)

	if r := reconcileWidthCycle(true); r.status != recWouldFix {
		t.Fatalf("--check state = %v, want a finding", r.status)
	} else if !strings.Contains(r.detail, "0.5") {
		t.Errorf("the finding must name the stored value, got %q", r.detail)
	}

	if r := reconcileWidthCycle(false); r.status != recFixed {
		t.Fatalf("repair state = %v, want fixed", r.status)
	}
	body, _ := os.ReadFile(store)
	if !strings.Contains(string(body), widthCycleDefault) {
		t.Fatalf("store still lacks a real cycle: %s", body)
	}
	// Every other setting survives the rewrite.
	for _, keep := range []string{"gapsIn", "overviewZoom"} {
		if !strings.Contains(string(body), keep) {
			t.Errorf("rewrite dropped %q: %s", keep, body)
		}
	}
	if r := reconcileWidthCycle(true); r.status != recOK {
		t.Errorf("a repaired store must read clean, got %v: %s", r.status, r.detail)
	}
}

func TestWidthCycleLeavesARealCycleAlone(t *testing.T) {
	store := widthCycleHome(t, `"0.25, 0.5, 0.75"`)
	if r := reconcileWidthCycle(false); r.status != recOK {
		t.Fatalf("state = %v, want ok: %s", r.status, r.detail)
	}
	body, _ := os.ReadFile(store)
	if !strings.Contains(string(body), "0.25, 0.5, 0.75") {
		t.Errorf("a usable cycle must be left as the user set it: %s", body)
	}
}

// An older store may hold the widths as an array rather than the Hub's string.
func TestWidthCycleReadsAnArrayValue(t *testing.T) {
	widthCycleHome(t, `[0.5]`)
	if r := reconcileWidthCycle(true); r.status != recWouldFix {
		t.Fatalf("a one-element array is the same dead cycle, got %v: %s", r.status, r.detail)
	}
	widthCycleHome(t, `[0.33333,0.66667]`)
	if r := reconcileWidthCycle(true); r.status != recOK {
		t.Errorf("a two-element array is a real cycle, got %v: %s", r.status, r.detail)
	}
}

// A trailing comma is not a second width.
func TestWidthCycleIgnoresEmptySlots(t *testing.T) {
	widthCycleHome(t, `"0.5, "`)
	if r := reconcileWidthCycle(true); r.status != recWouldFix {
		t.Errorf("state = %v, want a finding: %s", r.status, r.detail)
	}
}

func TestWidthCycleSilentWithoutTheSetting(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	dir := filepath.Join(home, ".config", "ryoku")
	os.MkdirAll(dir, 0o755)
	os.WriteFile(filepath.Join(dir, "desktop.json"), []byte(`{"wm":{"niri":{}}}`), 0o644)
	if r := reconcileWidthCycle(true); r.status != recOK {
		t.Errorf("state = %v, want ok when nothing is stored: %s", r.status, r.detail)
	}
}
