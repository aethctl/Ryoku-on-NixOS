package main

import (
	"fmt"
	"sort"
	"strings"
	"sync"
)

// Features register at package init so each lives in its own file.

type applyRequest struct {
	Type    string
	Path    string
	WeID    string
	Outputs []string // empty means every output
	Reason  string
}

type applyEvent struct {
	applyRequest
	Name string
	Key  string
}

type settingWatcher struct {
	prefix string
	fn     func(d *daemon, key string, value interface{})
}

var (
	startHooks      []func(d *daemon)
	applyGuards     []func(d *daemon, req *applyRequest) error
	afterApplyHooks []func(d *daemon, ev applyEvent)
	settingWatchers []settingWatcher
)

func onStart(fn func(d *daemon)) { startHooks = append(startHooks, fn) }

func guardApply(fn func(d *daemon, req *applyRequest) error) {
	applyGuards = append(applyGuards, fn)
}

func afterApply(fn func(d *daemon, ev applyEvent)) { afterApplyHooks = append(afterApplyHooks, fn) }

func watchSetting(prefix string, fn func(d *daemon, key string, value interface{})) {
	settingWatchers = append(settingWatchers, settingWatcher{prefix: prefix, fn: fn})
}

func (d *daemon) runStartHooks() {
	for _, fn := range startHooks {
		fn(d)
	}
}

// Guards run in registration order and see the outputs narrowed by earlier ones.
func (d *daemon) runApplyGuards(req *applyRequest) error {
	for _, fn := range applyGuards {
		if err := fn(d, req); err != nil {
			return err
		}
	}
	return nil
}

// Hooks run on their own goroutine so a slow one never delays the reply.
func (d *daemon) runAfterApply(ev applyEvent) {
	if len(afterApplyHooks) == 0 {
		return
	}
	go func() {
		for _, fn := range afterApplyHooks {
			fn(d, ev)
		}
	}()
}

var settingNotifyMu sync.Mutex

// notifySetting serialises watcher calls so a watcher never races itself.
func (d *daemon) notifySetting(key string, value interface{}) {
	settingNotifyMu.Lock()
	defer settingNotifyMu.Unlock()
	for _, w := range settingWatchers {
		if strings.HasPrefix(key, w.prefix) {
			w.fn(d, key, value)
		}
	}
}

type actionFunc func(d *daemon, args map[string]interface{}) (interface{}, error)

var (
	actions      = map[string]actionFunc{}
	availability = map[string]func(d *daemon) bool{}
)

func registerAction(id string, fn actionFunc) {
	if _, dup := actions[id]; dup {
		panic("ryogami: duplicate action " + id)
	}
	actions[id] = fn
}

func (d *daemon) runAction(id string, args map[string]interface{}) (interface{}, error) {
	fn, ok := actions[id]
	if !ok {
		return nil, fmt.Errorf("unknown action: %s", id)
	}
	return fn(d, args)
}

func registerAvailability(name string, fn func(d *daemon) bool) {
	availability[name] = fn
}

func (d *daemon) availabilityMap() map[string]bool {
	names := make([]string, 0, len(availability))
	for name := range availability {
		names = append(names, name)
	}
	sort.Strings(names)
	out := make(map[string]bool, len(names))
	for _, name := range names {
		out[name] = availability[name](d)
	}
	return out
}
