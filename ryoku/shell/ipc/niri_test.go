package main

import (
	"bufio"
	"net"
	"path/filepath"
	"strings"
	"testing"
)

func TestNiriCompositorIdentity(t *testing.T) {
	n := niriCompositor{socket: "/run/user/1000/niri.wayland-1.123.sock"}
	if got := n.Identity(); got != "niri:/run/user/1000/niri.wayland-1.123.sock" {
		t.Fatalf("Identity() = %q", got)
	}
}

func TestOpenNiriEventStream(t *testing.T) {
	path := filepath.Join(t.TempDir(), "niri.sock")
	ln, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	serverErr := make(chan error, 1)
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			serverErr <- err
			return
		}
		defer conn.Close()

		reader := bufio.NewReader(conn)
		line, err := reader.ReadString('\n')
		if err != nil {
			serverErr <- err
			return
		}
		if strings.TrimSpace(line) != `"EventStream"` {
			serverErr <- &unexpectedNiriRequest{got: strings.TrimSpace(line)}
			return
		}

		_, err = conn.Write([]byte("{\"Ok\":\"Handled\"}\n{\"WorkspacesChanged\":{\"workspaces\":[]}}\n"))
		serverErr <- err
	}()

	conn, reader, err := openNiriEventStream(path)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	event, err := reader.ReadString('\n')
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(event, "WorkspacesChanged") {
		t.Fatalf("unexpected event: %s", event)
	}

	if err := <-serverErr; err != nil {
		t.Fatal(err)
	}
}

type unexpectedNiriRequest struct {
	got string
}

func (e *unexpectedNiriRequest) Error() string {
	return "unexpected niri request: " + e.got
}
