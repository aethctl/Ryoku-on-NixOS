package main

import (
	"reflect"
	"testing"
)

func TestFreshInstallerSelectsSupportedApps(t *testing.T) {
	m := newModel(defaultOptions())
	got := m.selectedApps()
	var want []string
	for _, app := range optionalApps() {
		want = append(want, app.ID)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("fresh selected apps = %v, want %v", got, want)
	}
}

func TestAppSelectionKeepsCatalogueOrder(t *testing.T) {
	m := newModel(defaultOptions())
	for id := range m.keep {
		m.keep[id] = false
	}
	m.keep["docker"] = true
	m.keep["prompt"] = true
	m.keep["go"] = true
	got := m.selectedApps()
	want := []string{"prompt", "docker", "go"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("selected apps = %v, want catalogue order %v", got, want)
	}
}

func TestParseOptionsDirectBackendCompatibility(t *testing.T) {
	opts, direct, args, err := parseOptions([]string{
		"--cli", "--flake", "/tmp/nixos#host", "--source", "path:/tmp/ryoku",
		"--compositor", "niri", "--browser", "firefox", "--shell", "zsh",
		"--apps", "prompt,docker", "--dry-run", "-y",
	})
	if err != nil {
		t.Fatal(err)
	}
	if !direct {
		t.Fatal("--cli/-y should select direct backend mode")
	}
	if opts.flake != "/tmp/nixos#host" || opts.source != "path:/tmp/ryoku" || !opts.dryRun {
		t.Fatalf("parsed options = %+v", opts)
	}
	if len(args) == 0 || args[0] != "--flake" {
		t.Fatalf("backend args = %v", args)
	}
}

func TestRenderAllScreens(t *testing.T) {
	m := newModel(defaultOptions())
	m.w, m.h = 112, 40
	if got := m.render(); got == "" {
		t.Fatal("welcome rendered empty")
	}
	m.state = "wizard"
	for i := range flow {
		m.idx = i
		m.setCursorForStep()
		if got := m.render(); got == "" {
			t.Fatalf("screen %s rendered empty", flow[i].key)
		}
	}
	m.state = "install"
	if got := m.render(); got == "" {
		t.Fatal("install rendered empty")
	}
}

func TestBackendOnlyOptionsSelectDirectMode(t *testing.T) {
	_, direct, args, err := parseOptions([]string{"--compositor", "niri", "--browser", "firefox"})
	if err != nil {
		t.Fatal(err)
	}
	if !direct {
		t.Fatal("backend-only selection flags must bypass the interactive TUI")
	}
	if len(args) != 4 {
		t.Fatalf("backend args = %v", args)
	}
}
