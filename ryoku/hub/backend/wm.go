package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	wm "ryoku-wm"
)

// ryoku-hub wm is the neutral compositor-switch backend for the Hub. It answers
// two questions and mutates nothing: which providers exist and their state
// (list), and what a switch to one would cost (preview). The switch itself is
// `ryoku wm use <name>`, a reversible pacman transaction the Hub launches, so
// there is never a second package path with different rollback semantics.
//
//	wm list             every provider: name, package, installed, active, caps
//	wm preview <name>   the honest switch report, degrading when the target's
//	                    provider binary is absent the way `ryoku wm use` does

func runWm(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("wm needs list|preview")
	}
	switch args[0] {
	case "list":
		return wmList()
	case "preview":
		if len(args) < 2 {
			return fmt.Errorf("wm preview needs a name")
		}
		return wmPreview(args[1])
	default:
		return fmt.Errorf("wm needs list|preview")
	}
}

func wmPackage(name string) string { return "ryoku-desktop-" + name }

// wmDeployed reports whether a provider works without its package: its binary
// answers caps and its config tree exists. Both must hold, since a provider
// with no config tree would bring up a bare compositor.
func wmDeployed(name string) bool {
	if _, err := wm.OpenNamed(name).Caps(); err != nil {
		return false
	}
	dir := wm.ConfigDir(name)
	if dir == "" {
		return false
	}
	_, err := os.Stat(filepath.Join(configHome(), dir))
	return err == nil
}

// wmProvider is one row of `wm list`. Package and configDir travel with the row
// so the Hub can build the switch and the keep-or-remove cleanup from data,
// never from a compositor name spelled in QML.
type wmProvider struct {
	Name      string   `json:"name"`
	Package   string   `json:"package"`
	ConfigDir string   `json:"configDir"`
	Installed bool     `json:"installed"`
	Active    bool     `json:"active"`
	Caps      *wm.Caps `json:"caps,omitempty"`
}

func wmList() error {
	active := wm.Detect().Name
	out := []wmProvider{}
	for _, name := range wm.Providers() {
		p := wmProvider{
			Name:      name,
			Package:   wmPackage(name),
			ConfigDir: wm.ConfigDir(name),
			Installed: pkgInstalled(wmPackage(name)),
			Active:    name == active,
		}
		// The manifest is present only when the provider binary is, so a box
		// that has never installed a compositor still lists it as a target.
		if caps, err := wm.OpenNamed(name).Caps(); err == nil {
			p.Caps = &caps
		}
		out = append(out, p)
	}
	return printJSON(out)
}

// wmPreviewReport is the honest switch report the confirmation sheet renders.
// exact is false when the target's provider binary is absent: the dry run could
// not run, so unhonored is empty and the Hub says "install the package to see
// the exact list", the same degradation `ryoku wm use` prints.
type wmPreviewReport struct {
	Target    string `json:"target"`
	Active    string `json:"active"`
	Package   string `json:"package"`
	ConfigDir string `json:"configDir"`
	Installed bool   `json:"installed"`
	Available bool   `json:"available"`
	// Deployed means the target works without its package: its provider answers
	// and its config tree is in place, which is what a checkout deploy leaves.
	// Such a box switches by picking the session at the greeter, so the sheet
	// must offer that instead of reporting a package it will never use.
	Deployed     bool           `json:"deployed"`
	KeybindCount int            `json:"keybindCount"`
	Exact        bool           `json:"exact"`
	Provider     string         `json:"provider,omitempty"`
	Unhonored    []wm.Unhonored `json:"unhonored"`
	ReloadNeeded bool           `json:"reloadNeeded"`
}

func wmPreview(name string) error {
	if !wmKnown(name) {
		return fmt.Errorf("unknown compositor %q", name)
	}
	store := desktopStorePath()
	out := wmPreviewReport{
		Target:       name,
		Active:       wm.Detect().Name,
		Package:      wmPackage(name),
		ConfigDir:    wm.ConfigDir(name),
		Installed:    pkgInstalled(wmPackage(name)),
		Available:    pkgAvailable(wmPackage(name)),
		Deployed:     wmDeployed(name),
		KeybindCount: storeKeybindCount(store),
		Unhonored:    []wm.Unhonored{},
	}
	// Best-effort: the target may not be installed yet, and DryRun then errors
	// rather than authoring its config. The report degrades, it does not fail.
	if rep, err := wm.OpenNamed(name).DryRun(store); err == nil {
		out.Exact = true
		out.Provider = rep.Provider
		out.ReloadNeeded = rep.ReloadNeeded
		if len(rep.Unhonored) > 0 {
			out.Unhonored = rep.Unhonored
		}
	}
	return printJSON(out)
}

func wmKnown(name string) bool {
	for _, p := range wm.Providers() {
		if p == name {
			return true
		}
	}
	return false
}

// pkgAvailable reports whether a package can be installed from a synced repo
// (pacman -Si succeeds), so a target on a channel that does not carry it yet is
// shown as unavailable instead of a switch that would fail at the transaction.
func pkgAvailable(pkg string) bool { return exec.Command("pacman", "-Si", pkg).Run() == nil }

// storeKeybindCount is the neutral keybind carry-over: the count `ryoku wm use`
// prints, so the sheet says the same number. Zero when the store or field is
// absent.
func storeKeybindCount(store string) int {
	raw, err := os.ReadFile(store)
	if err != nil {
		return 0
	}
	var doc struct {
		Desktop struct {
			Keybinds       json.RawMessage `json:"keybinds"`
			KeybindRebinds json.RawMessage `json:"keybindRebinds"`
		} `json:"desktop"`
	}
	if json.Unmarshal(raw, &doc) != nil {
		return 0
	}
	return jsonLen(doc.Desktop.Keybinds) + jsonLen(doc.Desktop.KeybindRebinds)
}

// jsonLen counts entries in a JSON array or object, or 0 for anything else.
func jsonLen(raw json.RawMessage) int {
	if len(raw) == 0 {
		return 0
	}
	var arr []json.RawMessage
	if json.Unmarshal(raw, &arr) == nil {
		return len(arr)
	}
	var obj map[string]json.RawMessage
	if json.Unmarshal(raw, &obj) == nil {
		return len(obj)
	}
	return 0
}
