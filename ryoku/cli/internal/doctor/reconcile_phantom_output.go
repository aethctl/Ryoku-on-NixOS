package doctor

import (
	"strings"

	i18n "ryoku-i18n"
	wm "ryoku-wm"
)

// ---- reconciler: phantom Wayland output --------------------------------------
//
// Ryoku's monitors.lua ends in a catch-all monitor rule so a freshly plugged
// display comes up without a hand-written rule. The cost is the compositor
// enables EVERY connector it reports as connected, and on some machines that
// includes a connector with no display on it: a port routed through the discrete
// GPU on a hybrid laptop, a KVM or dock that keeps a dead EDID line alive, or a
// driver that lights a ghost after a MUX/kernel change. It comes up as a blank
// second desktop windows open onto and get lost.
//
// The tell of a ghost is an ENABLED, non-internal output whose EDID is empty (no
// make AND no model) AND whose physical size is zero. To stay conservative the
// check also requires a genuinely real display to be present, so a single-output
// machine whose only panel has a broken EDID is left alone.
//
// Report-only: disabling an output could black out a real-but-EDID-less monitor,
// so doctor only names the ghost and the one-line rule that pins it off.

// gatherMonitors reads the live output list through the provider. A var so a test
// drives every branch through the one seam; any failure (no session, no provider)
// yields nil, which planPhantomOutput reads as "nothing to flag".
var gatherMonitors = func() []wm.Output {
	snap, err := wm.Open().State()
	if err != nil {
		return nil
	}
	return snap.Outputs
}

// isInternalPanel reports whether a connector name is a built-in laptop panel
// (eDP/LVDS/DSI); those are always real, never phantoms.
func isInternalPanel(name string) bool {
	for _, p := range []string{"eDP-", "LVDS-", "DSI-"} {
		if strings.HasPrefix(name, p) {
			return true
		}
	}
	return false
}

// looksPhantom reports whether an enabled output is almost certainly a ghost:
// non-internal, no EDID (empty make and model), and zero physical size.
func looksPhantom(m wm.Output) bool {
	return !m.Disabled &&
		!isInternalPanel(m.Name) &&
		strings.TrimSpace(m.Make) == "" &&
		strings.TrimSpace(m.Model) == "" &&
		m.PhysicalWidth <= 0
}

// planPhantomOutput turns the output list into a result. pure.
func planPhantomOutput(mons []wm.Output) recResult {
	var ghosts []string
	realEnabled := 0
	for _, m := range mons {
		if m.Disabled {
			continue
		}
		if looksPhantom(m) {
			ghosts = append(ghosts, m.Name)
		} else {
			realEnabled++
		}
	}
	if len(ghosts) == 0 {
		return okRes(i18n.T("no phantom outputs; every enabled display reports a real EDID"))
	}
	// A machine whose only enabled output is EDID-less is running on that panel:
	// its real, if quirky, screen, not a phantom.
	if realEnabled == 0 {
		return okRes(i18n.T("the sole enabled output has no EDID; treating it as a real display, not a phantom"))
	}
	names := strings.Join(ghosts, ", ")
	line := "hl.monitor({ output = \"" + ghosts[0] + "\", disabled = true })"
	return warnRes(i18n.T("a phantom Wayland output is enabled with no display on it: %s (no EDID, zero physical size). Windows can open onto this blank second desktop and get lost; it is usually a dual-GPU, KVM, or dock connector the compositor lit through the catch-all monitor rule"), names).
		withFix(i18n.T("turn it off in ~/.config/hypr/monitors_user.lua (one line per output): %s. If it is really a display with a broken EDID, force its mode there instead"), line)
}

func reconcilePhantomOutput(_ bool) recResult {
	if !wm.Detect().Live {
		return okRes(i18n.T("no live session; phantom outputs cannot be checked"))
	}
	return planPhantomOutput(gatherMonitors())
}
