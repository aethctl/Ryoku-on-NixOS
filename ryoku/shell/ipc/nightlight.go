package main

import (
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

// nightlight.go owns the night light so its state is a pushed topic instead of
// a shell poll. The on/off truth is the hyprsunset process (gamma lives in the
// compositor, so a dead process is the only honest "off"); the temperature is
// the state file ryoku-cmd-nightlight already writes. The watcher inotifies the
// state directory and rescans /proc on every change, so a toggle from the
// keybind, the script, the Hub, or a kill all reach QML without anything
// polling. Toggling from QML rides the same script: an intent is a user action,
// not a poll, and the script stays the single writer of the temp file.

const (
	nlProcessName = "hyprsunset"
	nlDefaultTemp = 4000
)

type nightlightState struct {
	topic    *stateTopic
	stateDir string
	tempFile string
}

// nightlightPaths derives the script's state files from XDG_STATE_HOME. The
// script hardcodes the same defaults, so the two stay in lockstep by naming.
func nightlightPaths() (dir, temp string) {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", ""
		}
		base = filepath.Join(home, ".local", "state")
	}
	return base, filepath.Join(base, "ryoku-nightlight")
}

// startNightlight registers the `nightlight` topic and its intents, then starts
// the watcher. An unresolvable state directory leaves the topic publishing the
// off frame only; nothing else degrades.
func (d *daemon) startNightlight() {
	dir, temp := nightlightPaths()
	n := &nightlightState{topic: d.registerTopic("nightlight"), stateDir: dir, tempFile: temp}

	d.registerCall("nightlight.toggle", func(json.RawMessage) (any, error) {
		return nil, n.run("toggle")
	})
	d.registerCall("nightlight.set", func(raw json.RawMessage) (any, error) {
		var a struct {
			On          *bool `json:"on"`
			Temperature int   `json:"temperature"`
		}
		if err := json.Unmarshal(raw, &a); err != nil {
			return nil, err
		}
		if a.On != nil && *a.On {
			if a.Temperature > 0 {
				return nil, n.run("on", strconv.Itoa(a.Temperature))
			}
			return nil, n.run("on")
		}
		return nil, n.run("off")
	})

	if dir == "" {
		n.publish(false)
		return
	}
	go n.watch()
}

// run execs ryoku-cmd-nightlight with the verb and waits, so the caller's reply
// reflects a completed toggle. The script republishes nothing itself; the
// marker and temp writes land in the state dir, which wakes the watcher to push
// the new frame.
func (n *nightlightState) run(args ...string) error {
	bin, err := exec.LookPath("ryoku-cmd-nightlight")
	if err != nil {
		return err
	}
	cmd := exec.Command(bin, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGKILL}
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("ryoku-shell: nightlight %v: %v: %s", args, err, strings.TrimSpace(string(out)))
	}
	return err
}

// watch publishes the current state once, then blocks in poll(2) on an inotify
// watch of the state directory: the marker create/remove and the temp write all
// land there, so every script-driven change pokes the watcher. A raw pkill from
// outside the script touches no file, so the bounded poll timeout doubles as a
// settle re-check: each expiry rescans /proc. No timer, no subprocess.
func (n *nightlightState) watch() {
	on, temp := n.running(), n.savedTemp()
	n.publish(on)

	fd, err := unix.InotifyInit1(unix.IN_CLOEXEC | unix.IN_NONBLOCK)
	if err != nil {
		// No inotify: fall back to the settle re-check alone.
		n.loopNoWatch(on, temp)
		return
	}
	defer unix.Close(fd)
	if _, err := unix.InotifyAddWatch(fd, n.stateDir, unix.IN_CLOSE_WRITE|unix.IN_CREATE|unix.IN_DELETE|unix.IN_MOVED_TO); err != nil {
		log.Printf("ryoku-shell: nightlight watch failed: %v", err)
	}

	buf := make([]byte, 4096)
	for {
		pfds := []unix.PollFd{{Fd: int32(fd), Events: unix.POLLIN | unix.POLLERR}}
		// The bounded poll doubles as the settle re-check: a raw pkill from
		// outside the script touches no watched file, so every expiry rescans
		// /proc and the temp file.
		if _, err := unix.Poll(pfds, 5000); err != nil && err != unix.EINTR {
			return
		}
		// Drain the inotify queue so the next poll does not fire immediately.
		for {
			if _, err := unix.Read(fd, buf); err != nil {
				break
			}
		}
		next, nextTemp := n.running(), n.savedTemp()
		if next != on || nextTemp != temp {
			on, temp = next, nextTemp
			n.publish(on)
		}
	}
}

// loopNoWatch is the degraded watcher when inotify is unavailable: a slow tick
// only, still fork-free.
func (n *nightlightState) loopNoWatch(on bool, temp int) {
	tick := time.NewTicker(5 * time.Second)
	defer tick.Stop()
	for range tick.C {
		next, nextTemp := n.running(), n.savedTemp()
		if next != on || nextTemp != temp {
			on, temp = next, nextTemp
			n.publish(on)
		}
	}
}

// publish writes the nightlight frame. The topic drops a byte-identical frame,
// so an unchanged state never wakes a binding.
func (n *nightlightState) publish(on bool) {
	if n.topic == nil {
		return
	}
	frame, err := json.Marshal(map[string]any{
		"on":          on,
		"temperature": n.savedTemp(),
	})
	if err != nil {
		return
	}
	n.topic.publish(frame)
}

// savedTemp reads the persisted temperature, defaulting to the script's default
// when no file exists or it is unparseable.
func (n *nightlightState) savedTemp() int {
	b, err := os.ReadFile(n.tempFile)
	if err != nil {
		return nlDefaultTemp
	}
	v, err := strconv.Atoi(strings.TrimSpace(string(b)))
	if err != nil || v <= 0 {
		return nlDefaultTemp
	}
	return v
}

// running scans /proc for a process named hyprsunset. This is the fork-free
// pgrep: read each pid's comm (one small file per process, no exec) and compare
// the name. comm truncates at 15 characters; hyprsunset fits, so an exact
// compare is right.
func (n *nightlightState) running() bool {
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return false
	}
	for _, e := range ents {
		if procCommIs(e.Name(), nlProcessName) {
			return true
		}
	}
	return false
}

// procCommIs reports whether the pid's comm equals name. It skips anything that
// is not a numeric process directory, so the caller can hand it every /proc
// entry. comm truncates at 15 characters; hyprsunset fits, so an exact compare
// is right.
func procCommIs(pid, name string) bool {
	if _, err := strconv.Atoi(pid); err != nil {
		return false
	}
	b, err := os.ReadFile("/proc/" + pid + "/comm")
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(b)) == name
}
