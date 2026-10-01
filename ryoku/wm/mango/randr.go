package main

import (
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// randrDetail reads the editor detail for one output over wlr-randr, which
// speaks the wlr-output-management-v1 protocol mango serves (verified in
// src/main.c). IPC carries none of this: advertised modes, position, transform
// and the EDID make/model come from the protocol instead. Best-effort: an
// absent tool or a failed read yields ok=false and the lean IPC fields stand
// alone.

type randrOutput struct {
	x, y, transform int
	enabled         bool
	mode            string
	modes           []string
	make, model     string
}

func randrDetail(name string) (randrOutput, bool) {
	out, err := exec.Command("wlr-randr").Output()
	if err != nil {
		return randrOutput{}, false
	}
	return parseRandr(string(out), name)
}

// parseRandr walks wlr-randr's output block for one named output: a header
// line `NAME "make" "model"`, then indented `Enabled:`, `Position: x,y`,
// `Transform:` and `Modes:` rows with `WxH px (current)` entries.
func parseRandr(text, name string) (randrOutput, bool) {
	var cur randrOutput
	have, inBlock, inModes := false, false, false
	for _, raw := range strings.Split(text, "\n") {
		if raw == "" {
			continue
		}
		if !strings.HasPrefix(raw, " ") && !strings.HasPrefix(raw, "\t") {
			fields := strings.Fields(raw)
			inBlock = len(fields) > 0 && fields[0] == name
			inModes = false
			if inBlock {
				have = true
				cur = randrOutput{enabled: true}
				if len(fields) > 1 {
					cur.make = strings.Trim(fields[1], `"`)
				}
				if len(fields) > 2 {
					cur.model = strings.Trim(fields[2], `"`)
				}
			}
			continue
		}
		if !inBlock {
			continue
		}
		trimmed := strings.TrimSpace(raw)
		if trimmed == "Modes:" {
			inModes = true
			continue
		}
		if inModes && strings.Contains(trimmed, "px") {
			mode := strings.Fields(trimmed)[0]
			cur.modes = append(cur.modes, mode)
			if strings.Contains(trimmed, "(current)") {
				cur.mode = mode
			}
			continue
		}
		inModes = false
		k, v, ok := strings.Cut(trimmed, ":")
		if !ok {
			continue
		}
		val := strings.TrimSpace(v)
		switch k {
		case "Enabled":
			cur.enabled = val == "yes"
		case "Position":
			xy := strings.Split(val, ",")
			if len(xy) == 2 {
				cur.x, _ = strconv.Atoi(strings.TrimSpace(xy[0]))
				cur.y, _ = strconv.Atoi(strings.TrimSpace(xy[1]))
			}
		case "Transform":
			cur.transform = waylandTransformName(val)
		}
	}
	return cur, have
}

// waylandTransformName folds wlr-randr's spelling ("normal", "_90",
// "flipped-90", …) to the wayland transform integer the neutral Output carries.
// An unknown name reads as normal, the safe default.
func waylandTransformName(s string) int {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "_90", "90", "0_90":
		return 1
	case "_180", "180", "0_180":
		return 2
	case "_270", "270", "0_270":
		return 3
	case "flipped", "flipped_0":
		return 4
	case "flipped-90", "flipped_90":
		return 5
	case "flipped-180", "flipped_180":
		return 6
	case "flipped-270", "flipped_270":
		return 7
	}
	return 0
}

// fileExists is the provider's one stat helper, a var so a sandbox test can
// fake a tree without a filesystem.
var fileExists = func(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
