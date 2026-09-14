package main

import (
	"bufio"
	"encoding/json"
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

func TestQueryNiriFocusedOutput(t *testing.T) {
	path := filepath.Join(t.TempDir(), "niri-focused.sock")
	ln, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		reader := bufio.NewReader(conn)
		line, _ := reader.ReadString('\n')
		if strings.TrimSpace(line) == `"FocusedOutput"` {
			_, _ = conn.Write([]byte("{\"Ok\":{\"FocusedOutput\":{\"name\":\"DP-2\"}}}\n"))
		}
	}()

	if got := queryNiriFocusedOutput(path); got != "DP-2" {
		t.Fatalf("queryNiriFocusedOutput() = %q, want DP-2", got)
	}
}

func TestNiriWindowAllowsMissingMetadata(t *testing.T) {
	d := &daemon{}
	d.compState = newCompositorState(newStateTopic(), compositorNiri)

	event := []byte(`{"WindowsChanged":{"windows":[{"id":9,"title":null,"app_id":null,"pid":null,"workspace_id":null,"is_focused":false,"is_floating":false,"is_urgent":false}]}}`)
	if err := d.consumeNiriEvent(event); err != nil {
		t.Fatal(err)
	}

	snapshot := d.compState.snapshot()
	if len(snapshot.Windows) != 1 {
		t.Fatalf("window count = %d, want 1", len(snapshot.Windows))
	}
	window := snapshot.Windows[0]
	if window.Title != "" || window.AppID != "" || window.PID != 0 || window.WorkspaceID != "" {
		t.Fatalf("optional metadata was not normalized: %+v", window)
	}
}

func TestConsumeNiriState(t *testing.T) {
	d := &daemon{}
	d.compState = newCompositorState(newStateTopic(), compositorNiri)

	workspaceEvent := []byte(`{"WorkspacesChanged":{"workspaces":[{"id":4,"idx":2,"name":null,"output":"DP-2","is_urgent":false,"is_active":false,"is_focused":false,"active_window_id":null},{"id":1,"idx":1,"name":null,"output":"DP-1","is_urgent":false,"is_active":true,"is_focused":false,"active_window_id":null},{"id":3,"idx":1,"name":null,"output":"DP-2","is_urgent":false,"is_active":true,"is_focused":true,"active_window_id":2}]}}`)
	if err := d.consumeNiriEvent(workspaceEvent); err != nil {
		t.Fatal(err)
	}

	snapshot := d.compState.snapshot()
	if snapshot.FocusedOutput != "DP-2" || snapshot.FocusedWorkspaceID != "3" {
		t.Fatalf("focused state = output %q workspace %q", snapshot.FocusedOutput, snapshot.FocusedWorkspaceID)
	}
	if got := d.cachedMonitor(); got != "DP-2" {
		t.Fatalf("cached monitor = %q, want DP-2", got)
	}

	windowEvent := []byte(`{"WindowsChanged":{"windows":[{"id":2,"title":"zsh","app_id":"kitty","pid":136786,"workspace_id":3,"is_focused":true,"is_floating":false,"is_urgent":false},{"id":4,"title":"Firefox","app_id":"firefox","pid":138290,"workspace_id":3,"is_focused":false,"is_floating":false,"is_urgent":false}]}}`)
	if err := d.consumeNiriEvent(windowEvent); err != nil {
		t.Fatal(err)
	}

	snapshot = d.compState.snapshot()
	if snapshot.FocusedWindowID != "2" || len(snapshot.Windows) != 2 {
		t.Fatalf("window state = focused %q count %d", snapshot.FocusedWindowID, len(snapshot.Windows))
	}

	if err := d.consumeNiriEvent([]byte(`{"WorkspaceActivated":{"id":4,"focused":true}}`)); err != nil {
		t.Fatal(err)
	}
	if err := d.consumeNiriEvent([]byte(`{"WindowFocusChanged":{"id":4}}`)); err != nil {
		t.Fatal(err)
	}

	snapshot = d.compState.snapshot()
	if snapshot.FocusedWorkspaceID != "4" || snapshot.FocusedWindowID != "4" {
		t.Fatalf("incremental state = workspace %q window %q", snapshot.FocusedWorkspaceID, snapshot.FocusedWindowID)
	}
}

func TestNiriWorkspaceActions(t *testing.T) {
	path := filepath.Join(t.TempDir(), "niri-actions.sock")
	ln, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	requests := make(chan string, 3)
	go func() {
		for i := 0; i < 3; i++ {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			reader := bufio.NewReader(conn)
			line, _ := reader.ReadString('\n')
			requests <- strings.TrimSpace(line)
			_, _ = conn.Write([]byte("{\"Ok\":\"Handled\"}\n"))
			conn.Close()
		}
	}()

	n := niriCompositor{socket: path}
	if err := n.FocusWorkspace(3); err != nil {
		t.Fatal(err)
	}
	if err := n.FocusWorkspaceID("42"); err != nil {
		t.Fatal(err)
	}
	if err := n.FocusWorkspaceRelative(-1); err != nil {
		t.Fatal(err)
	}

	focus := <-requests
	focusID := <-requests
	relative := <-requests

	var focusJSON map[string]any
	if err := json.Unmarshal([]byte(focus), &focusJSON); err != nil {
		t.Fatal(err)
	}
	action := focusJSON["Action"].(map[string]any)
	focusWorkspace := action["FocusWorkspace"].(map[string]any)
	reference := focusWorkspace["reference"].(map[string]any)
	if reference["Index"] != float64(3) {
		t.Fatalf("workspace index = %#v, want 3", reference["Index"])
	}

	var focusIDJSON map[string]any
	if err := json.Unmarshal([]byte(focusID), &focusIDJSON); err != nil {
		t.Fatal(err)
	}
	idAction := focusIDJSON["Action"].(map[string]any)
	idFocusWorkspace := idAction["FocusWorkspace"].(map[string]any)
	idReference := idFocusWorkspace["reference"].(map[string]any)
	if idReference["Id"] != float64(42) {
		t.Fatalf("workspace id = %#v, want 42", idReference["Id"])
	}

	var relativeJSON map[string]any
	if err := json.Unmarshal([]byte(relative), &relativeJSON); err != nil {
		t.Fatal(err)
	}
	relativeAction := relativeJSON["Action"].(map[string]any)
	if _, ok := relativeAction["FocusWorkspaceUp"]; !ok {
		t.Fatalf("relative action = %#v, want FocusWorkspaceUp", relativeAction)
	}
}
