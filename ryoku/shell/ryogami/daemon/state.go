package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

func (c config) stateDir() string {
	return filepath.Join(stateHome(), "ryogami")
}

// Copy metadata only. Thumbnails and transcodes remain disposable.
func (c config) migrateState() error {
	for _, name := range []string{"outputs.json", "wallpaper/index.json", "wallpaper/state.json", "wallpaper/playlists.json", "wallpaper/we_properties.json"} {
		dst := filepath.Join(c.stateDir(), name)
		if _, err := os.Lstat(dst); err == nil {
			continue
		} else if !os.IsNotExist(err) {
			return err
		}
		data, err := os.ReadFile(filepath.Join(c.cacheDir(), name))
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if !json.Valid(data) {
			return fmt.Errorf("invalid JSON in legacy %s", name)
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		tmp, err := os.CreateTemp(filepath.Dir(dst), ".migrate-*")
		if err != nil {
			return err
		}
		tmpName := tmp.Name()
		defer os.Remove(tmpName)
		if _, err := tmp.Write(data); err != nil {
			tmp.Close()
			return err
		}
		if err := tmp.Close(); err != nil {
			return err
		}
		// Linking publishes a complete file without replacing a newer choice.
		if err := os.Link(tmpName, dst); err != nil && !os.IsExist(err) {
			return err
		}
	}
	return nil
}
