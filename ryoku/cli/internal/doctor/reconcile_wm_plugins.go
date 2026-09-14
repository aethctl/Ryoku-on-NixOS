package doctor

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	i18n "ryoku-i18n"
	wm "ryoku-wm"
)

// ---- reconciler: window-manager plugin builds -------------------------------
//
// A compositor plugin is ABI-locked to the exact compositor build, so a distro
// bumping a dependency between two Ryoku releases leaves an enabled plugin no
// longer loading and a cursor effect or title bar the user turned on silently
// stops. The provider owns the plugin tier (list and rebuild); this converges
// the enabled plugins whose receipts no longer match the installed headers.
// Gated on CapPlugins: a compositor with no plugin ABI has nothing to check.

type wmPluginState struct {
	capable   bool
	listed    bool     // the provider answered
	managed   bool     // the distribution owns plugin binaries declaratively
	stale     []string // enabled, installed, rebuildable, built for another build
	unhealthy []string // enabled managed plugin not healthy in the running session
	enabled   int
	toolchain bool
	missing   []string
}

var gatherWmPlugins = func() wmPluginState {
	var s wmPluginState
	c := wm.Open()
	if !c.Can(wm.CapPlugins) {
		return s
	}
	s.capable = true
	out, err := c.Plugins("list")
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
				s.unhealthy = append(s.unhealthy, p.ID+" ("+p.Status+")")
			}
			continue
		}
		if p.Installed && !p.Current && p.Rebuildable {
			s.stale = append(s.stale, p.ID)
		}
	}
	sort.Strings(s.stale)
	sort.Strings(s.unhealthy)
	return s
}

// repairWmPlugins rebuilds the stale enabled plugins through the provider and
// reports which ones the builder could not.
var repairWmPlugins = func() (map[string]string, error) {
	out, err := wm.Open().Plugins("rebuild", "--stale")
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

// planWmPlugins turns observed state into a result. pure.
func planWmPlugins(s wmPluginState, checkOnly bool, repair func() (map[string]string, error)) recResult {
	if !s.capable {
		return okRes(i18n.T("the window manager has no plugin support"))
	}
	if !s.listed {
		return noteRes(i18n.T("plugin builds not checked (no headers or the provider did not answer)"))
	}
	if s.managed {
		if len(s.unhealthy) == 0 {
			if s.enabled == 0 {
				return okRes(i18n.T("the distribution manages compositor plugin binaries; no plugin enabled"))
			}
			return okRes(i18n.T("%d enabled compositor plugin(s) are provided by the active system generation"), s.enabled)
		}
		return warnRes(i18n.T("enabled system-managed compositor plugin(s) do not match the running session: %s"), strings.Join(s.unhealthy, ", ")).
			withFix(i18n.T("rebuild or update the system generation, then start a new compositor session"))
	}
	if len(s.stale) == 0 {
		if s.enabled == 0 {
			return okRes(i18n.T("no plugin enabled"))
		}
		return okRes(i18n.T("%d enabled plugin(s) built for the installed compositor"), s.enabled)
	}
	list := strings.Join(s.stale, ", ")
	if !s.toolchain {
		return warnRes(i18n.T("enabled plugin(s) built for another compositor build and this box cannot rebuild them (missing %s): %s"), strings.Join(s.missing, ", "), list).
			withFix(i18n.T("sudo pacman -S --needed base-devel cmake git, then Settings > Plugins > Rebuild"))
	}
	if checkOnly {
		return wouldRes(i18n.T("enabled plugin(s) built for another compositor build: %s"), list).
			withFix(i18n.T("ryoku doctor rebuilds them through the provider"))
	}
	failed, err := repair()
	if err != nil {
		return failRes(i18n.T("could not rebuild plugins (%s): %v"), list, err).
			withFix(i18n.T("open Settings > Plugins and use Rebuild, which shows the build log"))
	}
	if len(failed) > 0 {
		names := make([]string, 0, len(failed))
		for id, why := range failed {
			names = append(names, id+": "+why)
		}
		sort.Strings(names)
		return failRes(i18n.T("rebuilt plugins, except %s"), strings.Join(names, "; ")).
			withFix(i18n.T("open Settings > Plugins and use Rebuild, which shows the build log"))
	}
	return fixedRes(i18n.T("rebuilt plugin(s) for the installed compositor: %s"), list)
}

func reconcileWmPlugins(checkOnly bool) recResult {
	return planWmPlugins(gatherWmPlugins(), checkOnly, repairWmPlugins)
}
