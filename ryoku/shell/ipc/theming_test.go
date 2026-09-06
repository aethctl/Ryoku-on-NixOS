package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestIsVideo(t *testing.T) {
	cases := map[string]bool{
		"/x/a.mp4": true, "/x/a.MP4": true, "/x/a.webm": true,
		"/x/a.mkv": true, "/x/a.mov": true,
		"/x/a.jpg": false, "/x/a.png": false, "/x/a.gif": false, "/x/plain": false,
	}
	for p, want := range cases {
		if got := isVideo(p); got != want {
			t.Errorf("isVideo(%q) = %v, want %v", p, got, want)
		}
	}
}

func TestFrameOffset(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_STATE_HOME", dir)
	tune := filepath.Join(dir, "ryoku-ryowalls.json")
	video := "/home/x/Pictures/livewalls/clip.mp4"

	// no tune -> the auto default
	if got := frameOffset(video); got != "1" {
		t.Fatalf("no tune: got %q want 1", got)
	}
	// a tune for this video -> its chosen second
	_ = os.WriteFile(tune, []byte(`{"image":"`+video+`","frame":3.5}`), 0o644)
	if got := frameOffset(video); got != "3.50" {
		t.Fatalf("matching tune: got %q want 3.50", got)
	}
	// a tune keyed to another video never bleeds across
	if got := frameOffset("/home/x/other.mp4"); got != "1" {
		t.Fatalf("other video: got %q want 1", got)
	}
	// frame 0 falls back to the default
	_ = os.WriteFile(tune, []byte(`{"image":"`+video+`","frame":0}`), 0o644)
	if got := frameOffset(video); got != "1" {
		t.Fatalf("zero frame: got %q want 1", got)
	}
}

// liveFrame caches one still per clip + mtime + offset. The still used to be a
// single shared file, which is how a preview of one clip could hand the reader
// another clip's frame.
func TestLiveFramePerClip(t *testing.T) {
	state := t.TempDir()
	t.Setenv("XDG_STATE_HOME", state)
	bin := t.TempDir()
	runs := filepath.Join(state, "ffmpeg.runs")
	body := `printf x >> "` + runs + `"; for a in "$@"; do o="$a"; done; : > "$o"`
	if err := os.WriteFile(filepath.Join(bin, "ffmpeg"), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	clips := t.TempDir()
	one := filepath.Join(clips, "one.mp4")
	two := filepath.Join(clips, "two.mp4")
	for _, c := range []string{one, two} {
		if err := os.WriteFile(c, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	first := liveFrame(one)
	if first == "" || !strings.Contains(first, "ryoku-live-frames") {
		t.Fatalf("still for one.mp4 = %q, want a file under ryoku-live-frames", first)
	}
	if again := liveFrame(one); again != first {
		t.Errorf("second call = %q, want the cached %q", again, first)
	}
	if b, _ := os.ReadFile(runs); len(b) != 1 {
		t.Errorf("ffmpeg ran %d times for one clip, want 1", len(b))
	}
	if other := liveFrame(two); other == first {
		t.Errorf("two.mp4 reused one.mp4's still (%q): a shared still is the bug", other)
	}

	// The ryowalls frame slider picks a different second: that is a different
	// still, not an overwrite of the one already on screen.
	tune := filepath.Join(state, "ryoku-ryowalls.json")
	if err := os.WriteFile(tune, []byte(`{"image":"`+one+`","frame":4}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if moved := liveFrame(one); moved == first {
		t.Errorf("offset 4 reused the offset 1 still (%q)", moved)
	}
}
