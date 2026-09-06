package main

import (
	"bufio"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// At login the wallpaper file (a late mount) or the outputs (a late monitor)
// can lag the daemon; a one-shot restore then left the grey default for the
// session. retryRestore covers the first, watchOutputs the second.

const (
	restoreRetryWindow   = 30 * time.Second
	restoreRetryInterval = 1 * time.Second
)

func (d *daemon) retryRestore() {
	deadline := time.Now().Add(restoreRetryWindow)
	for time.Now().Before(deadline) {
		time.Sleep(restoreRetryInterval)
		if want, applied := d.restoreOutputs(); want == 0 || applied > 0 {
			return
		}
	}
}

// Only the external live-wall player is spawned per output; a static frame
// and the in-shell engine ride the retained topic the shell repaints itself.
func (d *daemon) externalLiveStored() bool {
	if wallPrefs().Engine == "in_shell" {
		return false
	}
	state := map[string]map[string]interface{}{}
	loadJSON(filepath.Join(d.config().cacheDir(), "outputs.json"), &state)
	for _, e := range state {
		if e["type"] == "video" {
			return true
		}
	}
	return false
}

func (d *daemon) watchOutputs() {
	for {
		sock := hyprEventSocket()
		if sock == "" {
			time.Sleep(restoreRetryInterval)
			continue
		}
		conn, err := net.Dial("unix", sock)
		if err != nil {
			time.Sleep(restoreRetryInterval)
			continue
		}
		r := bufio.NewReader(conn)
		for {
			line, err := r.ReadString('\n')
			if err != nil {
				break
			}
			if strings.HasPrefix(line, "monitoradded") && d.config().restoreEnabled() && d.externalLiveStored() {
				d.restoreOutputs()
			}
		}
		_ = conn.Close()
		time.Sleep(restoreRetryInterval)
	}
}

// hyprEventSocket picks the newest instance directory: a daemon restarted
// from a lagging user-manager environment can inherit a stale signature.
func hyprEventSocket() string {
	best, bestMod := "", time.Time{}
	for _, base := range hyprRunDirs() {
		entries, err := os.ReadDir(base)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			sock := filepath.Join(base, e.Name(), ".socket2.sock")
			fi, err := os.Stat(sock)
			if err != nil {
				continue
			}
			if best == "" || fi.ModTime().After(bestMod) {
				best, bestMod = sock, fi.ModTime()
			}
		}
	}
	return best
}

func hyprRunDirs() []string {
	var dirs []string
	if rt := os.Getenv("XDG_RUNTIME_DIR"); rt != "" {
		dirs = append(dirs, filepath.Join(rt, "hypr"))
	}
	dirs = append(dirs, filepath.Join("/tmp", "hypr"))
	return dirs
}
