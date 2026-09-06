package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// theming.go is what ryoku-shell keeps of the old wallpaper file after Ryogami
// took ownership of the wallpaper (apply, the topic, transitions, depth) and the
// dynamic wallpaper->palette pipeline: the named-theme palette worker, plus the
// few wallpaper-adjacent helpers the surviving readers (walltone, the matugen
// preview CLI) still need. The wallpaper render backend itself lives in the
// Ryogami daemon now.

func findHubBin() string {
	if p, err := exec.LookPath("ryoku-hub"); err == nil {
		return p
	}
	home := os.Getenv("HOME")
	for _, cand := range []string{
		filepath.Join(home, ".local", "bin", "ryoku-hub"),
		"/usr/local/bin/ryoku-hub",
		"/usr/bin/ryoku-hub",
	} {
		if _, err := os.Stat(cand); err == nil {
			return cand
		}
	}
	return "ryoku-hub"
}

func wallState() string { return filepath.Join(stateDir(), "ryoku-wallpaper") }

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}

func isVideo(p string) bool {
	switch strings.ToLower(filepath.Ext(p)) {
	case ".mp4", ".webm", ".mkv", ".mov":
		return true
	}
	return false
}

func readState() string {
	b, err := os.ReadFile(wallState())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// ryowallsTune: the ryowalls per-image tune (ryoku-ryowalls.json). frameOffset
// reads the sampled frame second for a video wallpaper from it.
func ryowallsTune() string { return filepath.Join(stateDir(), "ryoku-ryowalls.json") }

// liveFrame: one still from the video, for matugen (and the ryowalls preview) to
// read. Cached per clip, mtime and offset, and renamed into place. It used to be
// one shared file, so a ryowalls preview of another clip handed the reader that
// clip's frame: the palette took its light/dark from the wrong video. "" on
// failure, so the palette keeps its previous value.
func liveFrame(video string) string {
	st, err := os.Stat(video)
	if err != nil {
		return ""
	}
	off := frameOffset(video)
	dir := filepath.Join(stateDir(), "ryoku-live-frames")
	name := strings.TrimSuffix(filepath.Base(video), filepath.Ext(video))
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-"+off+".png")
	if isFile(out) {
		return out
	}
	if os.MkdirAll(dir, 0o755) != nil {
		return ""
	}
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + "-" + strconv.FormatInt(time.Now().UnixNano(), 10) + ".png"
	// -update says "one image, not a sequence": without it ffmpeg 8 warns, and a
	// warning here is an error in the next release.
	err = exec.Command("ffmpeg", "-y", "-ss", off, "-i", video,
		"-frames:v", "1", "-update", "1", tmp).Run()
	if err != nil || !isFile(tmp) {
		_ = os.Remove(tmp)
		return ""
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	pruneLiveFrames(dir)
	return out
}

// pruneLiveFrames bounds the still cache: a 4K frame is a couple of MB and a
// wallpaper library grows.
const liveFrameKeep = 24

func pruneLiveFrames(dir string) {
	// the one shared still this cache replaced, on a box that still carries it
	_ = os.Remove(filepath.Join(stateDir(), "ryoku-live-frame.png"))
	ents, err := os.ReadDir(dir)
	if err != nil || len(ents) <= liveFrameKeep {
		return
	}
	type still struct {
		path string
		mod  time.Time
	}
	var stills []still
	for _, e := range ents {
		info, err := e.Info()
		if err != nil || e.IsDir() {
			continue
		}
		stills = append(stills, still{filepath.Join(dir, e.Name()), info.ModTime()})
	}
	if len(stills) <= liveFrameKeep {
		return
	}
	sort.Slice(stills, func(i, j int) bool { return stills[i].mod.After(stills[j].mod) })
	for _, s := range stills[liveFrameKeep:] {
		_ = os.Remove(s.path)
	}
}

// frameOffset: seconds into the video that matugen samples, from the per-video
// sticky tune; "1" by default.
func frameOffset(video string) string {
	b, err := os.ReadFile(ryowallsTune())
	if err != nil {
		return "1"
	}
	var t struct {
		Image string  `json:"image"`
		Frame float64 `json:"frame"`
	}
	if json.Unmarshal(b, &t) == nil && t.Image == video && t.Frame > 0 {
		return strconv.FormatFloat(t.Frame, 'f', 2, 64)
	}
	return "1"
}

// scheduleTheme: nudge the palette/border worker, non-blocking. buffered channel
// coalesces a burst into the latest, so theming runs once the presses settle.
func (d *daemon) scheduleTheme() {
	select {
	case d.paintSig <- struct{}{}:
	default:
	}
}

// paintWorker: regen the palette for whatever is on screen, reload hypr
// (config-only, monitors untouched), wake the LED worker. The wallpaper source
// is the ryogami frame the bridge mirrors (watchRyogami schedules a pass on
// every switch), matugenApply authors ~/.cache/ryoku/colors.json and fans the
// palette into the app templates, and a fixed named theme overrides the
// dynamic path entirely so the two never write colors.json on the same
// trigger. Runs for the life of the daemon.
func (d *daemon) paintWorker() {
	for range d.paintSig {
		// Self-heal a stale signature before any hyprctl fork: if Hyprland
		// restarted under this persisted daemon, re-bind so the border reload
		// and the cursor recolour reach the live compositor (see hyprsig.go).
		ensureLiveHyprSignature()
		// The surfaces floating on the picture need its luminance map either
		// way, named theme or not.
		writeWallpaperTone(d.currentWall())
		// A fixed named theme owns the palette: fan its curated palette into the
		// same app templates and reload, so apps follow the shell rail's master.
		if staticThemeActive() {
			if name := staticThemeName(); name != "" {
				if err := d.matugenApplyStatic(name); err != nil {
					fmt.Fprintf(os.Stderr, "paintWorker matugen static: %v\n", err)
					continue
				}
				_ = exec.Command("hyprctl", "reload", "config-only").Run()
				// A hyprctl reload re-runs decoration.lua, which reverts
				// col.active_border to the value it parses at config time; the
				// eval is the only path that lands the live palette border.
				applyHyprBorder()
				select {
				case d.ledsSig <- struct{}{}:
				default:
				}
			}
			continue
		}
		pic := d.currentWall()
		if pic == "" || !isFile(pic) {
			continue
		}
		// The dynamic pipeline owns the palette only while Match wallpaper is on
		// and no fixed named theme is selected; otherwise it idles so it never
		// fights the static palette. matugenApply samples a still from a video
		// itself.
		if !matugenFollows() {
			continue
		}
		if err := d.matugenApply(pic); err != nil {
			fmt.Fprintf(os.Stderr, "paintWorker matugen: %v\n", err)
			// Leave the last good palette in place rather than reloading onto
			// decoration.lua's red fallback.
			continue
		}
		_ = exec.Command("hyprctl", "reload", "config-only").Run()
		// The reload reverts the window border to decoration.lua's parsed
		// fallback (#e0563b when hypr-colors.lua is stale); eval lands the live
		// wallpaper border over it. Lost when the wallpaper backend moved to the
		// daemon, which is why the border kept snapping back to red.
		applyHyprBorder()
		select {
		case d.ledsSig <- struct{}{}:
		default:
		}
	}
}

// themeAppsEnabled reports whether the palette should reach GTK / GUI apps.
// Mirrors the hub control plane: a theme.json without the key reads as on, so
// existing installs keep the themed apps they already had.
func themeAppsEnabled() bool {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "theme.json"))
	if err != nil {
		return true
	}
	var s struct {
		ThemeApps *bool `json:"themeApps"`
	}
	if json.Unmarshal(b, &s) != nil || s.ThemeApps == nil {
		return true
	}
	return *s.ThemeApps
}

// blankGtk drops the Ryoku palette from the generated GTK stylesheets, so GTK /
// libadwaita apps fall back to their own stock colours when app theming is off.
func blankGtk(cfgBase string) {
	const off = "/* Ryoku: app theming is off; apps use their own colours. */\n"
	for _, rel := range []string{"gtk-3.0/gtk.css", "gtk-4.0/gtk.css"} {
		p := filepath.Join(cfgBase, rel)
		_ = os.MkdirAll(filepath.Dir(p), 0o755)
		_ = os.WriteFile(p, []byte(off), 0o644)
	}
}

// ledsWorker: push the new accent at the lighting devices the user put under
// Ryoku's control. `ryoku-hub lighting accent` returns without touching anything
// while lighting is off or no device is adopted, so an untouched install never
// talks to a keyboard. Reaching hardware is slow (seconds on first use), so it
// lives on its own coalescing worker and never touches the theme hot path. Runs
// for the life of the daemon.
func (d *daemon) ledsWorker() {
	for range d.ledsSig {
		_ = exec.Command(findHubBin(), "lighting", "accent").Run()
	}
}
