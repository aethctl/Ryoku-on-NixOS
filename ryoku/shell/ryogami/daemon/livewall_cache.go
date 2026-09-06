package main

import (
	"os"
	"path/filepath"
	"time"
)

// livewallCacheDir holds the transcoded clips (livewallSource) and sampled
// stills (liveStill) the video wallpaper pipeline reuses across plays. It grows
// with every distinct clip and is never reclaimed on its own, so the picker
// exposes a retention policy that drives pruneLivewallCache.
func livewallCacheDir() string {
	return filepath.Join(cacheHome(), "ryogami", "livewall")
}

// pruneLivewallCache reclaims the livewall cache. With days > 0 it removes only
// files last modified before the cutoff; with days <= 0 it clears everything.
// It reports how many files were removed and how many bytes were freed. The
// clips regenerate on the next play, so pruning is always safe.
func pruneLivewallCache(days int) (removed int, freed int64) {
	dir := livewallCacheDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0, 0
	}
	cutoff := time.Now().AddDate(0, 0, -days)
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, ierr := e.Info()
		if ierr != nil {
			continue
		}
		if days > 0 && !info.ModTime().Before(cutoff) {
			continue
		}
		size := info.Size()
		if err := os.Remove(filepath.Join(dir, e.Name())); err == nil {
			removed++
			freed += size
		}
	}
	return removed, freed
}
