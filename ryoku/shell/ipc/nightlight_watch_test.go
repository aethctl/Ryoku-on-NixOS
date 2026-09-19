package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestNightlightWatcherEndToEnd drives the real watcher: a fake hyprsunset
// binary, a PATH-shimmed ryoku-cmd-nightlight that starts/stops it and writes
// the marker and temp files, and the inotify loop publishing to a live topic
// subscription. It proves a toggle intent reaches QML as a pushed frame with
// no polling anywhere. The shim never pkills by name, so the watcher test can
// not disturb a real hyprsunset on the dev box.
func TestNightlightWatcherEndToEnd(t *testing.T) {
	// The watcher reads the real /proc, so a live hyprsunset on the dev box
	// would make the startup frame on:true; skip rather than fight it.
	if (&nightlightState{}).running() {
		t.Skip("hyprsunset is running on this machine")
	}
	state := t.TempDir()
	t.Setenv("XDG_STATE_HOME", state)

	bin := t.TempDir()
	fake := filepath.Join(bin, nlProcessName)
	sleep, err := exec.LookPath("sleep")
	if err != nil {
		t.Skip("no sleep binary")
	}
	raw, err := os.ReadFile(sleep)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(fake, raw, 0o755); err != nil {
		t.Fatal(err)
	}

	pidFile := filepath.Join(state, "fake.pid")
	marker := filepath.Join(state, "ryoku-nightlight-enabled")
	tempFile := filepath.Join(state, "ryoku-nightlight")
	shim := filepath.Join(bin, "ryoku-cmd-nightlight")
	script := strings.NewReplacer(
		"@PID@", pidFile, "@MARKER@", marker, "@TEMP@", tempFile, "@FAKE@", fake,
	).Replace(`#!/usr/bin/env bash
set -u
pid="@PID@"; marker="@MARKER@"; temp="@TEMP@"; fake="@FAKE@"
running() { [[ -f $pid ]] && kill -0 "$(cat "$pid")" 2>/dev/null; }
case "${1:-toggle}" in
  on)
    printf '%s\n' "${2:-4000}" >"$temp"; : >"$marker"
    running && exit 0
    setsid "$fake" 600 >/dev/null 2>&1 </dev/null & echo $! >"$pid"
    ;;
  off)
    running && kill "$(cat "$pid")" 2>/dev/null
    rm -f "$pid" "$marker"
    ;;
  toggle)
    if running; then "$0" off; else "$0" on "$(cat "$temp" 2>/dev/null || echo 4000)"; fi
    ;;
esac
exit 0
`)
	if err := os.WriteFile(shim, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	// The shim must win over the packaged script; without this the test drives
	// the real ryoku-cmd-nightlight, whose hyprsunset cannot survive a session
	// without gamma-control support and the watcher never sees it.
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	d := &daemon{}
	d.startNightlight()
	topic := d.topic("nightlight")
	sub := topic.subscribe()
	defer topic.unsubscribe(sub)
	t.Cleanup(func() {
		_, _ = d.callHandler("nightlight.set")(json.RawMessage(`{"on":false}`))
	})

	first := frameOn(t, <-sub.frames)
	if first.On {
		t.Fatalf("startup frame should be off: %s", first.Raw)
	}

	handler := d.callHandler("nightlight.toggle")
	if _, err := handler(json.RawMessage(`{}`)); err != nil {
		t.Fatalf("toggle on: %v", err)
	}
	got := waitForFrame(t, sub, func(f nlFrame) bool { return f.On }, "on:true")
	if got.Temperature != 4000 {
		t.Fatalf("after toggle: want temperature 4000, got %s", got.Raw)
	}

	// The script changes temperature by restarting hyprsunset, so the watcher
	// may coalesce that into one frame; the settled state must carry the new
	// temperature with the light still on.
	set := d.callHandler("nightlight.set")
	if _, err := set(json.RawMessage(`{"on":true,"temperature":3500}`)); err != nil {
		t.Fatalf("set temp: %v", err)
	}
	if got := waitForFrame(t, sub, func(f nlFrame) bool { return f.On && f.Temperature == 3500 }, "on:true temperature:3500"); !got.On || got.Temperature != 3500 {
		t.Fatalf("after set: got %s", got.Raw)
	}

	if _, err := handler(json.RawMessage(`{}`)); err != nil {
		t.Fatalf("toggle off: %v", err)
	}
	if got := waitForFrame(t, sub, func(f nlFrame) bool { return !f.On }, "on:false"); got.On {
		t.Fatalf("after toggle off: want on:false, got %s", got.Raw)
	}
}

type nlFrame struct {
	On          bool
	Temperature int
	Raw         string
}

func frameOn(t *testing.T, b []byte) nlFrame {
	t.Helper()
	var f struct {
		On          bool `json:"on"`
		Temperature int  `json:"temperature"`
	}
	if err := json.Unmarshal(b, &f); err != nil {
		t.Fatalf("frame not json: %v (%s)", err, b)
	}
	return nlFrame{On: f.On, Temperature: f.Temperature, Raw: strings.TrimSpace(string(b))}
}

// waitForFrame reads frames until one satisfies want, failing the test after a
// bounded wait (the watcher settles within its poll timeout).
func waitForFrame(t *testing.T, sub *topicSubscriber, want func(nlFrame) bool, desc string) nlFrame {
	t.Helper()
	deadline := time.After(8 * time.Second)
	for {
		select {
		case f := <-sub.frames:
			got := frameOn(t, f)
			if want(got) {
				return got
			}
		case <-deadline:
			t.Fatalf("no frame with %s within 8s", desc)
		}
	}
}
