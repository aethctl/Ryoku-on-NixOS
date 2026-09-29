package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"syscall"
	"time"
)

// fixterm.go opens Fix with AI in the user's own agent harness, in a real
// terminal: the harness's TUI already streams its thinking, shows every tool
// call and its output, asks its own approvals, and switches models, so a repair
// runs where all of that is native. The problem brief is the session's first
// message and the Needle persona rides as extra system prompt where the
// harness takes one.

// fixHarness is an agent whose terminal UI can open a repair session.
type fixHarness struct {
	ID   string
	Name string
	bin  func() (string, bool)
	// argv starts the harness interactively with prompt as the first message.
	argv func(bin, persona, prompt string) []string
}

func onPath(name string) func() (string, bool) {
	return func() (string, bool) {
		p, err := exec.LookPath(name)
		return p, err == nil
	}
}

// fixHarnesses lists the harnesses Fix with AI can open, in the chat backend
// preference order (Hermes leads).
func fixHarnesses() []fixHarness {
	return []fixHarness{
		{
			ID: "hermes", Name: "Hermes", bin: FindHermes,
			// Hermes has no interactive start with a first message: the brief
			// runs as one query in this terminal, then the same session opens
			// for the rest of the conversation. A failed first query must not
			// resume some older session.
			argv: func(bin, persona, prompt string) []string {
				return []string{"sh", "-c", `"$0" chat -q "$1" && exec "$0" chat --continue`, bin, persona + "\n\n" + prompt}
			},
		},
		{
			ID: "omp", Name: "Oh My Pi", bin: onPath("omp"),
			argv: func(bin, persona, prompt string) []string {
				return []string{bin, "--append-system-prompt", persona, prompt}
			},
		},
		{
			ID: "claude", Name: "Claude Code", bin: onPath("claude"),
			argv: func(bin, persona, prompt string) []string {
				return []string{bin, "--append-system-prompt", persona, prompt}
			},
		},
	}
}

// pickFixHarness prefers the agent the user chose for the chat, then the
// first installed harness.
func pickFixHarness(want string, hs []fixHarness) (fixHarness, string, bool) {
	for _, h := range hs {
		if h.ID == want {
			if bin, ok := h.bin(); ok {
				return h, bin, true
			}
		}
	}
	for _, h := range hs {
		if bin, ok := h.bin(); ok {
			return h, bin, true
		}
	}
	return fixHarness{}, "", false
}

// fixLaunch is a repair ready to run: which harness, and the command line.
type fixLaunch struct {
	Harness string
	Argv    []string
}

func planFix(display, brief string) (fixLaunch, error) {
	h, bin, ok := pickFixHarness(LoadConfig().ChatAgent, fixHarnesses())
	if !ok {
		return fixLaunch{}, errors.New("no agent harness to open; install Hermes or Oh My Pi")
	}
	return fixLaunch{Harness: h.Name, Argv: h.argv(bin, needlePersona, display+"\n\n"+brief)}, nil
}

// holdOnFailure keeps the terminal open when the harness exits with an error,
// so a missing key or a crash reads as a message instead of a window that
// flashes and vanishes.
func holdOnFailure(name string, argv []string) []string {
	script := `n=$1; shift; "$@"; s=$?; [ "$s" -eq 0 ] && exit 0; ` +
		`printf '\n%s stopped (exit %d). Press Enter to close.' "$n" "$s"; read -r _; exit "$s"`
	return append([]string{"sh", "-c", script, "ryoku-fix", name}, argv...)
}

// openFixTerminal opens the repair in the user's terminal (the Default Apps
// terminal role). It runs as its own transient user unit, not as a child of
// whoever asked: restarting the Rashin daemon must not close a repair in
// progress, and the unit gets the session's display environment even when the
// caller started before the compositor exported it.
func openFixTerminal(l fixLaunch) error {
	run, err := exec.LookPath("systemd-run")
	if err != nil {
		return errors.New("systemd-run is missing")
	}
	app, err := exec.LookPath("ryoku-app")
	if err != nil {
		return errors.New("ryoku-app is missing, so the terminal cannot be opened")
	}
	args := []string{
		"--user", "--collect", "--quiet",
		"--unit=ryoku-fix-" + strconv.FormatInt(time.Now().UnixNano(), 36),
		"--working-directory=" + VaultDir(),
		"--setenv=PATH=" + os.Getenv("PATH"),
		"--", app, "terminal", "--",
	}
	args = append(args, holdOnFailure(l.Harness, l.Argv)...)
	if out, err := exec.Command(run, args...).CombinedOutput(); err != nil {
		return fmt.Errorf("could not open the terminal: %v %s", err, out)
	}
	return nil
}

// runFixHere replaces this process with the harness, for a fix asked from a
// terminal: the repair continues right where the user typed.
func runFixHere(l fixLaunch) error {
	if err := os.Chdir(VaultDir()); err != nil {
		return err
	}
	bin, err := exec.LookPath(l.Argv[0])
	if err != nil {
		return err
	}
	return syscall.Exec(bin, l.Argv, os.Environ())
}
