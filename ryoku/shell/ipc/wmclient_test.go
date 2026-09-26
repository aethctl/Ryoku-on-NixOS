package main

import (
	"encoding/json"
	"os/exec"
	"testing"
	"time"

	wm "ryoku-wm"
)

// A focus frame warms the cache; a focus frame with an empty output clears it.
func TestFocusFrameUpdatesCache(t *testing.T) {
	d := &daemon{}
	d.onWMFrame(wm.Frame{Kind: wm.FrameFocus, FocusedOutput: "DP-1"})
	if got := d.activeMonitor(); got != "DP-1" {
		t.Fatalf("activeMonitor() = %q, want DP-1", got)
	}
	d.onWMFrame(wm.Frame{Kind: wm.FrameFocus})
	if got := d.activeMonitor(); got != "" {
		t.Fatalf("after empty focus frame, activeMonitor() = %q, want empty", got)
	}
}

// A cold cache resolves to "" without a fork; callers tolerate no focused output.
func TestActiveMonitorColdCacheEmpty(t *testing.T) {
	d := &daemon{}
	if got := d.activeMonitor(); got != "" {
		t.Fatalf("cold activeMonitor() = %q, want empty", got)
	}
}

// The watcher writes while keybinds read; run with -race to prove it is safe.
func TestMonitorConcurrent(t *testing.T) {
	d := &daemon{}
	done := make(chan struct{})
	go func() {
		for range 2000 {
			d.onWMFrame(wm.Frame{Kind: wm.FrameFocus, FocusedOutput: "DP-1"})
			d.onWMFrame(wm.Frame{Kind: wm.FrameFocus})
		}
		close(done)
	}()
	for range 2000 {
		_ = d.activeMonitor()
	}
	<-done
}

// An overview frame warms the cached overview state the wm topic publishes, so
// the backdrop's blur gate reads the compositor's live overview, not a stale one.
func TestOverviewFrameUpdatesCache(t *testing.T) {
	d := &daemon{}
	d.onWMFrame(wm.Frame{Kind: wm.FrameOverview, OverviewOpen: true})
	d.wmMu.Lock()
	got := d.wmOverview
	d.wmMu.Unlock()
	if !got {
		t.Fatal("overview frame did not set the cached state")
	}
	d.onWMFrame(wm.Frame{Kind: wm.FrameOverview})
	d.wmMu.Lock()
	got = d.wmOverview
	d.wmMu.Unlock()
	if got {
		t.Fatal("a closed overview frame must clear the cached state")
	}
}

// The bar's layout indicator reads Wm.keyboardLayout off the wm topic, so a
// keyboard frame must reach the published snapshot (it was silently dropped
// once) and every section must carry a version so a QML consumer rebinds only
// what moved. This asserts the wire, not just the cache.
func TestPublishCarriesKeyboardAndVersions(t *testing.T) {
	d := &daemon{wmc: wm.OpenNamed("does-not-exist")}
	d.wmTopic = newStateTopic()
	sub := d.wmTopic.subscribe()
	defer d.wmTopic.unsubscribe(sub)

	d.onWMFrame(wm.Frame{Kind: wm.FrameKeyboard, KeyboardLayout: "English (US)", KeyboardLayouts: []string{"us", "dvorak"}})

	select {
	case frame := <-sub.frames:
		var out wmTopicFrame
		if err := json.Unmarshal(frame, &out); err != nil {
			t.Fatal(err)
		}
		if out.KeyboardLayout != "English (US)" {
			t.Errorf("keyboardLayout = %q, want the folded layout", out.KeyboardLayout)
		}
		if len(out.KeyboardLayouts) != 2 {
			t.Errorf("keyboardLayouts = %v, want two", out.KeyboardLayouts)
		}
		if out.Versions["keyboard"] != 1 {
			t.Errorf("versions[keyboard] = %d, want 1", out.Versions["keyboard"])
		}
		if out.Versions["windows"] != 0 {
			t.Errorf("versions[windows] = %d, want 0 (untouched by a keyboard frame)", out.Versions["windows"])
		}
	case <-time.After(2 * time.Second):
		t.Fatal("no frame published")
	}
}

func BenchmarkActiveMonitorCached(b *testing.B) {
	d := &daemon{}
	d.onWMFrame(wm.Frame{Kind: wm.FrameFocus, FocusedOutput: "DP-1"})
	b.ReportAllocs()
	for b.Loop() {
		if d.activeMonitor() == "" {
			b.Fatal("empty monitor")
		}
	}
}

// BenchmarkMonitorSpawnProxy measures a bare fork+exec: the per-keybind floor the
// cache removes. A provider query is strictly more expensive than this.
func BenchmarkMonitorSpawnProxy(b *testing.B) {
	if _, err := exec.LookPath("true"); err != nil {
		b.Skip("true not on PATH")
	}
	b.ReportAllocs()
	for b.Loop() {
		_ = exec.Command("true").Run()
	}
}

func TestUnchangedWorkspaceFrameDoesNotWakeWidgets(t *testing.T) {
	d := &daemon{widgetSig: make(chan struct{}, 1)}

	f := wm.Frame{
		Kind:       wm.FrameWorkspaces,
		Workspaces: []wm.Workspace{{ID: "1", Windows: 2}},
	}

	d.onWMFrame(f)
	<-d.widgetSig

	first := d.wmVersions[string(wm.FrameWorkspaces)]
	d.onWMFrame(f)

	select {
	case <-d.widgetSig:
		t.Fatal("unchanged frame woke widget gate")
	default:
	}

	if got := d.wmVersions[string(wm.FrameWorkspaces)]; got != first {
		t.Fatalf("unchanged workspace frame advanced version: %d -> %d", first, got)
	}

	d.onWMFrame(wm.Frame{
		Kind:       wm.FrameWorkspaces,
		Workspaces: []wm.Workspace{},
	})

	select {
	case <-d.widgetSig:
	default:
		t.Fatal("empty workspace transition lost")
	}
}

func TestReadyFrameAdvancesVersionOnReconnect(t *testing.T) {
	d := &daemon{}

	d.onWMFrame(wm.Frame{Kind: wm.FrameReady})
	first := d.wmVersions[string(wm.FrameReady)]

	d.onWMFrame(wm.Frame{Kind: wm.FrameReady})
	second := d.wmVersions[string(wm.FrameReady)]

	if second != first+1 {
		t.Fatalf("ready version = %d after reconnect, want %d", second, first+1)
	}
}
