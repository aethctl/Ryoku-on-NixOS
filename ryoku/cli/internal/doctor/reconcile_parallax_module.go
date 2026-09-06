package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
)

// Existing installs may carry a persisted quick-settings rail from before
// Parallax existed. New installs get Parallax from MenuCatalog defaults, while
// this migration appends it to genuine existing quick-settings rails.
func reconcileParallaxModule(checkOnly bool) recResult {
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")

	raw, err := os.ReadFile(path)
	if err != nil {
		return okRes("no shell.json yet (seeded on first shell run)")
	}

	migrated, changed, err := addParallaxModule(raw)
	if err != nil {
		return warnRes("shell.json does not parse (%v); the shell falls back to defaults", err).
			withFix("delete %s to re-seed it", path)
	}

	if !changed {
		return okRes("quick-settings rail carries the parallax tab (or a custom module list)")
	}

	if checkOnly {
		return wouldRes("quick-settings rail predates the Parallax tab").
			withFix("ryoku doctor adds it to the quick-settings rail")
	}

	tmp := path + ".ryoku-tmp"

	if err := os.WriteFile(tmp, migrated, 0o644); err != nil {
		return failRes("could not write %s: %v", tmp, err)
	}

	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return failRes("could not replace %s: %v", path, err)
	}

	return fixedRes("added the parallax tab to the quick-settings rail")
}

func addParallaxModule(raw []byte) ([]byte, bool, error) {
	var top map[string]json.RawMessage
	if err := json.Unmarshal(raw, &top); err != nil {
		return nil, false, err
	}

	frameRaw, ok := top["frameBars"]
	if !ok {
		return nil, false, nil
	}

	var frame map[string]json.RawMessage
	if err := json.Unmarshal(frameRaw, &frame); err != nil {
		return nil, false, err
	}

	menusRaw, ok := frame["menus"]
	if !ok {
		return nil, false, nil
	}

	var menus map[string]json.RawMessage
	if err := json.Unmarshal(menusRaw, &menus); err != nil {
		return nil, false, err
	}

	qsRaw, ok := menus["quick-settings"]
	if !ok {
		return nil, false, nil
	}

	var qs map[string]json.RawMessage
	if err := json.Unmarshal(qsRaw, &qs); err != nil {
		return nil, false, err
	}

	var modules []string
	if err := json.Unmarshal(qs["modules"], &modules); err != nil {
		return nil, false, nil
	}

	hasHome := false

	for _, module := range modules {
		if module == "parallax" {
			return nil, false, nil
		}

		if module == "home" {
			hasHome = true
		}
	}

	if !hasHome {
		return nil, false, nil
	}

	next, err := json.Marshal(append(modules, "parallax"))
	if err != nil {
		return nil, false, err
	}

	qs["modules"] = next

	qsBytes, err := json.Marshal(qs)
	if err != nil {
		return nil, false, err
	}

	menus["quick-settings"] = qsBytes

	menusBytes, err := json.Marshal(menus)
	if err != nil {
		return nil, false, err
	}

	frame["menus"] = menusBytes

	frameBytes, err := json.Marshal(frame)
	if err != nil {
		return nil, false, err
	}

	top["frameBars"] = frameBytes

	out, err := json.MarshalIndent(top, "", "  ")
	if err != nil {
		return nil, false, err
	}

	return append(out, '\n'), true, nil
}
