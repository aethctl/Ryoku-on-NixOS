package main

import (
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func effectsTestImage(w, h int) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		for x := range w {
			img.Set(x, y, color.RGBA{uint8(x * 9), uint8(y * 11), uint8((x + y) * 5), 255})
		}
	}
	return img
}

func writeTestPNG(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(f, effectsTestImage(24, 18)); err != nil {
		f.Close()
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
}

func decodePNG(t *testing.T, path string) *image.RGBA {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	img, err := png.Decode(f)
	if err != nil {
		t.Fatal(err)
	}
	return toRGBA(img)
}

// The picker reads id/label/description/params off each list item and id/label/
// type off each param, so every entry must carry those.
func TestEffectsListShape(t *testing.T) {
	list := EffectsList()
	if len(list) < 10 {
		t.Fatalf("expected at least 10 effects, got %d", len(list))
	}
	ids := map[string]bool{}
	for _, e := range list {
		id, _ := e["id"].(string)
		if id == "" {
			t.Fatalf("effect missing id: %v", e)
		}
		ids[id] = true
		if _, ok := e["label"].(string); !ok {
			t.Errorf("effect %s missing label", id)
		}
		if _, ok := e["description"].(string); !ok {
			t.Errorf("effect %s missing description", id)
		}
		if cat, _ := e["category"].(string); cat == "" {
			t.Errorf("effect %s missing category", id)
		}
		params, ok := e["params"].([]map[string]interface{})
		if !ok {
			t.Fatalf("effect %s params not an array", id)
		}
		for _, p := range params {
			if _, ok := p["id"].(string); !ok {
				t.Errorf("param missing id in %s", id)
			}
			if _, ok := p["label"].(string); !ok {
				t.Errorf("param missing label in %s", id)
			}
			if _, ok := p["type"].(string); !ok {
				t.Errorf("param missing type in %s", id)
			}
		}
	}
	for _, want := range []string{"theme", "invert", "grayscale", "brightness", "contrast", "saturation"} {
		if !ids[want] {
			t.Errorf("missing expected effect %q", want)
		}
	}
	for _, e := range EffectsList() {
		if e["id"] == "theme" && e["category"] != "Colour" {
			t.Errorf("theme category = %v, want Colour", e["category"])
		}
	}
}

func TestEffectsToneOpsChangePixels(t *testing.T) {
	cases := []struct {
		effect string
		params map[string]interface{}
	}{
		{"invert", nil},
		{"grayscale", nil},
		{"brightness", map[string]interface{}{"factor": 1.5}},
		{"contrast", map[string]interface{}{"mode": "normal", "factor": 60.0}},
		{"saturation", map[string]interface{}{"percentage": float64(-100)}},
		{"gamma", map[string]interface{}{"gamma": 2.2}},
	}
	for _, c := range cases {
		src := effectsTestImage(24, 18)
		before := append([]uint8(nil), src.Pix...)
		out, err := renderEffect(c.effect, src, c.params)
		if err != nil {
			t.Fatalf("%s: %v", c.effect, err)
		}
		if len(out.Pix) != len(before) {
			t.Fatalf("%s changed pixel count", c.effect)
		}
		changed := false
		for i := range before {
			if out.Pix[i] != before[i] {
				changed = true
				break
			}
		}
		if !changed {
			t.Errorf("%s did not change any pixels", c.effect)
		}
	}
}

// nearestPaletteDist returns the squared distance from (r,g,b) to the closest
// colour in the palette; theming should pull pixels toward the palette.
func nearestPaletteDist(pal [][3]uint8, r, g, b uint8) int {
	best := 1 << 30
	for _, c := range pal {
		dr := int(r) - int(c[0])
		dg := int(g) - int(c[1])
		db := int(b) - int(c[2])
		d := dr*dr + dg*dg + db*db
		if d < best {
			best = d
		}
	}
	return best
}

func TestEffectsThemeRecolorsTowardPalette(t *testing.T) {
	pal, ok := themeLookup("Nord")
	if !ok {
		t.Fatal("Nord palette missing")
	}
	// A saturated colour unlikely to sit on the Nord palette.
	src := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for i := 0; i < len(src.Pix); i += 4 {
		src.Pix[i], src.Pix[i+1], src.Pix[i+2], src.Pix[i+3] = 200, 20, 180, 255
	}
	beforeDist := nearestPaletteDist(pal, 200, 20, 180)
	out, err := applyTheme(src, map[string]interface{}{"theme": "Nord"})
	if err != nil {
		t.Fatal(err)
	}
	r, g, b := out.Pix[0], out.Pix[1], out.Pix[2]
	if r == 200 && g == 20 && b == 180 {
		t.Fatal("theme did not recolor the pixel")
	}
	afterDist := nearestPaletteDist(pal, r, g, b)
	if afterDist >= beforeDist {
		t.Errorf("theme did not move pixel toward palette: before=%d after=%d", beforeDist, afterDist)
	}
}

func TestEffectsPreviewCommitDiscard(t *testing.T) {
	tmp := t.TempDir()
	cache := filepath.Join(tmp, "cache")
	input := filepath.Join(tmp, "wall", "pic.png")
	writeTestPNG(t, input)

	preview, err := EffectsPreview(cache, input, "invert", nil)
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	wantDir := filepath.Join(cache, "effects-preview")
	if filepath.Dir(preview) != wantDir {
		t.Errorf("preview dir = %s, want %s", filepath.Dir(preview), wantDir)
	}
	if !strings.HasSuffix(preview, "-pic-invert.png") {
		t.Errorf("preview name = %s, want *-pic-invert.png", filepath.Base(preview))
	}
	if _, err := os.Stat(preview); err != nil {
		t.Fatalf("preview file missing: %v", err)
	}

	// Inverting an inverted image should restore the source pixels.
	orig := decodePNG(t, input)
	prev := decodePNG(t, preview)
	if prev.Pix[0] != 255-orig.Pix[0] {
		t.Errorf("preview not inverted: got %d, want %d", prev.Pix[0], 255-orig.Pix[0])
	}

	final, err := EffectsCommit(preview, input, "invert", nil)
	if err != nil {
		t.Fatalf("commit: %v", err)
	}
	wantFinal := filepath.Join(tmp, "wall", "effects", "pic-invert.png")
	if final != wantFinal {
		t.Errorf("commit path = %s, want %s", final, wantFinal)
	}
	if _, err := os.Stat(final); err != nil {
		t.Fatalf("committed file missing: %v", err)
	}
	if _, err := os.Stat(preview); !os.IsNotExist(err) {
		t.Errorf("preview should be gone after commit, stat err = %v", err)
	}

	discardTarget, err := EffectsPreview(cache, input, "grayscale", nil)
	if err != nil {
		t.Fatalf("preview for discard: %v", err)
	}
	if err := EffectsDiscard(discardTarget); err != nil {
		t.Fatalf("discard: %v", err)
	}
	if _, err := os.Stat(discardTarget); !os.IsNotExist(err) {
		t.Errorf("discard should remove preview, stat err = %v", err)
	}
	if err := EffectsDiscard(discardTarget); err != nil {
		t.Errorf("discard of missing file should be a no-op, got %v", err)
	}
}

func TestEffectsSuffixAndPaths(t *testing.T) {
	if got := effectSuffix("theme", map[string]interface{}{"theme": "Tokyo Moon"}); got != "theme-tokyo-moon" {
		t.Errorf("theme suffix = %q", got)
	}
	if got := effectSuffix("theme", nil); got != "theme-catppuccin" {
		t.Errorf("default theme suffix = %q", got)
	}
	if got := effectSuffix("invert", nil); got != "invert" {
		t.Errorf("invert suffix = %q", got)
	}
	if _, err := libraryPath("/", "x"); err == nil {
		t.Error("libraryPath(\"/\") should error")
	}
	if _, err := previewPath("/c", "/", "x"); err == nil {
		t.Error("previewPath with rootless input should error")
	}
	p, err := libraryPath("/wall/pic.png", "invert")
	if err != nil {
		t.Fatal(err)
	}
	if p != "/wall/effects/pic-invert.png" {
		t.Errorf("libraryPath = %s", p)
	}
}
