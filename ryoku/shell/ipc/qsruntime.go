package main

import (
	"io"
	"os"
	"path/filepath"
	"strconv"
	"syscall"
	"time"
)

// Quickshell keeps a per-instance directory under $XDG_RUNTIME_DIR (a tmpfs,
// so RAM) with its lock, socket and two unbounded logs, and never removes the
// directory when the instance ends. One warning storm filled 4 GB of tmpfs
// here before the shell was restarted, and a hundred dead instances kept
// their logs after it. The daemon prunes dead instances and caps live logs.
const (
	qsLogCap       = 32 << 20
	qsPruneEvery   = 5 * time.Minute
	qsInstanceLock = "instance.lock"
)

func quickshellRuntimeDir() string {
	rt := os.Getenv("XDG_RUNTIME_DIR")
	if rt == "" {
		return ""
	}
	return filepath.Join(rt, "quickshell", "by-id")
}

func pruneQuickshellRuntime() {
	root := quickshellRuntimeDir()
	if root == "" {
		return
	}
	entries, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		dir := filepath.Join(root, e.Name())
		if instanceAlive(filepath.Join(dir, qsInstanceLock)) {
			for _, name := range []string{"log.log", "log.qslog"} {
				capFile(filepath.Join(dir, name))
			}
			continue
		}
		_ = os.RemoveAll(dir)
	}
	pruneQuickshellLinks()
}

// Quickshell indexes each instance under by-pid, by-path, by-shell and vfs as
// links into by-id. It does not clear them either, so a box collects hundreds
// of dangling entries; a link whose target is gone has nothing left to name.
func pruneQuickshellLinks() {
	rt := os.Getenv("XDG_RUNTIME_DIR")
	if rt == "" {
		return
	}
	for _, index := range []string{"by-pid", "by-path", "by-shell", "vfs"} {
		dir := filepath.Join(rt, "quickshell", index)
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, e := range entries {
			path := filepath.Join(dir, e.Name())
			if _, err := os.Stat(path); err != nil {
				_ = os.Remove(path)
			}
		}
	}
}

// instanceAlive: a running quickshell holds its instance.lock, and deleting a
// live instance's directory takes its ipc.sock with it, so every shell verb
// stops answering until the shell is relaunched. Linux keeps flock and POSIX
// record locks in separate families that do not see each other: quickshell
// takes a record lock, so probing with flock alone succeeds against a live
// instance and reads it as dead. Probe both and treat either as alive, because
// a stale directory costs tmpfs while a deleted live one costs the session.
func instanceAlive(lock string) bool {
	f, err := os.OpenFile(lock, os.O_RDWR, 0)
	if err != nil {
		// No lock to read: an instance mid-startup has not written one yet, so
		// fall back to whether a live process still claims this directory.
		return pidClaims(filepath.Dir(lock))
	}
	defer f.Close()
	rec := syscall.Flock_t{Type: syscall.F_WRLCK, Whence: io.SeekStart}
	if err := syscall.FcntlFlock(f.Fd(), syscall.F_SETLK, &rec); err != nil {
		return true
	}
	rec.Type = syscall.F_UNLCK
	_ = syscall.FcntlFlock(f.Fd(), syscall.F_SETLK, &rec)
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return true
	}
	_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
	return pidClaims(filepath.Dir(lock))
}

// pidClaims: quickshell also records each instance under by-pid as a symlink to
// the instance directory, so a live process pointing here is proof of life even
// when the lock cannot be read.
func pidClaims(dir string) bool {
	rt := os.Getenv("XDG_RUNTIME_DIR")
	if rt == "" {
		return false
	}
	byPid := filepath.Join(rt, "quickshell", "by-pid")
	entries, err := os.ReadDir(byPid)
	if err != nil {
		return false
	}
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		target, err := filepath.EvalSymlinks(filepath.Join(byPid, e.Name()))
		if err != nil || target != dir {
			continue
		}
		if syscall.Kill(pid, 0) == nil {
			return true
		}
	}
	return false
}

func capFile(path string) {
	st, err := os.Stat(path)
	if err != nil || st.Size() <= qsLogCap {
		return
	}
	_ = os.Truncate(path, 0)
}

func (d *daemon) runtimeJanitor() {
	pruneQuickshellRuntime()
	t := time.NewTicker(qsPruneEvery)
	defer t.Stop()
	for {
		select {
		case <-d.quit:
			return
		case <-t.C:
			pruneQuickshellRuntime()
		}
	}
}
