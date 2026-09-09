package doctor

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"ryoku-cli/internal/ryotunesrelease"
	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
)

// ryotunesSocketUnit provides native daemon socket activation. Arch enables the
// package-delivered socket during repair; NixOS owns enablement declaratively
// through the Ryoku module and Doctor may only repair transient runtime state.
const ryotunesSocketUnit = "ryotunesd.socket"

// Ryotunes is delivered independently from the core Ryoku package set on Arch.
// A stale wrapper/local build under ~/.local/bin can shadow the packaged app on
// either platform. Package installation and unit ownership remain
// platform-specific.
func reconcileRyotunes(checkOnly bool) recResult {
	var problems, fixes []string

	bin := filepath.Join(sys.Home(), ".local", "bin", "ryotunes")
	stale := staleUserRyotunes(bin)
	if stale != "" {
		problems = append(problems, i18n.Tf("%s in ~/.local/bin shadows the packaged app", stale))
		fixes = append(fixes, "rm -f ~/.local/bin/ryotunes ~/.local/share/applications/ryotunes.desktop")
	}

	if sys.NixBackend() {
		return reconcileRyotunesNixOS(checkOnly, bin, stale, problems, fixes)
	}

	return reconcileRyotunesArch(checkOnly, bin, stale, problems, fixes)
}

func reconcileRyotunesArch(
	checkOnly bool,
	bin string,
	stale string,
	problems []string,
	fixes []string,
) recResult {
	managedDesktop := sys.ResolveRepo() != "" || sys.PkgInstalled("ryoku-desktop")
	desktopMissingRyotunes := managedDesktop && !sys.PkgInstalled("ryotunes")
	if desktopMissingRyotunes {
		problems = append(problems, i18n.T("the ryotunes package is not installed"))
		fixes = append(fixes, "ryoku update")
	}

	socketMissing := sys.PkgInstalled("ryotunes") && !ryotunesSocketEnabled()
	if socketMissing {
		problems = append(problems, i18n.T("the ryotunesd socket is not enabled for session activation"))
		fixes = append(fixes, "systemctl --user enable --now ryotunesd.socket")
	}

	if len(problems) == 0 {
		if _, err := sys.RunOut("pacman", "-Qoq", "/usr/bin/ryotunes"); err != nil && sys.Exists("/usr/bin/ryotunes") {
			return warnRes(i18n.T("/usr/bin/ryotunes is not owned by the ryotunes package")).
				withFix("sudo pacman -S --overwrite /usr/bin/ryotunes ryotunes")
		}
		if note, ok := ryotunesUpdateNote(); ok {
			return note
		}
		return okRes(i18n.T("ryotunes is the packaged app"))
	}

	if checkOnly {
		return wouldRes("%s", strings.Join(problems, "; ")).withFix(strings.Join(fixes, " && "))
	}

	if stale != "" {
		removeStaleUserRyotunes(bin)
	}

	if desktopMissingRyotunes {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		_, err := ryotunesrelease.Ensure(ctx)
		cancel()
		if err != nil {
			return failRes(i18n.T("could not install ryotunes: %v"), err).withFix("ryoku update")
		}
	}

	if socketMissing {
		_ = exec.Command("systemctl", "--user", "daemon-reload").Run()
		if err := exec.Command("systemctl", "--user", "enable", "--now", ryotunesSocketUnit).Run(); err != nil {
			return failRes(i18n.T("could not enable %s: %v"), ryotunesSocketUnit, err).
				withFix("systemctl --user enable --now ryotunesd.socket")
		}
	}

	return fixedRes(i18n.T("ryotunes opens the packaged app (%s)"), strings.Join(problems, "; "))
}

// NixOS owns both the Ryotunes package and socket enablement through the active
// system generation. Doctor never installs packages or creates an imperative
// systemd enablement symlink. It may remove an obsolete user wrapper and start
// an already-delivered socket in the current session.
func reconcileRyotunesNixOS(
	checkOnly bool,
	bin string,
	stale string,
	problems []string,
	fixes []string,
) recResult {
	available := sys.Has("ryotunes")
	if !available {
		problems = append(problems, i18n.T("ryotunes is not available from the active Ryoku NixOS generation"))
		fixes = append(fixes, i18n.T("rebuild the NixOS configuration that enables Ryoku"))
	}

	socketMissing := available && !ryotunesSocketEnabled()
	if socketMissing {
		problems = append(problems, i18n.T("the declarative ryotunesd socket is not enabled"))
		fixes = append(fixes, i18n.T("rebuild the NixOS configuration that enables Ryoku"))
	}

	if len(problems) == 0 {
		return okRes(i18n.T("ryotunes and its socket are provided by the Ryoku NixOS generation"))
	}

	if checkOnly {
		return wouldRes("%s", strings.Join(problems, "; ")).withFix(strings.Join(fixes, " && "))
	}

	if stale != "" {
		removeStaleUserRyotunes(bin)
	}

	if !available {
		return warnRes(i18n.T("ryotunes is not available from the active Ryoku NixOS generation")).
			withFix(i18n.T("rebuild the NixOS configuration that enables Ryoku"))
	}

	if socketMissing {
		_ = exec.Command("systemctl", "--user", "daemon-reload").Run()
		if err := exec.Command("systemctl", "--user", "start", ryotunesSocketUnit).Run(); err != nil {
			return warnRes(i18n.T("could not start the declarative %s: %v"), ryotunesSocketUnit, err).
				withFix(i18n.T("rebuild the NixOS configuration that enables Ryoku"))
		}
	}

	return fixedRes(i18n.T("repaired Ryotunes user state; the NixOS package remains authoritative"))
}

// Release availability is advisory on Arch: Doctor checks but never installs.
func ryotunesUpdateNote() (recResult, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	st, err := ryotunesrelease.Check(ctx)
	if err != nil {
		return noteRes(i18n.T("could not check Ryotunes releases: %v"), err), true
	}
	if !st.Available {
		return recResult{}, false
	}
	return noteRes(i18n.T("a newer Ryotunes (%s) is available; `ryoku update` installs it"), st.Latest).
		withFix("ryoku update"), true
}

func ryotunesSocketEnabled() bool {
	out, _ := exec.Command("systemctl", "--user", "is-enabled", ryotunesSocketUnit).Output()
	return strings.TrimSpace(string(out)) == "enabled"
}

func removeStaleUserRyotunes(bin string) {
	appshare := sys.Xdg("XDG_DATA_HOME", ".local/share")
	for _, p := range []string{
		bin,
		filepath.Join(appshare, "applications", "ryotunes.desktop"),
		filepath.Join(appshare, "ryoku", "ryotunes.commit"),
		filepath.Join(appshare, "icons", "hicolor", "scalable", "apps", "ryotunes.svg"),
	} {
		_ = os.Remove(p)
	}
	icons, _ := filepath.Glob(filepath.Join(appshare, "icons", "hicolor", "*", "apps", "ryotunes.png"))
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
		f.Close()
		head = head[:n]
	}
	if strings.HasPrefix(string(head), "#!") && strings.Contains(string(head), "music.youtube.com") {
		return "the Chromium YouTube Music wrapper"
	}
	if sys.Exists(filepath.Join(sys.Xdg("XDG_DATA_HOME", ".local/share"), "ryoku", "ryotunes.commit")) {
		return "a locally built ryotunes"
	}
	return ""
}
