package keyboard

import (
	"bufio"
	"os"
	"strings"
)

// The xkb rules base names every layout and variant twice over: a code the
// compositor and localectl compile ("us", "fr", the variant "azerty") and a
// human description a picker shows ("English (US)", "French (AZERTY)"). The Hub
// layout picker shows the description and stores the code behind it, so the
// neutral store is meant to hold codes. This reads the base the other way, from
// a stored description back to its code, which is what doctor needs to repair a
// store an older writer left holding the description itself.

// XkbRulesPaths lists the rules .lst files to read, most complete first. A
// package var so a test points it at a fixture; the system paths are fixed
// otherwise.
var XkbRulesPaths = []string{
	"/usr/share/X11/xkb/rules/base.lst",
	"/usr/share/X11/xkb/rules/evdev.lst",
}

// XkbCatalog is the layout and variant tables from the rules base. Variants are
// scoped by layout, because xkb ties each variant description to the layouts it
// belongs to and the same description recurs across layouts.
type XkbCatalog struct {
	layouts     map[string]bool              // valid layout codes
	layoutName  map[string]string            // lowercased description -> layout code
	variants    map[string]map[string]bool   // layout code -> valid variant codes
	variantName map[string]map[string]string // layout code -> lowercased description -> variant code
}

// LoadXkbCatalog parses the first rules file that yields any layout. An empty
// catalog (no base readable) reports Empty, so a caller declines to judge a
// value it has no base to check against rather than calling everything invalid.
func LoadXkbCatalog() *XkbCatalog {
	for _, p := range XkbRulesPaths {
		if c := parseXkbCatalog(p); c != nil && len(c.layouts) > 0 {
			return c
		}
	}
	return &XkbCatalog{}
}

// Empty reports that no rules base could be read, so nothing can be checked.
func (c *XkbCatalog) Empty() bool { return len(c.layouts) == 0 }

// IsLayout reports whether code is a real xkb layout code.
func (c *XkbCatalog) IsLayout(code string) bool { return c.layouts[code] }

// LayoutByName resolves a layout description ("English (US)") to its code.
func (c *XkbCatalog) LayoutByName(name string) (string, bool) {
	code, ok := c.layoutName[strings.ToLower(strings.TrimSpace(name))]
	return code, ok
}

// IsVariant reports whether code is a real variant of layout.
func (c *XkbCatalog) IsVariant(layout, code string) bool { return c.variants[layout][code] }

// VariantByName resolves a variant description within one layout to its code.
func (c *XkbCatalog) VariantByName(layout, name string) (string, bool) {
	code, ok := c.variantName[layout][strings.ToLower(strings.TrimSpace(name))]
	return code, ok
}

const (
	xkbSectionNone = iota
	xkbSectionLayout
	xkbSectionVariant
)

// parseXkbCatalog reads the "! layout" and "! variant" blocks of a rules .lst.
// A layout line is "<code>  <description>"; a variant line is
// "<code>  <layout[,layout...]>: <description>". nil when the file is absent.
func parseXkbCatalog(path string) *XkbCatalog {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	c := &XkbCatalog{
		layouts:     map[string]bool{},
		layoutName:  map[string]string{},
		variants:    map[string]map[string]bool{},
		variantName: map[string]map[string]string{},
	}
	section := xkbSectionNone
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		t := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(t, "!") {
			switch t {
			case "! layout":
				section = xkbSectionLayout
			case "! variant":
				section = xkbSectionVariant
			default:
				section = xkbSectionNone
			}
			continue
		}
		if section == xkbSectionNone || t == "" {
			continue
		}
		fields := strings.Fields(t)
		if len(fields) < 2 {
			continue
		}
		code := fields[0]
		rest := strings.TrimSpace(strings.TrimPrefix(t, code))
		if section == xkbSectionLayout {
			c.layouts[code] = true
			c.layoutName[strings.ToLower(rest)] = code
			continue
		}
		layouts, desc, ok := strings.Cut(rest, ":")
		if !ok {
			continue
		}
		desc = strings.TrimSpace(desc)
		for _, l := range strings.Split(layouts, ",") {
			l = strings.TrimSpace(l)
			if l == "" {
				continue
			}
			if c.variants[l] == nil {
				c.variants[l] = map[string]bool{}
				c.variantName[l] = map[string]string{}
			}
			c.variants[l][code] = true
			if desc != "" {
				c.variantName[l][strings.ToLower(desc)] = code
			}
		}
	}
	return c
}
