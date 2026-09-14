package main

import (
	"testing"

	wm "ryoku-wm"
)

// classifyLayout is the whole basis of the open-maximise correction, and a niri
// upgrade that shifts tile geometry by a pixel is exactly what would rot it, so
// every state is pinned at two gap values and two output sizes. The eDP-2 rows
// are the sizes niri actually reported on the live session (gaps 16 and 24); the
// 2560x1440 rows are the same relationships on a second output, and two rows
// carry side struts to show the working width, not the raw output, is the ruler.
func TestClassifyLayout(t *testing.T) {
	edp := wm.Output{Name: "eDP-2", Width: 1706, Height: 1066}
	qhd := wm.Output{Name: "DP-1", Width: 2560, Height: 1440}
	none := Struts{}
	sides := Struts{Left: 100, Right: 100}

	cases := []struct {
		name   string
		out    wm.Output
		gaps   int
		struts Struts
		w, h   int
		want   winLayout
	}{
		// eDP-2, gaps 16, measured live.
		{"edp16 normal", edp, 16, none, 829, 945, layoutNormal},
		{"edp16 column-maximized", edp, 16, none, 1675, 945, layoutColumnMaximized},
		{"edp16 client-maximized", edp, 16, none, 1707, 977, layoutClientMaximized},
		{"edp16 fullscreen", edp, 16, none, 1707, 1067, layoutFullscreen},

		// eDP-2, gaps 24, measured live: the gap widens, the client-maximized and
		// fullscreen footprints do not (they ignore gaps).
		{"edp24 normal", edp, 24, none, 817, 929, layoutNormal},
		{"edp24 column-maximized", edp, 24, none, 1659, 929, layoutColumnMaximized},
		{"edp24 client-maximized", edp, 24, none, 1707, 977, layoutClientMaximized},
		{"edp24 fullscreen", edp, 24, none, 1707, 1067, layoutFullscreen},

		// A second output size, same relationships (working height 1400).
		{"qhd16 normal", qhd, 16, none, 1256, 1368, layoutNormal},
		{"qhd16 column-maximized", qhd, 16, none, 2528, 1368, layoutColumnMaximized},
		{"qhd16 client-maximized", qhd, 16, none, 2560, 1400, layoutClientMaximized},
		{"qhd16 fullscreen", qhd, 16, none, 2560, 1440, layoutFullscreen},
		{"qhd24 normal", qhd, 24, none, 1244, 1352, layoutNormal},
		{"qhd24 column-maximized", qhd, 24, none, 2512, 1352, layoutColumnMaximized},
		{"qhd24 client-maximized", qhd, 24, none, 2560, 1400, layoutClientMaximized},
		{"qhd24 fullscreen", qhd, 24, none, 2560, 1440, layoutFullscreen},

		// Side struts move the working width: a 1474-wide tile is a full column
		// only once 200px of struts are taken off the output, and a tile that
		// fills that narrower working width is a client-maximized one.
		{"struts column-maximized", edp, 16, sides, 1474, 945, layoutColumnMaximized},
		{"struts client-maximized", edp, 16, sides, 1506, 977, layoutClientMaximized},
	}

	for _, c := range cases {
		if got := classifyLayout(c.out, c.gaps, c.struts, c.w, c.h); got != c.want {
			t.Errorf("%s: classifyLayout(%dx%d, gaps %d, %+v, %dx%d) = %d, want %d",
				c.name, c.out.Width, c.out.Height, c.gaps, c.struts, c.w, c.h, got, c.want)
		}
	}
}
