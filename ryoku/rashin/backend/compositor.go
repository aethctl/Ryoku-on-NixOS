package main

import (
	"context"
	"time"

	wm "ryoku-wm"
)

// compositorConfigDir is the ~/.config subdir the active window-manager provider
// owns, resolved through the seam rather than a compositor-specific literal. ""
// when no provider is detected.
func compositorConfigDir() string {
	return wm.ConfigDir(wm.Detect().Name)
}

// monitorOutputs reads the compositor's outputs once. wm streams state, so this
// opens watch, takes the first outputs frame, and cancels. Nil on no provider.
func monitorOutputs() []wm.Output {
	c := wm.Open()
	if !c.Available() {
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	var outs []wm.Output
	_ = c.Watch(ctx, func(f wm.Frame) {
		if f.Kind == wm.FrameOutputs {
			outs = f.Outputs
			cancel()
		}
	})
	return outs
}
