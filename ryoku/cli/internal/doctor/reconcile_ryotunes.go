package doctor

import (
	"os"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/sys"
)

// Ryotunes ships as a Ryoku desktop package.
//
// Arch installs the package beneath /usr and owns it through pacman. NixOS
// instead exposes the native Ryotunes derivation through Ryoku's immutable
// package bundle. Keep the stale ~/.local/bin migration on both platforms,
// because an old browser wrapper there can shadow either packaged app.
func reconcileRyotunes(checkOnly bool) recResult {
	var problems, fixes []string

	bin := filepath.Join(sys.Home(), ".local", "bin", "ryotunes")
	stale := staleUserRyotunes(bin)

	if stale != "" {
		problems = append(
			problems,
			stale+" in ~/.local/bin shadows the packaged app",
		)

		fixes = append(
			fixes,
			"rm -f ~/.local/bin/ryotunes ~/.local/share/applications/ryotunes.desktop",
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

	// Arch package ownership / repair path.
	if sys.ResolveRepo() == "" &&
		sys.PkgInstalled("ryoku-desktop") &&
		!sys.PkgInstalled("ryotunes") {

		problems = append(
			problems,
			"the ryotunes package is not installed",
		)

		fixes = append(
			fixes,
			"sudo pacman -S --needed ryotunes",
		)
	}

	if len(problems) == 0 {
		if _, err := sys.RunOut(
			"pacman",
			"-Qoq",
			"/usr/bin/ryotunes",
		); err == nil {
			return okRes("ryotunes is the packaged app")
		}

		if sys.Exists("/usr/bin/ryotunes") {
			return warnRes(
				"/usr/bin/ryotunes is not owned by the ryotunes package",
			).withFix(
				"sudo pacman -S --overwrite /usr/bin/ryotunes ryotunes",
			)
		}

		return okRes("ryotunes is the packaged app")
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

	if sys.ResolveRepo() == "" &&
		sys.PkgInstalled("ryoku-desktop") &&
		!sys.PkgInstalled("ryotunes") {

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

	return fixedRes(
		"ryotunes opens the packaged app (%s)",
		strings.Join(problems, "; "),
	)
}

// NixOS never asks doctor to install or repair a package imperatively.
// The Ryoku module owns the native Ryotunes derivation through the system
// closure; doctor may only remove an obsolete per-user wrapper that shadows it.
func reconcileRyotunesNixOS(
	checkOnly bool,
	bin string,
	stale string,
	problems []string,
	fixes []string,
) recResult {
	if stale == "" && !sys.Has("ryotunes") {
		problems = append(
			problems,
			"ryotunes is not available from the active Ryoku NixOS generation",
		)

		fixes = append(
			fixes,
			"rebuild the NixOS configuration that enables Ryoku",
		)
	}

	if len(problems) == 0 {
		return okRes(
			"ryotunes is provided by the Ryoku NixOS package set",
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

	if !sys.Has("ryotunes") {
		return warnRes(
			"ryotunes is not available from the active Ryoku NixOS generation",
		).withFix(
			"rebuild the NixOS configuration that enables Ryoku",
		)
	}

	return fixedRes(
		"removed the stale user Ryotunes app; the NixOS package is now authoritative",
	)
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
