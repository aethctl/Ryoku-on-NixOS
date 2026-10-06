package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestVesktopThemeCategoryLoadsFromStore(t *testing.T) {
	setTransactionXDG(t)
	entry := ProductEntry{
		ID: "ryoku-discord", Name: "Ryoku Discord", Version: "1.22.2",
		Path: "vesktop-themes/ryoku-discord", Author: "Ron",
		Summary: "Vesktop theme", Description: "Vesktop theme with palette colors.",
		Tags: []string{"vesktop"}, Accent: "#e2342a", Surface: "#2a2a2a",
		Preview: "assets/preview.png", Screenshots: []string{}, Manifest: "manifest.json",
		ManifestSHA256: strings.Repeat("0", 64), Upstream: "https://github.com/Sipper1236/ryoku-discord",
	}
	registry, err := json.Marshal(map[string]any{"schema": 1, vesktopThemesCategory: []ProductEntry{entry}})
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/vesktop-themes/registry.json" {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(registry)
	}))
	t.Cleanup(server.Close)
	cache := &Cache{client: server.Client(), base: server.URL, dir: t.TempDir(), memo: map[string]memoEntry{}}
	provider := newVesktopThemesProvider(cache)
	items, _, err := provider.Load(context.Background(), false)
	if err != nil || len(items) != 1 || items[0].ID != entry.ID {
		t.Fatalf("catalogue items = %+v, %v", items, err)
	}
	if !storeSection(vesktopThemesCategory) {
		t.Fatal("Vesktop theme category cannot open in Store")
	}
}

func installLocalVesktopTheme(t *testing.T, version, name, css string) error {
	t.Helper()
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, name), []byte(css), 0o644); err != nil {
		t.Fatal(err)
	}
	manifest := ProductManifest{
		Schema:      1,
		ID:          "demo",
		Category:    vesktopThemesCategory,
		Version:     version,
		Destination: "ryoku/vesktop-themes/demo",
		Files: []ProductFile{{
			Source: name, Destination: name, Mode: "0644", Install: true,
			Size: int64(len(css)), SHA256: fmt.Sprintf("%x", sha256.Sum256([]byte(css))),
		}},
	}
	entry := ProductEntry{ID: "demo", Version: version}
	return installProductFrom(context.Background(), nil, vesktopThemesCategory, entry,
		&localProductSource{root: root, manifest: manifest})
}

func TestVesktopThemeInstallAndRemove(t *testing.T) {
	setTransactionXDG(t)
	if err := installLocalVesktopTheme(t, "1.0.0", "Ryoku.theme.css", "theme one\n"); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(configHome(), "vesktop", "themes", "Ryoku.theme.css")
	info, err := os.Lstat(link)
	if err != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("theme link = %v, %v", info, err)
	}
	if raw, err := os.ReadFile(link); err != nil || string(raw) != "theme one\n" {
		t.Fatalf("theme content = %q, %v", raw, err)
	}
	if err := removeProduct(context.Background(), vesktopThemesCategory, "demo"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Fatalf("theme link remains: %v", err)
	}
}

func TestVesktopThemePreservesUnmanagedFile(t *testing.T) {
	setTransactionXDG(t)
	link := filepath.Join(configHome(), "vesktop", "themes", "Ryoku.theme.css")
	if err := os.MkdirAll(filepath.Dir(link), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(link, []byte("user theme\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := installLocalVesktopTheme(t, "1.0.0", "Ryoku.theme.css", "store theme\n"); err == nil {
		t.Fatal("install replaced an unmanaged theme")
	}
	if raw, err := os.ReadFile(link); err != nil || string(raw) != "user theme\n" {
		t.Fatalf("unmanaged theme changed: %q, %v", raw, err)
	}
	if _, err := readReceipt(vesktopThemesCategory, "demo"); !os.IsNotExist(err) {
		t.Fatalf("failed install left a receipt: %v", err)
	}
}

func TestVesktopThemeUpdateRollbackRestoresLink(t *testing.T) {
	setTransactionXDG(t)
	if err := installLocalVesktopTheme(t, "1.0.0", "Old.theme.css", "old\n"); err != nil {
		t.Fatal(err)
	}
	original := writeProductRevision
	writeProductRevision = func(StoreRevision) error { return errors.New("revision unavailable") }
	t.Cleanup(func() { writeProductRevision = original })
	if err := installLocalVesktopTheme(t, "2.0.0", "New.theme.css", "new\n"); err == nil {
		t.Fatal("update unexpectedly succeeded")
	}
	oldLink := filepath.Join(configHome(), "vesktop", "themes", "Old.theme.css")
	newLink := filepath.Join(configHome(), "vesktop", "themes", "New.theme.css")
	if raw, err := os.ReadFile(oldLink); err != nil || string(raw) != "old\n" {
		t.Fatalf("prior theme was not restored: %q, %v", raw, err)
	}
	if _, err := os.Lstat(newLink); !os.IsNotExist(err) {
		t.Fatalf("new link remains after rollback: %v", err)
	}
}

func TestVesktopThemeInterruptedInstallRecoversLink(t *testing.T) {
	setTransactionXDG(t)
	original := productTransactionCheckpoint
	productTransactionCheckpoint = func(phase string) error {
		if phase == "derived-state" {
			return errProductTransactionInterrupted
		}
		return nil
	}
	t.Cleanup(func() { productTransactionCheckpoint = original })
	if err := installLocalVesktopTheme(t, "1.0.0", "Ryoku.theme.css", "theme\n"); !errors.Is(err, errProductTransactionInterrupted) {
		t.Fatalf("interrupted install = %v", err)
	}
	link := filepath.Join(configHome(), "vesktop", "themes", "Ryoku.theme.css")
	if _, err := os.Lstat(link); err != nil {
		t.Fatalf("theme link was not published: %v", err)
	}
	productTransactionCheckpoint = original
	if err := recoverStoreTransactions(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(link); !os.IsNotExist(err) {
		t.Fatalf("theme link remains after recovery: %v", err)
	}
	if _, err := readReceipt(vesktopThemesCategory, "demo"); !os.IsNotExist(err) {
		t.Fatalf("receipt remains after recovery: %v", err)
	}
}

func TestVesktopThemeRequiresFlatCSS(t *testing.T) {
	if validVesktopThemeName("nested/Ryoku.theme.css") || validVesktopThemeName("theme.css") {
		t.Fatal("accepted a theme filename Vesktop cannot load")
	}
}
