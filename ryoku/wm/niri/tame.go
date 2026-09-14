package main

import (
	"time"

	wm "ryoku-wm"
)

// Taming the windows apps open maximised. niri honours a client's set_maximized
// by filling the working area edge to edge, gaps and all, which is not where the
// desktop wants a window to land. niri offers no way to refuse the request, so
// the only lever is to clear the state the moment it appears: the provider is
// already streaming every window event, so this rides that stream rather than
// opening a second one.
//
// The correction is confined to the open. A window carries no maximized flag, so
// a window the user maximises later looks identical by geometry to one an app
// maximised for itself; the open time is what tells them apart. Only a window
// that reaches the client-maximised footprint within a short grace of mapping is
// reset, and only once. A window already up when the watch connects, a window
// maximised long after it opened, and a true fullscreen are all left as they are.

// openMaximizeGrace is how long after a window maps its maximise still counts as
// part of the open. niri commits a client's set_maximized within tens of
// milliseconds of the map, so a second is a wide margin over that and far below
// any deliberate maximise a person makes after settling in.
const openMaximizeGrace = time.Second

type tamer struct {
	enabled bool
	gaps    int
	struts  Struts

	baseline map[uint64]struct{} // present at connect, so not ours to correct
	opened   map[uint64]time.Time
	done     map[uint64]struct{}

	now func() time.Time
	// load re-reads the setting and the geometry from the store. It runs on each
	// open, so a Hub toggle or a gap change takes effect on the very next window
	// rather than waiting for the compositor, and the watch stream, to restart.
	load func() (enabled bool, gaps int, struts Struts)
}

func newTamer() *tamer {
	return &tamer{
		baseline: map[uint64]struct{}{},
		opened:   map[uint64]time.Time{},
		done:     map[uint64]struct{}{},
		now:      time.Now,
		load: func() (bool, int, Struts) {
			s := loadStore(storePath())
			return s.Windows.TameMaximizeOnOpen, s.Appearance.GapsOut, s.Niri.Struts
		},
	}
}

// seen records a window replayed during the connect burst, before the session is
// ready. It existed before this watch did, so its state is the user's.
func (t *tamer) seen(id uint64) { t.baseline[id] = struct{}{} }

// open stamps the first sighting of a window after the session is ready and
// refreshes the setting from the store, so the correction is held to the moment
// right after the window maps and reflects whatever the user last chose.
func (t *tamer) open(id uint64) {
	if _, pre := t.baseline[id]; pre {
		return
	}
	if _, ok := t.opened[id]; ok {
		return
	}
	t.enabled, t.gaps, t.struts = t.load()
	t.opened[id] = t.now()
}

// wantsClear reports whether a window is an app that just opened itself
// maximised and should be reset to an ordinary tile: enabled, freshly opened,
// not already handled, and sitting in the client-maximised footprint. Fullscreen
// and a later maximise both fail one of those and are left alone.
func (t *tamer) wantsClear(out wm.Output, id uint64, w, h int) bool {
	if !t.enabled {
		return false
	}
	if _, ok := t.done[id]; ok {
		return false
	}
	at, ok := t.opened[id]
	if !ok || t.now().Sub(at) > openMaximizeGrace {
		return false
	}
	return classifyLayout(out, t.gaps, t.struts, w, h) == layoutClientMaximized
}

func (t *tamer) cleared(id uint64) { t.done[id] = struct{}{} }

func (t *tamer) forget(id uint64) {
	delete(t.baseline, id)
	delete(t.opened, id)
	delete(t.done, id)
}

// clearClientMaximized resets a window an app opened maximised back to an
// ordinary column. Focusing it first is what lets maximize-column land on it,
// and a window that just mapped is the focused one anyway. Best effort: a failed
// request just leaves the window as the app asked, the behaviour before this.
func clearClientMaximized(id uint64) {
	_ = perform(action("FocusWindow", map[string]any{"id": id}))
	_ = perform(action("MaximizeColumn", map[string]any{}))
}
