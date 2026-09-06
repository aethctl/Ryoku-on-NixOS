package doctor

import (
	"os/exec"
	"strings"

	"ryoku-cli/internal/sys"
)

// ---- reconciler: cut existing boxes over from the old awww daemon to Ryogami -
//
// Arch receives the Ryogami user unit from its package and doctor therefore
// enables the delivered unit during migration.
//
// Musubi/NixOS owns that service declaratively. Doctor must never create an
// imperative enablement symlink there; it may only repair transient runtime
// state such as a failed unit or an obsolete awww process left from an older
// Ryoku session.

const ryogamiUserUnit = "ryogami.service"

type ryogamiWallpaperState struct {
	enabled     bool
	failed      bool
	awwwRunning bool
}

func ryogamiWallpaperActions(
	s ryogamiWallpaperState,
) (
	enable bool,
	clearFailed bool,
	stopAwww bool,
) {
	return !s.enabled, s.failed, s.awwwRunning
}

func ryogamiUnitEnabled() bool {
	out, _ := exec.Command(
		"systemctl",
		"--user",
		"is-enabled",
		ryogamiUserUnit,
	).Output()

	return strings.TrimSpace(string(out)) == "enabled"
}

func ryogamiUnitFailed() bool {
	out, _ := exec.Command(
		"systemctl",
		"--user",
		"is-failed",
		ryogamiUserUnit,
	).Output()

	return strings.TrimSpace(string(out)) == "failed"
}

func awwwDaemonRunning() bool {
	return exec.Command(
		"pgrep",
		"-x",
		"awww-daemon",
	).Run() == nil
}

func reconcileRyogamiWallpaper(
	checkOnly bool,
) recResult {
	if !sys.Has("ryogami") {
		return okRes(
			"ryogami not installed yet (arrives with the ryoku-desktop update)",
		)
	}

	if sys.Exists("/etc/NIXOS") {
		return reconcileRyogamiWallpaperNixOS(
			checkOnly,
		)
	}

	return reconcileRyogamiWallpaperArch(
		checkOnly,
	)
}

// NixOS owns enablement through systemd.user.services.ryogami in the Ryoku
// module. Runtime repair is still useful, but enable/disable and package
// installation remain entirely declarative.
func reconcileRyogamiWallpaperNixOS(
	checkOnly bool,
) recResult {
	failed := ryogamiUnitFailed()
	stopAwww := awwwDaemonRunning()

	if !failed && !stopAwww {
		return okRes(
			"ryogami wallpaper daemon is managed declaratively; no awww remains",
		)
	}

	if checkOnly {
		switch {
		case stopAwww:
			return wouldRes(
				"the retired awww wallpaper daemon is still running and stacks over Ryogami",
			).withFix(
				"ryoku doctor stops awww-daemon and restarts the declarative Ryogami service",
			)

		default:
			return wouldRes(
				"the declarative Ryogami service is in a failed state",
			).withFix(
				"ryoku doctor clears the failed state and restarts Ryogami",
			)
		}
	}

	var did []string

	if failed {
		_ = exec.Command(
			"systemctl",
			"--user",
			"reset-failed",
			ryogamiUserUnit,
		).Run()

		did = append(
			did,
			"cleared the failed Ryogami state",
		)
	}

	if stopAwww {
		_ = exec.Command(
			"pkill",
			"-x",
			"awww-daemon",
		).Run()

		did = append(
			did,
			"stopped the retired awww-daemon",
		)
	}

	_ = exec.Command(
		"systemctl",
		"--user",
		"restart",
		ryogamiUserUnit,
	).Run()

	did = append(
		did,
		"restarted the declarative Ryogami service",
	)

	return fixedRes(
		"repaired the Ryogami runtime: " +
			strings.Join(did, ", "),
	)
}

func reconcileRyogamiWallpaperArch(
	checkOnly bool,
) recResult {
	state := ryogamiWallpaperState{
		enabled:     ryogamiUnitEnabled(),
		failed:      ryogamiUnitFailed(),
		awwwRunning: awwwDaemonRunning(),
	}

	enable, clearFailed, stopAwww :=
		ryogamiWallpaperActions(state)

	if !enable && !clearFailed && !stopAwww {
		return okRes(
			"ryogami wallpaper daemon enabled; no awww left to retire",
		)
	}

	if checkOnly {
		switch {
		case stopAwww:
			return wouldRes(
				"the retired awww wallpaper daemon is still running and stacks over Ryogami",
			).withFix(
				"ryoku doctor stops awww-daemon and enables the ryogami unit",
			)

		case clearFailed:
			return wouldRes(
				"the ryogami wallpaper daemon is wedged off (failed); the wallpaper is down",
			).withFix(
				"ryoku doctor reloads and restarts the ryogami unit",
			)

		default:
			return wouldRes(
				"the ryogami wallpaper daemon is delivered but not enabled",
			).withFix(
				"ryoku doctor enables the ryogami unit so the session starts it",
			)
		}
	}

	_ = exec.Command(
		"systemctl",
		"--user",
		"daemon-reload",
	).Run()

	var did []string

	if enable {
		_ = exec.Command(
			"systemctl",
			"--user",
			"enable",
			ryogamiUserUnit,
		).Run()

		did = append(
			did,
			"enabled the ryogami unit",
		)
	}

	if clearFailed {
		_ = exec.Command(
			"systemctl",
			"--user",
			"reset-failed",
			ryogamiUserUnit,
		).Run()

		did = append(
			did,
			"cleared the wedged failed state",
		)
	}

	if stopAwww {
		_ = exec.Command(
			"pkill",
			"-x",
			"awww-daemon",
		).Run()

		did = append(
			did,
			"stopped the retired awww-daemon",
		)
	}
	// Refresh a daemon still running the pre-cutover binary so the delivered one
	// takes over and paints -- it restores the recorded wallpaper, or a shipped
	// default when none is recorded, instead of leaving the empty grey frame --
	// then start one that is down. Best-effort: a no-op outside a graphical
	// session (the unit gates on ConditionEnvironment=WAYLAND_DISPLAY), where
	// autostart starts it at login.
	_ = exec.Command("systemctl", "--user", "try-restart", ryogamiUserUnit).Run()
	_ = exec.Command("systemctl", "--user", "start", ryogamiUserUnit).Run()
	return fixedRes("cut the wallpaper over to Ryogami: " + strings.Join(did, ", "))
}
