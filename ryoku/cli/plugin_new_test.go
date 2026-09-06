package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func fileThere(p string) bool { _, err := os.Stat(p); return err == nil }

// TestPluginNewScaffold checks the bar scaffold lays every required file, renames
// gitignore to .gitignore, creates assets/, ships no symlink, and templates the
// author, name and id into the docs.
func TestPluginNewScaffold(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "demo-x")
	if err := scaffoldPlugin(dir, "demo-x", "Demo X", "QA <qa@example.com>", "topbarGlyph", true); err != nil {
		t.Fatal(err)
	}
	for _, f := range []string{
		"manifest.json", "service/Main.qml", "content/Widget.qml", "content/Panel.qml",
		"README.md", "LICENSE", "AGENTS.md", "CLAUDE.md", ".gitignore",
	} {
		if !fileThere(filepath.Join(dir, f)) {
			t.Errorf("scaffold missing %s", f)
		}
	}
	if fileThere(filepath.Join(dir, "gitignore")) {
		t.Errorf("gitignore should be renamed to .gitignore")
	}
	if fi, err := os.Stat(filepath.Join(dir, "assets")); err != nil || !fi.IsDir() {
		t.Errorf("assets/ dir not created")
	}
	if link, _ := firstSymlink(dir); link != "" {
		t.Errorf("scaffold contains a symlink: %s", link)
	}
	lic, _ := os.ReadFile(filepath.Join(dir, "LICENSE"))
	if !strings.Contains(string(lic), "QA") {
		t.Errorf("LICENSE not templated with the author name")
	}
	rd, _ := os.ReadFile(filepath.Join(dir, "README.md"))
	if !strings.Contains(string(rd), "Demo X") || !strings.Contains(string(rd), "demo-x") {
		t.Errorf("README not templated with name/id")
	}
	cl, _ := os.ReadFile(filepath.Join(dir, "CLAUDE.md"))
	if !strings.Contains(string(cl), "AGENTS.md") {
		t.Errorf("CLAUDE.md should point at AGENTS.md")
	}
}

// TestPluginNewBarManifest pins the bar manifest: a panel entry point, a panel
// width, honest official/author, and the topbarGlyph host.
func TestPluginNewBarManifest(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "bary")
	if err := scaffoldPlugin(dir, "bary", "Bary", "QA <qa@example.com>", "topbarGlyph", true); err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	b, _ := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatalf("manifest not valid JSON: %v", err)
	}
	ep, _ := m["entryPoints"].(map[string]any)
	if ep["panel"] != "content/Panel.qml" {
		t.Errorf("bar manifest missing panel entry point: %v", ep)
	}
	panel, ok := m["panel"].(map[string]any)
	if !ok || int(panel["width"].(float64)) != 320 {
		t.Errorf("bar manifest missing panel width 320: %v", m["panel"])
	}
	if m["official"] != false {
		t.Errorf("official must be false for a community plugin")
	}
	if m["author"] != "QA <qa@example.com>" {
		t.Errorf("author not written: %v", m["author"])
	}
	hosts, _ := m["hosts"].([]any)
	if len(hosts) != 1 || hosts[0] != "topbarGlyph" {
		t.Errorf("host wrong: %v", hosts)
	}
}

// TestPluginNewDesktopNoPanel checks the desktop host omits the panel file and
// the panel manifest fields.
func TestPluginNewDesktopNoPanel(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "desky")
	if err := scaffoldPlugin(dir, "desky", "Desky", "QA <qa@example.com>", "desktopWidget", false); err != nil {
		t.Fatal(err)
	}
	if fileThere(filepath.Join(dir, "content/Panel.qml")) {
		t.Errorf("desktop scaffold should not ship content/Panel.qml")
	}
	var m map[string]any
	b, _ := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	ep, _ := m["entryPoints"].(map[string]any)
	if _, ok := ep["panel"]; ok {
		t.Errorf("desktop manifest should not declare a panel entry point")
	}
	if _, ok := m["panel"]; ok {
		t.Errorf("desktop manifest should not declare a panel width")
	}
	hosts, _ := m["hosts"].([]any)
	if len(hosts) != 1 || hosts[0] != "desktopWidget" {
		t.Errorf("host wrong: %v", hosts)
	}
}

func TestPluginTitleFromID(t *testing.T) {
	for in, want := range map[string]string{"demo-x": "Demo X", "vpn": "Vpn", "a-b-c": "A B C"} {
		if got := titleFromID(in); got != want {
			t.Errorf("titleFromID(%q)=%q want %q", in, got, want)
		}
	}
}
