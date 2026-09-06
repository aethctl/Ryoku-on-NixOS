package main

import (
	"hash/fnv"
	"io/fs"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// watchLibrary triggers a rescan when the wallpaper or video directory's media
// set changes, so files dropped into the folders by hand appear without a
// daemon restart. The module takes no external deps, so this polls rather than
// using inotify: a signature of every catalogued file's path, mtime and size,
// compared every few seconds. A no-op tick only stats the media files already
// there; a real change reuses the mtime-gated rescan, whose per-item
// `ryogami.wall.cached` and closing `cache ready` events the resident picker
// already folds into its grid live (and reloads from on next open). The
// startup rescan seeds the baseline, so this never double-scans at boot.
func (d *daemon) watchLibrary() {
	last := d.librarySignature()
	for {
		time.Sleep(3 * time.Second)
		sig := d.librarySignature()
		if sig == last {
			continue
		}
		last = sig
		d.rescan(false)
	}
}

// librarySignature is an order-stable fingerprint of every media file under the
// wallpaper and video dirs (path, mtime, size). Any add, remove, or in-place
// replace changes it. It mirrors collectMedia's walk filters (skip dotdirs and
// the cache subtree, keep only catalogued extensions) so it tracks exactly the
// files a rescan would, and never trips on thumbnails the daemon writes.
func (d *daemon) librarySignature() uint64 {
	cfg := d.config()
	absCache, _ := filepath.Abs(cfg.cacheDir())
	h := fnv.New64a()
	seen := map[string]bool{}
	for _, root := range []string{cfg.wallpaperDir(), cfg.videoDir()} {
		if root == "" || seen[root] {
			continue
		}
		seen[root] = true
		_ = filepath.WalkDir(root, func(path string, e fs.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if e.IsDir() {
				if abs, _ := filepath.Abs(path); abs == absCache {
					return filepath.SkipDir
				}
				if path != root && strings.HasPrefix(e.Name(), ".") {
					return filepath.SkipDir
				}
				return nil
			}
			ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(e.Name()), "."))
			if !imageExts[ext] && !videoExts[ext] {
				return nil
			}
			info, ierr := e.Info()
			if ierr != nil {
				return nil
			}
			h.Write([]byte(path))
			h.Write([]byte{0})
			h.Write([]byte(strconv.FormatInt(info.ModTime().UnixNano(), 10)))
			h.Write([]byte{0})
			h.Write([]byte(strconv.FormatInt(info.Size(), 10)))
			h.Write([]byte{0})
			return nil
		})
	}
	return h.Sum64()
}
