package main

import (
	"net"
	"os"
	"path/filepath"
	"testing"
)

// A second `ryogami` in a terminal must refuse to start while a daemon is
// live on the socket, never steal it: the interloper restores the saved
// wallpaper over the running one and dies with the terminal, leaving the
// picker with no daemon at all.
func TestRunDaemonRefusesWhileLive(t *testing.T) {
	runtime := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", runtime)
	sock := socketPath()

	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatalf("live listener: %v", err)
	}
	defer ln.Close()

	if err := runDaemon(); err == nil {
		t.Error("runDaemon() started a second daemon on a live socket")
	}
	if _, err := os.Stat(sock); err != nil {
		t.Errorf("the live socket was disturbed: %v", err)
	}
}

// a stale socket left by a dead daemon must not block the rebind.
func TestDaemonLiveFalseOnStaleSocket(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "ryogami.sock")
	if err := os.WriteFile(sock, []byte(""), 0o600); err != nil {
		t.Fatal(err)
	}
	if daemonLive(sock) {
		t.Error("daemonLive() reported a stale socket as live")
	}
}
