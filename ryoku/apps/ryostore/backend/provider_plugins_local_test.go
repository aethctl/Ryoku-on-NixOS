package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

// writeLocalPlugin lays a plugin tree for the local-install path: manifest.json,
// the two entry files, a symlink, and a .git tree, so the builder tests can
// prove symlinks and .git are skipped.
func writeLocalPlugin(t *testing.T, id, version string) string {
	t.Helper()
	dir := t.TempDir()
	manifest := fmt.Sprintf(`{"id":%q,"name":"Demo Pulse","version":%q,
		"hosts":["topbarGlyph","framePopout"],
		"defaults":{"bar":{"section":"left"}},
		"entryPoints":{"main":"service/Main.qml","content":"content/Widget.qml"}}`, id, version)
	write := func(rel, body string) {
		p := filepath.Join(dir, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("manifest.json", manifest)
	write("service/Main.qml", "// main\n")
	write("content/Widget.qml", "// widget\n")
	write(".git/config", "[core]\n")
	if err := os.Symlink("/etc/passwd", filepath.Join(dir, "content", "sneaky.qml")); err != nil {
		t.Skipf("symlink unsupported here: %v", err)
	}
	return dir
}

func TestBuildLocalProductManifest(t *testing.T) {
	dir := writeLocalPlugin(t, "demo-pulse", "0.1.0")
	entry, manifest, err := buildLocalProductManifest("demo-pulse", dir)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if entry.ID != "demo-pulse" || entry.Version != "0.1.0" {
		t.Fatalf("entry = %+v", entry)
	}
	if manifest.Schema != 1 || manifest.Category != "plugins" || manifest.Version != "0.1.0" {
		t.Fatalf("manifest identity = %+v", manifest)
	}
	if manifest.Destination != "ryoku/plugins/demo-pulse" {
		t.Fatalf("destination = %q", manifest.Destination)
	}
	got := map[string]ProductFile{}
	for _, f := range manifest.Files {
		got[f.Source] = f
	}
	for _, want := range []string{"manifest.json", "service/Main.qml", "content/Widget.qml"} {
		if _, ok := got[want]; !ok {
			t.Fatalf("missing file %q in %v", want, keysOf(got))
		}
	}
	if _, ok := got["content/sneaky.qml"]; ok {
		t.Fatal("symlink must be skipped")
	}
	if _, ok := got[".git/config"]; ok {
		t.Fatal(".git tree must be skipped")
	}
	// Hash and mirror-destination are correct for a known file.
	widget := got["content/Widget.qml"]
	if widget.Destination != "content/Widget.qml" || !widget.Install || widget.Mode != "0644" {
		t.Fatalf("widget file = %+v", widget)
	}
	if widget.SHA256 != fmt.Sprintf("%x", sha256.Sum256([]byte("// widget\n"))) {
		t.Fatalf("widget hash = %q", widget.SHA256)
	}
}

func TestBuildLocalProductManifestRejections(t *testing.T) {
	t.Run("id mismatch", func(t *testing.T) {
		dir := writeLocalPlugin(t, "demo-pulse", "0.1.0")
		if _, _, err := buildLocalProductManifest("other-id", dir); err == nil {
			t.Fatal("want id mismatch error")
		}
	})
	t.Run("missing version", func(t *testing.T) {
		dir := t.TempDir()
		if err := os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(`{"id":"demo-pulse","name":"x"}`), 0o644); err != nil {
			t.Fatal(err)
		}
		if _, _, err := buildLocalProductManifest("demo-pulse", dir); err == nil {
			t.Fatal("want missing-version error")
		}
	})
}

func keysOf(m map[string]ProductFile) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

// TestInstallProductFromLocal mirrors an existing install test but drives the
// --from path: a plugin installed from a local dir must land with a receipt, a
// content-hashed view, and an index entry, exactly as a registry install, and
// remove cleanly.
func TestInstallProductFromLocal(t *testing.T) {
	setTransactionXDG(t)
	ctx := context.Background()
	dir := writeLocalPlugin(t, "demo-pulse", "0.1.0")

	if err := (pluginProvider{}).InstallFrom(ctx, "demo-pulse", dir); err != nil {
		t.Fatalf("install from local: %v", err)
	}

	// Installed files landed under the plugins destination.
	dest := filepath.Join(dataHome(), "ryoku", "plugins", "demo-pulse")
	for _, rel := range []string{"manifest.json", "service/Main.qml", "content/Widget.qml"} {
		if _, err := os.Stat(filepath.Join(dest, filepath.FromSlash(rel))); err != nil {
			t.Fatalf("installed file %s: %v", rel, err)
		}
	}
	if _, err := os.Lstat(filepath.Join(dest, "content", "sneaky.qml")); err == nil {
		t.Fatal("symlink must not be installed")
	}

	// The receipt owns the install.
	receipt, err := readReceipt("plugins", "demo-pulse")
	if err != nil {
		t.Fatalf("receipt: %v", err)
	}
	if receipt.Version != "0.1.0" {
		t.Fatalf("receipt version = %q", receipt.Version)
	}

	// The index names the plugin with a content-hashed view that exists on disk.
	rows := readPluginIndexForTest(t)
	var view string
	for _, r := range rows {
		if r.ID == "demo-pulse" {
			view = r.View
		}
	}
	if view == "" {
		t.Fatalf("index does not name demo-pulse: %+v", rows)
	}
	viewDir := filepath.Join(storeStateDir(), filepath.FromSlash(view))
	if _, err := os.Stat(filepath.Join(viewDir, "manifest.json")); err != nil {
		t.Fatalf("view dir missing manifest: %v", err)
	}

	// Remove tears down the receipt, the destination, and the view.
	if err := (pluginProvider{}).Remove(ctx, "demo-pulse"); err != nil {
		t.Fatalf("remove: %v", err)
	}
	if _, err := readReceipt("plugins", "demo-pulse"); err == nil {
		t.Fatal("receipt should be gone after remove")
	}
	if _, err := os.Stat(dest); !os.IsNotExist(err) {
		t.Fatalf("destination should be gone: %v", err)
	}
	if _, err := os.Stat(filepath.Join(storeStateDir(), "plugin-views", "demo-pulse")); !os.IsNotExist(err) {
		t.Fatalf("view dir should be pruned: %v", err)
	}
}

func readPluginIndexForTest(t *testing.T) []pluginIndexRow {
	t.Helper()
	raw, err := os.ReadFile(pluginIndexPath())
	if err != nil {
		t.Fatalf("read index: %v", err)
	}
	var rows []pluginIndexRow
	if err := json.Unmarshal(raw, &rows); err != nil {
		t.Fatalf("parse index: %v", err)
	}
	return rows
}
