package main

import (
	"image/color"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// buildGradeArgs is the wire contract between the daemon and magick: the exact
// operator sequence ryowalls' adjust_image emitted. Pin it operator by operator.
func TestBuildGradeArgs(t *testing.T) {
	cases := []struct {
		name string
		p    gradeParams
		want []string
	}{
		{
			name: "identity",
			p:    gradeParams{},
			want: []string{"in.png", "-modulate", "100,100,100", "out.png"},
		},
		{
			name: "preview size caps the long edge first",
			p:    gradeParams{size: 1100},
			want: []string{"in.png", "-resize", "1100x1100>", "-modulate", "100,100,100", "out.png"},
		},
		{
			name: "brightness and saturation ride the modulate",
			p:    gradeParams{brightness: 10, saturation: -20},
			want: []string{"in.png", "-modulate", "110,80,100", "out.png"},
		},
		{
			name: "contrast becomes 0x<c>, negative kept",
			p:    gradeParams{contrast: -22},
			want: []string{"in.png", "-modulate", "100,100,100", "-brightness-contrast", "0x-22", "out.png"},
		},
		{
			name: "warm reweights R up and B down",
			p:    gradeParams{warmth: 46},
			want: []string{
				"in.png",
				"-channel", "R", "-evaluate", "multiply", "1.0828", "+channel",
				"-channel", "B", "-evaluate", "multiply", "0.9172", "+channel",
				"-modulate", "100,100,100", "out.png",
			},
		},
		{
			name: "cool reweights R down and B up",
			p:    gradeParams{warmth: -44},
			want: []string{
				"in.png",
				"-channel", "R", "-evaluate", "multiply", "0.9208", "+channel",
				"-channel", "B", "-evaluate", "multiply", "1.0792", "+channel",
				"-modulate", "100,100,100", "out.png",
			},
		},
		{
			name: "vignette overlays last",
			p:    gradeParams{vignette: true},
			want: []string{"in.png", "-modulate", "100,100,100", "-background", "black", "-vignette", "0x18", "out.png"},
		},
		{
			name: "negate inverts after vignette",
			p:    gradeParams{vignette: true, negate: true},
			want: []string{"in.png", "-modulate", "100,100,100", "-background", "black", "-vignette", "0x18", "-negate", "out.png"},
		},
		{
			name: "full grade keeps operator order",
			p:    gradeParams{brightness: -4, contrast: 18, saturation: -8, warmth: 12, vignette: true, size: 1100},
			want: []string{
				"in.png", "-resize", "1100x1100>",
				"-channel", "R", "-evaluate", "multiply", "1.0216", "+channel",
				"-channel", "B", "-evaluate", "multiply", "0.9784", "+channel",
				"-modulate", "96,92,100",
				"-brightness-contrast", "0x18",
				"-background", "black", "-vignette", "0x18",
				"out.png",
			},
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := buildGradeArgs("in.png", "out.png", c.p)
			if !reflect.DeepEqual(got, c.want) {
				t.Fatalf("args mismatch\n got: %v\nwant: %v", got, c.want)
			}
		})
	}
}

// gradeParamsFrom reads the request map; JSON numbers arrive as float64.
func TestGradeParamsFrom(t *testing.T) {
	p := map[string]interface{}{
		"brightness": float64(12),
		"contrast":   float64(-7),
		"saturation": float64(30),
		"warmth":     float64(-40),
		"vignette":   true,
		"negate":     true,
	}
	got := gradeParamsFrom(p)
	want := gradeParams{brightness: 12, contrast: -7, saturation: 30, warmth: -40, vignette: true, negate: true}
	if got != want {
		t.Fatalf("gradeParamsFrom: got %+v, want %+v", got, want)
	}
	// size is never taken from the caller; it is set by preview/commit.
	if got.size != 0 {
		t.Fatalf("size should default to 0, got %d", got.size)
	}

	def := gradeParamsFrom(map[string]interface{}{})
	if (def != gradeParams{}) {
		t.Fatalf("empty params should be all-zero, got %+v", def)
	}
}

func TestEditedPath(t *testing.T) {
	out, err := editedPath("/pics/wall.jpg")
	if err != nil {
		t.Fatal(err)
	}
	if out != "/pics/wall.edit.jpg" {
		t.Fatalf("edited path: got %q", out)
	}
	// no-extension inputs default the extension to png (stemExt contract).
	out, err = editedPath("/pics/wall")
	if err != nil {
		t.Fatal(err)
	}
	if out != "/pics/wall.edit.png" {
		t.Fatalf("edited path (no ext): got %q", out)
	}
	if _, err := editedPath("/"); err == nil {
		t.Fatal("a stemless path should error")
	}
}

// End-to-end grade through the real magick binary: the preview lands in the
// cache dir under an alternating slot name, commit writes the .edit sibling, and
// the source is left untouched.
func TestGradePreviewAndCommit(t *testing.T) {
	if !haveMagick() {
		t.Skip("magick not installed")
	}
	cache := t.TempDir()
	dir := t.TempDir()
	src := filepath.Join(dir, "wall.png")
	writePNG(t, src, color.RGBA{120, 80, 200, 255})

	g := NewGrader(cache)
	p := gradeParams{brightness: 10, contrast: 8, saturation: 20, warmth: 12, vignette: true}

	prev1, err := g.Preview(src, p)
	if err != nil {
		t.Fatalf("preview: %v", err)
	}
	if filepath.Dir(prev1) != cache {
		t.Fatalf("preview should live in the cache dir, got %q", prev1)
	}
	if !strings.HasPrefix(filepath.Base(prev1), "grade-preview-") || !strings.HasSuffix(prev1, ".png") {
		t.Fatalf("unexpected preview name: %q", prev1)
	}
	if !fileNonEmpty(prev1) {
		t.Fatal("preview file is empty")
	}
	// The slot alternates so a fresh preview never clobbers the shown one.
	prev2, err := g.Preview(src, p)
	if err != nil {
		t.Fatalf("preview 2: %v", err)
	}
	if prev1 == prev2 {
		t.Fatalf("consecutive previews should double-buffer, both %q", prev1)
	}

	out, err := g.Commit(src, "", p)
	if err != nil {
		t.Fatalf("commit: %v", err)
	}
	if want := filepath.Join(dir, "wall.edit.png"); out != want {
		t.Fatalf("commit path: got %q, want %q", out, want)
	}
	if !fileNonEmpty(out) {
		t.Fatal("committed file is empty")
	}
	if !fileNonEmpty(src) {
		t.Fatal("commit must not remove the source")
	}

	// An explicit output path is honoured verbatim.
	explicit := filepath.Join(dir, "chosen.png")
	got, err := g.Commit(src, explicit, p)
	if err != nil {
		t.Fatalf("commit explicit: %v", err)
	}
	if got != explicit || !fileNonEmpty(explicit) {
		t.Fatalf("explicit commit path not honoured: got %q", got)
	}
}

func TestGradeMissingInput(t *testing.T) {
	g := NewGrader(t.TempDir())
	if _, err := g.Preview("", gradeParams{}); err == nil {
		t.Fatal("preview should reject empty input")
	}
	if _, err := g.Commit("", "", gradeParams{}); err == nil {
		t.Fatal("commit should reject empty input")
	}
}
