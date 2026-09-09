package doctor

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"

	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
)

// ---- reconciler: Hyprland plugin builds -------------------------------------
//
// A compositor plugin is ABI-locked to the exact Hyprland build: the commit
// plus the major.minor of aquamarine, hyprutils, hyprgraphics, hyprcursor and
// hyprlang. Arch can bump any of those between two Ryoku releases, and then
// the plugin copies on the box (the [ryoku] package, a local build) no longer
// load: Hyprland refuses each with "version mismatch" on every reload, and a
// cursor effect or title bar the user turned on silently stops. Each copy
// carries an .abi receipt, so the Hub's backend can tell without loading.
//
// Enabled plugins are what the user will miss at the next login, so those are
// converged here: `ryoku-hub hypr plugins rebuild --stale` rebuilds every
// enabled plugin whose receipts no longer match the installed headers (what the
// next session runs), from upstream, with the same builder the Plugins page
// uses. A disabled stale plugin costs nothing and is left for the page. A box
// without a toolchain is told what to install; the page then offers Rebuild.

// hyprPluginState is what the verdict needs, lifted so the plan is pure.
type hyprPluginState struct {
	hubPresent bool
	listed     bool     // the backend answered
	managed    bool     // NixOS owns plugin binaries declaratively
	stale      []string // Arch: enabled, rebuildable and built for another Hyprland
	unhealthy  []string // NixOS: enabled plugin not healthy in the running session
	enabled    int
	toolchain  bool
	missing    []string
}

var gatherHyprPlugins = func() hyprPluginState {
	var s hyprPluginState
	if _, err := exec.LookPath("ryoku-hub"); err != nil {
		return s
	}
	s.hubPresent = true
	cmd := exec.Command(
		"ryoku-hub",
		"hypr",
		"plugins",
		"list",
	)

	// A terminal that existed before the first Ryoku 0.59 NixOS switch
	// cannot inherit the newly declared session variables. Doctor knows
	// the platform already, so make the Hub subprocess generation-aware
	// explicitly instead of temporarily falling back to Arch's mutable
	// plugin-builder model.
	if sys.Exists("/etc/NIXOS") {
		cmd.Env = append(
			os.Environ(),
			"RYOKU_HYPR_PLUGINS_MANAGED=nix",
			"RYOKU_HYPR_PLUGIN_DIR=/run/current-system/sw/lib/hyprland/plugins",
		)
	}

	out, err := cmd.Output()
	if err != nil {
		return s
	}
	var roster struct {
		Toolchain struct {
			OK      bool     `json:"ok"`
			Managed bool     `json:"managed"`
			Missing []string `json:"missing"`
		} `json:"toolchain"`
		Plugins []struct {
			ID          string `json:"id"`
			Enabled     bool   `json:"enabled"`
			Installed   bool   `json:"installed"`
			Current     bool   `json:"current"`
			Rebuildable bool   `json:"rebuildable"`
			Status      string `json:"status"`
		} `json:"plugins"`
	}
	if json.Unmarshal(out, &roster) != nil {
		return s
	}
	s.listed = true
	s.managed = roster.Toolchain.Managed
	s.toolchain, s.missing = roster.Toolchain.OK, roster.Toolchain.Missing

	for _, p := range roster.Plugins {
		if !p.Enabled {
			continue
		}

		s.enabled++

		if s.managed {
			switch p.Status {
			case "stale", "missing", "failed":
				s.unhealthy = append(
					s.unhealthy,
					p.ID+" ("+p.Status+")",
				)
			}

			continue
		}

		if p.Installed && !p.Current && p.Rebuildable {
			s.stale = append(
				s.stale,
				p.ID,
			)
		}
	}

	sort.Strings(s.stale)
	sort.Strings(s.unhealthy)

	return s
}

// repairHyprPlugins rebuilds the stale enabled plugins and reports which ones
// the builder could not.
var repairHyprPlugins = func() (map[string]string, error) {
	out, err := exec.Command("ryoku-hub", "hypr", "plugins", "rebuild", "--stale").Output()
	if err != nil {
		return nil, err
	}
	var res struct {
		Failed map[string]string `json:"failed"`
	}
	if err := json.Unmarshal(out, &res); err != nil {
		return nil, fmt.Errorf(i18n.T("unreadable builder result: %w"), err)
	}
	return res.Failed, nil
}

// planHyprPlugins turns observed state into a result. pure.
func planHyprPlugins(s hyprPluginState, checkOnly bool, repair func() (map[string]string, error)) recResult {
	if !s.hubPresent {
		return warnRes(i18n.T("ryoku-hub is not installed, so Hyprland plugin builds cannot be checked")).withFix("ryoku update")
	}
	if !s.listed {
		return noteRes(i18n.T("Hyprland plugin builds not checked (no Hyprland headers or the backend did not answer)"))
	}

	if s.managed {
		if len(s.unhealthy) == 0 {
			if s.enabled == 0 {
				return okRes("NixOS manages Hyprland plugin binaries declaratively; no plugin enabled")
			}

			return okRes(
				"%d enabled Hyprland plugin(s) are provided by the active NixOS Ryoku generation",
				s.enabled,
			)
		}

		return warnRes(
			"enabled NixOS-managed Hyprland plugin(s) do not match the running session: %s",
			strings.Join(
				s.unhealthy,
				", ",
			),
		).withFix(
			"rebuild or update the NixOS Ryoku generation, then start a new Hyprland session",
		)
	}

	if len(s.stale) == 0 {
		if s.enabled == 0 {
			return okRes(i18n.T("no Hyprland plugin enabled"))
		}
		return okRes(i18n.T("%d enabled Hyprland plugin(s) built for the installed Hyprland"), s.enabled)
	}
	list := strings.Join(s.stale, ", ")
	if !s.toolchain {
		return warnRes(i18n.T("enabled Hyprland plugin(s) built for another Hyprland and this box cannot rebuild them (missing %s): %s"), strings.Join(s.missing, ", "), list).
			withFix(i18n.T("sudo pacman -S --needed base-devel cmake git hyprland, then Settings > Plugins > Rebuild"))
	}
	if checkOnly {
		return wouldRes(i18n.T("enabled Hyprland plugin(s) built for another Hyprland: %s"), list).
			withFix(i18n.T("ryoku doctor rebuilds them via ryoku-hub hypr plugins rebuild --stale"))
	}
	failed, err := repair()
	if err != nil {
		return failRes(i18n.T("could not rebuild Hyprland plugins (%s): %v"), list, err).
			withFix(i18n.T("open Settings > Plugins and use Rebuild, which shows the build log"))
	}
	if len(failed) > 0 {
		names := make([]string, 0, len(failed))
		for id, why := range failed {
			names = append(names, id+": "+why)
		}
		sort.Strings(names)
		return failRes(i18n.T("rebuilt Hyprland plugins, except %s"), strings.Join(names, "; ")).
			withFix(i18n.T("open Settings > Plugins and use Rebuild, which shows the build log"))
	}
	return fixedRes(i18n.T("rebuilt Hyprland plugin(s) for the installed Hyprland: %s"), list)
}

func reconcileHyprPlugins(checkOnly bool) recResult {
	return planHyprPlugins(gatherHyprPlugins(), checkOnly, repairHyprPlugins)
}
