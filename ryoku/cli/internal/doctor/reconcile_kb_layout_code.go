package doctor

import (
	"encoding/json"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/keyboard"
	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
	wm "ryoku-wm"
)

// ---- reconciler: keyboard layout stored as a code, not a display name --------
//
// The neutral store must hold xkb codes: "us", "fr", or a comma family "fr,us",
// the form the providers render, `ryoku keyboard apply` hands localectl, and
// xkbcommon compiles. The Hub layout picker shows the human description and
// writes the code behind it, but a store an older writer seeded can carry the
// description itself ("English (US)"). xkbcommon cannot compile a description as
// a layout, so the compositor logs a BadKeymap and drops to us, and the pick is
// silently ignored on any layout whose description is not the us one.
//
// This resolves such a description back to its code against the same xkb rules
// base the picker reads, per element of a comma family, and leaves a store
// already on codes untouched. A value that is neither a code nor a known
// description is left in place and reported, never guessed at.

func reconcileKbLayoutCode(checkOnly bool) recResult {
	store := filepath.Join(sys.ConfigHome(), "ryoku", "desktop.json")
	raw := readFileSafe(store)
	layout, hasLayout := hyprGetKbLayout(raw)
	variant, hasVariant := hyprGetKbVariant(raw)
	if strings.TrimSpace(layout) == "" && strings.TrimSpace(variant) == "" {
		return okRes(i18n.T("no session keyboard layout recorded yet"))
	}

	cat := keyboard.LoadXkbCatalog()
	if cat.Empty() {
		return okRes(i18n.T("keyboard layout could not be checked against the xkb rules base"))
	}

	p := planKbCodes(layout, hasLayout, variant, hasVariant, cat)
	if p.clean() {
		return okRes(i18n.T("keyboard layout %q is stored as an xkb code"), layout)
	}

	// Nothing resolves: the value is not a code and no description matches it, so
	// there is nothing to safely set. Leave it and say what it is.
	if !p.changed() {
		return warnRes(i18n.T("the keyboard layout %q is not an xkb code and no name in the rules base matches it, so it was left unchanged"), strings.Join(p.unresolved, ", "))
	}

	if checkOnly {
		r := kbDriftWould(p)
		if len(p.unresolved) > 0 {
			r = wouldRes(i18n.T("some keyboard layout names resolve to xkb codes, but %q matches no code or name in the rules base and is left as is"), strings.Join(p.unresolved, ", "))
		}
		return r.withFix("ryoku doctor")
	}

	fixed, err := rewriteInputCodes(raw, p)
	if err != nil {
		return failRes(i18n.T("could not update the keyboard layout in desktop settings: %v"), err)
	}
	if err := writeStore(store, []byte(fixed)); err != nil {
		return failRes(i18n.T("could not save the corrected keyboard layout: %v"), err).withFix("ryoku doctor")
	}
	// Re-author the active provider's config from the corrected store so the fix
	// reaches the running session without the user touching anything.
	_, _ = wm.Open().Apply(store)
	if len(p.unresolved) > 0 {
		return warnRes(i18n.T("set the keyboard layout names that resolve to xkb codes, but left %q unchanged: no code or name in the rules base matches it"), strings.Join(p.unresolved, ", "))
	}
	return kbDriftFixed(p)
}

// kbCodePlan is the resolution of a stored layout and variant against the rules
// base: the corrected strings, and the descriptions nothing in the base could
// resolve, kept for the report.
type kbCodePlan struct {
	layoutOld, layoutNew   string
	variantOld, variantNew string
	unresolved             []string
}

func (p kbCodePlan) changed() bool {
	return p.layoutOld != p.layoutNew || p.variantOld != p.variantNew
}

// clean is true when the store already holds codes: nothing changed and nothing
// was left unresolved.
func (p kbCodePlan) clean() bool { return !p.changed() && len(p.unresolved) == 0 }

// planKbCodes resolves each comma element of the layout and the variant. A code
// is kept, a description becomes its code, and anything else is kept in place
// and recorded as unresolved. Variants are matched within the layout code at the
// same position, because xkb aligns the variant slots to the layout slots.
func planKbCodes(layout string, hasLayout bool, variant string, hasVariant bool, cat *keyboard.XkbCatalog) kbCodePlan {
	p := kbCodePlan{layoutOld: layout, layoutNew: layout, variantOld: variant, variantNew: variant}

	var layoutCodes []string
	if hasLayout {
		parts := strings.Split(layout, ",")
		out := make([]string, len(parts))
		for i, elRaw := range parts {
			el := strings.TrimSpace(elRaw)
			switch {
			case el == "":
				out[i] = ""
			case cat.IsLayout(el):
				out[i] = el
			default:
				if code, ok := cat.LayoutByName(el); ok {
					out[i] = code
				} else {
					out[i] = el
					p.unresolved = append(p.unresolved, el)
				}
			}
			layoutCodes = append(layoutCodes, out[i])
		}
		p.layoutNew = strings.Join(out, ",")
	}

	if hasVariant {
		parts := strings.Split(variant, ",")
		out := make([]string, len(parts))
		for i, elRaw := range parts {
			el := strings.TrimSpace(elRaw)
			lay := ""
			if i < len(layoutCodes) {
				lay = layoutCodes[i]
			}
			switch {
			case el == "":
				out[i] = ""
			case lay != "" && cat.IsVariant(lay, el):
				out[i] = el
			default:
				if code, ok := cat.VariantByName(lay, el); lay != "" && ok {
					out[i] = code
				} else {
					out[i] = el
					p.unresolved = append(p.unresolved, el)
				}
			}
		}
		p.variantNew = strings.Join(out, ",")
	}
	return p
}

// kbDriftWould names the drift for a --check run: what is stored and the code it
// should be, for the layout, the style, or both.
func kbDriftWould(p kbCodePlan) recResult {
	lc := p.layoutOld != p.layoutNew
	vc := p.variantOld != p.variantNew
	switch {
	case lc && vc:
		return wouldRes(i18n.T("the keyboard layout %q and style %q are saved as names, not the xkb codes %q and %q the compositor needs"), p.layoutOld, p.variantOld, p.layoutNew, p.variantNew)
	case vc:
		return wouldRes(i18n.T("the layout style is saved as its name %q, not the xkb variant code %q the compositor needs"), p.variantOld, p.variantNew)
	default:
		return wouldRes(i18n.T("the keyboard layout is saved as its name %q, not the xkb code %q the compositor needs"), p.layoutOld, p.layoutNew)
	}
}

// kbDriftFixed names what was set, and the name it replaced, after a repair.
func kbDriftFixed(p kbCodePlan) recResult {
	lc := p.layoutOld != p.layoutNew
	vc := p.variantOld != p.variantNew
	switch {
	case lc && vc:
		return fixedRes(i18n.T("the keyboard layout and style were saved as names %q and %q; set them to the xkb codes %q and %q"), p.layoutOld, p.variantOld, p.layoutNew, p.variantNew)
	case vc:
		return fixedRes(i18n.T("the layout style was saved as its name %q; set it to the xkb variant code %q"), p.variantOld, p.variantNew)
	default:
		return fixedRes(i18n.T("the keyboard layout was saved as its name %q; set it to the xkb code %q"), p.layoutOld, p.layoutNew)
	}
}

// hyprGetKbVariant pulls desktop.input.kbVariant out of the neutral store.
func hyprGetKbVariant(raw string) (string, bool) {
	var o struct {
		Desktop struct {
			Input struct {
				KbVariant *string `json:"kbVariant"`
			} `json:"input"`
		} `json:"desktop"`
	}
	if json.Unmarshal([]byte(raw), &o) != nil || o.Desktop.Input.KbVariant == nil {
		return "", false
	}
	return *o.Desktop.Input.KbVariant, true
}

// rewriteInputCodes writes the resolved layout and variant back into the store,
// touching only the keys the plan actually changed and leaving every other key
// intact.
func rewriteInputCodes(raw string, p kbCodePlan) (string, error) {
	var doc map[string]any
	if err := json.Unmarshal([]byte(raw), &doc); err != nil {
		return "", err
	}
	desktop, _ := doc["desktop"].(map[string]any)
	if desktop == nil {
		desktop = map[string]any{}
		doc["desktop"] = desktop
	}
	input, _ := desktop["input"].(map[string]any)
	if input == nil {
		input = map[string]any{}
		desktop["input"] = input
	}
	if p.layoutOld != p.layoutNew {
		input["kbLayout"] = p.layoutNew
	}
	if p.variantOld != p.variantNew {
		input["kbVariant"] = p.variantNew
	}
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return "", err
	}
	return string(out), nil
}
