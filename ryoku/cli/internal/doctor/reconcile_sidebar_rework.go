package doctor

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
)

func defaultSidebars() map[string]any {
	return map[string]any{
		"motion": "standard",
		"left": map[string]any{
			"enabled":       true,
			"cards":         []any{"system", "notifications", "weather", "media", "capture", "stage"},
			"width":         float64(1040),
			"height":        float64(1000),
			"heightMode":    "fixed",
			"maxHeight":     float64(85),
			"position":      "center",
			"pinned":        false,
			"presentations": map[string]any{},
		},
		"right": map[string]any{
			"enabled":       true,
			"cards":         []any{"usage", "tools", "chat"},
			"width":         float64(1040),
			"height":        float64(1000),
			"heightMode":    "fixed",
			"maxHeight":     float64(85),
			"position":      "center",
			"pinned":        false,
			"presentations": map[string]any{},
		},
	}
}

func reconcileSidebarRework(checkOnly bool) recResult {
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return okRes(i18n.T("no shell.json yet (seeded on first shell run)"))
	}
	migrated, changed, err := migrateSidebarRework(raw)
	if err != nil {
		return warnRes(i18n.T("shell.json does not parse (%v); the shell falls back to defaults"), err).
			withFix(i18n.T("delete %s to re-seed it"), path)
	}
	if !changed {
		return okRes(i18n.T("sidebar settings use the current schema"))
	}
	if checkOnly {
		return wouldRes(i18n.T("shell.json still carries retired sidebar records or lacks sidebar settings")).
			withFix(i18n.T("ryoku doctor migrates it in place"))
	}

	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, migrated, 0o644); err != nil {
		return failRes(i18n.T("could not write %s: %v"), tmp, err)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return failRes(i18n.T("could not replace %s: %v"), path, err)
	}
	return fixedRes(i18n.T("migrated shell.json to the sidebar settings schema"))
}

// migrateSidebarRework retires the frame-bar leaves replaced by sidebars and
// the overlay-incompatible sidebar controls, then seeds missing sidebar settings
// without disturbing sibling records.
func migrateSidebarRework(raw []byte) ([]byte, bool, error) {
	var top map[string]json.RawMessage
	if err := json.Unmarshal(raw, &top); err != nil {
		return nil, false, err
	}
	if top == nil {
		return nil, false, fmt.Errorf("top-level shell config is null")
	}

	changed := false
	frameBarsChanged := false
	if frameBarsRaw, present := top["frameBars"]; present {
		var frameBars map[string]json.RawMessage
		if err := json.Unmarshal(frameBarsRaw, &frameBars); err != nil {
			return nil, false, err
		}

		if menusRaw, present := frameBars["menus"]; present {
			var menus map[string]json.RawMessage
			if err := json.Unmarshal(menusRaw, &menus); err != nil {
				return nil, false, err
			}
			if _, present := menus["quick-settings"]; present {
				delete(menus, "quick-settings")
				repacked, err := json.Marshal(menus)
				if err != nil {
					return nil, false, err
				}
				frameBars["menus"] = repacked
				frameBarsChanged = true
			}
		}

		if surfacesRaw, present := frameBars["surfaces"]; present {
			var surfaces map[string]json.RawMessage
			if err := json.Unmarshal(surfacesRaw, &surfaces); err != nil {
				return nil, false, err
			}
			if _, present := surfaces["stash"]; present {
				delete(surfaces, "stash")
				repacked, err := json.Marshal(surfaces)
				if err != nil {
					return nil, false, err
				}
				frameBars["surfaces"] = repacked
				frameBarsChanged = true
			}
		}

		if frameBarsChanged {
			repacked, err := json.Marshal(frameBars)
			if err != nil {
				return nil, false, err
			}
			top["frameBars"] = repacked
			changed = true
		}
	}

	if _, present := top["sidebars"]; !present {
		seed, err := json.Marshal(defaultSidebars())
		if err != nil {
			return nil, false, err
		}
		top["sidebars"] = seed
		changed = true
	}

	if sidebarsRaw, present := top["sidebars"]; present {
		var sidebars map[string]json.RawMessage
		if err := json.Unmarshal(sidebarsRaw, &sidebars); err != nil {
			return nil, false, err
		}
		if sidebars == nil {
			return nil, false, fmt.Errorf("sidebars config is null")
		}
		sidebarsChanged := false
		legacyWidth, hadLegacyWidth := sidebars["width"]
		for _, key := range []string{"width", "depth", "push", "parallax", "wallpaperSlide"} {
			if _, found := sidebars[key]; found {
				delete(sidebars, key)
				sidebarsChanged = true
			}
		}

		defaults := defaultSidebars()
		if _, found := sidebars["motion"]; !found {
			value, err := json.Marshal(defaults["motion"])
			if err != nil {
				return nil, false, err
			}
			sidebars["motion"] = value
			sidebarsChanged = true
		}
		for _, side := range []string{"left", "right"} {
			fallback := defaults[side].(map[string]any)
			sideRaw, found := sidebars[side]
			if !found {
				seeded := fallback
				if side == "left" && hadLegacyWidth {
					seeded = make(map[string]any, len(fallback))
					for key, value := range fallback {
						seeded[key] = value
					}
					var width any
					if err := json.Unmarshal(legacyWidth, &width); err != nil {
						return nil, false, err
					}
					seeded["width"] = width
				}
				value, err := json.Marshal(seeded)
				if err != nil {
					return nil, false, err
				}
				sidebars[side] = value
				sidebarsChanged = true
				continue
			}

			var current map[string]json.RawMessage
			if err := json.Unmarshal(sideRaw, &current); err != nil {
				return nil, false, err
			}
			if current == nil {
				return nil, false, fmt.Errorf("sidebars.%s config is null", side)
			}
			sideChanged := false
			if _, exists := current["geometry"]; exists {
				delete(current, "geometry")
				sideChanged = true
			}
			var position string
			if json.Unmarshal(current["position"], &position) == nil {
				switch position {
				case "top-left", "top-right":
					current["position"] = json.RawMessage(`"top"`)
					sideChanged = true
				case "bottom-left", "bottom-right":
					current["position"] = json.RawMessage(`"bottom"`)
					sideChanged = true
				}
			}
			for key, fallbackValue := range fallback {
				if _, exists := current[key]; exists {
					continue
				}
				if side == "left" && key == "width" && hadLegacyWidth {
					current[key] = append(json.RawMessage(nil), legacyWidth...)
				} else {
					value, err := json.Marshal(fallbackValue)
					if err != nil {
						return nil, false, err
					}
					current[key] = value
				}
				sideChanged = true
			}
			if sideChanged {
				value, err := json.Marshal(current)
				if err != nil {
					return nil, false, err
				}
				sidebars[side] = value
				sidebarsChanged = true
			}
		}
		if sidebarsChanged {
			repacked, err := json.Marshal(sidebars)
			if err != nil {
				return nil, false, err
			}
			top["sidebars"] = repacked
			changed = true
		}
	}
	if !changed {
		return nil, false, nil
	}

	out, err := json.MarshalIndent(top, "", "  ")
	if err != nil {
		return nil, false, err
	}
	return append(out, '\n'), true, nil
}
