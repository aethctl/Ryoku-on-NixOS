package wm

import (
	"path/filepath"
	"testing"
	"time"
)

// One FN press reported by two devices must toggle once; a real second press
// a moment later must toggle again.
func TestTouchpadToggleEcho(t *testing.T) {
	dir := t.TempDir()
	old := touchpadStampPath
	touchpadStampPath = func() string { return filepath.Join(dir, "stamp") }
	t.Cleanup(func() { touchpadStampPath = old })

	t0 := time.Now()
	if TouchpadToggleIsEcho(t0) {
		t.Fatal("first press read as an echo")
	}
	if !TouchpadToggleIsEcho(t0.Add(40 * time.Millisecond)) {
		t.Fatal("the same press reported by a second device toggled again")
	}
	if TouchpadToggleIsEcho(t0.Add(2 * time.Second)) {
		t.Fatal("a real second press was swallowed")
	}
}
