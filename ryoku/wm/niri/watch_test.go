package main

import (
	"encoding/json"
	"testing"

	wm "ryoku-wm"
)

func foldEvents(t *testing.T, s *session, wants func(wm.FrameKind) bool, events ...map[string]any) []wm.Frame {
	t.Helper()
	var out []wm.Frame
	emit := func(f wm.Frame) { out = append(out, f) }
	for _, ev := range events {
		for name, body := range ev {
			raw, err := json.Marshal(body)
			if err != nil {
				t.Fatal(err)
			}
			s.apply(name, raw, emit, wants)
		}
	}
	return out
}

func allKinds(wm.FrameKind) bool { return true }

func TestFoldOverviewEmitsFrame(t *testing.T) {
	s := &session{}
	frames := foldEvents(t, s, allKinds,
		map[string]any{"OverviewOpenedOrClosed": map[string]any{"is_open": true}},
		map[string]any{"OverviewOpenedOrClosed": map[string]any{"is_open": false}},
	)
	if len(frames) != 2 {
		t.Fatalf("got %d frames, want 2", len(frames))
	}
	if frames[0].Kind != wm.FrameOverview || !frames[0].OverviewOpen {
		t.Errorf("open frame = %+v, want overview/open", frames[0])
	}
	if frames[1].Kind != wm.FrameOverview || frames[1].OverviewOpen {
		t.Errorf("close frame = %+v, want overview/closed", frames[1])
	}
	if s.overview {
		t.Error("session must hold the latest state (closed)")
	}
}

func TestFoldOverviewSkippedWhenNotWanted(t *testing.T) {
	s := &session{}
	wants := func(k wm.FrameKind) bool { return k == wm.FrameWindows }
	frames := foldEvents(t, s, wants,
		map[string]any{"OverviewOpenedOrClosed": map[string]any{"is_open": true}},
	)
	if len(frames) != 0 {
		t.Fatalf("got %d frames, want none", len(frames))
	}
	if !s.overview {
		t.Error("session must still track overview state")
	}
}
