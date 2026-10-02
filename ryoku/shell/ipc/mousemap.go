package main

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unsafe"

	"golang.org/x/sys/unix"
)

// The mouse remapper seizes each physical mouse (EVIOCGRAB), publishes a uinput
// clone that carries every event straight through, and rewrites only the mapped
// buttons into a key/button sequence. Grabbing at the evdev layer means the
// rewrite lands in every app, the lockscreen, and under any window manager, with
// nothing here that has to know which one is running. A mouse with no mappings is
// left ungrabbed so it stays byte-for-byte transparent.

const (
	// struct input_event on 64-bit: two 64-bit times (sec, usec), then u16 type,
	// u16 code, i32 value. Native endian, the kernel fills timestamps on write.
	mouseEventSize = 24

	// evKey (EV_KEY = 1) is declared in keypress.go; reuse it.
	evSyn = 0x00
	evRel = 0x02
	evMsc = 0x04

	relX      = 0x00
	relY      = 0x01
	relHWheel = 0x06
	relDial   = 0x07
	relWheel  = 0x08
	mscScan   = 0x04

	btnMouseFirst = 272 // BTN_MOUSE — the lowest button code a mouse claims
	btnMouseLast  = 285 // BTN_TASK — top of the range the Hub can bind
	btnToolFinger = 325 // BTN_TOOL_FINGER — set only by touchpads

	busUSB = 0x03 // BUS_USB, the bustype the clone advertises

	// EVIOCGRAB is Linux _IOW('E', 0x90, int): seize the device so its events
	// reach only this reader. Derived like keypress.go's EVIOCSCLOCKID
	// (_IOW('E', 0xa0, int) = 0x400445a0); 'E' is 0x45, sizeof(int) is 4.
	evIoCGrab = 0x40044590

	// uinput control ioctls (linux/uinput.h). 'U' is 0x55; _IO('U', n) for the
	// no-argument pair, _IOW('U', n, T) for the setters.
	uiDevCreate  = 0x5501     // _IO('U', 1)
	uiDevDestroy = 0x5502     // _IO('U', 2)
	uiDevSetup   = 0x405c5503 // _IOW('U', 3, struct uinput_setup), sizeof 92 (0x5c)
	uiSetEvBit   = 0x40045564 // _IOW('U', 100, int)
	uiSetKeyBit  = 0x40045565 // _IOW('U', 101, int)
	uiSetRelBit  = 0x40045566 // _IOW('U', 102, int)
	uiSetAbsBit  = 0x40045567 // _IOW('U', 103, int) — declared for parity, unused
	uiSetMscBit  = 0x40045568 // _IOW('U', 104, int)

	// struct uinput_setup: struct input_id id (8), char name[80], u32
	// ff_effects_max, padded to 92. The kernel ABI orders id before name.
	uinputSetupSize = 92
	uinputNameSize  = 80
)

// chordKeyCodes maps a chord token to its Linux KEY_* code — the same stable
// evdev ABI keypress.go's inputKeys encodes, left-hand modifier variants. The
// Hub emits these tokens; an unknown one rejects the map rather than binding a
// silent no-op.
var chordKeyCodes = map[string]uint16{
	"a": 30, "b": 48, "c": 46, "d": 32, "e": 18, "f": 33, "g": 34, "h": 35, "i": 23,
	"j": 36, "k": 37, "l": 38, "m": 50, "n": 49, "o": 24, "p": 25, "q": 16, "r": 19,
	"s": 31, "t": 20, "u": 22, "v": 47, "w": 17, "x": 45, "y": 21, "z": 44,

	"1": 2, "2": 3, "3": 4, "4": 5, "5": 6, "6": 7, "7": 8, "8": 9, "9": 10, "0": 11,

	"f1": 59, "f2": 60, "f3": 61, "f4": 62, "f5": 63, "f6": 64,
	"f7": 65, "f8": 66, "f9": 67, "f10": 68, "f11": 87, "f12": 88,

	"enter": 28, "esc": 1, "space": 57, "tab": 15, "backspace": 14,
	"left": 105, "right": 106, "up": 103, "down": 108,
	"home": 102, "end": 107, "pgup": 104, "pgdn": 109,
	"minus": 12, "equal": 13, "bracketleft": 26, "bracketright": 27,
	"comma": 51, "period": 52, "slash": 53, "semicolon": 39,
	"apostrophe": 40, "backslash": 43, "grave": 41,

	"ctrl": 29, "shift": 42, "alt": 56, "super": 125,
}

// chordCodes resolves the token sequence a chord binds to, in press order. An
// unrecognised token is an error so a bad map never silently drops keys.
func chordCodes(keys []string) ([]uint16, error) {
	out := make([]uint16, 0, len(keys))
	for _, key := range keys {
		code, ok := chordKeyCodes[strings.ToLower(strings.TrimSpace(key))]
		if !ok {
			return nil, fmt.Errorf("unknown chord key %q", key)
		}
		out = append(out, code)
	}
	return out, nil
}

// mouseTarget is one button's rewrite: a key chord, another button, or nothing.
type mouseTarget struct {
	Kind   string   `json:"kind"`
	Keys   []string `json:"keys,omitempty"`
	Button uint16   `json:"button,omitempty"`
}

// validateTarget rejects a mapping the reader could not honour, so mouse.map
// fails loudly instead of arming a reader that will misbehave.
func validateTarget(t mouseTarget) error {
	switch t.Kind {
	case "disabled":
		return nil
	case "button":
		if t.Button == 0 {
			return fmt.Errorf("button target requires a button code")
		}
		return nil
	case "chord":
		if len(t.Keys) == 0 {
			return fmt.Errorf("chord target requires at least one key")
		}
		_, err := chordCodes(t.Keys)
		return err
	default:
		return fmt.Errorf("unknown target kind %q", t.Kind)
	}
}

// synthEvent is one decoded event the reader forwards to the clone.
type synthEvent struct {
	etype uint16
	code  uint16
	value int32
}

// downUp turns a target into the events to emit on press and on release. The
// release list is the press list reversed, so a chord unwinds outermost-last.
func (t mouseTarget) downUp() (down, up []synthEvent, err error) {
	switch t.Kind {
	case "disabled":
		return nil, nil, nil
	case "button":
		return []synthEvent{{evKey, t.Button, 1}}, []synthEvent{{evKey, t.Button, 0}}, nil
	case "chord":
		codes, err := chordCodes(t.Keys)
		if err != nil {
			return nil, nil, err
		}
		down = make([]synthEvent, 0, len(codes))
		up = make([]synthEvent, 0, len(codes))
		for _, c := range codes {
			down = append(down, synthEvent{evKey, c, 1})
		}
		for i := len(codes) - 1; i >= 0; i-- {
			up = append(up, synthEvent{evKey, codes[i], 0})
		}
		return down, up, nil
	default:
		return nil, nil, fmt.Errorf("unknown target kind %q", t.Kind)
	}
}

type mouseBinding struct {
	down []synthEvent
	up   []synthEvent
}

// mouseSubstitutor is the pure rewrite core: it turns a source EV_KEY on a mapped
// button into the target's events and reports whether the source event was
// consumed. It tracks the outstanding press per button so a release unwinds the
// exact down sequence even if pointer motion arrives in between.
type mouseSubstitutor struct {
	bindings map[uint16]mouseBinding
	held     map[uint16][]synthEvent
}

func newMouseSubstitutor(mapping map[uint16]mouseTarget) (*mouseSubstitutor, error) {
	s := &mouseSubstitutor{
		bindings: make(map[uint16]mouseBinding, len(mapping)),
		held:     make(map[uint16][]synthEvent),
	}
	for code, target := range mapping {
		down, up, err := target.downUp()
		if err != nil {
			return nil, err
		}
		s.bindings[code] = mouseBinding{down: down, up: up}
	}
	return s, nil
}

// apply returns the events to emit for one decoded source event and whether the
// source event was consumed (dropped from pass-through). Unmapped codes and
// every non-EV_KEY event pass through untouched.
func (s *mouseSubstitutor) apply(etype, code uint16, value int32) (out []synthEvent, consumed bool) {
	if etype != evKey {
		return nil, false
	}
	binding, ok := s.bindings[code]
	if !ok {
		return nil, false
	}
	switch value {
	case 1:
		s.held[code] = binding.up
		return binding.down, true
	case 0:
		up, held := s.held[code]
		delete(s.held, code)
		if !held {
			return nil, true
		}
		return up, true
	default:
		// Autorepeat and any other value: swallow, mouse buttons never repeat.
		return nil, true
	}
}

// mouseDevice is one enumerated physical mouse. node and sysDevice stay internal:
// the Hub sees only the wire fields.
type mouseDevice struct {
	ID      string   `json:"id"`
	Name    string   `json:"name"`
	Bus     string   `json:"bus"`
	Buttons []uint16 `json:"buttons"`

	node      string // /dev/input/eventN, opened by the reader
	sysDevice string // realpath of the sysfs device dir, mined for vendor/product
}

type mousePressed struct {
	Device string `json:"device"`
	Button uint16 `json:"button"`
}

// mouseFrame is the one line published on every state change. pressed rides only
// on the frame that answers a capture.
type mouseFrame struct {
	Devices []mouseDevice                     `json:"devices"`
	Maps    map[string]map[string]mouseTarget `json:"maps"`
	Pressed *mousePressed                     `json:"pressed,omitempty"`
}

// mouseSettings is the on-disk store, deviceKey -> buttonCode(string) -> target.
type mouseSettings struct {
	Maps map[string]map[string]mouseTarget `json:"maps"`
}

func mouseSettingsPath() string {
	dir := ryokuConfigDir()
	if dir == "" {
		return ""
	}
	return filepath.Join(dir, "mousemap.json")
}

// loadMouseSettings reads the store, dropping any entry the reader could not
// honour so a hand-edited or stale file can never wedge the daemon.
func loadMouseSettings(path string) mouseSettings {
	settings := mouseSettings{Maps: map[string]map[string]mouseTarget{}}
	body, err := os.ReadFile(path)
	if err != nil {
		return settings
	}
	var saved mouseSettings
	if json.Unmarshal(body, &saved) != nil {
		return settings
	}
	for device, buttons := range saved.Maps {
		clean := map[string]mouseTarget{}
		for code, target := range buttons {
			if _, err := strconv.ParseUint(code, 10, 16); err != nil {
				continue
			}
			if validateTarget(target) != nil {
				continue
			}
			clean[code] = target
		}
		if len(clean) > 0 {
			settings.Maps[device] = clean
		}
	}
	return settings
}

// writeMouseSettings persists atomically (temp + rename) so a crash mid-write
// never leaves a half-written map.
func writeMouseSettings(path string, settings mouseSettings) error {
	if path == "" {
		return fmt.Errorf("mouse settings path is unavailable")
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	body, err := json.Marshal(settings)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, body, 0o600); err != nil {
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return nil
}

// cloneMouseMaps deep-copies the store so a patch never mutates a map a reader
// still holds.
func cloneMouseMaps(maps map[string]map[string]mouseTarget) map[string]map[string]mouseTarget {
	out := make(map[string]map[string]mouseTarget, len(maps))
	for device, buttons := range maps {
		copied := make(map[string]mouseTarget, len(buttons))
		for code, target := range buttons {
			copied[code] = target
		}
		out[device] = copied
	}
	return out
}

// patchMouseMaps applies one edit: a nil target removes the button, and a device
// left with no buttons drops out entirely.
func patchMouseMaps(maps map[string]map[string]mouseTarget, device string, button uint16, target *mouseTarget) map[string]map[string]mouseTarget {
	out := cloneMouseMaps(maps)
	key := strconv.FormatUint(uint64(button), 10)
	if target == nil {
		if buttons, ok := out[device]; ok {
			delete(buttons, key)
			if len(buttons) == 0 {
				delete(out, device)
			}
		}
		return out
	}
	buttons := out[device]
	if buttons == nil {
		buttons = map[string]mouseTarget{}
		out[device] = buttons
	}
	buttons[key] = *target
	return out
}

// deviceMapCodes converts one device's string-keyed map into the uint16-keyed
// form the substitutor and clone want.
func deviceMapCodes(buttons map[string]mouseTarget) map[uint16]mouseTarget {
	out := make(map[uint16]mouseTarget, len(buttons))
	for code, target := range buttons {
		parsed, err := strconv.ParseUint(code, 10, 16)
		if err != nil {
			continue
		}
		out[uint16(parsed)] = target
	}
	return out
}

// mapSig is a stable fingerprint of one device's map, used to notice when an edit
// means a reader must be re-armed. json sorts map keys, so equal maps compare
// equal.
func mapSig(buttons map[string]mouseTarget) string {
	if len(buttons) == 0 {
		return ""
	}
	body, _ := json.Marshal(buttons)
	return string(body)
}

func mouseDevicesEqual(a, b []mouseDevice) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i].ID != b[i].ID || a[i].Name != b[i].Name || a[i].Bus != b[i].Bus {
			return false
		}
		if len(a[i].Buttons) != len(b[i].Buttons) {
			return false
		}
		for j := range a[i].Buttons {
			if a[i].Buttons[j] != b[i].Buttons[j] {
				return false
			}
		}
	}
	return true
}

// classifyMouseDevices walks the input class and returns the physical mice: a
// device with BTN_MOUSE, no BTN_TOOL_FINGER (touchpads), not backed by the
// virtual bus (built-in virtual mice and our own clones), and not one of our
// clones by name.
func classifyMouseDevices(sysRoot, devRoot, byIDRoot string) []mouseDevice {
	inputDir := filepath.Join(sysRoot, "class", "input")
	entries, err := os.ReadDir(inputDir)
	if err != nil {
		return []mouseDevice{}
	}
	virtualPrefix := filepath.Join(sysRoot, "devices", "virtual", "input")
	out := []mouseDevice{}
	for _, entry := range entries {
		name := entry.Name()
		if !strings.HasPrefix(name, "event") {
			continue
		}
		base := filepath.Join(inputDir, name)
		capRaw, err := os.ReadFile(filepath.Join(base, "device", "capabilities", "key"))
		if err != nil {
			continue
		}
		bits, ok := parseKeyCapabilities(string(capRaw))
		if !ok {
			continue
		}
		if bits.Bit(btnMouseFirst) == 0 || bits.Bit(btnToolFinger) != 0 {
			continue
		}
		real, err := filepath.EvalSymlinks(filepath.Join(base, "device"))
		if err != nil {
			real = filepath.Join(base, "device")
		}
		if strings.HasPrefix(real, virtualPrefix) {
			continue
		}
		devName := ""
		if raw, err := os.ReadFile(filepath.Join(base, "device", "name")); err == nil {
			devName = strings.TrimSpace(string(raw))
		}
		if strings.HasPrefix(devName, "Ryoku Mouse") {
			continue
		}
		node := filepath.Join(devRoot, name)
		if _, err := os.Stat(node); err != nil {
			continue
		}
		buttons := []uint16{}
		for code := btnMouseFirst; code <= btnMouseLast; code++ {
			if bits.Bit(code) != 0 {
				buttons = append(buttons, uint16(code))
			}
		}
		out = append(out, mouseDevice{
			ID:        mouseDeviceID(byIDRoot, node),
			Name:      devName,
			Bus:       mouseBus(real),
			Buttons:   buttons,
			node:      node,
			sysDevice: real,
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// mouseDeviceID prefers the by-id symlink resolving to this event node, which
// survives a replug; the raw eventN name (which does not) is the fallback.
func mouseDeviceID(byIDRoot, node string) string {
	target, err := filepath.EvalSymlinks(node)
	if err != nil {
		target = node
	}
	entries, err := os.ReadDir(byIDRoot)
	if err == nil {
		for _, entry := range entries {
			link := filepath.Join(byIDRoot, entry.Name())
			resolved, err := filepath.EvalSymlinks(link)
			if err != nil {
				continue
			}
			if resolved == target {
				return entry.Name()
			}
		}
	}
	return filepath.Base(node)
}

func mouseBus(realpath string) string {
	switch {
	case strings.Contains(realpath, "/usb"):
		return "usb"
	case strings.Contains(realpath, "/bluetooth"):
		return "bluetooth"
	case strings.Contains(realpath, "/serio"):
		return "ps2"
	default:
		return "other"
	}
}

func decodeInputEvent(raw []byte) (etype, code uint16, value int32) {
	etype = binary.NativeEndian.Uint16(raw[16:18])
	code = binary.NativeEndian.Uint16(raw[18:20])
	value = int32(binary.NativeEndian.Uint32(raw[20:24]))
	return
}

func writeInputEvent(w io.Writer, event synthEvent) error {
	var raw [mouseEventSize]byte
	binary.NativeEndian.PutUint16(raw[16:18], event.etype)
	binary.NativeEndian.PutUint16(raw[18:20], event.code)
	binary.NativeEndian.PutUint32(raw[20:24], uint32(event.value))
	_, err := w.Write(raw[:])
	return err
}

func openMouseUinput() (*os.File, error) {
	return os.OpenFile("/dev/uinput", os.O_WRONLY|unix.O_NONBLOCK, 0)
}

func ioctlPointer(fd, req uintptr, arg unsafe.Pointer) error {
	if _, _, errno := unix.Syscall(unix.SYS_IOCTL, fd, req, uintptr(arg)); errno != 0 {
		return errno
	}
	return nil
}

// buildUinputSetup lays out struct uinput_setup: id first, then the NUL-padded
// name, then ff_effects_max (left zero).
func buildUinputSetup(name string, vendor, product uint16) [uinputSetupSize]byte {
	var buf [uinputSetupSize]byte
	binary.NativeEndian.PutUint16(buf[0:2], busUSB)
	binary.NativeEndian.PutUint16(buf[2:4], vendor)
	binary.NativeEndian.PutUint16(buf[4:6], product)
	binary.NativeEndian.PutUint16(buf[6:8], 1)
	label := []byte(name)
	if len(label) > uinputNameSize-1 {
		label = label[:uinputNameSize-1]
	}
	copy(buf[8:8+len(label)], label)
	return buf
}

// readSysHex reads a sysfs hex attribute (no 0x prefix, e.g. idVendor).
func readSysHex(path string) (uint16, bool) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return 0, false
	}
	value, err := strconv.ParseUint(strings.TrimSpace(string(raw)), 16, 16)
	if err != nil {
		return 0, false
	}
	return uint16(value), true
}

// sysMouseIDs walks up from the device dir for the USB idVendor/idProduct pair so
// the clone can carry the source's identity; 0x0001 stands in when unreadable.
func sysMouseIDs(dir string) (uint16, uint16) {
	for i := 0; i < 6 && dir != "" && dir != "/" && dir != "."; i++ {
		vendor, vok := readSysHex(filepath.Join(dir, "idVendor"))
		product, pok := readSysHex(filepath.Join(dir, "idProduct"))
		if vok && pok {
			return vendor, product
		}
		dir = filepath.Dir(dir)
	}
	return 0x0001, 0x0001
}

const (
	cmdState = iota
	cmdMap
	cmdCapture
)

type mouseCmd struct {
	kind    int
	device  string
	button  uint16
	target  *mouseTarget
	timeout time.Duration
	reply   chan mouseCmdReply
}

type mouseCmdReply struct {
	frame mouseFrame
	err   error
}

type capturePress struct {
	device string
	button uint16
}

type mouseReader struct {
	cancel context.CancelFunc
	sig    string
}

type mouseMapManager struct {
	topic        *stateTopic
	sysRoot      string
	devRoot      string
	byIDRoot     string
	settingsPath string
	openUinput   func() (*os.File, error)
	classify     func(string, string, string) []mouseDevice

	commands chan mouseCmd
	done     chan struct{}

	mu     sync.Mutex
	cancel context.CancelFunc

	// curMaps is owned by the run loop once started; newMouseMapManager seeds it.
	curMaps map[string]map[string]mouseTarget
}

func newMouseMapManager(sysRoot, devRoot, byIDRoot, settingsPath string, openUinput func() (*os.File, error)) *mouseMapManager {
	settings := loadMouseSettings(settingsPath)
	return &mouseMapManager{
		sysRoot:      sysRoot,
		devRoot:      devRoot,
		byIDRoot:     byIDRoot,
		settingsPath: settingsPath,
		openUinput:   openUinput,
		classify:     classifyMouseDevices,
		commands:     make(chan mouseCmd),
		done:         make(chan struct{}),
		curMaps:      settings.Maps,
	}
}

func (m *mouseMapManager) start() {
	m.mu.Lock()
	if m.cancel != nil {
		m.mu.Unlock()
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	m.cancel = cancel
	m.mu.Unlock()
	go m.run(ctx)
}

// stop tears down every reader before the process is replaced, so the grabs and
// clones are gone before a fresh daemon tries to seize the same devices.
func (m *mouseMapManager) stop() {
	m.mu.Lock()
	cancel := m.cancel
	m.cancel = nil
	m.mu.Unlock()
	if cancel != nil {
		cancel()
	}
}

func (m *mouseMapManager) currentFrame(devices []mouseDevice, pressed *mousePressed) mouseFrame {
	if devices == nil {
		devices = []mouseDevice{}
	}
	maps := m.curMaps
	if maps == nil {
		maps = map[string]map[string]mouseTarget{}
	}
	return mouseFrame{Devices: devices, Maps: maps, Pressed: pressed}
}

// run owns the readers, the current map, and the capture waiter. Every mutation
// flows through here, so nothing needs a lock and the published frames stay in
// order.
func (m *mouseMapManager) run(ctx context.Context) {
	defer close(m.done)

	events := make(chan capturePress, 64)
	deaths := make(chan string, 8)
	readers := map[string]*mouseReader{}
	var curDevices []mouseDevice

	defer func() {
		for _, reader := range readers {
			reader.cancel()
		}
	}()

	captureArmed := false
	var captureTimer *time.Timer
	var captureFire <-chan time.Time
	disarm := func() {
		captureArmed = false
		captureFire = nil
		if captureTimer != nil {
			captureTimer.Stop()
		}
	}

	reconcile := func() bool {
		devices := m.classify(m.sysRoot, m.devRoot, m.byIDRoot)
		present := make(map[string]bool, len(devices))
		for _, dev := range devices {
			present[dev.ID] = true
			sig := mapSig(m.curMaps[dev.ID])
			if reader, ok := readers[dev.ID]; ok {
				if reader.sig == sig {
					continue
				}
				reader.cancel()
				delete(readers, dev.ID)
			}
			grab := len(m.curMaps[dev.ID]) > 0
			readerCtx, cancel := context.WithCancel(ctx)
			readers[dev.ID] = &mouseReader{cancel: cancel, sig: sig}
			go m.readDevice(readerCtx, dev, grab, deviceMapCodes(m.curMaps[dev.ID]), events, deaths)
		}
		for id, reader := range readers {
			if !present[id] {
				reader.cancel()
				delete(readers, id)
			}
		}
		changed := !mouseDevicesEqual(curDevices, devices)
		curDevices = devices
		return changed
	}

	publish := func(pressed *mousePressed) {
		if m.topic == nil {
			return
		}
		body, err := json.Marshal(m.currentFrame(curDevices, pressed))
		if err == nil {
			m.topic.publish(body)
		}
	}

	reconcile()
	publish(nil)

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if reconcile() {
				publish(nil)
			}
		case id := <-deaths:
			if reader, ok := readers[id]; ok {
				reader.cancel()
				delete(readers, id)
			}
			// Do not immediately reconcile a failed reader. If an event node is
			// still present but unreadable, recreating it here produces a tight
			// open/fail/rescan loop across all of /sys/class/input. The regular
			// device ticker retries it without turning one bad HID into idle CPU.
		case press := <-events:
			if captureArmed {
				disarm()
				publish(&mousePressed{Device: press.device, Button: press.button})
			}
		case <-captureFire:
			if captureArmed {
				disarm()
				publish(&mousePressed{})
			}
		case cmd := <-m.commands:
			switch cmd.kind {
			case cmdState:
				reconcile()
				cmd.reply <- mouseCmdReply{frame: m.currentFrame(curDevices, nil)}
			case cmdMap:
				next := patchMouseMaps(m.curMaps, cmd.device, cmd.button, cmd.target)
				if err := writeMouseSettings(m.settingsPath, mouseSettings{Maps: next}); err != nil {
					cmd.reply <- mouseCmdReply{err: err}
					break
				}
				m.curMaps = next
				reconcile()
				publish(nil)
				cmd.reply <- mouseCmdReply{frame: m.currentFrame(curDevices, nil)}
			case cmdCapture:
				captureArmed = true
				if captureTimer == nil {
					captureTimer = time.NewTimer(cmd.timeout)
				} else {
					if !captureTimer.Stop() {
						select {
						case <-captureTimer.C:
						default:
						}
					}
					captureTimer.Reset(cmd.timeout)
				}
				captureFire = captureTimer.C
				cmd.reply <- mouseCmdReply{}
			}
		}
	}
}

// readDevice reads one mouse. A grabbed device forwards every event to its clone
// and rewrites mapped buttons; an ungrabbed device is a transparent observer that
// exists only so a capture can see its presses. Either way, a button press feeds
// the capture waiter.
func (m *mouseMapManager) readDevice(ctx context.Context, dev mouseDevice, grab bool, codes map[uint16]mouseTarget, events chan<- capturePress, deaths chan<- string) {
	src, err := os.Open(dev.node)
	if err != nil {
		m.signalDeath(ctx, deaths, dev.ID)
		return
	}
	defer src.Close()

	// Poll with a short timeout rather than blocking in read: an evdev fd is a
	// character device, so Go treats it as non-pollable and a Close from the
	// cancel goroutine does not break a blocked read. Without this, clearing a
	// mapping left the source grabbed and its clone alive until the next mouse
	// event. A POLLIN on evdev always means at least one whole event is
	// buffered, so the read below cannot block.
	raw := make([]byte, mouseEventSize)
	pfd := []unix.PollFd{{Fd: int32(src.Fd()), Events: unix.POLLIN}}

	var clone *os.File
	var sub *mouseSubstitutor
	if grab {
		if err := unix.IoctlSetInt(int(src.Fd()), evIoCGrab, 1); err != nil {
			m.signalDeath(ctx, deaths, dev.ID)
			return
		}
		sub, err = newMouseSubstitutor(codes)
		if err != nil {
			return
		}
		clone, err = m.makeClone(dev)
		if err != nil {
			return
		}
		defer m.destroyClone(clone)
	}

	for {
		if ctx.Err() != nil {
			return
		}
		n, err := unix.Poll(pfd, 200)
		if err != nil {
			if err == unix.EINTR {
				continue
			}
			m.signalDeath(ctx, deaths, dev.ID)
			return
		}
		if n == 0 {
			continue
		}
		if pfd[0].Revents&(unix.POLLERR|unix.POLLHUP|unix.POLLNVAL) != 0 {
			m.signalDeath(ctx, deaths, dev.ID)
			return
		}
		if _, err := io.ReadFull(src, raw); err != nil {
			m.signalDeath(ctx, deaths, dev.ID)
			return
		}
		etype, code, value := decodeInputEvent(raw)
		if etype == evKey && value == 1 && code >= btnMouseFirst && code <= btnMouseLast {
			select {
			case events <- capturePress{device: dev.ID, button: code}:
			case <-ctx.Done():
				return
			}
		}
		if !grab {
			continue
		}
		if out, consumed := sub.apply(etype, code, value); consumed {
			for _, event := range out {
				if writeInputEvent(clone, event) != nil {
					return
				}
			}
			continue
		}
		if _, err := clone.Write(raw); err != nil {
			return
		}
	}
}

// signalDeath tells the run loop a reader died from a read error (an unplug) so
// it republishes at once. A cancelled context is an orderly stop, not a death.
func (m *mouseMapManager) signalDeath(ctx context.Context, deaths chan<- string, id string) {
	if ctx.Err() != nil {
		return
	}
	select {
	case deaths <- id:
	case <-ctx.Done():
	}
}

// makeClone builds the uinput passthrough: EV_KEY for every button the source
// carries plus the whole chord table (so any binding works), the relative axes a
// mouse uses, MSC_SCAN, and EV_SYN.
func (m *mouseMapManager) makeClone(dev mouseDevice) (*os.File, error) {
	ui, err := m.openUinput()
	if err != nil {
		return nil, err
	}
	fd := int(ui.Fd())
	fail := func(err error) (*os.File, error) {
		_ = ui.Close()
		return nil, err
	}

	if err := unix.IoctlSetInt(fd, uiSetEvBit, evKey); err != nil {
		return fail(err)
	}
	keyset := map[uint16]bool{}
	for _, button := range dev.Buttons {
		keyset[button] = true
	}
	for _, code := range chordKeyCodes {
		keyset[code] = true
	}
	for code := range keyset {
		if err := unix.IoctlSetInt(fd, uiSetKeyBit, int(code)); err != nil {
			return fail(err)
		}
	}
	if err := unix.IoctlSetInt(fd, uiSetEvBit, evRel); err != nil {
		return fail(err)
	}
	for _, axis := range []int{relX, relY, relHWheel, relWheel, relDial} {
		if err := unix.IoctlSetInt(fd, uiSetRelBit, axis); err != nil {
			return fail(err)
		}
	}
	if err := unix.IoctlSetInt(fd, uiSetEvBit, evMsc); err != nil {
		return fail(err)
	}
	if err := unix.IoctlSetInt(fd, uiSetMscBit, mscScan); err != nil {
		return fail(err)
	}
	if err := unix.IoctlSetInt(fd, uiSetEvBit, evSyn); err != nil {
		return fail(err)
	}

	vendor, product := sysMouseIDs(dev.sysDevice)
	setup := buildUinputSetup("Ryoku Mouse "+dev.Name, vendor, product)
	if err := ioctlPointer(uintptr(fd), uiDevSetup, unsafe.Pointer(&setup[0])); err != nil {
		return fail(err)
	}
	if err := unix.IoctlSetInt(fd, uiDevCreate, 0); err != nil {
		return fail(err)
	}
	return ui, nil
}

func (m *mouseMapManager) destroyClone(clone *os.File) {
	if clone == nil {
		return
	}
	_ = unix.IoctlSetInt(int(clone.Fd()), uiDevDestroy, 0)
	_ = clone.Close()
}

func (m *mouseMapManager) state() (any, error) {
	reply := make(chan mouseCmdReply, 1)
	select {
	case m.commands <- mouseCmd{kind: cmdState, reply: reply}:
	case <-m.done:
		return nil, fmt.Errorf("mouse remapper is not running")
	}
	select {
	case result := <-reply:
		return result.frame, result.err
	case <-m.done:
		return nil, fmt.Errorf("mouse remapper is not running")
	}
}

func (m *mouseMapManager) mapButton(raw json.RawMessage) (any, error) {
	var args struct {
		Device string       `json:"device"`
		Button uint16       `json:"button"`
		Target *mouseTarget `json:"target"`
	}
	if err := json.Unmarshal(raw, &args); err != nil {
		return nil, err
	}
	if args.Device == "" {
		return nil, fmt.Errorf("device is required")
	}
	if args.Button == 0 {
		return nil, fmt.Errorf("button is required")
	}
	if args.Target != nil {
		if err := validateTarget(*args.Target); err != nil {
			return nil, err
		}
	}
	reply := make(chan mouseCmdReply, 1)
	select {
	case m.commands <- mouseCmd{kind: cmdMap, device: args.Device, button: args.Button, target: args.Target, reply: reply}:
	case <-m.done:
		return nil, fmt.Errorf("mouse remapper is not running")
	}
	select {
	case result := <-reply:
		return result.frame, result.err
	case <-m.done:
		return nil, fmt.Errorf("mouse remapper is not running")
	}
}

func (m *mouseMapManager) capture(raw json.RawMessage) (any, error) {
	var args struct {
		TimeoutMs int `json:"timeoutMs"`
	}
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &args); err != nil {
			return nil, err
		}
	}
	timeout := 5 * time.Second
	if args.TimeoutMs > 0 {
		timeout = time.Duration(args.TimeoutMs) * time.Millisecond
	}
	if timeout < 100*time.Millisecond {
		timeout = 100 * time.Millisecond
	}
	if timeout > 120*time.Second {
		timeout = 120 * time.Second
	}
	reply := make(chan mouseCmdReply, 1)
	select {
	case m.commands <- mouseCmd{kind: cmdCapture, timeout: timeout, reply: reply}:
	case <-m.done:
		return nil, fmt.Errorf("mouse remapper is not running")
	}
	select {
	case <-reply:
		return map[string]any{"armed": true}, nil
	case <-m.done:
		return nil, fmt.Errorf("mouse remapper is not running")
	}
}

func (d *daemon) startMouseMap() {
	topic := d.registerEventTopic("mouse")
	manager := newMouseMapManager("/sys", "/dev/input", "/dev/input/by-id", mouseSettingsPath(), openMouseUinput)
	manager.topic = topic
	d.mousemap = manager
	manager.start()
	d.registerCall("mouse.state", func(json.RawMessage) (any, error) {
		return d.mousemap.state()
	})
	d.registerCall("mouse.map", func(raw json.RawMessage) (any, error) {
		return d.mousemap.mapButton(raw)
	})
	d.registerCall("mouse.capture", func(raw json.RawMessage) (any, error) {
		return d.mousemap.capture(raw)
	})
}
