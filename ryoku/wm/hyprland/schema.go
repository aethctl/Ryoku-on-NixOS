package main

import _ "embed"

//go:embed schema.json
var schemaRows []byte

// runSchema prints the Hyprland exclusive settings rows, in the shape the Hub's
// settings renderer already consumes. The rows are the single source: they were
// hardcoded in the Hub, and moving them here is what lets a compositor's
// settings arrive by shipping this file rather than editing the Hub. Each row's
// `page` names the surface that draws it: the shared window-manager page, or a
// capability-gated bespoke page (plugins, animations, layerrules) that keeps its
// own interactions and reads its rows from here.
func runSchema() error {
	_, err := stdout.Write(schemaRows)
	return err
}
