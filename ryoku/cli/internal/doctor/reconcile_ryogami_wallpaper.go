package doctor

import (
	"os"
	"os/exec"
	"strings"

	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
)

// ---- reconciler: cut existing boxes over from the old awww daemon to Ryogami -
//
// Arch receives the Ryogami user unit from its package and doctor therefore
// enables the delivered unit during migration.
//
// NixOS owns that service declaratively. Doctor must never create an imperative
// enablement symlink there; it may only repair transient runtime state such as a
// failed/inactive unit or an obsolete awww process left from an older session.

const ryogamiUserUnit = "ryogami.service"

// ryogamiWallpaperState is the subset of session state the reconciler decides
// on, split out so the decision is unit-testable without a live user manager.
type ryogamiWallpaperState struct {
	enabled     bool
	active      bool
	failed      bool
	awwwRunning bool
	inSession   bool
}

// ryogamiWallpaperActions is the Arch migration decision. NixOS uses the same
// runtime facts but never consumes the enable action because service enablement
// belongs to the active NixOS generation.
func ryogamiWallpaperActions(s ryogamiWallpaperState) (enable, clearFailed, start, stopAwww bool) {
	return !s.enabled, s.failed, s.inSession && !s.active, s.awwwRunning
}

func ryogamiUnitEnabled() bool {
	out, _ := exec.Command("systemctl", "--user", "is-enabled", ryogamiUserUnit).Output()
	return strings.TrimSpace(string(out)) == "enabled"
}

func ryogamiUnitActive() bool {
	out, _ := exec.Command("systemctl", "--user", "is-active", ryogamiUserUnit).Output()
	return strings.TrimSpace(string(out)) == "active"
}

func ryogamiUnitFailed() bool {
	out, _ := exec.Command("systemctl", "--user", "is-failed", ryogamiUserUnit).Output()
	return strings.TrimSpace(string(out)) == "failed"
}

func inGraphicalSession() bool {
	return os.Getenv("WAYLAND_DISPLAY") != ""
}

func awwwDaemonRunning() bool {
	return exec.Command("pgrep", "-x", "awww-daemon").Run() == nil
}

func reconcileRyogamiWallpaper(checkOnly bool) recResult {
	if !sys.Has("ryogami") {
		return okRes(i18n.T("ryogami not installed yet (arrives with the ryoku-desktop update)"))
	}

	if sys.NixBackend() {
		return reconcileRyogamiWallpaperNixOS(checkOnly)
	}

	return reconcileRyogamiWallpaperArch(checkOnly)
}

// NixOS owns enablement through systemd.user.services.ryogami in the Ryoku
// module. Runtime repair remains useful, but enable/disable and package
// installation stay entirely declarative.
func reconcileRyogamiWallpaperNixOS(checkOnly bool) recResult {
	failed := ryogamiUnitFailed()
	stopAwww := awwwDaemonRunning()
	start := inGraphicalSession() && !ryogamiUnitActive()

	if !failed && !stopAwww && !start {
		return okRes(i18n.T("ryogami wallpaper daemon is managed declaratively and running; no awww remains"))
	}

	if checkOnly {
		switch {
		case stopAwww:
			return wouldRes(i18n.T("the retired awww wallpaper daemon is still running and stacks over Ryogami")).
				withFix(i18n.T("ryoku doctor stops awww-daemon and restarts the declarative Ryogami service"))
		case failed:
			return wouldRes(i18n.T("the declarative Ryogami service is in a failed state")).
				withFix(i18n.T("ryoku doctor clears the failed state and restarts Ryogami"))
		default:
			return wouldRes(i18n.T("the declarative Ryogami service is down in this graphical session")).
				withFix(i18n.T("ryoku doctor starts the already-declared Ryogami service"))
		}
	}

	var did []string

	if failed || start {
		_ = exec.Command("systemctl", "--user", "reset-failed", ryogamiUserUnit).Run()
		if failed {
			did = append(did, i18n.T("cleared the failed Ryogami state"))
		}
	}

	if stopAwww {
		_ = exec.Command("pkill", "-x", "awww-daemon").Run()
		did = append(did, i18n.T("stopped the retired awww-daemon"))
	}

	// Refresh a service that may still be running a pre-switch binary, then bring
	// it up if it is inactive. These are runtime operations only; no enablement
	// symlink is created on NixOS.
	_ = exec.Command("systemctl", "--user", "try-restart", ryogamiUserUnit).Run()
	_ = exec.Command("systemctl", "--user", "start", ryogamiUserUnit).Run()
	if start {
		did = append(did, i18n.T("started the declarative Ryogami service"))
	}

	if len(did) == 0 {
		did = append(did, i18n.T("refreshed the declarative Ryogami service"))
	}

	return fixedRes(i18n.T("repaired the Ryogami runtime: ") + strings.Join(did, ", "))
}

func reconcileRyogamiWallpaperArch(checkOnly bool) recResult {
	state := ryogamiWallpaperState{
		enabled:     ryogamiUnitEnabled(),
		active:      ryogamiUnitActive(),
		failed:      ryogamiUnitFailed(),
		awwwRunning: awwwDaemonRunning(),
		inSession:   inGraphicalSession(),
	}

	enable, clearFailed, start, stopAwww := ryogamiWallpaperActions(state)
	if !enable && !clearFailed && !start && !stopAwww {
		return okRes(i18n.T("ryogami wallpaper daemon enabled and running"))
	}

	if checkOnly {
		switch {
		case stopAwww:
			return wouldRes(i18n.T("the retired awww wallpaper daemon is still running and stacks over Ryogami")).
				withFix(i18n.T("ryoku doctor stops awww-daemon and enables the ryogami unit"))
		case clearFailed:
			return wouldRes(i18n.T("the ryogami wallpaper daemon is wedged off (failed); the wallpaper is down")).
				withFix(i18n.T("ryoku doctor reloads and restarts the ryogami unit"))
		case enable:
			return wouldRes(i18n.T("the ryogami wallpaper daemon is delivered but not enabled")).
				withFix(i18n.T("ryoku doctor enables the ryogami unit so the session starts it"))
		default:
			return wouldRes(i18n.T("the ryogami wallpaper daemon is down in this session; the desktop has no wallpaper")).
				withFix(i18n.T("ryoku doctor starts the ryogami unit"))
		}
	}

	_ = exec.Command("systemctl", "--user", "daemon-reload").Run()
	var did []string

	if enable {
		_ = exec.Command("systemctl", "--user", "enable", ryogamiUserUnit).Run()
		did = append(did, i18n.T("enabled the ryogami unit"))
	}

	if clearFailed {
		_ = exec.Command("systemctl", "--user", "reset-failed", ryogamiUserUnit).Run()
		did = append(did, i18n.T("cleared the wedged failed state"))
	}

	if stopAwww {
		_ = exec.Command("pkill", "-x", "awww-daemon").Run()
		did = append(did, i18n.T("stopped the retired awww-daemon"))
	}

	if start {
		did = append(did, i18n.T("started the wallpaper daemon"))
		_ = exec.Command("systemctl", "--user", "reset-failed", ryogamiUserUnit).Run()
	}

	_ = exec.Command("systemctl", "--user", "try-restart", ryogamiUserUnit).Run()
	_ = exec.Command("systemctl", "--user", "start", ryogamiUserUnit).Run()
	return fixedRes(i18n.T("cut the wallpaper over to Ryogami: ") + strings.Join(did, ", "))
}
