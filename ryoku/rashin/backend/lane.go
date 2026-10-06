package main

import (
	"os"
	"path/filepath"
)

// A lane is one purpose for the agent conversation, and each lane is its own
// hub with its own agent process. The agent learns what a lane is for through
// the only system prompt ACP offers: the context file at the session's cwd.
// The Ryoku lane runs in the vault, whose AGENTS.md the daemon writes, so the
// Needle knows the machine; the chat lane runs in a bare directory, so the
// harness answers as itself with nothing about the machine in front of it.
type lane struct {
	Name string
	// Cwd is the session's working directory and the source of its context.
	Cwd string
	// Quick: the fast direct-model path (and the escalation into this lane's
	// agent) belongs here. Only the Ryoku lane has one.
	Quick bool
	// Intro returns the preamble that rides a session's first turn, or "" for
	// none. The vault lane carries the Needle's identity for agents that read
	// no context file; the chat lane adds nothing.
	Intro func() string
}

const (
	laneRyoku = "ryoku"
	laneChat  = "chat"
)

func ryokuLane() lane {
	return lane{Name: laneRyoku, Cwd: VaultDir(), Quick: true,
		Intro: func() string { return LoadConfig().IntroPreamble() }}
}

func chatLane() lane {
	return lane{Name: laneChat, Cwd: ChatLaneDir(), Quick: false,
		Intro: func() string { return "" }}
}

// ChatLaneDir is the plain-chat session cwd: under the state dir, outside the
// vault, so Hermes finds no AGENTS.md there (it reads the cwd only, never the
// parents) and nothing in it is a knowledge base anyone should write to.
func ChatLaneDir() string {
	if d := os.Getenv("RYOKU_RASHIN_CHAT_DIR"); d != "" {
		return d
	}
	state := os.Getenv("XDG_STATE_HOME")
	if state == "" {
		state = filepath.Join(home(), ".local", "state")
	}
	return filepath.Join(state, "ryoku", "rashin-chat")
}

// ownsSession reports whether a stored session belongs to this lane: the one
// whose cwd it was opened in. Paths compare resolved, since a data dir reached
// through a symlink is still the same vault. An agent that reports no cwd
// cannot be sorted, so its sessions show in every lane rather than vanish.
func (l lane) ownsSession(s SessionMeta) bool {
	if s.Cwd == "" {
		return true
	}
	return resolvedPath(s.Cwd) == resolvedPath(l.Cwd)
}

// resolvedPath follows symlinks when the path still exists and cleans it
// either way, so two spellings of one directory compare equal.
func resolvedPath(p string) string {
	if r, err := filepath.EvalSymlinks(p); err == nil {
		return filepath.Clean(r)
	}
	return filepath.Clean(p)
}
