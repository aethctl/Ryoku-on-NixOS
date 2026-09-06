// The colorscheme provider serves the ryostore colorschemes catalogue as the
// Themes category. It installs a scheme install-only into the shell's theme
// library (dataHome/ryoku/themes/<id>), where the shell daemon converts it into a
// live palette and the Color-scheme picker (Super+W / Hub) applies it. Each
// registry entry carries its Noctalia dark/light palette inline, so an install is
// a cache-only copy that works offline; the catalogue's preview art is fetched
// best-effort beside it so the picker's card shows the same image the store did.
// The entry's provider drives the store's per-provider subtab strip.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const colorschemeRegistryPath = "colorschemes/registry.json"

type colorschemeEntry struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	Provider string `json:"provider"`
	Path     string `json:"path"`
	Accent   string `json:"accent,omitempty"`
	Surface  string `json:"surface,omitempty"`
	Source   string `json:"source,omitempty"`
	Preview  string `json:"preview,omitempty"`
	// Wallpapers the scheme was drawn for (raw URLs, pinned to a commit).
	Wallpapers []string        `json:"wallpapers,omitempty"`
	Dark       json.RawMessage `json:"dark,omitempty"`
	Light      json.RawMessage `json:"light,omitempty"`
}

type colorschemeRegistry struct {
	Version int                `json:"version"`
	Themes  []colorschemeEntry `json:"themes"`
}

type colorschemeProvider struct {
	cache        *Cache
	base         string
	libraryDir   string
	wallpaperDir string
	activeName   func() string
}

func newColorschemeProvider(cache *Cache) colorschemeProvider {
	if cache == nil {
		cache = newCache()
	}
	return colorschemeProvider{
		cache:      cache,
		base:       cache.base,
		libraryDir: filepath.Join(dataHome(), "ryoku", "themes"),
		// The still-wallpaper pool the picker scans (flat), shared with rices.
		wallpaperDir: filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers"),
		activeName:   activeSchemeName,
	}
}

func (colorschemeProvider) Category() Category {
	return Category{
		ID:          "colorschemes",
		Name:        "Themes",
		Group:       "wear",
		Description: "Color schemes for the desktop palette, from every provider.",
	}
}

func (p colorschemeProvider) Load(ctx context.Context, refresh bool) ([]Item, SourceState, error) {
	raw, state, err := p.cache.Fetch(ctx, colorschemeRegistryPath, refresh)
	if err != nil {
		return nil, state, err
	}
	var reg colorschemeRegistry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return nil, state, fmt.Errorf("parse colorscheme registry: %w", err)
	}
	active := p.activeName()
	items := make([]Item, 0, len(reg.Themes))
	for _, e := range reg.Themes {
		if !validComponent(e.ID) {
			return nil, state, fmt.Errorf("invalid colorscheme id %q", e.ID)
		}
		provider := e.Provider
		if provider == "" {
			provider = "Community"
		}
		installed := isRegularFile(filepath.Join(p.libraryDir, e.ID, "scheme.json"))
		tags := make([]string, 0, 2)
		if len(e.Dark) > 0 {
			tags = append(tags, "dark")
		}
		if len(e.Light) > 0 {
			tags = append(tags, "light")
		}
		items = append(items, Item{
			ID:        e.ID,
			Category:  "colorschemes",
			Name:      e.Name,
			Summary:   provider,
			Art:       resolveAsset(p.base, e.Path, e.Preview),
			Author:    provider,
			Accent:    e.Accent,
			Surface:   e.Surface,
			Tags:      tags,
			Installed: installed,
			Active:    installed && e.ID == active,
			Metadata:  map[string]any{"provider": provider},
		})
	}
	return items, state, nil
}

func (p colorschemeProvider) Install(ctx context.Context, id string) error {
	if !validComponent(id) {
		return fmt.Errorf("bad colorscheme id %q", id)
	}
	raw, _, err := p.cache.Fetch(ctx, colorschemeRegistryPath, false)
	if err != nil {
		return err
	}
	var reg colorschemeRegistry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return fmt.Errorf("parse colorscheme registry: %w", err)
	}
	var entry *colorschemeEntry
	for i := range reg.Themes {
		if reg.Themes[i].ID == id {
			entry = &reg.Themes[i]
			break
		}
	}
	if entry == nil {
		return fmt.Errorf("colorscheme %q is not in the store", id)
	}

	// The registry embeds the palette; assemble the library scheme.json from it so
	// an install needs no second fetch and works from the cache offline.
	scheme := map[string]json.RawMessage{}
	if len(entry.Dark) > 0 {
		scheme["dark"] = entry.Dark
	}
	if len(entry.Light) > 0 {
		scheme["light"] = entry.Light
	}
	if len(scheme) == 0 {
		return fmt.Errorf("colorscheme %q carries no palette", id)
	}
	schemeBytes, err := json.MarshalIndent(scheme, "", "  ")
	if err != nil {
		return err
	}
	meta := map[string]any{"label": entry.Name, "provider": entry.Provider}
	if entry.Source != "" {
		meta["source"] = entry.Source
	}
	metaBytes, err := json.MarshalIndent(meta, "", "  ")
	if err != nil {
		return err
	}

	dst := filepath.Join(p.libraryDir, id)
	unlock, err := lockTree(dst)
	if err != nil {
		return err
	}
	defer unlock()
	stage, err := os.MkdirTemp(filepath.Dir(dst), ".ryostore-stage-"+id+"-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(stage)
	if err := atomicWrite(filepath.Join(stage, "scheme.json"), schemeBytes, 0o644); err != nil {
		return err
	}
	if err := atomicWrite(filepath.Join(stage, "meta.json"), metaBytes, 0o644); err != nil {
		return err
	}
	// The catalogue's preview art goes beside the scheme as preview.<ext>: the
	// Color-scheme picker shows that image on the card when the folder carries
	// one and draws the palette pills otherwise. Fetched through the asset cache,
	// so the store's own card and the install share one download, and a failure
	// (offline, upstream 404) still installs the scheme; only the art is missing.
	if cached := p.fetchCached(ctx, entry.Preview); cached != "" {
		if ext := imageExt(cached); ext != "" {
			if b, err := os.ReadFile(cached); err == nil {
				_ = atomicWrite(filepath.Join(stage, "preview"+ext), b, 0o644)
			}
		}
	}
	if err := replaceTree(stage, dst, nil); err != nil {
		return err
	}
	// The scheme's own wallpapers land in the wallpaper library the picker
	// scans (flat; a subfolder would be invisible to it), named after the scheme
	// so Remove can take them back out and so they read as a set in Super+W.
	// Best-effort like the preview: a wall that fails to fetch is simply absent.
	for i, u := range entry.Wallpapers {
		cached := p.fetchCached(ctx, u)
		if cached == "" {
			continue
		}
		ext := imageExt(cached)
		if ext == "" {
			continue
		}
		if err := os.MkdirAll(p.wallpaperDir, 0o755); err != nil {
			break
		}
		wall := filepath.Join(p.wallpaperDir, fmt.Sprintf("%s-%d%s", id, i+1, ext))
		if isRegularFile(wall) {
			continue
		}
		if b, err := os.ReadFile(cached); err == nil {
			_ = atomicWrite(wall, b, 0o644)
		}
	}
	return nil
}

// fetchCached returns the asset-cache path of a remote image, downloading it
// on a miss, or "" when the URL is not remote or the fetch fails.
func (p colorschemeProvider) fetchCached(ctx context.Context, url string) string {
	if !remoteAsset(url) {
		return ""
	}
	cached := cachedAssetPath(url)
	if isRegularFile(cached) {
		return cached
	}
	if err := os.MkdirAll(assetCacheDir(), 0o755); err != nil {
		return ""
	}
	if err := downloadAsset(ctx, p.cache.client, url, cached); err != nil {
		return ""
	}
	return cached
}

// imageExt is the lower-cased extension of an image path the pickers can show,
// or "" for anything else.
func imageExt(path string) string {
	switch ext := strings.ToLower(filepath.Ext(path)); ext {
	case ".jpg", ".jpeg", ".png", ".webp":
		return ext
	default:
		return ""
	}
}

func (p colorschemeProvider) Remove(ctx context.Context, id string) error {
	if !validComponent(id) {
		return fmt.Errorf("bad colorscheme id %q", id)
	}
	dst := filepath.Join(p.libraryDir, id)
	if !isRegularFile(filepath.Join(dst, "scheme.json")) {
		return fmt.Errorf("colorscheme %q is not installed", id)
	}
	unlock, err := lockTree(dst)
	if err != nil {
		return err
	}
	defer unlock()
	if err := os.RemoveAll(dst); err != nil {
		return err
	}
	// The wallpapers the install landed go with it; anything the user saved
	// under another name stays.
	if walls, err := filepath.Glob(filepath.Join(p.wallpaperDir, id+"-[0-9]*.*")); err == nil {
		for _, w := range walls {
			_ = os.Remove(w)
		}
	}
	return nil
}

// activeSchemeName reads the applied scheme (shell.json theme.theme). It is empty
// for the dynamic variants, so no library scheme reads as active until it is worn
// through the Color-scheme picker; install alone never activates.
func activeSchemeName() string {
	raw, err := os.ReadFile(filepath.Join(configHome(), "ryoku", "shell.json"))
	if err != nil {
		return ""
	}
	var doc struct {
		Theme struct {
			Theme string `json:"theme"`
		} `json:"theme"`
	}
	if json.Unmarshal(raw, &doc) != nil {
		return ""
	}
	return doc.Theme.Theme
}
