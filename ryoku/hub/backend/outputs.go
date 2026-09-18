package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	wm "ryoku-wm"
)

// outputs is the display page's backend. It enumerates the connected screens
// through the seam, applies a layout the page built, and keeps named layout
// profiles, so the Hub never spells a compositor or its display tool. Enumeration
// is the provider's full state read; apply and profiles hand the neutral layout
// to the provider, which persists it and applies live.
//
// Profiles are Hub-owned: a profile is just a stored OutputLayout, replayed
// through ApplyOutputs, so it works on every compositor and survives a switch
// (the provider reports whatever the new compositor cannot honour).
//
//	ryoku-hub outputs                list the connected outputs (JSON)
//	ryoku-hub outputs apply <json>   apply an output layout, print the report
//	ryoku-hub outputs profiles       list saved profiles and whether each matches
//	ryoku-hub outputs save <n> <json> save a profile and apply it
//	ryoku-hub outputs load <n>       apply a saved profile
//	ryoku-hub outputs rm <n>         delete a saved profile

// outputRow is one output as the display editor reads it: the seam's Output plus
// the physical width, height and refresh parsed from the current mode, since the
// editor sizes tiles in real pixels while Output.Width is the logical rectangle.
// Mirror and the colour fields are empty unless the provider supports those
// behaviours, so the page pre-fills its controls without clobbering them.
type outputRow struct {
	Name          string   `json:"name"`
	Focused       bool     `json:"focused"`
	Disabled      bool     `json:"disabled"`
	Make          string   `json:"make,omitempty"`
	Model         string   `json:"model,omitempty"`
	Width         int      `json:"width"`
	Height        int      `json:"height"`
	Refresh       int      `json:"refresh"`
	PhysicalWidth int      `json:"physicalWidth"`
	Scale         float64  `json:"scale"`
	X             int      `json:"x"`
	Y             int      `json:"y"`
	Transform     int      `json:"transform"`
	VRR           bool     `json:"vrr"`
	Mode          string   `json:"mode"`
	Modes         []string `json:"modes"`
	Mirror        string   `json:"mirror"`
	ColorMode     string   `json:"colorMode"`
	SdrBrightness float64  `json:"sdrBrightness"`
}

func runOutputs(args []string) error {
	switch {
	case len(args) == 0 || args[0] == "list":
		return listOutputs()
	case args[0] == "apply":
		if len(args) < 2 {
			return fmt.Errorf("outputs apply needs a layout JSON")
		}
		return applyOutputs(args[1])
	case args[0] == "profiles":
		return listProfiles()
	case args[0] == "save":
		if len(args) < 3 {
			return fmt.Errorf("outputs save needs a name and a layout JSON")
		}
		return saveProfile(args[1], args[2])
	case args[0] == "load":
		if len(args) < 2 {
			return fmt.Errorf("outputs load needs a name")
		}
		return loadProfile(args[1])
	case args[0] == "rm":
		if len(args) < 2 {
			return fmt.Errorf("outputs rm needs a name")
		}
		return rmProfile(args[1])
	}
	return fmt.Errorf("outputs: unknown subcommand %q", args[0])
}

func listOutputs() error {
	snap, err := desktopClient().State()
	if err != nil {
		return err
	}
	rows := make([]outputRow, 0, len(snap.Outputs))
	for _, o := range snap.Outputs {
		w, h, refresh := parseModeDims(o.Mode)
		rows = append(rows, outputRow{
			Name:          o.Name,
			Focused:       o.Focused,
			Disabled:      o.Disabled,
			Make:          o.Make,
			Model:         o.Model,
			Width:         w,
			Height:        h,
			Refresh:       refresh,
			PhysicalWidth: o.PhysicalWidth,
			Scale:         o.Scale,
			X:             o.X,
			Y:             o.Y,
			Transform:     o.Transform,
			VRR:           o.VRR,
			Mode:          o.Mode,
			Modes:         o.Modes,
			Mirror:        o.Mirror,
			ColorMode:     o.ColorMode,
			SdrBrightness: o.SdrBrightness,
		})
	}
	return printJSON(rows)
}

func applyOutputs(raw string) error {
	layout, err := parseLayout(raw)
	if err != nil {
		return err
	}
	return applyLayout(layout)
}

// outputHasIdentity reports whether a saved layout carries enough physical
// monitor metadata to require identity-safe resolution. Legacy layouts without
// any of these fields deliberately retain connector-name semantics.
func outputHasIdentity(spec wm.OutputLayout) bool {
	return strings.TrimSpace(spec.Make) != "" ||
		strings.TrimSpace(spec.Model) != "" ||
		spec.PhysicalWidth > 0
}

func layoutHasIdentity(layout []wm.OutputLayout) bool {
	for _, spec := range layout {
		if outputHasIdentity(spec) {
			return true
		}
	}
	return false
}

// resolveOutputName maps a saved physical monitor onto its connector in the
// compositor that is live now. Connector names are a fallback only for legacy
// layouts that carry no physical identity.
//
// Once identity metadata exists, guessing the old connector is unsafe: Hyprland
// and niri may assign DP-1/DP-2 to different physical panels.
func resolveOutputName(spec wm.OutputLayout, live []wm.Output) (string, error) {
	makeWant := strings.TrimSpace(spec.Make)
	modelWant := strings.TrimSpace(spec.Model)

	if !outputHasIdentity(spec) {
		return spec.Name, nil
	}

	matched := ""
	count := 0

	for _, out := range live {
		if makeWant != "" &&
			!strings.EqualFold(makeWant, strings.TrimSpace(out.Make)) {
			continue
		}
		if modelWant != "" &&
			!strings.EqualFold(modelWant, strings.TrimSpace(out.Model)) {
			continue
		}
		if spec.PhysicalWidth > 0 &&
			out.PhysicalWidth != spec.PhysicalWidth {
			continue
		}

		matched = out.Name
		count++
	}

	switch count {
	case 1:
		return matched, nil
	case 0:
		return "", fmt.Errorf(
			"output %q: physical identity make=%q model=%q width=%d matched no connected output",
			spec.Name,
			makeWant,
			modelWant,
			spec.PhysicalWidth,
		)
	default:
		return "", fmt.Errorf(
			"output %q: physical identity make=%q model=%q width=%d is ambiguous across %d connected outputs",
			spec.Name,
			makeWant,
			modelWant,
			spec.PhysicalWidth,
			count,
		)
	}
}

// resolveLayoutOutputs preserves the physical layout while translating every
// connector reference into the names used by the compositor that is live now.
//
// Resolution is intentionally conservative. Identity-bearing entries must map
// uniquely, and two saved entries may never claim the same live output.
// Mirror targets travel through the completed old-name -> live-name map.
func resolveLayoutOutputs(layout []wm.OutputLayout, live []wm.Output) ([]wm.OutputLayout, error) {
	out := append([]wm.OutputLayout(nil), layout...)
	remap := make(map[string]string, len(out))
	claimed := make(map[string]string, len(out))

	for i := range out {
		old := out[i].Name

		name, err := resolveOutputName(out[i], live)
		if err != nil {
			return nil, err
		}

		if previous, exists := claimed[name]; exists {
			return nil, fmt.Errorf(
				"outputs %q and %q both resolve to live output %q",
				previous,
				old,
				name,
			)
		}

		out[i].Name = name
		claimed[name] = old

		if old != "" {
			remap[old] = name
		}
	}

	for i := range out {
		if out[i].Mirror == "" || out[i].Mirror == "none" {
			continue
		}

		if name, ok := remap[out[i].Mirror]; ok {
			out[i].Mirror = name
		}

		if out[i].Mirror == out[i].Name {
			return nil, fmt.Errorf(
				"output %q resolves to mirror itself",
				out[i].Name,
			)
		}
	}

	return out, nil
}

// applyLayout hands the layout to the provider by path, like the seam wants, and
// prints its report so the page can surface anything the compositor could not
// honour. Shared by a direct apply and a profile load.
func applyLayout(layout []wm.OutputLayout) error {
	resolved := layout

	snap, stateErr := desktopClient().State()
	if stateErr == nil {
		var err error
		resolved, err = resolveLayoutOutputs(layout, snap.Outputs)
		if err != nil {
			return fmt.Errorf("outputs: %w", err)
		}
	} else if layoutHasIdentity(layout) {
		return fmt.Errorf(
			"outputs: cannot resolve physical monitor identity without live compositor state: %w",
			stateErr,
		)
	}

	body, err := json.Marshal(resolved)
	if err != nil {
		return err
	}
	f, err := os.CreateTemp("", "ryoku-outputs-*.json")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if _, err := f.Write(body); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	rep, err := desktopClient().ApplyOutputs(f.Name())
	if err != nil {
		return err
	}
	return printJSON(rep)
}

func parseLayout(raw string) ([]wm.OutputLayout, error) {
	var layout []wm.OutputLayout
	if err := json.Unmarshal([]byte(raw), &layout); err != nil {
		return nil, fmt.Errorf("outputs: %w", err)
	}
	return layout, nil
}

// --- profiles -------------------------------------------------------------

// outputProfile is a saved profile as the page lists it: the name, and whether
// every output it configures is connected now, so the page can mark the ones
// ready to apply.
type outputProfile struct {
	Name    string `json:"name"`
	Matches bool   `json:"matches"`
}

func profilesDir() string { return filepath.Join(ryokuConfigDir(), "output-profiles") }

// profileName rejects a name that would escape the profiles dir, since it comes
// from a text field.
func profileName(name string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", fmt.Errorf("profile name is empty")
	}
	if name == "." || name == ".." || strings.ContainsAny(name, `/\`) {
		return "", fmt.Errorf("invalid profile name %q", name)
	}
	return name, nil
}

func saveProfile(name, raw string) error {
	n, err := profileName(name)
	if err != nil {
		return err
	}
	layout, err := parseLayout(raw)
	if err != nil {
		return err
	}
	body, err := json.Marshal(layout)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(profilesDir(), 0o755); err != nil {
		return err
	}
	if err := atomicWrite(filepath.Join(profilesDir(), n+".json"), body, 0o644); err != nil {
		return err
	}
	return applyLayout(layout)
}

func loadProfile(name string) error {
	layout, err := readProfile(name)
	if err != nil {
		return err
	}
	return applyLayout(layout)
}

func rmProfile(name string) error {
	n, err := profileName(name)
	if err != nil {
		return err
	}
	if err := os.Remove(filepath.Join(profilesDir(), n+".json")); err != nil && !os.IsNotExist(err) {
		return err
	}
	return printJSON(map[string]bool{"removed": true})
}

func readProfile(name string) ([]wm.OutputLayout, error) {
	n, err := profileName(name)
	if err != nil {
		return nil, err
	}
	raw, err := os.ReadFile(filepath.Join(profilesDir(), n+".json"))
	if err != nil {
		return nil, err
	}
	var layout []wm.OutputLayout
	if err := json.Unmarshal(raw, &layout); err != nil {
		return nil, err
	}
	return layout, nil
}

func listProfiles() error {
	connected := connectedOutputs()
	ents, err := os.ReadDir(profilesDir())
	if err != nil {
		if os.IsNotExist(err) {
			return printJSON([]outputProfile{})
		}
		return err
	}
	out := make([]outputProfile, 0, len(ents))
	for _, e := range ents {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		name := strings.TrimSuffix(e.Name(), ".json")
		layout, err := readProfile(name)
		if err != nil {
			continue
		}
		out = append(out, outputProfile{Name: name, Matches: profileMatches(layout, connected)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return printJSON(out)
}

// connectedOutputs returns the live output identities for profile matching.
// Keeping the physical identity here lets a profile remain applicable when a
// compositor gives the same panels different connector names.
func connectedOutputs() []wm.Output {
	snap, err := desktopClient().State()
	if err != nil {
		return nil
	}
	return snap.Outputs
}

// profileMatches is true when every physical output the profile describes is
// connected now. Old profiles without identity retain their name-only behaviour.
func profileMatches(layout []wm.OutputLayout, connected []wm.Output) bool {
	if len(layout) == 0 || len(connected) == 0 {
		return false
	}

	resolved, err := resolveLayoutOutputs(layout, connected)
	if err != nil {
		return false
	}
	names := make(map[string]bool, len(connected))
	for _, o := range connected {
		names[o.Name] = true
	}
	for _, o := range resolved {
		if !names[o.Name] {
			return false
		}
	}
	return true
}

// parseModeDims pulls the physical width, height and rounded refresh from a
// "WxH@Hz" mode string. Zeroes for an empty mode, which is how a disabled output
// reads.
func parseModeDims(s string) (w, h, refresh int) {
	if s == "" {
		return 0, 0, 0
	}
	dims := s
	if at := strings.IndexByte(s, '@'); at >= 0 {
		dims = s[:at]
		if f, err := strconv.ParseFloat(s[at+1:], 64); err == nil {
			refresh = int(f + 0.5)
		}
	}
	if x := strings.IndexByte(dims, 'x'); x >= 0 {
		w, _ = strconv.Atoi(dims[:x])
		h, _ = strconv.Atoi(dims[x+1:])
	}
	return w, h, refresh
}
