package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
)

// The enhance pipeline runs OUTSIDE the daemon, in this worker child process.
// waifu2x-ncnn-vulkan and ffmpeg are heavy Vulkan/IO children; run from the
// daemon's own goroutine, a wedged or panicking job could take the whole
// daemon -- and the picker with it -- down, and a crash would leave the job
// lock wedged. As a child process the job is fully isolable: the daemon only
// ever parses the worker's stdout, a crash mid-job is just a failed verdict,
// and a kill takes the worker's whole process group (its children inherit it),
// so nothing keeps burning the GPU behind a dead daemon.

// upscaleSpec is one job: the file, its kind, the scale factor.
type upscaleSpec struct {
	Input string
	Kind  string
	Scale int
}

// workerEvent is one NDJSON line on the worker's stdout: a relayed Upscaler
// progress event, or the final verdict (always the last line).
type workerEvent struct {
	Event   string                 `json:"event,omitempty"`
	Data    map[string]interface{} `json:"data,omitempty"`
	Verdict map[string]interface{} `json:"verdict,omitempty"`
}

// workerProcess is one running job child: its event stream (closed at exit),
// a channel closed when the child is reaped, and the group kill.
type workerProcess struct {
	events <-chan workerEvent
	done   <-chan struct{}
	kill   func()
}

// spawnWorkerProcess is the production worker seam: the daemon's own binary
// re-invoked in upscale-worker mode, in its own process group, with stdin
// held open so the worker can detect a daemon death (EOF) and tear itself
// down instead of orphaning waifu2x on the GPU.
func spawnWorkerProcess(spec upscaleSpec) (workerProcess, error) {
	bin, err := os.Executable()
	if err != nil {
		return workerProcess{}, err
	}
	cmd := exec.Command(bin, "upscale-worker", spec.Input, spec.Kind, strconv.Itoa(spec.Scale))
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return workerProcess{}, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return workerProcess{}, err
	}
	// waifu2x's device banner and ffmpeg's noise land in the daemon's log.
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return workerProcess{}, err
	}

	events := make(chan workerEvent, 64)
	go func() {
		defer close(events)
		scan := bufio.NewScanner(stdout)
		scan.Buffer(make([]byte, 0, 64*1024), 1024*1024)
		for scan.Scan() {
			var ev workerEvent
			if json.Unmarshal(scan.Bytes(), &ev) != nil {
				continue
			}
			events <- ev
		}
	}()
	done := make(chan struct{}, 1)
	go func() {
		_ = cmd.Wait()
		stdin.Close()
		close(done)
	}()
	pid := cmd.Process.Pid
	return workerProcess{
		events: events,
		done:   done,
		kill: func() {
			// negative pid: the whole group, waifu2x/ffmpeg included.
			_ = syscall.Kill(-pid, syscall.SIGKILL)
		},
	}, nil
}

// runUpscaleWorker is the worker entry: one enhance job, events on stdout.
// stdout is the only channel back to the daemon, so nothing the pipeline does
// can wedge the parent.
func runUpscaleWorker(args []string) error {
	if len(args) < 3 {
		return fmt.Errorf("usage: ryogami upscale-worker <input> <kind> <scale>")
	}
	input, kind := args[0], args[1]
	scale, err := strconv.Atoi(args[2])
	if err != nil || scale <= 0 {
		scale = defaultUpscaleScale
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	// The daemon holds our stdin for the job's life; its death (crash,
	// restart, kill) closes the pipe and cancels the run.
	go func() {
		_, _ = io.Copy(io.Discard, os.Stdin)
		cancel()
	}()
	u := NewUpscaler(stateHome(), workerEmit)
	var verdict map[string]interface{}
	if kind == upscaleKindVideo {
		verdict = u.enhanceVideo(ctx, input, scale)
	} else {
		verdict = u.enhanceImage(ctx, input, scale)
	}
	return json.NewEncoder(os.Stdout).Encode(workerEvent{Verdict: verdict})
}

// workerEmit streams the job's progress events to the daemon as NDJSON.
func workerEmit(ev string, data map[string]interface{}) {
	if !strings.HasSuffix(ev, "upscale.progress") && !strings.HasSuffix(ev, "upscale.finished") {
		return
	}
	_ = json.NewEncoder(os.Stdout).Encode(workerEvent{Event: ev, Data: data})
}
