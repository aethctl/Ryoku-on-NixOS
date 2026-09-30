package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"time"
)

// Each key persists in one store, chosen by its schema Store: ryogami.json, shell.json or the Hub's matugen store.

const (
	settingsFlushDelay   = 300 * time.Millisecond
	settingsPollInterval = 2 * time.Second
)

var (
	settingsMu         sync.Mutex
	settingsPending    = map[string]interface{}{}
	settingsFlushTimer *time.Timer
)

var settingsTombstone = &struct{}{}

func isTombstone(v interface{}) bool { return v == settingsTombstone }

func shellPath() string        { return filepath.Join(ryokuConfigDir(), "shell.json") }
func matugenStorePath() string { return filepath.Join(ryokuConfigDir(), "matugen.json") }

var hubFieldByKey = map[string]string{
	"theme.mode":         "mode",
	"matugen.schemeType": "schemeType",
	"matugen.contrast":   "contrast",
	"matugen.colorIndex": "sourceColorIndex",
}

// span has no shell token; the caller keeps it in ryogami.json.
func modeToContentFit(mode string) string {
	switch mode {
	case "fill":
		return "Cover"
	case "fit":
		return "Contain"
	case "stretch":
		return "Fill"
	case "center":
		return "Center"
	case "tile":
		return "Tile"
	}
	return "Cover"
}

func contentFitToMode(fit string) string {
	switch fit {
	case "Cover":
		return "fill"
	case "Contain", "ScaleDown":
		return "fit"
	case "Fill":
		return "stretch"
	case "Center":
		return "center"
	case "Tile":
		return "tile"
	}
	return "fill"
}

func shellKeyOf(spec *settingSpec) string {
	if spec.StoreKey != "" {
		return spec.StoreKey
	}
	return spec.Key
}

func settingValue(key string) interface{} {
	spec, ok := specFor(key)
	if !ok {
		if v, ok := userRyogami(key); ok {
			return v
		}
		return nil
	}
	switch spec.Store {
	case "shell":
		return shellSettingValue(spec)
	case "hub":
		return hubSettingValue(spec)
	default:
		if v, ok := userRyogami(key); ok {
			return v
		}
		return spec.Default
	}
}

func shellSettingValue(spec *settingSpec) interface{} {
	if spec.Key == "display.fillMode" {
		if v, ok := userRyogami("display.fillMode"); ok {
			return v
		}
		if v, ok := lookupDotted(loadShellTree(), "wallpaper.content_fit"); ok {
			if s, ok := v.(string); ok {
				return contentFitToMode(s)
			}
		}
		return spec.Default
	}
	if v, ok := lookupDotted(loadShellTree(), shellKeyOf(spec)); ok {
		return v
	}
	return spec.Default
}

func hubSettingValue(spec *settingSpec) interface{} {
	field := hubFieldByKey[spec.Key]
	if v, ok := loadHubMap()[field]; ok {
		return v
	}
	return spec.Default
}

func userRyogami(key string) (interface{}, bool) {
	settingsMu.Lock()
	if v, ok := settingsPending[key]; ok {
		settingsMu.Unlock()
		if isTombstone(v) {
			return nil, false
		}
		return v, true
	}
	// A map read must see queued writes to its children too: they reach the file only on flush.
	var queued map[string]interface{}
	for k, v := range settingsPending {
		if strings.HasPrefix(k, key+".") {
			if queued == nil {
				queued = map[string]interface{}{}
			}
			queued[k] = v
		}
	}
	settingsMu.Unlock()
	tree := loadRyogamiTree()
	if len(queued) > 0 {
		if tree == nil {
			tree = map[string]interface{}{}
		}
		for k, v := range queued {
			if isTombstone(v) {
				deleteDotted(tree, k)
			} else {
				setDotted(tree, k, v)
			}
		}
	}
	return lookupDotted(tree, key)
}

func (d *daemon) setting(key string) interface{} { return settingValue(key) }

func (d *daemon) settingBool(key string) bool {
	if b, ok := settingValue(key).(bool); ok {
		return b
	}
	return false
}

func (d *daemon) settingNumber(key string) float64 {
	if n, ok := toNumber(settingValue(key)); ok {
		return n
	}
	return 0
}

func (d *daemon) settingString(key string) string {
	if s, ok := settingValue(key).(string); ok {
		return s
	}
	return ""
}

func (d *daemon) settingList(key string) []interface{} {
	if l, ok := settingValue(key).([]interface{}); ok {
		return l
	}
	return nil
}

func (d *daemon) settingMap(key string) map[string]interface{} {
	if m, ok := settingValue(key).(map[string]interface{}); ok {
		return m
	}
	return nil
}

func (d *daemon) setSetting(key string, value interface{}) error {
	if _, ok := specFor(key); ok {
		if err := validateSetting(key, value); err != nil {
			return err
		}
	}
	if err := d.persistSetting(key, value); err != nil {
		return err
	}
	d.broadcast("ryogami.settings.changed", map[string]interface{}{"values": map[string]interface{}{key: value}})
	d.notifySetting(key, value)
	return nil
}

// No broadcast here: the RPC batches it so a multi-key set fans out once.
func (d *daemon) persistSetting(key string, value interface{}) error {
	spec, ok := specFor(key)
	if !ok {
		d.queueRyogami(key, value)
		return nil
	}
	switch spec.Store {
	case "shell":
		return d.writeShell(spec, value)
	case "hub":
		return writeHub(spec, value)
	default:
		d.queueRyogami(key, value)
		return nil
	}
}

func (d *daemon) resetSetting(key string) error {
	spec, ok := specFor(key)
	if !ok {
		d.queueRyogamiDelete(key)
		return nil
	}
	switch spec.Store {
	case "shell":
		if spec.Key == "display.fillMode" {
			d.queueRyogamiDelete("display.fillMode")
			return deleteShellKey("wallpaper.content_fit")
		}
		return deleteShellKey(shellKeyOf(spec))
	case "hub":
		return writeHub(spec, spec.Default)
	default:
		d.queueRyogamiDelete(key)
		return nil
	}
}

func (d *daemon) writeShell(spec *settingSpec, value interface{}) error {
	if spec.Key == "display.fillMode" {
		mode, _ := value.(string)
		if mode == "span" {
			d.queueRyogami("display.fillMode", "span")
			return nil
		}
		if err := patchShellFile("wallpaper.content_fit", modeToContentFit(mode)); err != nil {
			return err
		}
		// a prior span override would otherwise shadow the shell token on read
		d.queueRyogamiDelete("display.fillMode")
		return nil
	}
	return patchShellFile(shellKeyOf(spec), value)
}

func writeHub(spec *settingSpec, value interface{}) error {
	field := hubFieldByKey[spec.Key]
	if field == "" {
		return fmt.Errorf("no matugen field for %s", spec.Key)
	}
	v := value
	if field == "sourceColorIndex" {
		if n, ok := toNumber(value); ok {
			v = int(n)
		}
	}
	b, err := json.Marshal(map[string]interface{}{field: v})
	if err != nil {
		return err
	}
	out, err := exec.Command("ryoku-hub", "desktop", "matugen", "set", string(b)).CombinedOutput()
	if err != nil {
		return fmt.Errorf("ryoku-hub matugen set: %v: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

func (d *daemon) queueRyogami(key string, value interface{}) {
	settingsMu.Lock()
	settingsPending[key] = value
	d.scheduleFlushLocked()
	settingsMu.Unlock()
}

func (d *daemon) queueRyogamiDelete(key string) {
	settingsMu.Lock()
	settingsPending[key] = settingsTombstone
	d.scheduleFlushLocked()
	settingsMu.Unlock()
}

func (d *daemon) scheduleFlushLocked() {
	if settingsFlushTimer != nil {
		settingsFlushTimer.Stop()
	}
	settingsFlushTimer = time.AfterFunc(settingsFlushDelay, d.flushSettings)
}

// Rewritten on top of a fresh read so a concurrent targeted patch elsewhere survives.
func (d *daemon) flushSettings() {
	settingsMu.Lock()
	if len(settingsPending) == 0 {
		settingsMu.Unlock()
		return
	}
	pending := make(map[string]interface{}, len(settingsPending))
	for k, v := range settingsPending {
		pending[k] = v
	}
	settingsMu.Unlock()

	tree := loadRyogamiTree()
	if tree == nil {
		tree = map[string]interface{}{}
	}
	for k, v := range pending {
		if isTombstone(v) {
			deleteDotted(tree, k)
		} else {
			setDotted(tree, k, v)
		}
	}
	out, err := json.MarshalIndent(tree, "", "  ")
	if err != nil {
		return
	}
	_ = os.MkdirAll(ryokuConfigDir(), 0o755)
	if err := settingsAtomicWrite(configPath(), out); err != nil {
		return
	}
	setSettingsBaseline(flattenSettings(tree))
	d.reloadConfig()

	settingsMu.Lock()
	for k, v := range pending {
		if cur, ok := settingsPending[k]; ok && sameSetting(cur, v) {
			delete(settingsPending, k)
		}
	}
	settingsMu.Unlock()
}

func (d *daemon) flushSettingsNow() {
	settingsMu.Lock()
	if settingsFlushTimer != nil {
		settingsFlushTimer.Stop()
	}
	settingsMu.Unlock()
	d.flushSettings()
}

func patchShellFile(dotted string, value interface{}) error {
	tree := loadShellTree()
	if tree == nil {
		tree = map[string]interface{}{}
	}
	setDotted(tree, dotted, value)
	out, err := json.MarshalIndent(tree, "", "  ")
	if err != nil {
		return err
	}
	_ = os.MkdirAll(ryokuConfigDir(), 0o755)
	return settingsAtomicWrite(shellPath(), out)
}

func deleteShellKey(dotted string) error {
	tree := loadShellTree()
	if tree == nil {
		return nil
	}
	deleteDotted(tree, dotted)
	out, err := json.MarshalIndent(tree, "", "  ")
	if err != nil {
		return err
	}
	_ = os.MkdirAll(ryokuConfigDir(), 0o755)
	return settingsAtomicWrite(shellPath(), out)
}

func loadRyogamiTree() map[string]interface{} {
	b, err := os.ReadFile(configPath())
	if err != nil {
		return nil
	}
	var m map[string]interface{}
	if json.Unmarshal(b, &m) != nil {
		return nil
	}
	return m
}

func loadShellTree() map[string]interface{} {
	b, err := os.ReadFile(shellPath())
	if err != nil {
		return nil
	}
	var m map[string]interface{}
	if json.Unmarshal(b, &m) != nil {
		return nil
	}
	return m
}

func loadHubMap() map[string]interface{} {
	b, err := os.ReadFile(matugenStorePath())
	if err != nil {
		return nil
	}
	var m map[string]interface{}
	if json.Unmarshal(b, &m) != nil {
		return nil
	}
	return m
}

func lookupDotted(m map[string]interface{}, key string) (interface{}, bool) {
	var cur interface{} = m
	for _, part := range strings.Split(key, ".") {
		obj, ok := cur.(map[string]interface{})
		if !ok {
			return nil, false
		}
		cur, ok = obj[part]
		if !ok {
			return nil, false
		}
	}
	return cur, true
}

func setDotted(m map[string]interface{}, key string, value interface{}) {
	parts := strings.Split(key, ".")
	cur := m
	for _, part := range parts[:len(parts)-1] {
		next, ok := cur[part].(map[string]interface{})
		if !ok {
			next = map[string]interface{}{}
			cur[part] = next
		}
		cur = next
	}
	cur[parts[len(parts)-1]] = value
}

func deleteDotted(m map[string]interface{}, key string) {
	parts := strings.Split(key, ".")
	chain := []map[string]interface{}{m}
	cur := m
	for _, part := range parts[:len(parts)-1] {
		next, ok := cur[part].(map[string]interface{})
		if !ok {
			return
		}
		cur = next
		chain = append(chain, cur)
	}
	delete(cur, parts[len(parts)-1])
	for i := len(parts) - 2; i >= 0; i-- {
		parent := chain[i]
		if child, ok := parent[parts[i]].(map[string]interface{}); ok && len(child) == 0 {
			delete(parent, parts[i])
			continue
		}
		break
	}
}

// A path that is itself a schema key is a leaf even when its value is an object or list.
func flattenSettings(tree map[string]interface{}) map[string]interface{} {
	out := map[string]interface{}{}
	var walk func(prefix string, m map[string]interface{})
	walk = func(prefix string, m map[string]interface{}) {
		for k, v := range m {
			key := k
			if prefix != "" {
				key = prefix + "." + k
			}
			if _, isSchema := specFor(key); isSchema {
				out[key] = v
				continue
			}
			if child, ok := v.(map[string]interface{}); ok {
				walk(key, child)
				continue
			}
			out[key] = v
		}
	}
	if tree != nil {
		walk("", tree)
	}
	return out
}

var (
	settingsBaselineMu sync.Mutex
	settingsBaseline   map[string]interface{}
)

func setSettingsBaseline(flat map[string]interface{}) {
	settingsBaselineMu.Lock()
	settingsBaseline = flat
	settingsBaselineMu.Unlock()
}

func settingsBaselineSnapshot() map[string]interface{} {
	settingsBaselineMu.Lock()
	defer settingsBaselineMu.Unlock()
	return settingsBaseline
}

func (d *daemon) watchSettingsFile() {
	if settingsBaselineSnapshot() == nil {
		setSettingsBaseline(flattenSettings(loadRyogamiTree()))
	}
	var last time.Time
	for {
		time.Sleep(settingsPollInterval)
		st, err := os.Stat(configPath())
		if err != nil {
			continue
		}
		if !st.ModTime().After(last) {
			continue
		}
		last = st.ModTime()
		d.reconcileSettingsFile()
	}
}

func (d *daemon) reconcileSettingsFile() {
	fresh := flattenSettings(loadRyogamiTree())
	changed := diffSettings(settingsBaselineSnapshot(), fresh)
	setSettingsBaseline(fresh)
	if len(changed) == 0 {
		return
	}
	d.reloadConfig()
	d.broadcast("ryogami.settings.changed", map[string]interface{}{"values": changed})
	for k, v := range changed {
		d.notifySetting(k, v)
	}
}

// A vanished key reverts to its schema default so a client drops the override.
func diffSettings(prev, fresh map[string]interface{}) map[string]interface{} {
	changed := map[string]interface{}{}
	for k, v := range fresh {
		if old, ok := prev[k]; !ok || !sameSetting(old, v) {
			changed[k] = v
		}
	}
	for k := range prev {
		if _, ok := fresh[k]; ok {
			continue
		}
		if spec, ok := specFor(k); ok {
			changed[k] = spec.Default
		} else {
			changed[k] = nil
		}
	}
	return changed
}

func sameSetting(a, b interface{}) bool { return reflect.DeepEqual(a, b) }

func settingsAtomicWrite(path string, b []byte) error {
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
