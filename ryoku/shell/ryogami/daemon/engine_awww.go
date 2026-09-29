package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
)

type awwwOptions struct {
	Type       string
	DurationMs float64
	Fps        float64
	Step       float64
	Angle      float64
	Pos        string
	Bezier     string
	WaveWidth  float64
	WaveHeight float64
	InvertY    bool
	Filter     string
}

func awwwArgs(o awwwOptions) []string {
	var a []string
	if o.Type != "" {
		a = append(a, "--transition-type", o.Type)
	}
	if o.DurationMs > 0 {
		a = append(a, "--transition-duration", trimFloat(o.DurationMs/1000))
	}
	if o.Fps > 0 {
		a = append(a, "--transition-fps", strconv.Itoa(int(o.Fps)))
	}
	if o.Step > 0 {
		a = append(a, "--transition-step", strconv.Itoa(int(o.Step)))
	}
	a = append(a, "--transition-angle", trimFloat(o.Angle))
	if o.Pos != "" {
		a = append(a, "--transition-pos", o.Pos)
	}
	if o.Bezier != "" {
		a = append(a, "--transition-bezier", o.Bezier)
	}
	if o.WaveWidth > 0 || o.WaveHeight > 0 {
		a = append(a, "--transition-wave", trimFloat(o.WaveWidth)+","+trimFloat(o.WaveHeight))
	}
	if o.InvertY {
		a = append(a, "--invert-y")
	}
	if o.Filter != "" {
		a = append(a, "--filter", o.Filter)
	}
	return a
}

func trimFloat(f float64) string {
	return strconv.FormatFloat(f, 'f', -1, 64)
}

func (d *daemon) awwwOptions() awwwOptions {
	return awwwOptions{
		Type:       d.settingString("paper.awww.transitionType"),
		DurationMs: d.settingNumber("paper.awww.transitionDurationMs"),
		Fps:        d.settingNumber("paper.awww.transitionFps"),
		Step:       d.settingNumber("paper.awww.transitionStep"),
		Angle:      d.settingNumber("paper.awww.transitionAngle"),
		Pos:        d.settingString("paper.awww.transitionPos"),
		Bezier:     d.settingString("paper.awww.transitionBezier"),
		WaveWidth:  d.settingNumber("paper.awww.transitionWaveWidth"),
		WaveHeight: d.settingNumber("paper.awww.transitionWaveHeight"),
		InvertY:    d.settingBool("paper.awww.invertY"),
		Filter:     d.settingString("paper.awww.filter"),
	}
}

func awwwAvailable() bool {
	_, err := exec.LookPath("awww")
	return err == nil
}

// Best effort: awww img reports its own error when the daemon is not up.
func ensureAwwwDaemon() {
	if exec.Command("awww", "query").Run() == nil {
		return
	}
	bin, err := exec.LookPath("awww-daemon")
	if err != nil {
		return
	}
	cmd := exec.Command(bin)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = nil, nil, nil
	if cmd.Start() == nil {
		go func() { _ = cmd.Wait() }()
	}
}

func (d *daemon) applyViaAwww(path, mode string, outputs []string, mute map[string]bool, volume map[string]int) error {
	if !awwwAvailable() {
		return fmt.Errorf("awww is not installed")
	}
	ensureAwwwDaemon()
	args := []string{"img"}
	if len(outputs) > 0 && !contains(outputs, "*") {
		args = append(args, "--outputs", strings.Join(outputs, ","))
	}
	opts := d.awwwOptions()
	// A restore or live reload republishes the same image, so it cuts instead of replaying the reveal.
	if mode == "init" || mode == "live-reload" {
		opts.Type = "none"
	}
	args = append(args, awwwArgs(opts)...)
	args = append(args, path)
	cmd := exec.Command("awww", args...)
	cmd.Env = os.Environ()
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("awww img: %v: %s", err, strings.TrimSpace(string(out)))
	}
	if d.video.Playing() {
		d.video.Stop()
	}
	if d.paper != nil {
		_ = d.paper.stop(stopTargets(outputs))
	}
	d.recordAltApply("static", path, mode, outputs, mute, volume, path, false)
	return nil
}

func init() {
	registerAvailability("awww", func(d *daemon) bool { return awwwAvailable() })
}
