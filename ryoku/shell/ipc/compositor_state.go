package main

import (
	"encoding/json"
	"sync"
)

type compositorWorkspace struct {
	ID             string `json:"id"`
	Index          int    `json:"index"`
	Name           string `json:"name,omitempty"`
	Output         string `json:"output,omitempty"`
	Urgent         bool   `json:"urgent"`
	Active         bool   `json:"active"`
	Focused        bool   `json:"focused"`
	ActiveWindowID string `json:"activeWindowId,omitempty"`
}

type compositorWindow struct {
	ID          string `json:"id"`
	Title       string `json:"title,omitempty"`
	AppID       string `json:"appId,omitempty"`
	PID         int    `json:"pid,omitempty"`
	WorkspaceID string `json:"workspaceId,omitempty"`
	Focused     bool   `json:"focused"`
	Floating    bool   `json:"floating"`
	Urgent      bool   `json:"urgent"`
}

type compositorSnapshot struct {
	Compositor         string                `json:"compositor"`
	FocusedOutput      string                `json:"focusedOutput,omitempty"`
	FocusedWorkspaceID string                `json:"focusedWorkspaceId,omitempty"`
	FocusedWindowID    string                `json:"focusedWindowId,omitempty"`
	Workspaces         []compositorWorkspace `json:"workspaces"`
	Windows            []compositorWindow    `json:"windows"`
}

type compositorState struct {
	mu    sync.RWMutex
	topic *stateTopic
	data  compositorSnapshot
}

func newCompositorState(topic *stateTopic, name string) *compositorState {
	s := &compositorState{
		topic: topic,
		data: compositorSnapshot{
			Compositor: name,
			Workspaces: []compositorWorkspace{},
			Windows:    []compositorWindow{},
		},
	}
	s.publish()
	return s
}

func cloneCompositorSnapshot(in compositorSnapshot) compositorSnapshot {
	out := in
	out.Workspaces = append([]compositorWorkspace(nil), in.Workspaces...)
	out.Windows = append([]compositorWindow(nil), in.Windows...)
	return out
}

func (s *compositorState) snapshot() compositorSnapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return cloneCompositorSnapshot(s.data)
}

func (s *compositorState) publish() {
	if s == nil || s.topic == nil {
		return
	}
	frame, _ := json.Marshal(s.snapshot())
	s.topic.publish(frame)
}

func (s *compositorState) mutate(fn func(*compositorSnapshot)) {
	if s == nil {
		return
	}
	s.mu.Lock()
	fn(&s.data)
	s.mu.Unlock()
	s.publish()
}

func (s *compositorState) json() string {
	if s == nil {
		return "{}"
	}
	frame, _ := json.Marshal(s.snapshot())
	return string(frame)
}

func (s *compositorState) setFocusedOutput(output string) {
	s.mutate(func(data *compositorSnapshot) {
		data.FocusedOutput = output
	})
}

func (s *compositorState) replaceWorkspaces(workspaces []compositorWorkspace) {
	s.mutate(func(data *compositorSnapshot) {
		data.Workspaces = append([]compositorWorkspace(nil), workspaces...)
		data.FocusedWorkspaceID = ""
		data.FocusedOutput = ""
		for _, workspace := range data.Workspaces {
			if workspace.Focused {
				data.FocusedWorkspaceID = workspace.ID
				data.FocusedOutput = workspace.Output
				break
			}
		}
	})
}

func (s *compositorState) activateWorkspace(id string, focused bool) {
	s.mutate(func(data *compositorSnapshot) {
		output := ""
		for _, workspace := range data.Workspaces {
			if workspace.ID == id {
				output = workspace.Output
				break
			}
		}
		if output == "" {
			return
		}
		for i := range data.Workspaces {
			if data.Workspaces[i].Output == output {
				data.Workspaces[i].Active = data.Workspaces[i].ID == id
			}
			if focused {
				data.Workspaces[i].Focused = data.Workspaces[i].ID == id
			}
		}
		if focused {
			data.FocusedWorkspaceID = id
			data.FocusedOutput = output
		}
	})
}

func (s *compositorState) setWorkspaceUrgent(id string, urgent bool) {
	s.mutate(func(data *compositorSnapshot) {
		for i := range data.Workspaces {
			if data.Workspaces[i].ID == id {
				data.Workspaces[i].Urgent = urgent
				return
			}
		}
	})
}

func (s *compositorState) setWorkspaceActiveWindow(id, windowID string) {
	s.mutate(func(data *compositorSnapshot) {
		for i := range data.Workspaces {
			if data.Workspaces[i].ID == id {
				data.Workspaces[i].ActiveWindowID = windowID
				return
			}
		}
	})
}

func (s *compositorState) replaceWindows(windows []compositorWindow) {
	s.mutate(func(data *compositorSnapshot) {
		data.Windows = append([]compositorWindow(nil), windows...)
		data.FocusedWindowID = ""
		for _, window := range data.Windows {
			if window.Focused {
				data.FocusedWindowID = window.ID
				break
			}
		}
	})
}

func (s *compositorState) upsertWindow(window compositorWindow) {
	s.mutate(func(data *compositorSnapshot) {
		found := false
		for i := range data.Windows {
			if data.Windows[i].ID == window.ID {
				data.Windows[i] = window
				found = true
				break
			}
		}
		if !found {
			data.Windows = append(data.Windows, window)
		}
		if window.Focused {
			for i := range data.Windows {
				data.Windows[i].Focused = data.Windows[i].ID == window.ID
			}
			data.FocusedWindowID = window.ID
		} else if data.FocusedWindowID == window.ID {
			data.FocusedWindowID = ""
		}
	})
}

func (s *compositorState) removeWindow(id string) {
	s.mutate(func(data *compositorSnapshot) {
		for i := range data.Windows {
			if data.Windows[i].ID == id {
				data.Windows = append(data.Windows[:i], data.Windows[i+1:]...)
				break
			}
		}
		if data.FocusedWindowID == id {
			data.FocusedWindowID = ""
		}
	})
}

func (s *compositorState) focusWindow(id string) {
	s.mutate(func(data *compositorSnapshot) {
		for i := range data.Windows {
			data.Windows[i].Focused = data.Windows[i].ID == id
		}
		data.FocusedWindowID = id
	})
}

func (s *compositorState) setWindowUrgent(id string, urgent bool) {
	s.mutate(func(data *compositorSnapshot) {
		for i := range data.Windows {
			if data.Windows[i].ID == id {
				data.Windows[i].Urgent = urgent
				return
			}
		}
	})
}
