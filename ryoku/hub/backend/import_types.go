package main

import "strings"

// The store entries the Hyprland config importer produces. They serialise to the
// desktop.json arrays the provider reads, so the JSON tags match the provider's
// model; the importer is the only Hub code that still needs the typed shape.

// Keybind = a user shortcut. action "exec" runs Value; the dispatcher actions
// take no value.
type Keybind struct {
	Keys    string `json:"keys"`
	Action  string `json:"action"`
	Value   string `json:"value"`
	Release bool   `json:"release,omitempty"`
}

// WindowRule = one user rule: optional class/title match plus one action.
type WindowRule struct {
	Class  string `json:"class"`
	Title  string `json:"title"`
	Action string `json:"action"`
	Value  string `json:"value"`
}

// luaStr quotes a string for the Lua the importer renders into user.lua.
func luaStr(s string) string {
	r := strings.NewReplacer("\\", "\\\\", "\"", "\\\"", "\n", "\\n", "\r", "\\r")
	return "\"" + r.Replace(s) + "\""
}
