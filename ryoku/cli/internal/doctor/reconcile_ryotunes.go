package doctor

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/sys"
)

// ryotunesSocketUnit is the socket-activation unit used by the native
// Ryotunes daemon/client architecture introduced upstream.
//
// Arch enables the package-delivered socket during repair. NixOS owns
// enablement declaratively through the Ryoku module and Doctor may only
// repair transient runtime state there.
const ryotunesSocketUnit = "ryotunesd.socket"

// Ryotunes ships as a Ryoku desktop package.
//
// A stale wrapper/local build under ~/.local/bin can shadow the packaged
// application on either platform. Package installation and unit ownership,
// however, remain platform-specific.
func reconcileRyotunes(checkOnly bool) recResult {
	var problems, fixes []string

	bin := filepath.Join(
		sys.Home(),
		".local",
		"bin",
		"ryotunes",
	)

	stale := staleUserRyotunes(bin)

	if stale != "" {
		problems = append(
			problems,
			stale+" in ~/.local/bin shadows the packaged app",
		)

		fixes = append(
			fixes,
			"rm -f ~/.local/bin/ryotunes "+
				"~/.local/share/applications/ryotunes.desktop",
		)
	}

	if sys.Exists("/etc/NIXOS") {
		return reconcileRyotunesNixOS(
			checkOnly,
			bin,
			stale,
			problems,
			fixes,
		)
	}

	return reconcileRyotunesArch(
		checkOnly,
		bin,
		stale,
		problems,
		fixes,
	)
}

func reconcileRyotunesArch(
	checkOnly bool,
	bin string,
	stale string,
	problems []string,
	fixes []string,
) recResult {
	missingPackage :=
		sys.ResolveRepo() == "" &&
			sys.PkgInstalled("ryoku-desktop") &&
			!sys.PkgInstalled("ryotunes")

	if missingPackage {
		problems = append(
			problems,
			"the ryotunes package is not installed",
		)

		fixes = append(
			fixes,
			"sudo pacman -S --needed ryotunes",
		)
	}

	socketMissing :=
		sys.PkgInstalled("ryotunes") &&
			!ryotunesSocketEnabled()

	if socketMissing {
		problems = append(
			problems,
			"the ryotunesd socket is not enabled, "+
				"so `ryotunes` opens the old Tauri app",
		)

		fixes = append(
			fixes,
			"systemctl --user enable --now ryotunesd.socket",
		)
	}

	if len(problems) == 0 {
		if _, err := sys.RunOut(
			"pacman",
			"-Qoq",
			"/usr/bin/ryotunes",
		); err == nil {
			return okRes(
				"ryotunes is the packaged app",
			)
		}

		if sys.Exists("/usr/bin/ryotunes") {
			return warnRes(
				"/usr/bin/ryotunes is not owned by " +
					"the ryotunes package",
			).withFix(
				"sudo pacman -S --overwrite " +
					"/usr/bin/ryotunes ryotunes",
			)
		}

		return okRes(
			"ryotunes is the packaged app",
		)
	}

	if checkOnly {
		return wouldRes(
			"%s",
			strings.Join(problems, "; "),
		).withFix(
			strings.Join(fixes, " && "),
		)
	}

	if stale != "" {
		removeStaleUserRyotunes(bin)
	}

	if missingPackage {
		if err := sys.Sudo(
			"pacman",
			"-S",
			"--needed",
			"--noconfirm",
			"ryotunes",
		); err != nil {
			return failRes(
				"could not install ryotunes: %v",
				err,
			).withFix(
				"sudo pacman -S --needed ryotunes",
			)
		}
	}

	if socketMissing {
		_ = exec.Command(
			"systemctl",
			"--user",
			"daemon-reload",
		).Run()

		if err := exec.Command(
			"systemctl",
			"--user",
			"enable",
			"--now",
			ryotunesSocketUnit,
		).Run(); err != nil {
			return failRes(
				"could not enable %s: %v",
				ryotunesSocketUnit,
				err,
			).withFix(
				"systemctl --user enable --now " +
					"ryotunesd.socket",
			)
		}
	}

	return fixedRes(
		"ryotunes opens the packaged app (%s)",
		strings.Join(problems, "; "),
	)
}

// NixOS owns both the Ryotunes package and socket enablement through the
// active system generation. Doctor never installs packages or creates an
// imperative systemd enablement symlink.
//
// It may still remove an obsolete user wrapper and start an already-delivered
// socket in the current session after daemon-reload.
func reconcileRyotunesNixOS(
	checkOnly bool,
	bin string,
	stale string,
	problems []string,
	fixes []string,
) recResult {
	available := sys.Has("ryotunes")

	if !available {
		problems = append(
			problems,
			"ryotunes is not available from the active "+
				"Ryoku NixOS generation",
		)

		fixes = append(
			fixes,
			"rebuild the NixOS configuration that enables Ryoku",
		)
	}

	socketMissing :=
		available &&
			!ryotunesSocketEnabled()

	if socketMissing {
		problems = append(
			problems,
			"the declarative ryotunesd socket is not enabled",
		)

		fixes = append(
			fixes,
			"rebuild the NixOS configuration that enables Ryoku",
		)
	}

	if len(problems) == 0 {
		return okRes(
			"ryotunes and its socket are provided by " +
				"the Ryoku NixOS generation",
		)
	}

	if checkOnly {
		return wouldRes(
			"%s",
			strings.Join(problems, "; "),
		).withFix(
			strings.Join(fixes, " && "),
		)
	}

	if stale != "" {
		removeStaleUserRyotunes(bin)
	}

	if !available {
		return warnRes(
			"ryotunes is not available from the active " +
				"Ryoku NixOS generation",
		).withFix(
			"rebuild the NixOS configuration that enables Ryoku",
		)
	}

	if socketMissing {
		_ = exec.Command(
			"systemctl",
			"--user",
			"daemon-reload",
		).Run()

		// Runtime repair only. The NixOS module owns whether this unit is
		// enabled for future sessions.
		if err := exec.Command(
			"systemctl",
			"--user",
			"start",
			ryotunesSocketUnit,
		).Run(); err != nil {
			return warnRes(
				"could not start the declarative %s: %v",
				ryotunesSocketUnit,
				err,
			).withFix(
				"rebuild the NixOS configuration that enables Ryoku",
			)
		}
	}

	return fixedRes(
		"repaired Ryotunes user state; " +
			"the NixOS package remains authoritative",
	)
}

func ryotunesSocketEnabled() bool {
	out, _ := exec.Command(
		"systemctl",
		"--user",
		"is-enabled",
		ryotunesSocketUnit,
	).Output()

	return strings.TrimSpace(string(out)) == "enabled"
}

func removeStaleUserRyotunes(bin string) {
	appshare := sys.Xdg(
		"XDG_DATA_HOME",
		".local/share",
	)

	for _, p := range []string{
		bin,
		filepath.Join(
			appshare,
			"applications",
			"ryotunes.desktop",
		),
		filepath.Join(
			appshare,
			"ryoku",
			"ryotunes.commit",
		),
		filepath.Join(
			appshare,
			"icons",
			"hicolor",
			"scalable",
			"apps",
			"ryotunes.svg",
		),
	} {
		_ = os.Remove(p)
	}

	icons, _ := filepath.Glob(
		filepath.Join(
			appshare,
			"icons",
			"hicolor",
			"*",
			"apps",
			"ryotunes.png",
		),
	)

	for _, p := range icons {
		_ = os.Remove(p)
	}
}

// staleUserRyotunes names what ~/.local/bin/ryotunes is when it is not the
// user's own program: the Chromium wrapper or a build recorded by the old
// development deploy.
func staleUserRyotunes(bin string) string {
	st, err := os.Stat(bin)

	if err != nil || st.IsDir() {
		return ""
	}

	head := make([]byte, 4096)

	if f, err := os.Open(bin); err == nil {
		n, _ := f.Read(head)
		_ = f.Close()
		head = head[:n]
	}

	if strings.HasPrefix(
		string(head),
		"#!",
	) && strings.Contains(
		string(head),
		"music.youtube.com",
	) {
		return "the Chromium YouTube Music wrapper"
	}

	if sys.Exists(
		filepath.Join(
			sys.Xdg(
				"XDG_DATA_HOME",
				".local/share",
			),
			"ryoku",
			"ryotunes.commit",
		),
	) {
		return "a locally built ryotunes"
	}

	return ""
}
