package main

import (
	"os"
	"path/filepath"
	"testing"
)

// daemonWithDirs builds a daemon whose config points at temp wallpaper/video/
// cache dirs, so librarySignature runs against a controlled tree.
func daemonWithDirs(t *testing.T) (*daemon, string, string) {
	t.Helper()
	wall := t.TempDir()
	vid := t.TempDir()
	cache := t.TempDir()
	d := &daemon{}
	d.cfg.Paths.Wallpaper = wall
	d.cfg.Paths.VideoWallpaper = vid
	d.cfg.Paths.Cache = cache
	return d, wall, vid
}

func writeMedia(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestLibrarySignatureTracksMedia(t *testing.T) {
	d, wall, vid := daemonWithDirs(t)

	base := d.librarySignature()
	if base != d.librarySignature() {
		t.Fatal("signature is not stable across calls on an unchanged tree")
	}

	// A new image bumps it.
	writeMedia(t, filepath.Join(wall, "new.png"), "img")
	added := d.librarySignature()
	if added == base {
		t.Fatal("adding an image did not change the signature")
	}

	// A new video in the separate video dir bumps it too.
	writeMedia(t, filepath.Join(vid, "clip.mp4"), "vid")
	withVid := d.librarySignature()
	if withVid == added {
		t.Fatal("adding a video did not change the signature")
	}

	// A non-media file is ignored.
	writeMedia(t, filepath.Join(wall, "notes.txt"), "text")
	if d.librarySignature() != withVid {
		t.Fatal("a non-media file changed the signature")
	}

	// A dotfile dir is skipped (mirrors collectMedia).
	writeMedia(t, filepath.Join(wall, ".trash", "old.png"), "img")
	if d.librarySignature() != withVid {
		t.Fatal("a dotdir file changed the signature")
	}

	// Removing the image reverts to the video-only signature.
	if err := os.Remove(filepath.Join(wall, "new.png")); err != nil {
		t.Fatal(err)
	}
	if got := d.librarySignature(); got == withVid {
		t.Fatal("removing an image did not change the signature")
	}
}
