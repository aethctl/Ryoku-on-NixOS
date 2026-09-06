package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Grader ports ryowalls' `adjust` verb (bin/ryowalls adjust_image) into the
// daemon: an imagemagick colour grade (brightness / contrast / saturation /
// warmth, optional vignette and negate). The same magick pipeline drives the fast preview
// (long edge capped) and the full-resolution commit, so the specimen editor's
// preview is exactly what commit writes -- the guarantee the ryowalls GradeSheet
// relied on. Images only; ryowalls never graded video.
type Grader struct {
	cacheDir string

	mu  sync.Mutex
	rev int64
}

// gradeParams is one grade request. The int axes match the GradeSheet slider
// ranges (brightness/contrast -50..50, saturation/warmth -100..100); size caps
// the long edge for a fast preview render (0 = full resolution, used on commit).
type gradeParams struct {
	brightness int
	contrast   int
	saturation int
	warmth     int
	vignette   bool
	negate     bool
	size       int
}

// gradePreviewSize is the long-edge cap ryowalls used for the live grade preview
// (GradeSheet passes `--size 1100`): big enough to judge the grade, small enough
// to render on every debounced slider tick.
const gradePreviewSize = 1100

// gradeCmdTimeout bounds the magick child so a wedged decode never hangs the RPC.
const gradeCmdTimeout = 120 * time.Second

// NewGrader wires the cache dir the preview files live under.
func NewGrader(cacheDir string) *Grader {
	return &Grader{cacheDir: cacheDir}
}

// gradeParamsFrom reads a grade request off the JSON params map. It mirrors the
// GradeSheet flags: brightness/contrast/saturation/warmth ints and a vignette
// bool. size is set by the Grader, never by the caller.
func gradeParamsFrom(p map[string]interface{}) gradeParams {
	return gradeParams{
		brightness: int(intParam(p, "brightness", 0)),
		contrast:   int(intParam(p, "contrast", 0)),
		saturation: int(intParam(p, "saturation", 0)),
		warmth:     int(intParam(p, "warmth", 0)),
		vignette:   boolParam(p, "vignette", false),
		negate:     boolParam(p, "negate", false),
	}
}

// Preview renders a size-capped graded PNG into the cache dir and returns its
// path. The filename alternates between two slots (grade-preview-0/1.png) so a
// fresh preview never clobbers the one the UI is still showing and the path
// always changes between calls (Qt's Image cache reloads only on a new URL) --
// the double-buffer ryowalls used for its adjust slots. The caller debounces.
func (g *Grader) Preview(input string, p gradeParams) (string, error) {
	if input == "" {
		return "", errors.New("missing 'input' parameter")
	}
	p.size = gradePreviewSize

	g.mu.Lock()
	g.rev++
	slot := g.rev % 2
	g.mu.Unlock()

	output := filepath.Join(g.cacheDir, fmt.Sprintf("grade-preview-%d.png", slot))
	if err := runGrade(input, output, p); err != nil {
		return "", fmt.Errorf("grade preview failed: %w", err)
	}
	return output, nil
}

// Commit bakes the grade at full resolution. With no explicit output it writes a
// sibling `<stem>.edit.<ext>` beside the input (ryowalls' _editedPath), leaving
// the original untouched, and returns the written path.
func (g *Grader) Commit(input, output string, p gradeParams) (string, error) {
	if input == "" {
		return "", errors.New("missing 'input' parameter")
	}
	p.size = 0
	if output == "" {
		var err error
		output, err = editedPath(input)
		if err != nil {
			return "", err
		}
	}
	if err := runGrade(input, output, p); err != nil {
		return "", fmt.Errorf("grade commit failed: %w", err)
	}
	return output, nil
}

// editedPath is ryowalls' _editedPath: a sibling with an `.edit` infix before
// the extension, so a baked grade never overwrites the source wallpaper.
func editedPath(input string) (string, error) {
	stem, ext, err := stemExt(input)
	if err != nil {
		return "", err
	}
	return filepath.Join(filepath.Dir(input), stem+".edit."+ext), nil
}

// runGrade builds and runs the magick grade command.
func runGrade(input, output string, p gradeParams) error {
	if parent := filepath.Dir(output); parent != "" {
		if err := os.MkdirAll(parent, 0o755); err != nil {
			return err
		}
	}
	return runCmd(context.Background(), gradeCmdTimeout, "magick", buildGradeArgs(input, output, p)...)
}

// buildGradeArgs assembles the magick argument list, a faithful port of
// ryowalls' adjust_image pipeline:
//
//	magick <in> [-resize SIZExSIZE>]
//	  [-channel R -evaluate multiply <rmul> +channel
//	   -channel B -evaluate multiply <bmul> +channel]   (warmth != 0)
//	  -modulate <100+brightness>,<100+saturation>,100
//	  [-brightness-contrast 0x<contrast>]               (contrast != 0)
//	  [-background black -vignette 0x18]                 (vignette)
//	  [-negate]                                          (negate)
//	  <out>
//
// warmth reweights the red/blue channels (warm = redder, cool = bluer) by the
// same 0.0018-per-step factor ryowalls used.
func buildGradeArgs(input, output string, p gradeParams) []string {
	args := []string{input}
	if p.size > 0 {
		args = append(args, "-resize", fmt.Sprintf("%dx%d>", p.size, p.size))
	}
	if p.warmth != 0 {
		rmul := fmt.Sprintf("%.4f", 1+float64(p.warmth)*0.0018)
		bmul := fmt.Sprintf("%.4f", 1-float64(p.warmth)*0.0018)
		args = append(args,
			"-channel", "R", "-evaluate", "multiply", rmul, "+channel",
			"-channel", "B", "-evaluate", "multiply", bmul, "+channel")
	}
	args = append(args, "-modulate", fmt.Sprintf("%d,%d,100", 100+p.brightness, 100+p.saturation))
	if p.contrast != 0 {
		args = append(args, "-brightness-contrast", fmt.Sprintf("0x%d", p.contrast))
	}
	if p.vignette {
		args = append(args, "-background", "black", "-vignette", "0x18")
	}
	if p.negate {
		args = append(args, "-negate")
	}
	return append(args, output)
}
