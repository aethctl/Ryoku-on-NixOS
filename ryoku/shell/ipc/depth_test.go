package main

import (
	"bufio"
	"encoding/json"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestDepthConfigParses pins the render-knob contract: an absent file is the
// small-CPU default, model and alphaMatting are read verbatim, and the model
// falls back to the default when the key is missing. Whether depth is on is the
// per-wall registry, not depth.json, so enabled is no longer read here.
func TestDepthConfigParses(t *testing.T) {
	cfg := filepath.Join(t.TempDir(), ".config")
	t.Setenv("XDG_CONFIG_HOME", cfg)
	dir := filepath.Join(cfg, "ryoku")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}

	if got := depthConfig(); got.model != "u2netp" || got.alphaMatting {
		t.Fatalf("absent depth.json = %+v, want {u2netp false}", got)
	}
	writeFile(t, filepath.Join(dir, "depth.json"), `{"model":"birefnet-general-lite","alphaMatting":true}`)
	if got := depthConfig(); got.model != "birefnet-general-lite" || !got.alphaMatting {
		t.Fatalf("depth.json = %+v, want {birefnet-general-lite true}", got)
	}
	writeFile(t, filepath.Join(dir, "depth.json"), `{"alphaMatting":true}`)
	if got := depthConfig(); got.model != "u2netp" || !got.alphaMatting {
		t.Fatalf("model-absent depth.json = %+v, want {u2netp true}", got)
	}
}

// TestDepthOutNaming pins the discoverable, per-wallpaper name: a cutout is the
// wallpaper's stem plus -depth.png, in the Pictures/Depth folder.
func TestDepthOutNaming(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	want := filepath.Join(home, "Pictures", "Depth", "sunset-depth.png")
	if got := depthOut("/wallpapers/sunset.jpg"); got != want {
		t.Fatalf("depthOut = %q, want %q", got, want)
	}
}

// TestDepthReusable proves a saved cutout is reused only when it still matches
// its source and model and is no older than the source, so a wallpaper's return
// is instant but a change (model, edited image) regenerates.
func TestDepthReusable(t *testing.T) {
	dir := t.TempDir()
	source := filepath.Join(dir, "wp.png")
	out := filepath.Join(dir, "wp-depth.png")
	writeFile(t, source, "src")
	writeFile(t, out, "cut")
	// make the cutout newer than the source.
	newer := time.Now().Add(time.Hour)
	if err := os.Chtimes(out, newer, newer); err != nil {
		t.Fatal(err)
	}
	idx := map[string]depthMeta{out: {Source: source, Model: "u2netp"}}

	if !depthReusable(idx, source, "u2netp", false, out) {
		t.Fatal("a matching, fresh cutout must be reusable")
	}
	if depthReusable(idx, source, "birefnet-general-lite", false, out) {
		t.Fatal("a different model must not reuse")
	}
	if depthReusable(idx, source, "u2netp", true, out) {
		t.Fatal("a different edge setting must not reuse")
	}
	if depthReusable(idx, filepath.Join(dir, "other.png"), "u2netp", false, out) {
		t.Fatal("a different source must not reuse")
	}
	if depthReusable(map[string]depthMeta{}, source, "u2netp", false, out) {
		t.Fatal("an unindexed cutout must not reuse")
	}
	// a source edited after the cutout was made must regenerate.
	future := time.Now().Add(2 * time.Hour)
	if err := os.Chtimes(source, future, future); err != nil {
		t.Fatal(err)
	}
	if depthReusable(idx, source, "u2netp", false, out) {
		t.Fatal("a source newer than its cutout must regenerate")
	}
}

// TestDepthTargets returns the still wallpapers on screen, default plus per-
// output overrides, and skips videos and live-claimed slots.
func TestDepthTargets(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	img := filepath.Join(home, "a.png")
	vid := filepath.Join(home, "b.mp4")
	live := filepath.Join(home, "c.png")
	still := filepath.Join(home, "d-still.jpg")
	writeFile(t, img, "img")
	writeFile(t, vid, "vid")
	writeFile(t, live, "live")
	writeFile(t, still, "still")

	d := &daemon{}
	d.ryoWall = ryogamiFrame{
		Default: ryogamiFrameEntry{Path: img},
		Outputs: map[string]ryogamiFrameEntry{
			"DP-1": {Path: vid},
			"DP-2": {Path: live, Live: true},
			// A video's extracted still: a plain image path, but the frame's
			// video marker must keep depth away from it.
			"DP-3": {Path: still, Video: true},
		},
	}
	targets := d.depthTargets()
	if len(targets) != 1 || targets[0].slot != "" || targets[0].source != img {
		t.Fatalf("targets = %+v, want only the default still image", targets)
	}
}

// TestDepthPublishWire pins the bridge contract with ryogami: a finished cutout
// crosses the socket as `depth set` with a JSON body carrying the slot, source,
// cutout path and its mtime revision, and clearing crosses as `depth clear`.
// Staleness (a switch mid-generation) is ryogami's side of the contract: it
// validates the source against the slot before folding the cutout in.
func TestDepthPublishWire(t *testing.T) {
	rt := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", rt)
	ln, err := net.Listen("unix", filepath.Join(rt, "ryogami.sock"))
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	lines := make(chan string, 2)
	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			go func(c net.Conn) {
				defer c.Close()
				l, _ := bufio.NewReader(c).ReadString('\n')
				lines <- strings.TrimSpace(l)
				_, _ = io.WriteString(c, "ok\n")
			}(conn)
		}
	}()
	recv := func() string {
		select {
		case l := <-lines:
			return l
		case <-time.After(2 * time.Second):
			t.Fatal("no command reached the fake ryogami")
			return ""
		}
	}

	out := filepath.Join(t.TempDir(), "wp-depth.png")
	writeFile(t, out, "cutout")

	d := &daemon{}
	d.depthPublish("DP-1", "/walls/wp.png", out)
	got := recv()
	body, ok := strings.CutPrefix(got, "depth set ")
	if !ok {
		t.Fatalf("publish sent %q, want a `depth set` line", got)
	}
	var req struct {
		Screen string `json:"screen"`
		Source string `json:"source"`
		Out    string `json:"out"`
		Rev    int64  `json:"rev"`
	}
	if err := json.Unmarshal([]byte(body), &req); err != nil {
		t.Fatalf("publish body not JSON: %v", err)
	}
	if req.Screen != "DP-1" || req.Source != "/walls/wp.png" || req.Out != out {
		t.Fatalf("publish body = %+v", req)
	}
	if req.Rev == 0 || req.Rev != fileModTime(out) {
		t.Fatalf("rev = %d, want the cutout's mtime %d", req.Rev, fileModTime(out))
	}

	d.depthClear()
	if got := recv(); got != "depth clear" {
		t.Fatalf("clear sent %q", got)
	}
}

// TestRyogamiFrameWake pins the bridge trigger: a frame showing a different
// wallpaper, one that lost its cutout, or a live claim wakes the depth worker,
// while the frame our own publish produces (same sources, depth set) stays
// quiet, so the publish-subscribe loop settles.
func TestRyogamiFrameWake(t *testing.T) {
	d := &daemon{depthSig: make(chan struct{}, 1)}
	woke := func() bool {
		select {
		case <-d.depthSig:
			return true
		default:
			return false
		}
	}
	feed := func(js string) { d.consumeRyogamiFrames(strings.NewReader(js + "\n")) }

	feed(`{"default":{"path":"/w/a.png"},"outputs":{}}`)
	if !woke() {
		t.Fatal("a new wallpaper did not wake the worker")
	}
	feed(`{"default":{"path":"/w/a.png","depth":"/d/a-depth.png"},"outputs":{}}`)
	if woke() {
		t.Fatal("our own depth publish woke the worker again")
	}
	feed(`{"default":{"path":"/w/a.png"},"outputs":{}}`)
	if !woke() {
		t.Fatal("a re-set that dropped the cutout did not wake the worker")
	}
	feed(`{"default":{"path":"/w/a.png","live":true},"outputs":{}}`)
	if !woke() {
		t.Fatal("a live claim did not wake the worker")
	}
}

// TestDepthPerWallRegistry pins the per-wall opt-in: an untagged wallpaper is off
// and generates nothing (busy never sticks -- the switch-stuck fix), enabling
// tags the wallpaper, and switching away and back restores it from the persisted
// registry, which a fresh daemon reads on boot. The engine is forced absent so
// the effective flag and busy state are exercised without a real cutout.
func TestDepthPerWallRegistry(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_STATE_HOME", filepath.Join(home, ".local", "state"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))
	t.Setenv("PATH", t.TempDir())            // no ryoku-depth: engine reads as absent
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir()) // no ryogami: clears fail fast, harmlessly

	wx := filepath.Join(home, "x.png")
	wy := filepath.Join(home, "y.png")
	writeFile(t, wx, "x")
	writeFile(t, wy, "y")
	if err := os.MkdirAll(stateDir(), 0o755); err != nil {
		t.Fatal(err)
	}

	show := func(d *daemon, pic string) {
		d.ryoWallMu.Lock()
		d.ryoWall = ryogamiFrame{Default: ryogamiFrameEntry{Path: pic}}
		d.ryoWallMu.Unlock()
	}

	d := &daemon{}

	// Untagged wallpaper: off, no generation, busy never set, and the overlay is
	// cleared -- the switch never sticks on "Cutting out".
	show(d, wx)
	d.reconcileDepth(false, false)
	if loadDepthWalls().Current {
		t.Fatal("untagged wallpaper reported effective-enabled")
	}
	if d.depthBusy.Load() {
		t.Fatal("busy stuck true for an untagged wallpaper")
	}
	if !isFile(depthWallsPath()) {
		t.Fatal("registry not ensured on boot")
	}

	// Enable on X: tagged and effective immediately.
	d.depthSetEnabled(true)
	if reg := loadDepthWalls(); !reg.Current || !reg.Walls[wx] {
		t.Fatalf("after enable X = %+v, want current+tagged", reg)
	}

	// Switch to an untagged Y: off, busy clear, X's tag persists.
	show(d, wy)
	d.reconcileDepth(false, false)
	if loadDepthWalls().Current {
		t.Fatal("Y (never enabled) reported effective-enabled")
	}
	if d.depthBusy.Load() {
		t.Fatal("busy stuck true switching to an untagged wallpaper")
	}
	if !loadDepthWalls().Walls[wx] {
		t.Fatal("X's opt-in was lost when switching away")
	}

	// Switch back to X: depth restored from the registry.
	show(d, wx)
	d.reconcileDepth(false, false)
	if !loadDepthWalls().Current {
		t.Fatal("returning to X did not restore depth")
	}

	// Persisted across a daemon restart: a fresh daemon reads the same registry
	// once ryogami's retained frame reseeds its wallpaper mirror.
	d2 := &daemon{}
	show(d2, wx)
	d2.reconcileDepth(false, false)
	if !loadDepthWalls().Current {
		t.Fatal("depth opt-in did not survive a daemon restart")
	}

	// Disable on X: untagged again, off.
	d.depthSetEnabled(false)
	if reg := loadDepthWalls(); reg.Current || reg.Walls[wx] {
		t.Fatalf("after disable X = %+v, want off+untagged", reg)
	}
}
