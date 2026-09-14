package main

import wm "ryoku-wm"

// How niri sized a window, read back from its tile geometry. niri 26.04 carries
// no maximized or fullscreen flag in the window JSON, so size against the output
// and the gaps is the only signal, and it is enough: each state has a distinct
// footprint.
//
//	layoutNormal          an ordinary tile, narrower than the working width
//	layoutColumnMaximized full working width but the gaps kept (maximize-column)
//	layoutClientMaximized full working area with the gaps ignored, edge to edge,
//	                      but not over the bar: what an app that opens itself
//	                      maximised lands in, and the one state worth correcting
//	layoutFullscreen      the whole output, bar included
type winLayout int

const (
	layoutNormal winLayout = iota
	layoutColumnMaximized
	layoutClientMaximized
	layoutFullscreen
)

// layoutEdgeTolerance absorbs the sub-pixel rounding niri's fractional tile
// sizes leave behind (a 1706-wide output reports a 1707 tile). It stays well
// under a gap, so it never blurs the full-width states into each other.
const layoutEdgeTolerance = 6

// classifyLayout places a window's tile against its output. The working width is
// the output minus the struts a bar or dock reserves on the sides; the working
// height is not needed, because the states are told apart by which edges the
// tile reaches:
//
//   - fills the full width but keeps a gap all round -> column-maximized
//   - fills the full width and drops the gaps (edge to edge) -> client-maximized
//   - reaches the bottom of the output too -> fullscreen
//
// The full-vs-gapped test is the midpoint between the two full-width footprints
// (workingWidth and workingWidth - 2*gaps), so it separates them cleanly for any
// gap without a tolerance that could overlap.
func classifyLayout(out wm.Output, gaps int, struts Struts, w, h int) winLayout {
	workingW := out.Width - struts.Left - struts.Right

	coversOutput := w >= out.Width-layoutEdgeTolerance && h >= out.Height-layoutEdgeTolerance
	fillsWidth := w >= workingW-gaps // above the workingW / (workingW-2*gaps) midpoint
	overBar := h >= out.Height-layoutEdgeTolerance

	switch {
	case coversOutput:
		return layoutFullscreen
	case fillsWidth && !overBar:
		return layoutClientMaximized
	case abs(w-(workingW-2*gaps)) <= layoutEdgeTolerance:
		return layoutColumnMaximized
	default:
		return layoutNormal
	}
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}
