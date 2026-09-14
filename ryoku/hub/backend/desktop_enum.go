package main

import (
	"bufio"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Environment enumeration for the settings pickers: installed cursor themes and
// X11 keyboard layouts/variants. Pure filesystem reads, no compositor.

// listCursorThemes: installed cursor themes = icon-theme dirs with a cursors/
// subdir, across the standard search paths, deduped and sorted.
func listCursorThemes() []string {
	seen := map[string]bool{}
	for _, dir := range iconSearchDirs() {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			if _, err := os.Stat(filepath.Join(dir, e.Name(), "cursors")); err == nil {
				seen[e.Name()] = true
			}
		}
	}
	out := make([]string, 0, len(seen))
	for n := range seen {
		out = append(out, n)
	}
	sort.Strings(out)
	return out
}

func iconSearchDirs() []string {
	home := os.Getenv("HOME")
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		dataHome = filepath.Join(home, ".local", "share")
	}
	return []string{
		filepath.Join(home, ".icons"),
		filepath.Join(dataHome, "icons"),
		"/usr/share/icons",
		"/usr/local/share/icons",
	}
}

// listKbLayouts: X11 layout codes from the xkb rules base, each as {code, name};
// falls back to a small common set if the base is absent.
func listKbLayouts() []map[string]string {
	out := parseXkbLayouts("/usr/share/X11/xkb/rules/base.lst")
	if len(out) == 0 {
		out = parseXkbLayouts("/usr/share/X11/xkb/rules/evdev.lst")
	}
	if len(out) == 0 {
		for _, c := range []string{"us", "gb", "de", "fr", "es", "it", "ru", "jp"} {
			out = append(out, map[string]string{"code": c, "name": strings.ToUpper(c)})
		}
	}
	return out
}

// listKbVariants: X11 variant codes for one layout, each as {code, name}; an
// unknown layout (or absent base) yields [].
func listKbVariants(layout string) []map[string]string {
	out := parseXkbVariants("/usr/share/X11/xkb/rules/base.lst", layout)
	if len(out) == 0 {
		out = parseXkbVariants("/usr/share/X11/xkb/rules/evdev.lst", layout)
	}
	if out == nil {
		out = []map[string]string{}
	}
	return out
}

// parseXkbVariants reads the "! variant" block, keeping entries for one layout.
// Lines look like "  <variant>  <layout>: <description>"; the layout field can
// carry several comma-separated codes, so it is split before matching.
func parseXkbVariants(path, layout string) []map[string]string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []map[string]string
	in := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		t := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(t, "!") {
			in = t == "! variant"
			continue
		}
		if !in || t == "" {
			continue
		}
		fields := strings.Fields(t)
		if len(fields) < 2 {
			continue
		}
		code := fields[0]
		rest := strings.TrimSpace(strings.TrimPrefix(t, code))
		layouts, desc, ok := strings.Cut(rest, ":")
		if !ok {
			continue
		}
		match := false
		for _, l := range strings.Split(layouts, ",") {
			if strings.TrimSpace(l) == layout {
				match = true
				break
			}
		}
		if !match {
			continue
		}
		out = append(out, map[string]string{"code": code, "name": strings.TrimSpace(desc)})
	}
	return out
}

// parseXkbLayouts reads the "! layout" block of an xkb rules .lst file.
func parseXkbLayouts(path string) []map[string]string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	var out []map[string]string
	in := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		t := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(t, "!") {
			in = t == "! layout"
			continue
		}
		if !in || t == "" {
			continue
		}
		fields := strings.Fields(t)
		if len(fields) < 2 {
			continue
		}
		code := fields[0]
		name := strings.TrimSpace(strings.TrimPrefix(t, code))
		out = append(out, map[string]string{"code": code, "name": name})
	}
	return out
}
