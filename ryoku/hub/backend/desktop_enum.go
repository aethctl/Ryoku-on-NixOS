package main

import (
	"bufio"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func listCursorThemes() []string {
	seen := map[string]bool{}
	for _, dir := range iconSearchDirs() {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}

		for _, e := range entries {
			themeDir := filepath.Join(dir, e.Name())
			info, err := os.Stat(themeDir)
			if err != nil || !info.IsDir() {
				continue
			}

			if info, err := os.Stat(filepath.Join(themeDir, "cursors")); err == nil && info.IsDir() {
				seen[e.Name()] = true
			}
		}
	}

	out := make([]string, 0, len(seen))
	for name := range seen {
		out = append(out, name)
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

	var candidates []string
	candidates = append(candidates,
		filepath.Join(home, ".icons"),
		filepath.Join(dataHome, "icons"),
	)

	for _, root := range filepath.SplitList(os.Getenv("XDG_DATA_DIRS")) {
		if strings.TrimSpace(root) != "" {
			candidates = append(candidates, filepath.Join(root, "icons"))
		}
	}

	candidates = append(candidates,
		filepath.Join(home, ".nix-profile", "share", "icons"),
		"/run/current-system/sw/share/icons",
		"/usr/share/icons",
		"/usr/local/share/icons",
	)

	if user := os.Getenv("USER"); user != "" {
		candidates = append(
			candidates,
			filepath.Join("/etc/profiles/per-user", user, "share", "icons"),
		)
	}

	seen := map[string]bool{}
	out := make([]string, 0, len(candidates))
	for _, dir := range candidates {
		dir = filepath.Clean(dir)
		if dir == "." || dir == "" || seen[dir] {
			continue
		}
		seen[dir] = true
		out = append(out, dir)
	}
	return out
}

func xkbRuleFiles(name string) []string {
	var candidates []string

	if dir := strings.TrimSpace(os.Getenv("RYOKU_XKB_RULES_DIR")); dir != "" {
		candidates = append(candidates, filepath.Join(dir, name+".lst"))
	}

	if root := strings.TrimSpace(os.Getenv("XKB_CONFIG_ROOT")); root != "" {
		candidates = append(candidates, filepath.Join(root, "rules", name+".lst"))
	}

	candidates = append(candidates,
		filepath.Join("/usr/share/X11/xkb/rules", name+".lst"),
		filepath.Join("/usr/local/share/X11/xkb/rules", name+".lst"),
	)

	seen := map[string]bool{}
	out := make([]string, 0, len(candidates))
	for _, path := range candidates {
		path = filepath.Clean(path)
		if seen[path] {
			continue
		}
		seen[path] = true
		out = append(out, path)
	}
	return out
}

func listKbLayouts() []map[string]string {
	for _, name := range []string{"base", "evdev"} {
		for _, path := range xkbRuleFiles(name) {
			if out := parseXkbLayouts(path); len(out) > 0 {
				return out
			}
		}
	}

	out := []map[string]string{}
	for _, code := range []string{"us", "gb", "de", "fr", "es", "it", "ru", "jp"} {
		out = append(out, map[string]string{
			"code": code,
			"name": strings.ToUpper(code),
		})
	}
	return out
}

func listKbVariants(layout string) []map[string]string {
	for _, name := range []string{"base", "evdev"} {
		for _, path := range xkbRuleFiles(name) {
			if out := parseXkbVariants(path, layout); len(out) > 0 {
				return out
			}
		}
	}
	return []map[string]string{}
}

func parseXkbVariants(path, layout string) []map[string]string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	var out []map[string]string
	inVariants := false

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		text := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(text, "!") {
			inVariants = text == "! variant"
			continue
		}

		if !inVariants || text == "" {
			continue
		}

		fields := strings.Fields(text)
		if len(fields) < 2 {
			continue
		}

		code := fields[0]
		rest := strings.TrimSpace(strings.TrimPrefix(text, code))
		layouts, desc, ok := strings.Cut(rest, ":")
		if !ok {
			continue
		}

		match := false
		for _, candidate := range strings.Split(layouts, ",") {
			if strings.TrimSpace(candidate) == layout {
				match = true
				break
			}
		}

		if !match {
			continue
		}

		out = append(out, map[string]string{
			"code": code,
			"name": strings.TrimSpace(desc),
		})
	}

	return out
}

func parseXkbLayouts(path string) []map[string]string {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	var out []map[string]string
	inLayouts := false

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		text := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(text, "!") {
			inLayouts = text == "! layout"
			continue
		}

		if !inLayouts || text == "" {
			continue
		}

		fields := strings.Fields(text)
		if len(fields) < 2 {
			continue
		}

		code := fields[0]
		name := strings.TrimSpace(strings.TrimPrefix(text, code))

		out = append(out, map[string]string{
			"code": code,
			"name": name,
		})
	}

	return out
}
