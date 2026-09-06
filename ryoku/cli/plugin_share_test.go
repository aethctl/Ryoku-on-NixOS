package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// a bar widget with a preview, a script, a README and a nested content file:
// one of each kind the product manifest classifies.
func writeShareablePlugin(t *testing.T) string {
	t.Helper()
	dir := writePlugin(t, `{
  "id": "vpn", "name": "VPN", "version": "1.0.0",
  "author": "someone <someone@example.com>",
  "description": "Shows whether a VPN is up. Click to toggle it.",
  "tags": ["vpn", "network"],
  "hosts": ["topbarGlyph"],
  "defaults": { "host": "topbarGlyph", "icon": "vpn_lock" },
  "entryPoints": { "main": "service/Main.qml", "content": "content/Widget.qml" }
}`, "service/Main.qml", "content/Widget.qml", "content/Row.qml", "README.md", "assets/preview-widget.png", "assets/preview-desktop.png", "assets/shot-2.png")
	script := filepath.Join(dir, "bin", "ryoku-vpn-probe")
	if err := os.MkdirAll(filepath.Dir(script), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(script, []byte("#!/bin/sh\nnmcli\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	return dir
}

func TestBuildProductManifestClassifiesFiles(t *testing.T) {
	dir := writeShareablePlugin(t)
	preview, shots := previewMedia(dir)
	if preview != "assets/preview-widget.png" {
		t.Fatalf("preview = %q", preview)
	}
	if strings.Join(shots, ",") != "assets/preview-widget.png,assets/preview-desktop.png,assets/shot-2.png" {
		t.Fatalf("screenshots = %v", shots)
	}
	raw, err := buildProductManifest(dir, "vpn", "1.0.0", preview, shots)
	if err != nil {
		t.Fatal(err)
	}
	var pm productManifest
	if err := json.Unmarshal(raw, &pm); err != nil {
		t.Fatal(err)
	}
	if pm.Schema != 1 || pm.ID != "vpn" || pm.Category != "plugins" || pm.Version != "1.0.0" || pm.Destination != "ryoku/plugins/vpn" {
		t.Fatalf("envelope = %+v", pm)
	}
	got := map[string]productFile{}
	for i, f := range pm.Files {
		got[f.Source] = f
		if i > 0 && pm.Files[i-1].Source > f.Source {
			t.Fatalf("files not sorted: %s after %s", f.Source, pm.Files[i-1].Source)
		}
		if f.Source != f.Destination || len(f.SHA256) != 64 {
			t.Fatalf("row %+v", f)
		}
	}
	cases := map[string]struct {
		mode    string
		install bool
	}{
		"manifest.json":              {"0644", true},
		"service/Main.qml":           {"0644", true},
		"content/Widget.qml":         {"0644", true},
		"content/Row.qml":            {"0644", true},
		"bin/ryoku-vpn-probe":        {"0755", true},
		"README.md":                  {"0644", false},
		"assets/preview-widget.png":  {"0644", false},
		"assets/preview-desktop.png": {"0644", false},
		"assets/shot-2.png":          {"0644", false},
	}
	for src, want := range cases {
		f, ok := got[src]
		if !ok {
			t.Fatalf("%s not declared", src)
		}
		if f.Mode != want.mode || f.Install != want.install {
			t.Errorf("%s: mode=%s install=%v, want %s %v", src, f.Mode, f.Install, want.mode, want.install)
		}
	}
	if len(got) != len(cases) {
		t.Fatalf("declared %d files, want %d: %v", len(got), len(cases), got)
	}
}

func TestRegistryEntryIsCommunityAndTagged(t *testing.T) {
	dir := writeShareablePlugin(t)
	m, err := validateManifest(dir, map[string]bool{})
	if err != nil {
		t.Fatal(err)
	}
	raw := readManifestMap(filepath.Join(dir, "manifest.json"))
	e := registryEntryFor(raw, m, "assets/preview-widget.png", []string{"assets/preview-widget.png"}, strings.Repeat("a", 64))
	if e.Official {
		t.Fatal("an export is never official")
	}
	if e.Path != "plugins/vpn" || e.Manifest != "product-manifest.json" || e.Icon != "vpn_lock" {
		t.Fatalf("entry = %+v", e)
	}
	if e.Summary != "Shows whether a VPN is up." || e.Tagline != e.Summary {
		t.Fatalf("summary = %q tagline = %q", e.Summary, e.Tagline)
	}
	if strings.Join(e.Tags, ",") != "vpn,network,bar-widget" {
		t.Fatalf("tags = %v", e.Tags)
	}
	if strings.Join(e.Hosts, ",") != "topbarGlyph" || len(e.LastUpdated) != 10 {
		t.Fatalf("hosts = %v lastUpdated = %q", e.Hosts, e.LastUpdated)
	}
	// a desktop plugin takes the desktop tag instead
	m.Hosts = []string{"desktopWidget"}
	d := registryEntryFor(raw, m, "", nil, "")
	if strings.Join(d.Tags, ",") != "vpn,network,desktop-widget" || len(d.Screenshots) != 0 {
		t.Fatalf("desktop entry = %+v", d)
	}
}

func TestUpsertRegistryEntryReplacesAndAppends(t *testing.T) {
	path := filepath.Join(t.TempDir(), "registry.json")
	seed := "{\n  \"schema\": 1,\n  \"plugins\": [\n    {\n      \"id\": \"market\",\n      \"version\": \"1.0.0\"\n    }\n  ],\n  \"archived\": []\n}\n"
	if err := os.WriteFile(path, []byte(seed), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := upsertRegistryEntry(path, registryEntry{ID: "vpn", Version: "1.0.0", Tags: []string{}, Screenshots: []string{}, Hosts: []string{"topbarGlyph"}}); err != nil {
		t.Fatal(err)
	}
	if err := upsertRegistryEntry(path, registryEntry{ID: "vpn", Version: "1.1.0", Author: "me <me@x.y>", Tags: []string{}, Screenshots: []string{}, Hosts: []string{"topbarGlyph"}}); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(path)
	if !strings.Contains(string(b), "\"me <me@x.y>\"") {
		t.Fatalf("author was HTML-escaped:\n%s", b)
	}
	var reg struct {
		Schema   int              `json:"schema"`
		Plugins  []map[string]any `json:"plugins"`
		Archived []any            `json:"archived"`
	}
	if err := json.Unmarshal(b, &reg); err != nil {
		t.Fatalf("%v\n%s", err, b)
	}
	if reg.Schema != 1 || reg.Archived == nil || len(reg.Plugins) != 2 {
		t.Fatalf("registry = %s", b)
	}
	if reg.Plugins[0]["id"] != "market" || reg.Plugins[1]["id"] != "vpn" || reg.Plugins[1]["version"] != "1.1.0" {
		t.Fatalf("plugins = %v", reg.Plugins)
	}
	if !strings.HasPrefix(string(b), "{\n  \"schema\": 1,\n  \"plugins\": [\n    {\n") {
		t.Fatalf("formatting drifted:\n%s", b)
	}
}

func TestExportWritesAFullFolder(t *testing.T) {
	src := writeShareablePlugin(t)
	t.Setenv("RYOSTORE_PLUGINS_DIR", filepath.Dir(src))
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	// the dev dir is keyed by folder name, so the plugin must sit under its id
	idDir := filepath.Join(filepath.Dir(src), "vpn")
	if err := os.Rename(src, idDir); err != nil {
		t.Fatal(err)
	}
	dest := filepath.Join(t.TempDir(), "out")
	got, err := exportPlugin("vpn", dest)
	if err != nil {
		t.Fatal(err)
	}
	if got != dest {
		t.Fatalf("dest = %q", got)
	}
	for _, f := range []string{"manifest.json", "content/Widget.qml", "bin/ryoku-vpn-probe", "product-manifest.json", "registry-entry.json"} {
		if _, err := os.Stat(filepath.Join(dest, f)); err != nil {
			t.Fatalf("%s missing after export", f)
		}
	}
	eb, _ := os.ReadFile(filepath.Join(dest, "registry-entry.json"))
	var e registryEntry
	if err := json.Unmarshal(eb, &e); err != nil {
		t.Fatal(err)
	}
	pb, _ := os.ReadFile(filepath.Join(dest, "product-manifest.json"))
	if e.ManifestSHA256 != sha256Hex(pb) {
		t.Fatal("registry entry does not hash the written product manifest")
	}
}

func TestSplitAuthor(t *testing.T) {
	cases := map[string][2]string{
		"neur0map <hello@ryoku.dev>": {"neur0map", "hello@ryoku.dev"},
		"Jane Doe":                   {"Jane Doe", "jane-doe@users.noreply.github.com"},
		"":                           {"ryoku", "ryoku@users.noreply.github.com"},
		"<x@y.z>":                    {"ryoku", "x@y.z"},
	}
	for in, want := range cases {
		n, m := splitAuthor(in)
		if n != want[0] || m != want[1] {
			t.Errorf("%q -> %q %q, want %q %q", in, n, m, want[0], want[1])
		}
	}
}
