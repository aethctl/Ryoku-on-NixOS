package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func desiredEngine(paperEngine, videoEngine string, isVideo bool) string {
	if !isVideo {
		switch paperEngine {
		case "awww":
			return "awww"
		case "skwd-paper":
			return "skwd-paper"
		default:
			return "shell"
		}
	}
	// awww has no video path, so video on an awww box stays with the shell player.
	if videoEngine == "vulkan" || paperEngine == "skwd-paper" {
		return "skwd-paper"
	}
	return "shell"
}

// An engine whose tool is missing degrades to the shell so the wallpaper still paints.
func (d *daemon) effectiveEngine(isVideo bool) string {
	want := desiredEngine(d.settingString("paper.engine"), d.settingString("paper.videoEngine"), isVideo)
	switch want {
	case "awww":
		if !awwwAvailable() {
			return "shell"
		}
	case "skwd-paper":
		if !d.skwdPaperInstalled() {
			return "shell"
		}
	}
	return want
}

// handled is false on failure so the caller falls back to the shell painter.
func (d *daemon) routeAltEngine(wpType, path, mode string, outputs []string, mute map[string]bool, volume map[string]int) (bool, error) {
	isVideo := wpType == "video"
	switch d.effectiveEngine(isVideo) {
	case "skwd-paper":
		if err := d.applyViaPaper(wpType, path, mode, outputs, mute, volume); err != nil {
			fmt.Fprintf(os.Stderr, "ryogami: skwd-paper apply failed (%v); falling back to shell\n", err)
			return false, nil
		}
		return true, nil
	case "awww":
		if err := d.applyViaAwww(path, mode, outputs, mute, volume); err != nil {
			fmt.Fprintf(os.Stderr, "ryogami: awww apply failed (%v); falling back to shell\n", err)
			return false, nil
		}
		return true, nil
	}
	return false, nil
}

func (d *daemon) applyViaPaper(wpType, path, mode string, outputs []string, mute map[string]bool, volume map[string]int) error {
	if d.paper == nil {
		return fmt.Errorf("renderer client unavailable")
	}
	isVideo := wpType == "video"
	fill := paperFill(contentFit())
	layer := "background"
	if isVideo {
		layer = d.paperLayer()
	}
	kind := "static"
	if isVideo {
		kind = "video"
	}
	// A restore or live reload is a republish, not a switch, so it cuts.
	tr := d.buildPaperTransition()
	if mode == "init" || mode == "live-reload" {
		tr = nil
	}

	def := wallAudioDefaults()
	newAssign := func(outs []string, audioKey string) paperAssign {
		m, vol := effectiveAudio(audioKey, mute, volume, def)
		a := paperAssign{
			Outputs:  outs,
			Source:   paperSource{Kind: kind, Path: path},
			FillMode: fill,
			Mute:     m,
			Volume:   vol,
			Layer:    layer,
		}
		a.Transition = tr
		return a
	}

	var req paperApplyFull
	broadcast := len(outputs) == 0 || contains(outputs, "*")
	independent := isVideo && !d.settingBool("paper.videoMultiProcess")
	switch {
	case broadcast && !independent:
		req.Assignments = []paperAssign{newAssign([]string{"*"}, "*")}
		req.ReplaceAll = true
	default:
		targets := outputs
		if broadcast {
			targets = liveSlots()
		}
		for _, out := range targets {
			if out == "" || out == "*" {
				req.Assignments = append(req.Assignments, newAssign([]string{"*"}, "*"))
				continue
			}
			req.Assignments = append(req.Assignments, newAssign([]string{out}, out))
		}
		req.ReplaceAll = broadcast
	}
	if len(req.Assignments) == 0 {
		req.Assignments = []paperAssign{newAssign([]string{"*"}, "*")}
		req.ReplaceAll = true
	}
	req.Policy = d.buildRendererPolicy()

	if d.video.Playing() {
		d.video.Stop()
	}
	if _, err := d.paper.exchange("paper.apply", req, true); err != nil {
		return err
	}

	paint := path
	if isVideo {
		if still := liveStill(path, d.config().videoFrame()); still != "" {
			paint = still
		}
	}
	d.recordAltApply(wpType, path, mode, outputs, mute, volume, paint, isVideo)
	return nil
}

func (d *daemon) recordAltApply(wpType, path, mode string, outputs []string, mute map[string]bool, volume map[string]int, paint string, isVideo bool) {
	fit := contentFit()
	if len(outputs) == 0 || contains(outputs, "*") {
		d.surface.show(paint, fit, nil, true, isVideo, videoClip{})
	} else {
		for _, out := range outputs {
			d.surface.showOutput(out, paint, fit, nil, true, isVideo, videoClip{})
		}
	}
	// A boot restore is not a pick: it neither rewrites the stored state nor counts as a use.
	if mode == "init" {
		return
	}
	name := filepath.Base(path)
	d.setCurrent(name)
	d.saveOutputs(outputs, wpType, path, mute, volume)
	key := strings.TrimSuffix(name, filepath.Ext(name))
	d.store.mutate(keyFor(d.store, name, key), func(e *Entry) { e.ApplyCount++ })
	d.broadcast("ryogami.wall.applied", map[string]interface{}{
		"type": wpType, "name": name, "path": path, "we_id": "", "key": key,
	})
}
