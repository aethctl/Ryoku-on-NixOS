package main

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"strings"
	"time"
)

const (
	compositorHyprland = "hyprland"
	compositorNiri     = "niri"
)

type compositorBackend interface {
	Name() string
	Identity() string
	FocusedOutput() string
	FocusWorkspace(int) error
	FocusWorkspaceID(string) error
	FocusWorkspaceRelative(int) error
	Prepare()
	Start(*daemon)
}

type hyprlandCompositor struct{}

func (hyprlandCompositor) Name() string {
	return compositorHyprland
}

func (hyprlandCompositor) Identity() string {
	sig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	if sig == "" {
		return ""
	}
	return compositorHyprland + ":" + sig
}

func (hyprlandCompositor) FocusedOutput() string {
	return queryActiveMonitor()
}

func (hyprlandCompositor) FocusWorkspace(index int) error {
	if index < 1 {
		return fmt.Errorf("invalid workspace index %d", index)
	}
	return runHyprWorkspaceFocus(fmt.Sprintf("%d", index))
}

func (hyprlandCompositor) FocusWorkspaceID(id string) error {
	if strings.TrimSpace(id) == "" {
		return fmt.Errorf("invalid workspace id")
	}
	return runHyprWorkspaceFocus(id)
}

func (hyprlandCompositor) FocusWorkspaceRelative(delta int) error {
	switch {
	case delta < 0:
		return runHyprWorkspaceFocus("r-1")
	case delta > 0:
		return runHyprWorkspaceFocus("r+1")
	default:
		return nil
	}
}

func runHyprWorkspaceFocus(workspace string) error {
	out, err := exec.Command(
		"hyprctl",
		"dispatch",
		fmt.Sprintf(`hl.dsp.focus({ workspace = "%s" })`, workspace),
	).CombinedOutput()
	if err != nil {
		return fmt.Errorf("hyprland workspace focus: %w: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

func (hyprlandCompositor) Prepare() {
	ensureLiveHyprSignature()
}

func (hyprlandCompositor) Start(d *daemon) {
	go d.watchHyprland()
}

func currentCompositorBackend() (compositorBackend, error) {
	switch detectCompositor() {
	case compositorHyprland:
		return hyprlandCompositor{}, nil
	case compositorNiri:
		return niriCompositor{socket: os.Getenv("NIRI_SOCKET")}, nil
	default:
		return nil, fmt.Errorf("no supported compositor IPC socket found")
	}
}

func detectCompositor() string {
	desktop := strings.ToLower(os.Getenv("XDG_CURRENT_DESKTOP"))
	niriAlive := niriSocketAlive(os.Getenv("NIRI_SOCKET"))

	if strings.Contains(desktop, compositorNiri) && niriAlive {
		return compositorNiri
	}

	ensureLiveHyprSignature()
	hyprAlive := hyprSocketAlive(os.Getenv("HYPRLAND_INSTANCE_SIGNATURE"))

	return selectCompositor(desktop, hyprAlive, niriAlive)
}

func selectCompositor(desktop string, hyprAlive, niriAlive bool) string {
	desktop = strings.ToLower(desktop)

	switch {
	case strings.Contains(desktop, compositorHyprland) && hyprAlive:
		return compositorHyprland
	case strings.Contains(desktop, compositorNiri) && niriAlive:
		return compositorNiri
	case hyprAlive && !niriAlive:
		return compositorHyprland
	case niriAlive && !hyprAlive:
		return compositorNiri
	default:
		return ""
	}
}

func niriSocketAlive(path string) bool {
	if path == "" {
		return false
	}
	conn, err := net.DialTimeout("unix", path, 200*time.Millisecond)
	if err != nil {
		return false
	}
	_ = conn.Close()
	return true
}
