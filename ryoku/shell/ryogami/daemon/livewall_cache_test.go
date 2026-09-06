package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestPruneLivewallCache(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", dir)
	cache := filepath.Join(dir, "ryogami", "livewall")
	if err := os.MkdirAll(cache, 0o755); err != nil {
		t.Fatal(err)
	}
	mk := func(name string, age time.Duration) string {
		p := filepath.Join(cache, name)
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
		mt := time.Now().Add(-age)
		if err := os.Chtimes(p, mt, mt); err != nil {
			t.Fatal(err)
		}
		return p
	}
	old := mk("old.mp4", 40*24*time.Hour)
	fresh := mk("fresh.mp4", 2*24*time.Hour)

	// days > 0 removes only files older than the cutoff.
	removed, freed := pruneLivewallCache(30)
	if removed != 1 || freed != 1 {
		t.Fatalf("age prune: removed=%d freed=%d, want 1/1", removed, freed)
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Fatal("clip older than retention should be removed")
	}
	if _, err := os.Stat(fresh); err != nil {
		t.Fatal("clip within retention should remain")
	}

	// days <= 0 clears everything that remains.
	removed, _ = pruneLivewallCache(0)
	if removed != 1 {
		t.Fatalf("clear-all: removed=%d, want 1", removed)
	}
	if entries, _ := os.ReadDir(cache); len(entries) != 0 {
		t.Fatalf("cache should be empty, has %d entries", len(entries))
	}
}
