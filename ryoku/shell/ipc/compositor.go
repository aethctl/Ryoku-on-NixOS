package main

import (
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

const (
	compositorHyprland = "hyprland"
	compositorNiri     = "niri"
)

type compositorBackend interface {
	Name() string
	Prepare()
	Start(*daemon)
}

type hyprlandCompositor struct{}

func (hyprlandCompositor) Name() string {
	return compositorHyprland
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
		return nil, fmt.Errorf("niri compositor detected, but the Ryoku Niri backend is not implemented yet")
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
