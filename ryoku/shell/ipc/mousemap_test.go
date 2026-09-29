package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"
)

// capKey renders a capabilities/key value: hex words, most-significant first,
// exactly the sysfs shape parseKeyCapabilities decodes.
func capKey(bits ...int) string {
	maxWord := 0
	for _, bit := range bits {
		if bit/64 > maxWord {
			maxWord = bit / 64
		}
	}
	words := make([]uint64, maxWord+1)
	for _, bit := range bits {
		words[bit/64] |= 1 << uint(bit%64)
	}
	parts := make([]string, 0, len(words))
	for i := maxWord; i >= 0; i-- {
		parts = append(parts, strconv.FormatUint(words[i], 16))
	}
	return strings.Join(parts, " ")
}

// addFakeInput lays out one event node: the real device dir (carrying the key
// capabilities and name) lives under realSub, and class/input/<event>/device
// symlinks to it, so EvalSymlinks reports the bus/virtual path the classifier
// keys on.
func addFakeInput(t *testing.T, sysRoot, devRoot, event, realSub, key, name string, makeNode bool) {
	t.Helper()
	realDir := filepath.Join(sysRoot, realSub)
	if err := os.MkdirAll(filepath.Join(realDir, "capabilities"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(realDir, "capabilities", "key"), []byte(key), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(realDir, "name"), []byte(name), 0o644); err != nil {
		t.Fatal(err)
	}
	eventDir := filepath.Join(sysRoot, "class", "input", event)
	if err := os.MkdirAll(eventDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(realDir, filepath.Join(eventDir, "device")); err != nil {
		t.Fatal(err)
	}
	if makeNode {
		if err := os.WriteFile(filepath.Join(devRoot, event), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func TestClassifyMouseDevices(t *testing.T) {
	root := t.TempDir()
	sysRoot := filepath.Join(root, "sys")
	devRoot := filepath.Join(root, "dev", "input")
	byIDRoot := filepath.Join(devRoot, "by-id")
	if err := os.MkdirAll(byIDRoot, 0o755); err != nil {
		t.Fatal(err)
	}

	mouseKey := capKey(272, 273, 274, 275, 276)

	// A real USB mouse with a stable by-id symlink.
	addFakeInput(t, sysRoot, devRoot, "event0", "devices/pci0000/usb1/1-1/input5", mouseKey, "Logitech G502", true)
	if err := os.Symlink(filepath.Join(devRoot, "event0"), filepath.Join(byIDRoot, "usb-Logitech_G502-event-mouse")); err != nil {
		t.Fatal(err)
	}
	// A bluetooth mouse with no by-id entry: the id falls back to the event name.
	addFakeInput(t, sysRoot, devRoot, "event6", "devices/pci0000/bluetooth/hci0/input11", capKey(272, 273), "BT Mouse", true)
	// A keyboard: no BTN_MOUSE.
	addFakeInput(t, sysRoot, devRoot, "event1", "devices/pci0000/usb1/1-2/input6", capKey(30, 44, 28, 57), "AT Keyboard", true)
	// A touchpad: BTN_TOOL_FINGER set.
	addFakeInput(t, sysRoot, devRoot, "event2", "devices/platform/i2c/input7", capKey(272, 325), "Synaptics TouchPad", true)
	// A built-in virtual mouse: realpath under the virtual bus.
	addFakeInput(t, sysRoot, devRoot, "event3", "devices/virtual/input/input8", capKey(272, 273), "Virtual core pointer", true)
	// One of our own clones by name, on a non-virtual path.
	addFakeInput(t, sysRoot, devRoot, "event5", "devices/pci0000/usb1/1-3/input10", capKey(272, 273), "Ryoku Mouse Logitech G502", true)

	got := classifyMouseDevices(sysRoot, devRoot, byIDRoot)
	if len(got) != 2 {
		t.Fatalf("expected 2 mice, got %d: %+v", len(got), got)
	}

	byID := map[string]mouseDevice{}
	for _, dev := range got {
		byID[dev.ID] = dev
	}

	logi, ok := byID["usb-Logitech_G502-event-mouse"]
	if !ok {
		t.Fatalf("logitech mouse id not resolved from by-id: %+v", got)
	}
	if logi.Name != "Logitech G502" {
		t.Errorf("name = %q, want Logitech G502", logi.Name)
	}
	if logi.Bus != "usb" {
		t.Errorf("bus = %q, want usb", logi.Bus)
	}
	if !reflect.DeepEqual(logi.Buttons, []uint16{272, 273, 274, 275, 276}) {
		t.Errorf("buttons = %v, want [272 273 274 275 276]", logi.Buttons)
	}

	bt, ok := byID["event6"]
	if !ok {
		t.Fatalf("bluetooth mouse id did not fall back to event name: %+v", got)
	}
	if bt.Bus != "bluetooth" {
		t.Errorf("bus = %q, want bluetooth", bt.Bus)
	}
}

func TestMouseMapPatchPersistRoundTrip(t *testing.T) {
	path := filepath.Join(t.TempDir(), "mousemap.json")

	maps := map[string]map[string]mouseTarget{}
	maps = patchMouseMaps(maps, "dev1", 275, &mouseTarget{Kind: "chord", Keys: []string{"ctrl", "c"}})
	maps = patchMouseMaps(maps, "dev1", 276, &mouseTarget{Kind: "button", Button: 273})
	maps = patchMouseMaps(maps, "dev1", 277, &mouseTarget{Kind: "disabled"})

	if err := writeMouseSettings(path, mouseSettings{Maps: maps}); err != nil {
		t.Fatal(err)
	}
	loaded := loadMouseSettings(path)
	if !reflect.DeepEqual(loaded.Maps, maps) {
		t.Fatalf("round trip mismatch:\n got %+v\nwant %+v", loaded.Maps, maps)
	}

	// Removing one button leaves the rest.
	trimmed := patchMouseMaps(loaded.Maps, "dev1", 276, nil)
	if _, present := trimmed["dev1"]["276"]; present {
		t.Fatalf("button 276 not removed: %+v", trimmed)
	}
	if len(trimmed["dev1"]) != 2 {
		t.Fatalf("expected 2 remaining buttons, got %+v", trimmed["dev1"])
	}

	// Removing the last button drops the device entirely.
	trimmed = patchMouseMaps(trimmed, "dev1", 275, nil)
	trimmed = patchMouseMaps(trimmed, "dev1", 277, nil)
	if _, present := trimmed["dev1"]; present {
		t.Fatalf("empty device should be dropped: %+v", trimmed)
	}
}

func TestMouseSubstitution(t *testing.T) {
	sub, err := newMouseSubstitutor(map[uint16]mouseTarget{
		275: {Kind: "chord", Keys: []string{"ctrl", "c"}},
		276: {Kind: "button", Button: 273},
		277: {Kind: "disabled"},
	})
	if err != nil {
		t.Fatal(err)
	}

	// Chord press emits key-downs in order; release unwinds in reverse.
	out, consumed := sub.apply(evKey, 275, 1)
	if !consumed {
		t.Fatal("chord press not consumed")
	}
	if !reflect.DeepEqual(out, []synthEvent{{evKey, 29, 1}, {evKey, 46, 1}}) {
		t.Fatalf("chord down = %v, want ctrl+c down (29,46)", out)
	}
	out, consumed = sub.apply(evKey, 275, 0)
	if !consumed {
		t.Fatal("chord release not consumed")
	}
	if !reflect.DeepEqual(out, []synthEvent{{evKey, 46, 0}, {evKey, 29, 0}}) {
		t.Fatalf("chord up = %v, want reverse (46,29)", out)
	}

	// Button remap forwards a single BTN_ press/release.
	out, consumed = sub.apply(evKey, 276, 1)
	if !consumed || !reflect.DeepEqual(out, []synthEvent{{evKey, 273, 1}}) {
		t.Fatalf("button down = %v consumed=%v", out, consumed)
	}
	out, consumed = sub.apply(evKey, 276, 0)
	if !consumed || !reflect.DeepEqual(out, []synthEvent{{evKey, 273, 0}}) {
		t.Fatalf("button up = %v consumed=%v", out, consumed)
	}

	// Disabled swallows both edges.
	if out, consumed := sub.apply(evKey, 277, 1); !consumed || len(out) != 0 {
		t.Fatalf("disabled press = %v consumed=%v", out, consumed)
	}
	if out, consumed := sub.apply(evKey, 277, 0); !consumed || len(out) != 0 {
		t.Fatalf("disabled release = %v consumed=%v", out, consumed)
	}

	// Unmapped button and non-EV_KEY events pass through untouched.
	if out, consumed := sub.apply(evKey, 280, 1); consumed || out != nil {
		t.Fatalf("unmapped button should pass through, got %v consumed=%v", out, consumed)
	}
	if out, consumed := sub.apply(evRel, relX, 5); consumed || out != nil {
		t.Fatalf("pointer motion should pass through, got %v consumed=%v", out, consumed)
	}
}

func TestMouseChordRejectsUnknownToken(t *testing.T) {
	if err := validateTarget(mouseTarget{Kind: "chord", Keys: []string{"ctrl", "notakey"}}); err == nil {
		t.Fatal("expected unknown chord token to be rejected")
	}
	if _, err := newMouseSubstitutor(map[uint16]mouseTarget{
		275: {Kind: "chord", Keys: []string{"ctrl", "notakey"}},
	}); err == nil {
		t.Fatal("expected substitutor build to reject unknown chord token")
	}
	if err := validateTarget(mouseTarget{Kind: "weird"}); err == nil {
		t.Fatal("expected unknown kind to be rejected")
	}
	if err := validateTarget(mouseTarget{Kind: "button", Button: 0}); err == nil {
		t.Fatal("expected button target without a code to be rejected")
	}
}
