package wm

import (
	"os"
	"path/filepath"
	"strings"
)

// The only place allowed to care which compositor is running. It resolves an
// identity into a provider name once; every later decision reads Caps.

// Provider names name a binary (ryoku-wm-<name>) and a settings domain
// (wm.<name>.*), so they are part of the on-disk contract.
const (
	ProviderHyprland = "hyprland"
	ProviderNiri     = "niri"
)

type Detection struct {
	Name string
	// Live means the compositor is running for this user, so actions and watch
	// are meaningful. False means the box is configured for it and only caps
	// and apply are safe: doctor runs in a chroot right after install, where
	// the config tree exists but no compositor does.
	Live bool
	// Source records what answered, for doctor output and bug reports.
	Source string
}

// Presence of an instance handle beats XDG_CURRENT_DESKTOP, which a user or a
// greeter can set to anything.
var envProviders = []struct {
	env  string
	name string
}{
	{"HYPRLAND_INSTANCE_SIGNATURE", ProviderHyprland},
	{"NIRI_SOCKET", ProviderNiri},
}

// Every compositor-scoped delivery allowlist derives from this, so the mapping
// lives here once instead of in materialize, user_edits and doctor.
var configDirs = map[string]string{
	ProviderHyprland: "hypr",
	ProviderNiri:     "niri",
}

func ConfigDir(name string) string { return configDirs[name] }

// configSeeds are the per-machine files under a provider's config dir that are
// seeded once and then owned by the machine: the runtime rewrites them (display
// and GPU pins) or the user edits them in place. Delivery reads this for EVERY
// provider, not just the active one, so an update under one compositor never
// prunes another's. Naming them per provider matters because the file names are
// the compositor's own, not a shared shape.
var configSeeds = map[string][]string{
	ProviderHyprland: {"monitors.lua", "gpu.lua", "keyboard.lua", "user.lua"},
	// niri seeds its hand-edit file too, unlike Hyprland: config.kdl includes
	// monitors_user.kdl by name and a missing include is a hard config error,
	// so the file has to exist from first boot. Being a seed is also what stops
	// an update re-laying it over a user's edits.
	ProviderNiri: {"monitors.kdl", "gpu.kdl", "keyboard.kdl", "user.kdl", "monitors_user.kdl"},
}

// ConfigSeeds returns the seeded, machine-owned files for a provider, as paths
// relative to ~/.config. Empty for an unknown provider.
func ConfigSeeds(name string) []string {
	dir := configDirs[name]
	if dir == "" {
		return nil
	}
	out := make([]string, 0, len(configSeeds[name]))
	for _, leaf := range configSeeds[name] {
		out = append(out, dir+"/"+leaf)
	}
	return out
}

// ConfigUserOwned are the files a user edits in place under a provider's config
// dir. The overlay must never lay a frozen copy over one, or an update would
// silently wipe an edit made after it was captured.
func ConfigUserOwned(name string) []string {
	seeds := ConfigSeeds(name)
	dir := configDirs[name]
	if dir == "" {
		return nil
	}
	// Hyprland's monitors_user.lua is optional, so it is hand-created rather
	// than seeded; niri's equivalent is already in its seed list above.
	if name == ProviderHyprland {
		return append(seeds, dir+"/monitors_user.lua")
	}
	return seeds
}

// Providers is stable order, so generated config and installer prompts do not
// reshuffle between runs.
func Providers() []string { return []string{ProviderHyprland, ProviderNiri} }

// Detect resolves the active provider: RYOKU_WM so a developer can drive one
// without that session, then a live session handle, then XDG_CURRENT_DESKTOP,
// then a config tree.
func Detect() Detection {
	if forced := strings.TrimSpace(os.Getenv("RYOKU_WM")); forced != "" {
		return Detection{Name: forced, Live: liveFor(forced), Source: "RYOKU_WM"}
	}
	for _, p := range envProviders {
		if os.Getenv(p.env) != "" {
			return Detection{Name: p.name, Live: true, Source: p.env}
		}
	}
	// Colon-separated and case-inconsistent across greeters, so match a
	// component rather than the whole string.
	desktop := strings.ToLower(os.Getenv("XDG_CURRENT_DESKTOP"))
	for _, name := range Providers() {
		for _, part := range strings.Split(desktop, ":") {
			if strings.TrimSpace(part) == name {
				return Detection{Name: name, Live: true, Source: "XDG_CURRENT_DESKTOP"}
			}
		}
	}
	home, err := os.UserHomeDir()
	if err == nil {
		for _, name := range Providers() {
			dir := configDirs[name]
			if dir == "" {
				continue
			}
			if _, err := os.Stat(filepath.Join(home, ".config", dir)); err == nil {
				return Detection{Name: name, Live: false, Source: "config tree"}
			}
		}
	}
	return Detection{}
}

// liveFor stops a forced provider claiming liveness it cannot back.
func liveFor(name string) bool {
	for _, p := range envProviders {
		if p.name == name && os.Getenv(p.env) != "" {
			return true
		}
	}
	return false
}
