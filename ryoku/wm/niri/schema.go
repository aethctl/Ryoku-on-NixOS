package main

import _ "embed"

//go:embed schema.json
var schemaRows []byte

// runSchema prints niri's exclusive settings rows, in the shape the Hub's
// settings renderer already consumes. niri owns no bespoke Hub pages, so every
// row is tagged page "windowmanager" and renders on the shared window-manager
// page. The rows live here rather than in the Hub so niri's exclusives surface
// without a Hub edit, the same way a third compositor's would.
func runSchema() error {
	_, err := stdout.Write(schemaRows)
	return err
}
