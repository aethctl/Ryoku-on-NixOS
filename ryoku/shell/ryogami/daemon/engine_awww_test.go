package main

import (
	"strings"
	"testing"
)

func TestAwwwArgs(t *testing.T) {
	cases := []struct {
		name string
		opts awwwOptions
		want string
	}{
		{
			"full block, milliseconds to seconds",
			awwwOptions{Type: "wipe", DurationMs: 1000, Fps: 60, Step: 90, Angle: 45, Filter: "Lanczos3"},
			"--transition-type wipe --transition-duration 1 --transition-fps 60 --transition-step 90 --transition-angle 45 --filter Lanczos3",
		},
		{
			"fractional duration keeps precision",
			awwwOptions{DurationMs: 1500, Angle: 30},
			"--transition-duration 1.5 --transition-angle 30",
		},
		{
			"wave collapses width and height into one flag",
			awwwOptions{Type: "wave", WaveWidth: 20, WaveHeight: 10, Angle: 0},
			"--transition-type wave --transition-angle 0 --transition-wave 20,10",
		},
		{
			"invert-y is a bare flag, pos and bezier are values",
			awwwOptions{Angle: 45, Pos: "top-left", Bezier: "0.1,0.2,0.3,0.4", InvertY: true},
			"--transition-angle 45 --transition-pos top-left --transition-bezier 0.1,0.2,0.3,0.4 --invert-y",
		},
		{
			"angle always emitted even at zero, zero step and fps omitted",
			awwwOptions{Angle: 0, Step: 0, Fps: 0},
			"--transition-angle 0",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := strings.Join(awwwArgs(c.opts), " ")
			if got != c.want {
				t.Fatalf("awwwArgs\n got: %s\nwant: %s", got, c.want)
			}
		})
	}
}
