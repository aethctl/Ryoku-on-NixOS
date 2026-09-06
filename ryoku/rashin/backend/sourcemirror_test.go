package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestGoCopyTreeSkipsSymlinksAndBigFiles(t *testing.T) {
	src := t.TempDir()
	dst := t.TempDir()

	// A nested regular file and a top-level one, both copied.
	if err := os.MkdirAll(filepath.Join(src, "sub"), 0o755); err != nil {
		t.Fatal(err)
	}
	mustWrite(t, filepath.Join(src, "sub", "s.qml"), []byte("small"))
	mustWrite(t, filepath.Join(src, "a.txt"), []byte("hi"))

	// A file symlink and a directory symlink: both skipped, and the dir symlink
	// is never descended into.
	real := filepath.Join(src, "realdir")
	if err := os.MkdirAll(real, 0o755); err != nil {
		t.Fatal(err)
	}
	mustWrite(t, filepath.Join(real, "f.txt"), []byte("real"))
	if err := os.Symlink("a.txt", filepath.Join(src, "link.txt")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("realdir", filepath.Join(src, "dlink")); err != nil {
		t.Fatal(err)
	}

	// A file over the size cap: skipped.
	mustWrite(t, filepath.Join(src, "big.bin"), make([]byte, sourceMirrorMaxFileSize+1))

	goCopyTree(src, dst)

	// Copied.
	assertExists(t, filepath.Join(dst, "a.txt"))
	assertExists(t, filepath.Join(dst, "sub", "s.qml"))
	assertExists(t, filepath.Join(dst, "realdir", "f.txt"))
	// Skipped.
	assertAbsent(t, filepath.Join(dst, "link.txt"))
	assertAbsent(t, filepath.Join(dst, "dlink"))
	assertAbsent(t, filepath.Join(dst, "big.bin"))
}

func TestMirrorTreeGlobTakesTopLevelJSONOnly(t *testing.T) {
	src := t.TempDir()
	dst := t.TempDir()
	mustWrite(t, filepath.Join(src, "shell.json"), []byte("{}"))
	mustWrite(t, filepath.Join(src, "theme.json"), []byte("{}"))
	mustWrite(t, filepath.Join(src, "notes.txt"), []byte("x"))
	if err := os.MkdirAll(filepath.Join(src, "store"), 0o755); err != nil {
		t.Fatal(err)
	}
	mustWrite(t, filepath.Join(src, "store", "deep.json"), []byte("{}"))

	mirrorTree(mirrorInput{src: src, dst: dst, glob: "*.json"}, dst)

	assertExists(t, filepath.Join(dst, "shell.json"))
	assertExists(t, filepath.Join(dst, "theme.json"))
	assertAbsent(t, filepath.Join(dst, "notes.txt")) // not JSON
	assertAbsent(t, filepath.Join(dst, "store"))     // nested, not top-level
	assertAbsent(t, filepath.Join(dst, "deep.json"))
}

func mustWrite(t *testing.T, path string, data []byte) {
	t.Helper()
	if err := os.WriteFile(path, data, 0o644); err != nil {
		t.Fatal(err)
	}
}

func assertExists(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("expected %s: %v", path, err)
	}
}

func assertAbsent(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		t.Fatalf("expected %s absent, got err=%v", path, err)
	}
}
