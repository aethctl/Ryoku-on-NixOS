package main

import (
	"os"
	"path/filepath"
	"testing"
)

// The two lanes answer the same three questions differently: where the agent
// runs (and so which context file it reads), whether quick asks land there,
// and what rides the first turn. A wrong answer to any of them puts the
// machine map in front of a plain chat, or strips it from the Needle.
func TestLanesDiffer(t *testing.T) {
	t.Setenv("RYOKU_RASHIN_VAULT", filepath.Join(t.TempDir(), "vault"))
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	r, c := ryokuLane(), chatLane()
	if r.Cwd != VaultDir() {
		t.Fatalf("ryoku lane cwd = %q, want the vault %q", r.Cwd, VaultDir())
	}
	if c.Cwd == r.Cwd || filepath.HasPrefix(c.Cwd, r.Cwd) {
		t.Fatalf("chat lane cwd %q must sit outside the vault %q", c.Cwd, r.Cwd)
	}
	if !r.Quick || c.Quick {
		t.Fatalf("quick asks belong to the ryoku lane only: ryoku=%v chat=%v", r.Quick, c.Quick)
	}
	if r.Intro() == "" {
		t.Fatal("ryoku lane first turn carries the Needle's identity")
	}
	if c.Intro() != "" {
		t.Fatalf("chat lane first turn must add nothing, got %q", c.Intro())
	}
}

// A lane's history drawer lists the sessions opened in its cwd; a session
// the agent cannot place (no cwd) shows in every lane rather than nowhere,
// and a cwd reached through a symlink is the same directory.
func TestLaneOwnsSession(t *testing.T) {
	real := t.TempDir()
	link := filepath.Join(t.TempDir(), "link")
	if err := os.Symlink(real, link); err != nil {
		t.Skip("symlinks unavailable:", err)
	}
	if !(lane{Cwd: link}).ownsSession(SessionMeta{Cwd: real}) || !(lane{Cwd: real}).ownsSession(SessionMeta{Cwd: link}) {
		t.Fatal("a symlinked spelling of the lane dir must own the same sessions")
	}
	l := lane{Name: "x", Cwd: "/home/u/.local/share/ryoku/rashin"}
	cases := []struct {
		cwd  string
		want bool
	}{
		{"/home/u/.local/share/ryoku/rashin", true},
		{"/home/u/.local/share/ryoku/rashin/", true},
		{"/home/u/.local/state/ryoku/rashin-chat", false},
		{"/home/u/Work/foo", false},
		{"", true},
	}
	for _, c := range cases {
		if got := l.ownsSession(SessionMeta{Cwd: c.cwd}); got != c.want {
			t.Errorf("ownsSession(%q) = %v, want %v", c.cwd, got, c.want)
		}
	}
}
