// Local-source plugin install: `ryostore install plugins <id> --from <dir>`.
// It builds a ProductManifest from a directory and feeds the SAME install
// transaction as a registry install, so a plugin installed from git lands with
// the receipt, content-hashed view, and journal the shell's discover.sh
// requires. It reads no code from the plugin.
package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path"
	"path/filepath"
)

// localProductSource lets the install transaction take the manifest and read
// every file's bytes from a local directory instead of the cache. Only these two
// source seams change; every transaction check still runs.
type localProductSource struct {
	root     string
	manifest ProductManifest
}

// InstallFrom installs a plugin from a local directory through the shared
// install transaction. It never runs anything from the plugin.
func (pluginProvider) InstallFrom(ctx context.Context, id, dir string) error {
	entry, manifest, err := buildLocalProductManifest(id, dir)
	if err != nil {
		return err
	}
	return installProductFrom(ctx, nil, "plugins", entry, &localProductSource{root: dir, manifest: manifest})
}

// buildLocalProductManifest walks dir and builds the plugins ProductManifest and
// the ProductEntry the install transaction needs: every regular file hashed,
// with symlinks and the .git tree skipped, and the version taken from the
// plugin's own manifest.json. The resulting manifest is validated exactly as a
// registry manifest is.
func buildLocalProductManifest(id, dir string) (ProductEntry, ProductManifest, error) {
	if !productIDPattern.MatchString(id) {
		return ProductEntry{}, ProductManifest{}, fmt.Errorf("invalid plugin id %q", id)
	}
	name, version, err := localPluginIdentity(id, dir)
	if err != nil {
		return ProductEntry{}, ProductManifest{}, err
	}
	files, err := walkLocalProductFiles(dir)
	if err != nil {
		return ProductEntry{}, ProductManifest{}, err
	}
	manifest := ProductManifest{
		Schema:      1,
		ID:          id,
		Category:    "plugins",
		Version:     version,
		Destination: path.Join("ryoku", "plugins", id),
		Files:       files,
	}
	// A synthetic entry: only ID, Version, and (for logging) Name matter for a
	// local install; Path is unused because the file bytes come from the dir, not
	// the cache. The registry-metadata invariants validateProductEntry enforces
	// (accent colour, screenshots, manifest hash) do not apply to a local tree.
	entry := ProductEntry{
		ID:      id,
		Name:    name,
		Version: version,
		Path:    path.Join("plugins", id),
	}
	if err := validateProductManifest("plugins", entry, manifest); err != nil {
		return ProductEntry{}, ProductManifest{}, err
	}
	return entry, manifest, nil
}

// localPluginIdentity reads the plugin's own manifest.json for its name and
// version and confirms its id matches the requested one.
func localPluginIdentity(id, dir string) (name, version string, err error) {
	raw, err := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err != nil {
		return "", "", fmt.Errorf("read plugin manifest: %w", err)
	}
	var m struct {
		ID      string `json:"id"`
		Name    string `json:"name"`
		Version string `json:"version"`
	}
	if err := json.Unmarshal(raw, &m); err != nil {
		return "", "", fmt.Errorf("parse plugin manifest: %w", err)
	}
	if m.ID != id {
		return "", "", fmt.Errorf("plugin manifest id %q does not match %q", m.ID, id)
	}
	if m.Version == "" {
		return "", "", fmt.Errorf("plugin manifest has no version")
	}
	name = m.Name
	if name == "" {
		name = id
	}
	return name, m.Version, nil
}

// walkLocalProductFiles collects every regular file under dir as a ProductFile
// whose destination mirrors its source. It skips symlinks, the .git tree, and
// store-internal scratch names, and marks each file installable.
func walkLocalProductFiles(dir string) ([]ProductFile, error) {
	var files []ProductFile
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if p != dir && d.Name() == ".git" {
				return filepath.SkipDir
			}
			return nil
		}
		if d.Type()&fs.ModeSymlink != 0 {
			return nil
		}
		rel, err := filepath.Rel(dir, p)
		if err != nil {
			return err
		}
		source := filepath.ToSlash(rel)
		if !validProductPath(source) {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		mode := "0644"
		if info.Mode().Perm()&0o111 != 0 {
			mode = "0755"
		}
		files = append(files, ProductFile{
			Source:      source,
			Destination: source,
			SHA256:      fmt.Sprintf("%x", sha256.Sum256(data)),
			Mode:        mode,
			Size:        int64(len(data)),
			Install:     true,
		})
		return nil
	})
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, fmt.Errorf("no installable files in %s", dir)
	}
	return files, nil
}

// readLocalProductFile reads one file from a local product source under the same
// path, size, and hash guards fetchProductFile applies to a cached file.
func readLocalProductFile(root, source string, size int64, expectedHash string) ([]byte, error) {
	if !validProductPath(source) || size < 0 || size > maxProductFileSize || !productHashPattern.MatchString(expectedHash) {
		return nil, fmt.Errorf("invalid product file %q", source)
	}
	if err := rejectSymlinkPath(root, filepath.FromSlash(source)); err != nil {
		return nil, err
	}
	data, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(source)))
	if err != nil {
		return nil, err
	}
	if err := validateProductPayload(data, size, expectedHash); err != nil {
		return nil, err
	}
	return data, nil
}
