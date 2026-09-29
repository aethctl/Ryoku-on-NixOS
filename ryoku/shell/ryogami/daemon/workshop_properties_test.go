package main

import "testing"

func TestMergePropertiesPrecedenceAndKinds(t *testing.T) {
	declared := map[string]interface{}{
		"tint":  map[string]interface{}{"type": "color", "value": "1 1 1", "text": "Tint", "order": float64(2)},
		"speed": map[string]interface{}{"type": "slider", "value": float64(5), "min": float64(0), "max": float64(10), "order": float64(1)},
		"flag":  map[string]interface{}{"value": true},
		"pick":  map[string]interface{}{"value": float64(1), "options": []interface{}{map[string]interface{}{"label": "A", "value": float64(0)}}},
	}
	overrides := map[string]interface{}{"tint": "0 0 0"}
	rows := mergeProperties(declared, overrides)
	if len(rows) != 4 {
		t.Fatalf("rows=%d", len(rows))
	}
	if rows[0].Name != "speed" {
		t.Fatalf("order sort: first=%s want speed", rows[0].Name)
	}
	byName := map[string]weProperty{}
	for _, r := range rows {
		byName[r.Name] = r
	}
	if s := byName["speed"]; s.Kind != weKindSlider || s.Min == nil || *s.Min != 0 || s.Max == nil || *s.Max != 10 {
		t.Fatalf("speed row wrong: %#v", s)
	}
	if tint := byName["tint"]; tint.Kind != weKindColor || tint.Value != "0 0 0" || !tint.Overridden || tint.Default != "1 1 1" {
		t.Fatalf("tint override wrong: %#v", tint)
	}
	if byName["flag"].Kind != weKindBool {
		t.Fatalf("flag kind=%s want bool", byName["flag"].Kind)
	}
	if byName["pick"].Kind != weKindCombo {
		t.Fatalf("pick kind=%s want combo", byName["pick"].Kind)
	}
}

func TestInferColorKind(t *testing.T) {
	entry := map[string]interface{}{"value": "0.5 0.2 0.1"}
	if got := resolveKind("", entry, entry["value"]); got != weKindColor {
		t.Fatalf("three-float string should infer color, got %s", got)
	}
	if got := resolveKind("mystery", entry, entry["value"]); got != weKindUnsupported {
		t.Fatalf("unknown declared type should be unsupported, got %s", got)
	}
}

func TestWePropStoreRoundTrip(t *testing.T) {
	d := &daemon{}
	d.cfg.Paths.Cache = t.TempDir()
	s := newWePropStore(d)

	s.setValue("100", "tint", "0 0 0")
	if got := s.overrides("100")["tint"]; got != "0 0 0" {
		t.Fatalf("override not persisted: %v", got)
	}
	if got := newWePropStore(d).overrides("100")["tint"]; got != "0 0 0" {
		t.Fatalf("override not durable: %v", got)
	}

	s.setFps("100", 120)
	if fps, ok := s.fpsOverride("100"); !ok || fps != 120 {
		t.Fatalf("fps override: %d %v", fps, ok)
	}

	s.resetValue("100", "tint")
	if _, ok := s.overrides("100")["tint"]; ok {
		t.Fatal("override not cleared")
	}
	if fps, ok := s.fpsOverride("100"); !ok || fps != 120 {
		t.Fatalf("fps lost after reset: %d %v", fps, ok)
	}
}
