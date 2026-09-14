package main

import (
	"sync"

	wm "ryoku-wm"
)

// wmClient is the daemon's single window-manager seam handle, shared by the
// restore watcher, the caps RPC, and the output-geometry cache. One per process
// (the enhance worker is a separate process and opens its own).
var wmClient = wm.Open()

// outputs caches the compositor's output list so the wallpaper pipeline can size
// video and pick broadcast targets without asking the compositor per call. The
// restore watcher feeds it every output change, so it stays live in the daemon;
// the enhance worker has no watcher, so its first read probes once.
var outputs = &outputCache{}

type outputCache struct {
	mu     sync.Mutex
	outs   []wm.Output
	probed bool
}

// set replaces the cache; the restore watcher calls it on every outputs frame.
func (c *outputCache) set(outs []wm.Output) {
	c.mu.Lock()
	c.outs = outs
	c.probed = true
	c.mu.Unlock()
}

// list returns the cached outputs, probing once when nothing has fed the cache.
func (c *outputCache) list() []wm.Output {
	c.mu.Lock()
	if c.probed {
		outs := c.outs
		c.mu.Unlock()
		return outs
	}
	c.mu.Unlock()

	probed := probeOutputs()
	c.mu.Lock()
	if !c.probed {
		c.outs = probed
		c.probed = true
	}
	outs := c.outs
	c.mu.Unlock()
	return outs
}

// probeOutputs reads the output list once. Empty on no provider: callers fall
// back to a default width.
func probeOutputs() []wm.Output {
	if !wmClient.Available() {
		return nil
	}
	snap, err := wmClient.State()
	if err != nil {
		return nil
	}
	return snap.Outputs
}
