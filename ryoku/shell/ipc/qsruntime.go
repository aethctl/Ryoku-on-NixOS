package main

import (
	"os"
	"path/filepath"
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
}

// instanceAlive: a running quickshell holds a lock on its instance.lock; a
// lock we can take is one nobody holds.
func instanceAlive(lock string) bool {
	f, err := os.OpenFile(lock, os.O_RDWR, 0)
	if err != nil {
		return false
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return true
	}
	_ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
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
