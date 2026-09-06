package doctor

import "testing"

func TestRyogamiWallpaperActions(t *testing.T) {
	cases := []struct {
		name                            string
		state                           ryogamiWallpaperState
		wantEnable, wantFailed, wantAww bool
	}{
		{"fresh cutover: not enabled, awww still up", ryogamiWallpaperState{enabled: false, failed: false, awwwRunning: true}, true, false, true},
		{"enabled and clean does nothing", ryogamiWallpaperState{enabled: true, failed: false, awwwRunning: false}, false, false, false},
		{"enabled but wedged clears failed", ryogamiWallpaperState{enabled: true, failed: true, awwwRunning: false}, false, true, false},
		{"enabled with stray awww stops it", ryogamiWallpaperState{enabled: true, failed: false, awwwRunning: true}, false, false, true},
		{"not enabled only enables", ryogamiWallpaperState{enabled: false, failed: false, awwwRunning: false}, true, false, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			gotEnable, gotFailed, gotAww := ryogamiWallpaperActions(c.state)
			if gotEnable != c.wantEnable || gotFailed != c.wantFailed || gotAww != c.wantAww {
				t.Fatalf("ryogamiWallpaperActions(%+v) = (enable=%v, failed=%v, stopAwww=%v), want (enable=%v, failed=%v, stopAwww=%v)",
					c.state, gotEnable, gotFailed, gotAww, c.wantEnable, c.wantFailed, c.wantAww)
			}
		})
	}
}
