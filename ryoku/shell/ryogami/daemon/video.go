package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// videoPlayer drives video wallpapers through ryogami-live, one process per
// live output (each in its own process group so the whole tree dies on Stop).
// Play is asynchronous: the one-time transcode runs off the hot path while the
// shell paints the clip's still, and a generation counter serializes rapid
// switches so a clip the user already moved past never paints. The counter is
// bumped and captured under one lock, so two concurrent applies can never both
// believe they own the newest generation and stack two full-screen players.
// Each player announces READY once its first frame is committed; onLive fires
// with true once every requested output has announced and with false if every
// player is gone, so the shell never yields the screen to a surface that has
// not painted and the desktop always shows a frame, never a hole.
type videoPlayer struct {
	mu        sync.Mutex
	gen       int64
	procs     map[string]*liveProc
	log       *os.File
	path      string
	outputs   []string
	announced map[string]bool
	expect    int
	onLive    func(bool)
	// Unexpected-exit bookkeeping for respawn's backoff.
	deaths  int
	deathAt time.Time
}

// liveProc is one player bound to one output slot.
type liveProc struct {
	cmd    *exec.Cmd
	output string
	file   string
	capW   int
	fit    string
}

func newVideoPlayer() *videoPlayer { return &videoPlayer{procs: map[string]*liveProc{}} }

// liveSlots is the set of outputs a broadcast video spans: every connected
// output by name, or the NULL slot ("", the compositor's primary) when the
// list can't be read.
func liveSlots() []string {
	outs := outputs.list()
	if len(outs) == 0 {
		return []string{""}
	}
	slots := make([]string, 0, len(outs))
	for _, o := range outs {
		slots = append(slots, o.Name)
	}
	return slots
}

// Play stops whatever is playing (killing its players and bumping the shared
// generation under one lock, so an in-flight transcode of an older switch can
// never land), then prepares path (probe + cached transcode) and launches one
// player per target output. An empty outputs slice or one containing "*" spans
// every connected output. onLive fires with true once every target has
// announced its first frame and with false if every player is gone; nil is
// allowed. The audio verbs remain accepted state upstream: the player is a
// silent renderer, wallpapers do not own the mixer.
func (p *videoPlayer) Play(outputs []string, path, fit, tier string, onLive func(bool)) {
	all := len(outputs) == 0
	for _, o := range outputs {
		if o == "*" {
			all = true
			break
		}
	}

	p.mu.Lock()
	p.gen++
	gen := p.gen
	killed := p.takeLocked(nil)
	log := p.log
	p.log = nil
	p.announced = map[string]bool{}
	p.expect = 0
	p.onLive = onLive
	if f, err := os.OpenFile(managedLogPath("video"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644); err == nil {
		p.log = f
	}
	p.path = path
	if all {
		p.outputs = []string{"*"}
	} else {
		p.outputs = append([]string(nil), outputs...)
	}
	p.mu.Unlock()

	reapLivePlayers(killed, log)

	go func() {
		capW := liveCapWidth(tier)
		src := liveProbe(path)
		fps := liveFps(tier, src)
		file := livewallSource(path, src, capW, fps)
		if file == "" {
			fmt.Fprintf(os.Stderr, "ryogami: transcode failed for %s; keeping the still\n", path)
			return
		}
		targets := outputs
		if all {
			targets = liveSlots()
		}
		p.mu.Lock()
		defer p.mu.Unlock()
		if p.gen != gen {
			return // switched away while transcoding
		}
		p.expect = len(targets)
		for _, out := range targets {
			p.spawnLocked(gen, out, file, capW, fit)
		}
	}()
}

// takeLocked moves the tracked players (all, or those on the named outputs)
// out of the bookkeeping; caller holds the lock. A nil or "*" filter takes all.
func (p *videoPlayer) takeLocked(want []string) []*liveProc {
	all := len(want) == 0
	for _, o := range want {
		if o == "*" {
			all = true
		}
	}
	taken := make([]*liveProc, 0, len(p.procs))
	for slot, lp := range p.procs {
		if !all && !contains(want, slot) {
			continue
		}
		taken = append(taken, lp)
		delete(p.procs, slot)
	}
	return taken
}

// reapLivePlayers kills the player process groups and any orphans from a dead
// daemon (an orphan's surface stacks above ours, hiding every later wallpaper).
func reapLivePlayers(procs []*liveProc, log *os.File) {
	for _, lp := range procs {
		if lp.cmd.Process != nil {
			_ = syscall.Kill(-lp.cmd.Process.Pid, syscall.SIGKILL)
		}
	}
	if log != nil {
		_ = log.Close()
	}
	if len(procs) == 0 {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = exec.CommandContext(ctx, "pkill", "-x", liveDaemon).Run()
	_ = exec.CommandContext(ctx, "pkill", "-f", "mpvpaper").Run()
}

// StopOutputs tears down the players on the named outputs (empty or "*" means
// every one), leaving the rest of the bookkeeping intact.
func (p *videoPlayer) StopOutputs(want []string) {
	p.mu.Lock()
	p.gen++
	killed := p.takeLocked(want)
	p.mu.Unlock()
	reapLivePlayers(killed, nil)
}

// Abandon invalidates an in-flight transcode or a pending respawn without
// killing anything: a switch onto a wallpaper whose renderers own the screen,
// where no player of ours is expected, must still drop the queued surface.
func (p *videoPlayer) Abandon() {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.gen++
}

// spawnLocked launches one player bound to output ("" = compositor primary);
// caller holds the lock. Stdout is scanned for the READY handshake and teed to
// the managed log. A crash while the player still believes it should be
// running is logged to stderr, and respawn brings it back with a bounded
// backoff: a video wallpaper must not silently stay a still until next login.
func (p *videoPlayer) spawnLocked(gen int64, output, file string, capW int, fit string) {
	args := []string{file, strconv.Itoa(capW), fit}
	if output != "" && output != "*" {
		args = append(args, output)
	}
	cmd := exec.Command(liveDaemon, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdin = nil
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		stdout = nil
	}
	if p.log != nil {
		if stdout == nil {
			cmd.Stdout = p.log
		}
		cmd.Stderr = p.log
	}
	if err := cmd.Start(); err != nil {
		fmt.Fprintf(os.Stderr, "ryogami: launch %s: %v (build it with ryoku/shell/livewall/build.sh)\n", liveDaemon, err)
		if p.expect > 0 {
			p.expect--
		}
		return
	}
	lp := &liveProc{cmd: cmd, output: output, file: file, capW: capW, fit: fit}
	p.procs[output] = lp
	if stdout != nil {
		go p.scanReady(gen, output, stdout)
	}
	go func() {
		err := cmd.Wait()
		p.mu.Lock()
		// Still recorded means Stop did not remove it: an unexpected exit.
		tracked := p.procs[output] == lp
		if tracked {
			delete(p.procs, output)
		}
		lastGone := tracked && len(p.procs) == 0 && p.gen == gen && len(p.announced) > 0
		cb := p.onLive
		p.mu.Unlock()
		if tracked {
			fmt.Fprintf(os.Stderr, "ryogami: %s on %q exited unexpectedly: %v\n", liveDaemon, output, err)
		}
		if lastGone && cb != nil {
			cb(false) // every player died: the still shows meanwhile
		}
		if tracked {
			p.respawn(gen, lp)
		}
	}()
}

// respawn brings back a player that died under the daemon (a compositor
// output cycle, a suspend, a stray kill), so a video wallpaper never stays a
// still until the next login. Backoff steps 1s, 2s, 4s, 8s and gives up after
// the fifth death within a minute (a clip that cannot play at all would spin
// otherwise); Stop or a new Play (a generation change) cancels a pending one.
func (p *videoPlayer) respawn(gen int64, lp *liveProc) {
	p.mu.Lock()
	now := time.Now()
	if now.Sub(p.deathAt) > time.Minute {
		p.deaths = 0
	}
	p.deaths++
	p.deathAt = now
	n := p.deaths
	p.mu.Unlock()
	if n > 5 {
		fmt.Fprintf(os.Stderr, "ryogami: %s on %q keeps dying; leaving the still\n", liveDaemon, lp.output)
		return
	}
	delay := time.Second << (n - 1)
	if delay > 8*time.Second {
		delay = 8 * time.Second
	}
	time.Sleep(delay)
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.gen != gen {
		return
	}
	delete(p.announced, lp.output)
	p.spawnLocked(gen, lp.output, lp.file, lp.capW, lp.fit)
}

// scanReady tees one player's stdout into the managed log and marks its output
// announced on that output's first READY of the current generation. onLive
// fires with true only once every requested output has presented, so the
// shell never yields a screen whose player has not committed a frame yet.
func (p *videoPlayer) scanReady(gen int64, output string, r io.Reader) {
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		line := sc.Text()
		p.mu.Lock()
		if p.log != nil {
			fmt.Fprintln(p.log, line)
		}
		var cb func(bool)
		if strings.TrimSpace(line) == "READY" && p.gen == gen && !p.announced[output] {
			p.announced[output] = true
			if p.expect > 0 && len(p.announced) >= p.expect {
				cb = p.onLive
			}
		}
		p.mu.Unlock()
		if cb != nil {
			cb(true)
		}
	}
}

// Stop invalidates any in-flight transcode, kills every spawned player (whole
// process group) and, mirroring how process.go clears a stale picker, pkills
// orphans: livewall from a crashed daemon, mpvpaper from releases that shipped
// it (an orphan's surface stacks above ours, hiding every later wallpaper).
func (p *videoPlayer) Stop() {
	p.mu.Lock()
	p.gen++
	killed := p.takeLocked(nil)
	log := p.log
	p.log = nil
	p.path = ""
	p.outputs = nil
	p.announced = map[string]bool{}
	p.expect = 0
	p.mu.Unlock()

	reapLivePlayers(killed, log)
}

// Playing reports whether any player process is tracked.
func (p *videoPlayer) Playing() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.procs) > 0
}

// Ready reports that a player both runs and has announced its first frame:
// the state in which the shell may yield the screen to the video surface.
func (p *videoPlayer) Ready() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.procs) > 0 && len(p.announced) > 0
}

func (p *videoPlayer) Current() (path string, outputs []string) {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.path, append([]string(nil), p.outputs...)
}
