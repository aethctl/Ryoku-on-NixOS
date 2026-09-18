package main

import (
	"testing"
	"time"
)

// The supervisor must translate the worker's stream into the job contract:
// progress events relayed, the verdict landed, the running lock cleared, and
// a worker death a verdict at all — never a wedged "already running".

func fakeSpawner(evts []workerEvent, preClosed bool, onKill func()) func(upscaleSpec) (workerProcess, error) {
	return func(spec upscaleSpec) (workerProcess, error) {
		events := make(chan workerEvent, len(evts)+1)
		for _, e := range evts {
			events <- e
		}
		done := make(chan struct{})
		if preClosed {
			close(events)
			close(done)
		}
		return workerProcess{
			events: events,
			done:   done,
			kill: func() {
				if onKill != nil {
					onKill()
				}
				close(events)
				close(done)
			},
		}, nil
	}
}

func waitEvent(t *testing.T, evts chan string, timeout time.Duration) string {
	t.Helper()
	select {
	case ev := <-evts:
		return ev
	case <-time.After(timeout):
		t.Fatalf("no event within %s", timeout)
		return ""
	}
}

func TestUpscaleSuperviseRelaysProgressAndVerdict(t *testing.T) {
	evts := make(chan string, 64)
	u := NewUpscaler(t.TempDir(), func(ev string, data map[string]interface{}) { evts <- ev })
	u.spawnWorker = fakeSpawner([]workerEvent{
		{Event: "progress", Data: map[string]interface{}{"phase": "enhance", "progress": 5.0, "total": 10.0}},
		{Verdict: map[string]interface{}{"result": "done", "kind": "video", "out": "/x.mp4"}},
	}, true, nil)

	if err := u.Start("clip.mp4", "video", 2); err != nil {
		t.Fatal(err)
	}
	for {
		ev := waitEvent(t, evts, 2*time.Second)
		if ev != "ryogami.wall.upscale.finished" {
			continue
		}
		break
	}
	st := u.Status()
	if st["running"].(bool) {
		t.Error("job still running after the worker finished")
	}
	v, _ := st["verdict"].(map[string]interface{})
	if v == nil || v["result"] != "done" || v["out"] != "/x.mp4" {
		t.Errorf("verdict = %v, want done with out", st["verdict"])
	}
	if st["phase"] != "done" {
		t.Errorf("phase = %v, want done", st["phase"])
	}
}

func TestUpscaleSuperviseWorkerDiedWithoutVerdict(t *testing.T) {
	evts := make(chan string, 64)
	u := NewUpscaler(t.TempDir(), func(ev string, data map[string]interface{}) { evts <- ev })
	u.spawnWorker = fakeSpawner(nil, true, nil)

	if err := u.Start("x.png", "image", 2); err != nil {
		t.Fatal(err)
	}
	waitEvent(t, evts, 2*time.Second)
	st := u.Status()
	v, _ := st["verdict"].(map[string]interface{})
	if v == nil || v["result"] != "error" || v["why"] != "worker" {
		t.Errorf("verdict = %v, want error/worker for a silent death", st["verdict"])
	}
	if st["running"].(bool) {
		t.Error("running lock not cleared after the worker died")
	}
}

func TestUpscaleSuperviseCancelKillsWorker(t *testing.T) {
	evts := make(chan string, 64)
	killed := make(chan struct{}, 1)
	u := NewUpscaler(t.TempDir(), func(ev string, data map[string]interface{}) { evts <- ev })
	u.spawnWorker = fakeSpawner(nil, false, func() { killed <- struct{}{} })

	if err := u.Start("x.png", "image", 2); err != nil {
		t.Fatal(err)
	}
	u.Cancel()
	select {
	case <-killed:
	case <-time.After(2 * time.Second):
		t.Fatal("cancel never killed the worker")
	}
	waitEvent(t, evts, 2*time.Second)
	st := u.Status()
	v, _ := st["verdict"].(map[string]interface{})
	if v == nil || v["why"] != "cancelled" {
		t.Errorf("verdict = %v, want cancelled", st["verdict"])
	}
	if st["running"].(bool) {
		t.Error("running lock not cleared after cancel")
	}
}
