package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
	wm "ryoku-wm"
)

// The settings store was renamed and re-namespaced: the Hub-owned hypr.json
// becomes desktop.json, its top-level fields re-rooted under desktop.* (intent
// every compositor honours) and wm.hyprland.* (this compositor's exclusives).
// The Hub writes only the new file now, so an existing box's settings are
// migrated across here and the old file dropped. It runs before any reconciler
// that reads desktop.json so those see migrated data. Idempotent.

// wmHyprlandRoots are the old top-level fields that are Hyprland exclusives;
// every other field is neutral intent and re-roots under desktop.*.
var wmHyprlandRoots = map[string]bool{
	"dwindle":    true,
	"master":     true,
	"anim":       true,
	"layerRules": true,
	"plugins":    true,
}

func reconcileDesktopStore(checkOnly bool) recResult {
	old := filepath.Join(sys.ConfigHome(), "ryoku", "hypr.json")
	neu := filepath.Join(sys.ConfigHome(), "ryoku", "desktop.json")
	if !sys.Exists(old) {
		return okRes(i18n.T("settings store is on the neutral desktop.json"))
	}
	// The Hub writes desktop.json now, so an old file beside it is stale residue.
	if sys.Exists(neu) {
		if checkOnly {
			return wouldRes(i18n.T("the retired hypr.json lingers beside desktop.json")).
				withFix(i18n.T("ryoku doctor removes it"))
		}
		if err := os.Remove(old); err != nil {
			return failRes(i18n.T("could not remove the retired hypr.json: %v"), err)
		}
		return fixedRes(i18n.T("removed the retired hypr.json; desktop.json is the settings store"))
	}
	if checkOnly {
		return wouldRes(i18n.T("settings live in the retired hypr.json; the Hub reads desktop.json now")).
			withFix(i18n.T("ryoku doctor migrates it to desktop.json"))
	}
	raw, err := os.ReadFile(old)
	if err != nil {
		return failRes(i18n.T("could not read hypr.json to migrate it: %v"), err)
	}
	migrated, err := migrateDesktopStore(raw)
	if err != nil {
		return failRes(i18n.T("hypr.json does not parse, so it cannot be migrated: %v"), err).
			withFix(i18n.T("fix or delete %s, then re-run ryoku doctor"), old)
	}
	if err := writeStore(neu, migrated); err != nil {
		return failRes(i18n.T("could not write desktop.json: %v"), err)
	}
	if _, err := os.ReadFile(neu); err != nil {
		return failRes(i18n.T("wrote desktop.json but it is unreadable: %v"), err)
	}
	if err := os.Remove(old); err != nil {
		return warnRes(i18n.T("migrated settings to desktop.json but could not remove the old hypr.json: %v"), err).
			withFix(i18n.T("delete %s by hand"), old)
	}
	return fixedRes(i18n.T("migrated the settings store from hypr.json to desktop.json"))
}

// migrateDesktopStore re-roots the flat hypr.json fields into the namespaced
// desktop.json shape: Hyprland exclusives under wm.hyprland.*, everything else
// under desktop.* (the reader merges both, so an unknown field is still honoured).
func migrateDesktopStore(raw []byte) ([]byte, error) {
	old := map[string]any{}
	if strings.TrimSpace(string(raw)) != "" {
		if err := json.Unmarshal(raw, &old); err != nil {
			return nil, err
		}
	}
	desktop := map[string]any{}
	hyprland := map[string]any{}
	for k, v := range old {
		if wmHyprlandRoots[k] {
			hyprland[k] = v
		} else {
			desktop[k] = v
		}
	}
	out := map[string]any{
		"desktop": desktop,
		"wm":      map[string]any{wm.ProviderHyprland: hyprland},
	}
	b, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(b, '\n'), nil
}

// writeStore atomically replaces a settings store file.
func writeStore(path string, data []byte) error {
	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}
