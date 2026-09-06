package main

import (
	"os"
	"path/filepath"
	"syscall"
	"testing"
)

func TestPruneQuickshellRuntimeKeepsHeldInstances(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)
	root := filepath.Join(rt, "quickshell", "by-id")

	dead := filepath.Join(root, "dead")
	os.MkdirAll(dead, 0o755)
	os.WriteFile(filepath.Join(dead, qsInstanceLock), nil, 0o644)
	os.WriteFile(filepath.Join(dead, "log.log"), []byte("x"), 0o644)

	live := filepath.Join(root, "live")
	os.MkdirAll(live, 0o755)
	lock, _ := os.OpenFile(filepath.Join(live, qsInstanceLock), os.O_CREATE|os.O_RDWR, 0o644)
	defer lock.Close()
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		t.Fatal(err)
	}
	big := filepath.Join(live, "log.log")
	os.WriteFile(big, make([]byte, qsLogCap+1), 0o644)
	small := filepath.Join(live, "log.qslog")
	os.WriteFile(small, []byte("keep"), 0o644)

	pruneQuickshellRuntime()

	if _, err := os.Stat(dead); !os.IsNotExist(err) {
		t.Fatal("a dead instance dir must be removed")
	}
	if st, err := os.Stat(big); err != nil || st.Size() != 0 {
		t.Fatalf("an oversized live log must be truncated, got %v %v", st, err)
	}
	if b, _ := os.ReadFile(small); string(b) != "keep" {
		t.Fatal("a small live log must be left alone")
	}
}
