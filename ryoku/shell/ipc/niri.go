package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"strconv"
	"time"
)

type niriCompositor struct {
	socket string
}

func (n niriCompositor) Name() string {
	return compositorNiri
}

func (n niriCompositor) Identity() string {
	if n.socket == "" {
		return ""
	}
	return compositorNiri + ":" + n.socket
}

func (n niriCompositor) FocusedOutput() string {
	return queryNiriFocusedOutput(n.socket)
}

func (n niriCompositor) FocusWorkspace(index int) error {
	if index < 1 || index > 255 {
		return fmt.Errorf("invalid workspace index %d", index)
	}
	return sendNiriRequest(n.socket, map[string]any{
		"Action": map[string]any{
			"FocusWorkspace": map[string]any{
				"reference": map[string]any{"Index": index},
			},
		},
	})
}

func (n niriCompositor) FocusWorkspaceRelative(delta int) error {
	action := ""
	switch {
	case delta < 0:
		action = "FocusWorkspaceUp"
	case delta > 0:
		action = "FocusWorkspaceDown"
	default:
		return nil
	}
	return sendNiriRequest(n.socket, map[string]any{
		"Action": map[string]any{
			action: map[string]any{},
		},
	})
}

func (n niriCompositor) Prepare() {}

func (n niriCompositor) Start(d *daemon) {
	go d.watchNiri(n.socket)
}

type niriWorkspace struct {
	ID             uint64  `json:"id"`
	Index          int     `json:"idx"`
	Name           *string `json:"name"`
	Output         *string `json:"output"`
	Urgent         bool    `json:"is_urgent"`
	Active         bool    `json:"is_active"`
	Focused        bool    `json:"is_focused"`
	ActiveWindowID *uint64 `json:"active_window_id"`
}

type niriWindow struct {
	ID          uint64  `json:"id"`
	Title       *string `json:"title"`
	AppID       *string `json:"app_id"`
	PID         *int    `json:"pid"`
	WorkspaceID *uint64 `json:"workspace_id"`
	Focused     bool    `json:"is_focused"`
	Floating    bool    `json:"is_floating"`
	Urgent      bool    `json:"is_urgent"`
}

func niriID(id uint64) string {
	return strconv.FormatUint(id, 10)
}

func niriOptionalID(id *uint64) string {
	if id == nil {
		return ""
	}
	return niriID(*id)
}

func niriOptionalString(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func niriWorkspaceState(workspace niriWorkspace) compositorWorkspace {
	name := ""
	if workspace.Name != nil {
		name = *workspace.Name
	}
	output := ""
	if workspace.Output != nil {
		output = *workspace.Output
	}
	return compositorWorkspace{
		ID:             niriID(workspace.ID),
		Index:          workspace.Index,
		Name:           name,
		Output:         output,
		Urgent:         workspace.Urgent,
		Active:         workspace.Active,
		Focused:        workspace.Focused,
		ActiveWindowID: niriOptionalID(workspace.ActiveWindowID),
	}
}

func niriWindowState(window niriWindow) compositorWindow {
	pid := 0
	if window.PID != nil {
		pid = *window.PID
	}
	return compositorWindow{
		ID:          niriID(window.ID),
		Title:       niriOptionalString(window.Title),
		AppID:       niriOptionalString(window.AppID),
		PID:         pid,
		WorkspaceID: niriOptionalID(window.WorkspaceID),
		Focused:     window.Focused,
		Floating:    window.Floating,
		Urgent:      window.Urgent,
	}
}

func openNiriEventStream(path string) (net.Conn, *bufio.Reader, error) {
	conn, err := net.DialTimeout("unix", path, 500*time.Millisecond)
	if err != nil {
		return nil, nil, err
	}

	_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err := fmt.Fprintln(conn, `"EventStream"`); err != nil {
		conn.Close()
		return nil, nil, err
	}

	reader := bufio.NewReader(conn)
	line, err := reader.ReadBytes('\n')
	if err != nil {
		conn.Close()
		return nil, nil, err
	}

	var reply map[string]json.RawMessage
	if err := json.Unmarshal(line, &reply); err != nil {
		conn.Close()
		return nil, nil, err
	}

	ok, exists := reply["Ok"]
	if !exists || string(ok) != `"Handled"` {
		conn.Close()
		return nil, nil, fmt.Errorf("niri rejected event stream")
	}

	_ = conn.SetDeadline(time.Time{})
	return conn, reader, nil
}

func sendNiriRequest(path string, request any) error {
	conn, err := net.DialTimeout("unix", path, 500*time.Millisecond)
	if err != nil {
		return err
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
	if err := json.NewEncoder(conn).Encode(request); err != nil {
		return err
	}

	reader := bufio.NewReader(conn)
	line, err := reader.ReadBytes('\n')
	if err != nil {
		return err
	}

	var reply map[string]json.RawMessage
	if err := json.Unmarshal(line, &reply); err != nil {
		return err
	}
	if raw, ok := reply["Err"]; ok {
		var message string
		if json.Unmarshal(raw, &message) == nil && message != "" {
			return fmt.Errorf("niri request failed: %s", message)
		}
		return fmt.Errorf("niri request failed")
	}
	if _, ok := reply["Ok"]; !ok {
		return fmt.Errorf("invalid niri reply")
	}
	return nil
}

func queryNiriFocusedOutput(path string) string {
	conn, err := net.DialTimeout("unix", path, 500*time.Millisecond)
	if err != nil {
		return ""
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err := fmt.Fprintln(conn, `"FocusedOutput"`); err != nil {
		return ""
	}

	reader := bufio.NewReader(conn)
	line, err := reader.ReadBytes('\n')
	if err != nil {
		return ""
	}

	var reply map[string]json.RawMessage
	if json.Unmarshal(line, &reply) != nil {
		return ""
	}
	ok := reply["Ok"]
	if len(ok) == 0 {
		return ""
	}

	var response struct {
		FocusedOutput *struct {
			Name string `json:"name"`
		} `json:"FocusedOutput"`
	}
	if json.Unmarshal(ok, &response) != nil || response.FocusedOutput == nil {
		return ""
	}
	return response.FocusedOutput.Name
}

func (d *daemon) consumeNiriEvent(line []byte) error {
	var event map[string]json.RawMessage
	if err := json.Unmarshal(line, &event); err != nil {
		return err
	}

	for kind, payload := range event {
		switch kind {
		case "WorkspacesChanged":
			var body struct {
				Workspaces []niriWorkspace `json:"workspaces"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			workspaces := make([]compositorWorkspace, 0, len(body.Workspaces))
			for _, workspace := range body.Workspaces {
				workspaces = append(workspaces, niriWorkspaceState(workspace))
			}
			d.compState.replaceWorkspaces(workspaces)
			d.setMonitor(d.compState.snapshot().FocusedOutput)

		case "WorkspaceActivated":
			var body struct {
				ID      uint64 `json:"id"`
				Focused bool   `json:"focused"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			d.compState.activateWorkspace(niriID(body.ID), body.Focused)
			if body.Focused {
				d.setMonitor(d.compState.snapshot().FocusedOutput)
			}

		case "WorkspaceUrgencyChanged":
			var body struct {
				ID     uint64 `json:"id"`
				Urgent bool   `json:"urgent"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			d.compState.setWorkspaceUrgent(niriID(body.ID), body.Urgent)

		case "WorkspaceActiveWindowChanged":
			var body struct {
				WorkspaceID    uint64  `json:"workspace_id"`
				ActiveWindowID *uint64 `json:"active_window_id"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			d.compState.setWorkspaceActiveWindow(
				niriID(body.WorkspaceID),
				niriOptionalID(body.ActiveWindowID),
			)

		case "WindowsChanged":
			var body struct {
				Windows []niriWindow `json:"windows"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			windows := make([]compositorWindow, 0, len(body.Windows))
			for _, window := range body.Windows {
				windows = append(windows, niriWindowState(window))
			}
			d.compState.replaceWindows(windows)

		case "WindowOpenedOrChanged":
			var body struct {
				Window niriWindow `json:"window"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			d.compState.upsertWindow(niriWindowState(body.Window))

		case "WindowClosed":
			var body struct {
				ID uint64 `json:"id"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			d.compState.removeWindow(niriID(body.ID))

		case "WindowFocusChanged":
			var body struct {
				ID *uint64 `json:"id"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			d.compState.focusWindow(niriOptionalID(body.ID))

		case "WindowUrgencyChanged":
			var body struct {
				ID     uint64 `json:"id"`
				Urgent bool   `json:"urgent"`
			}
			if err := json.Unmarshal(payload, &body); err != nil {
				return err
			}
			d.compState.setWindowUrgent(niriID(body.ID), body.Urgent)
		}
	}

	return nil
}

func (d *daemon) watchNiri(path string) {
	backoff := 150 * time.Millisecond

	for {
		select {
		case <-d.quit:
			return
		default:
		}

		conn, reader, err := openNiriEventStream(path)
		if err != nil {
			select {
			case <-d.quit:
				return
			case <-time.After(backoff):
			}
			backoff = capDur(backoff*2, 5*time.Second)
			continue
		}

		backoff = 150 * time.Millisecond
		done := make(chan struct{})
		go func() {
			select {
			case <-d.quit:
				conn.Close()
			case <-done:
			}
		}()

		scanner := bufio.NewScanner(reader)
		scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)
		for scanner.Scan() {
			if err := d.consumeNiriEvent(scanner.Bytes()); err != nil {
				break
			}
		}

		close(done)
		conn.Close()
	}
}
