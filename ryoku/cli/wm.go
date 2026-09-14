package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"ryoku-cli/internal/sys"

	i18n "ryoku-i18n"
	wm "ryoku-wm"
)

// cmdWm is the neutral front door to the window-manager provider: what is running
// (status), dispatch an action from a script (act), print the provider's session
// entry (session), and switch compositors as a reversible package op (use).
func cmdWm(args []string) {
	if len(args) == 0 {
		wmUsage()
		os.Exit(2)
	}
	switch args[0] {
	case "status":
		cmdWmStatus()
	case "act":
		cmdWmAct(args[1:])
	case "session":
		cmdWmSession()
	case "use":
		cmdWmUse(args[1:])
	default:
		die("unknown wm command: %s", args[0])
	}
}

func wmUsage() {
	fmt.Print(i18n.T("Usage: ryoku wm <command>\n\n  status            print the detected provider, its capabilities and workspace model\n  use <name>        preview and switch to another compositor (installs its package)\n  act <id> [args]   dispatch a window-manager action through the provider\n  session           print the provider's wayland-session desktop entry\n"))
}

func cmdWmStatus() {
	c := wm.Open()
	d := c.Detection()
	name := d.Name
	if name == "" {
		name = i18n.T("(none)")
	}
	fmt.Printf(i18n.T("Provider: %s\n"), name)
	fmt.Printf(i18n.T("Live: %t\n"), d.Live)
	fmt.Printf(i18n.T("Source: %s\n"), d.Source)
	caps, err := c.Caps()
	if err != nil {
		fmt.Printf(i18n.T("Capabilities: unavailable (%v)\n"), err)
		return
	}
	if caps.Version != "" {
		fmt.Printf(i18n.T("Version: %s\n"), caps.Version)
	}
	fmt.Printf(i18n.T("Workspace model: %s\n"), caps.WorkspaceModel)
	supports := make([]string, 0, len(caps.Supports))
	for _, capability := range caps.Supports {
		supports = append(supports, string(capability))
	}
	sort.Strings(supports)
	fmt.Printf(i18n.T("Capabilities: %s\n"), strings.Join(supports, ", "))
	fmt.Printf(i18n.T("Setting domains: %s\n"), strings.Join(caps.SettingDomains, ", "))
}

// cmdWmAct dispatches an action and maps the two seam errors to distinct exit
// codes so a caller (a keybind, lock.sh) can tell "no compositor" from "this
// compositor cannot". Quiet on success: it runs on the idle and lock paths.
func cmdWmAct(args []string) {
	if len(args) == 0 {
		die("usage: ryoku wm act <action> [args...]")
	}
	err := wm.Open().Act(wm.Action(args[0]), args[1:]...)
	if err == nil {
		return
	}
	fmt.Fprintf(os.Stderr, "ryoku: %v\n", err)
	switch {
	case errors.Is(err, wm.ErrNoProvider):
		os.Exit(3)
	case errors.Is(err, wm.ErrUnsupported):
		os.Exit(4)
	}
	os.Exit(1)
}

// cmdWmSession writes the provider's wayland-session desktop entry verbatim, and
// nothing else, so sddm/setup can redirect it straight into a file.
func cmdWmSession() {
	out, err := wm.Open().Session()
	if err != nil {
		die("%v", err)
	}
	os.Stdout.Write(out)
}

func cmdWmUse(args []string) {
	if len(args) == 0 {
		die("usage: ryoku wm use <name>")
	}
	name := args[0]
	if !knownProvider(name) {
		die("unknown compositor %q; known: %s", name, strings.Join(wm.Providers(), ", "))
	}
	store := filepath.Join(sys.ConfigHome(), "ryoku", "desktop.json")
	active := wm.Detect().Name

	// Preview: the target applying the neutral store reports what it cannot
	// honour. Best-effort, since the provider may not be installed yet.
	report, applyErr := wm.OpenNamed(name).Apply(store)
	printWmSwitchPreview(name, active, store, report, applyErr)

	pkg := "ryoku-desktop-" + name
	if !packageAvailable(pkg) {
		die(i18n.T("cannot switch to %s yet: the %s package is not available on this channel"), name, pkg)
	}
	// A plain pacman transaction (no SNAP_PAC_SKIP) so snap-pac snapshots it and
	// `ryoku rollback` can undo the switch.
	if err := sys.Sudo("pacman", "-S", "--needed", "--noconfirm", pkg); err != nil {
		die(i18n.T("could not install %s: %v"), pkg, err)
	}
	fmt.Printf(i18n.T("Installed %s; %s is the compositor at the next login.\n"), pkg, name)
}

func knownProvider(name string) bool {
	for _, p := range wm.Providers() {
		if p == name {
			return true
		}
	}
	return false
}

func printWmSwitchPreview(name, active, store string, report wm.ApplyReport, applyErr error) {
	fmt.Printf(i18n.T("Preview: switch to %s\n"), name)
	if kb := storeKeybindCount(store); kb > 0 {
		fmt.Printf(i18n.T("  Keybinds: %d carry over unchanged (compositor-neutral).\n"), kb)
	}
	fmt.Print(i18n.T("  Settings: every desktop.* setting carries over; the target honours what it can.\n"))
	switch {
	case applyErr != nil:
		fmt.Printf(i18n.T("  Unavailable features: install %s to preview the exact list.\n"), "ryoku-desktop-"+name)
	case len(report.Unhonored) == 0:
		fmt.Printf(i18n.T("  Unavailable features: none; %s honours every current setting.\n"), name)
	default:
		fmt.Printf(i18n.T("  Unavailable on %s:\n"), name)
		for _, u := range report.Unhonored {
			fmt.Printf("    - %s: %s\n", u.Key, u.Reason)
		}
	}
	if active != "" && active != name {
		fmt.Printf(i18n.T("  Your wm.%s.* settings stay in the store and return if you switch back.\n"), active)
	}
}

// storeKeybindCount counts the neutral keybinds in the store for the honest
// carry-over line; zero when the store or the field is absent.
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
	return rawLen(doc.Desktop.Keybinds) + rawLen(doc.Desktop.KeybindRebinds)
}

// rawLen counts entries in a JSON array or object, or 0 for anything else.
func rawLen(raw json.RawMessage) int {
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

func packageAvailable(pkg string) bool {
	_, err := sys.RunOut("pacman", "-Si", pkg)
	return err == nil
}
