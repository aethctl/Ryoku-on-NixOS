package doctor

import (
	"encoding/json"
	"path/filepath"
	"strconv"
	"strings"

	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
	wm "ryoku-wm"
)

// ---- reconciler: a width cycle needs more than one width ---------------------
//
// The window width setting drives a keybind that steps a window through the
// widths it lists. The Hub used to offer a single-width choice, which parses and
// applies cleanly but leaves the key nothing to step to, so the bind reads as
// broken. The choice is gone and the provider now falls back to its default when
// it is handed fewer than two widths, so no session has a dead key; a store
// seeded with the old value keeps showing it in the Hub until it is replaced.

const (
	widthCycleKey     = "presetColumnWidths"
	widthCycleDefault = "0.33333, 0.5, 0.66667"
)

func reconcileWidthCycle(checkOnly bool) recResult {
	store := filepath.Join(sys.ConfigHome(), "ryoku", "desktop.json")
	raw := readFileSafe(store)
	stored, ok := widthCycleStored(raw)
	if !ok {
		return okRes(i18n.T("no window width cycle recorded yet"))
	}
	if n := countWidths(stored); n >= 2 {
		return okRes(i18n.T("the window width cycle steps through %d widths"), n)
	}

	if checkOnly {
		return wouldRes(i18n.T("the window width cycle holds only %q, so the key that steps a window through it has nowhere to go"), stored).
			withFix("ryoku doctor")
	}

	fixed, err := rewriteWidthCycle(raw, widthCycleDefault)
	if err != nil {
		return failRes(i18n.T("could not update the window width cycle: %v"), err)
	}
	if err := writeStore(store, []byte(fixed)); err != nil {
		return failRes(i18n.T("could not save the window width cycle: %v"), err).withFix("ryoku doctor")
	}
	// Re-author the active provider's config so the key works in this session.
	_, _ = wm.Open().Apply(store)
	return fixedRes(i18n.T("the window width cycle held only %q, which the stepping key cannot use; set it to %s"), stored, widthCycleDefault)
}

// widthCycleStored reads the setting as the Hub writes it. The value is a
// comma-separated string, and an older store may hold a JSON array, so both are
// flattened to the string form the rest of this reconciler compares.
func widthCycleStored(raw string) (string, bool) {
	var doc struct {
		Wm map[string]map[string]json.RawMessage `json:"wm"`
	}
	if json.Unmarshal([]byte(raw), &doc) != nil {
		return "", false
	}
	for _, provider := range doc.Wm {
		v, ok := provider[widthCycleKey]
		if !ok {
			continue
		}
		var s string
		if json.Unmarshal(v, &s) == nil {
			return s, true
		}
		var nums []float64
		if json.Unmarshal(v, &nums) == nil {
			parts := make([]string, 0, len(nums))
			for _, n := range nums {
				parts = append(parts, strconv.FormatFloat(n, 'g', -1, 64))
			}
			return strings.Join(parts, ", "), true
		}
	}
	return "", false
}

// countWidths counts the widths a cycle actually offers, ignoring empty slots so
// a trailing comma is not mistaken for a second width.
func countWidths(s string) int {
	n := 0
	for _, part := range strings.Split(s, ",") {
		if strings.TrimSpace(part) != "" {
			n++
		}
	}
	return n
}

// rewriteWidthCycle replaces the value wherever a provider holds it, leaving
// every other key in the store as it was.
func rewriteWidthCycle(raw, value string) (string, error) {
	var doc map[string]json.RawMessage
	if err := json.Unmarshal([]byte(raw), &doc); err != nil {
		return "", err
	}
	var byProvider map[string]map[string]json.RawMessage
	if err := json.Unmarshal(doc["wm"], &byProvider); err != nil {
		return "", err
	}
	encoded, err := json.Marshal(value)
	if err != nil {
		return "", err
	}
	for name, provider := range byProvider {
		if _, ok := provider[widthCycleKey]; !ok {
			continue
		}
		provider[widthCycleKey] = encoded
		byProvider[name] = provider
	}
	section, err := json.Marshal(byProvider)
	if err != nil {
		return "", err
	}
	doc["wm"] = section
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return "", err
	}
	return string(out) + "\n", nil
}
