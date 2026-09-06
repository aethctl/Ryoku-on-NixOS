package main

import "testing"

// newTestPlaylistDaemon builds a daemon with a temp-backed store and playlist
// manager, seeded with the given wallpaper keys, for pure state-machine tests.
func newTestPlaylistDaemon(t *testing.T, keys ...string) *daemon {
	t.Helper()
	tmp := t.TempDir()
	cfg := config{}
	cfg.Paths.Cache = tmp
	cfg.Paths.Wallpaper = tmp
	d := &daemon{cfg: cfg, store: openStore(tmp)}
	for _, k := range keys {
		d.store.entries[k] = Entry{Key: k, Name: k, Type: "static"}
	}
	d.playlists = newPlaylistManager(tmp, d)
	return d
}

func playlistCount(m *playlistManager, id int64) int {
	for _, l := range m.snapshot()["playlists"].([]map[string]interface{}) {
		if l["id"].(int64) == id {
			return l["count"].(int)
		}
	}
	return -1
}

func TestPlaylistCurdAndMembers(t *testing.T) {
	m := newTestPlaylistDaemon(t, "a.png", "b.png", "c.png").playlists

	id := m.create("Favourites")
	if id != 1 {
		t.Fatalf("first id = %d, want 1", id)
	}
	if !m.update(id, "dwell", "45") {
		t.Fatal("update dwell failed")
	}
	if m.findLocked(id).Dwell != 45 {
		t.Fatalf("dwell = %d, want 45", m.findLocked(id).Dwell)
	}

	// Adding members is idempotent and preserves insertion order.
	m.addMember(id, "a.png")
	m.addMember(id, "b.png")
	m.addMember(id, "c.png")
	m.addMember(id, "a.png") // duplicate ignored
	if got := playlistCount(m, id); got != 3 {
		t.Fatalf("member count = %d, want 3", got)
	}
	rows := m.members(id)
	if len(rows) != 3 || rows[0]["key"] != "a.png" || rows[2]["key"] != "c.png" {
		t.Fatalf("member order wrong: %+v", rows)
	}

	// Move "a.png" down two slots -> [b, c, a].
	m.moveMember(id, "a.png", 2)
	rows = m.members(id)
	if rows[0]["key"] != "b.png" || rows[2]["key"] != "a.png" {
		t.Fatalf("after move: %+v", rows)
	}

	m.removeMember(id, "b.png")
	if got := playlistCount(m, id); got != 2 {
		t.Fatalf("after remove count = %d, want 2", got)
	}
}

func TestPlaylistAssignToggleStop(t *testing.T) {
	d := newTestPlaylistDaemon(t, "a.png", "b.png")
	m := d.playlists
	id := m.create("Rotation")
	m.addMember(id, "a.png")
	m.addMember(id, "b.png")

	if !m.assign("DP-1", id) {
		t.Fatal("assign failed")
	}
	if got, _ := m.assignedLocked("DP-1"); got != id {
		t.Fatalf("DP-1 assigned to %d, want %d", got, id)
	}
	if _, ok := m.stops[id]; !ok {
		t.Fatal("rotation ticker not started on assign")
	}

	// toggle same id on same output turns it off.
	m.toggle("DP-1", id)
	if _, ok := m.assignedLocked("DP-1"); ok {
		t.Fatal("toggle did not unassign DP-1")
	}
	if _, ok := m.stops[id]; ok {
		t.Fatal("rotation ticker not stopped after last output removed")
	}

	// re-assign then stop clears everything.
	m.assign("DP-1", id)
	m.assign("HDMI-A-1", id)
	m.stop(id)
	if m.hasOutputsLocked(id) {
		t.Fatal("stop left assignments")
	}
	if _, ok := m.stops[id]; ok {
		t.Fatal("stop left a ticker running")
	}
}

func TestPlaylistAdvanceWraps(t *testing.T) {
	d := newTestPlaylistDaemon(t, "a.png", "b.png", "c.png")
	m := d.playlists
	id := m.create("Wrap")
	m.addMember(id, "a.png")
	m.addMember(id, "b.png")
	m.addMember(id, "c.png")

	// advance() steps position and wraps; applyKeyLocked no-ops safely here
	// because outputs.json is empty (nil outputs) and keys resolve in-store.
	for i, want := range []int64{1, 2, 0, 1} {
		m.advance(id)
		if got := m.findLocked(id).Position; got != want {
			t.Fatalf("advance %d: position = %d, want %d", i, got, want)
		}
	}
}

func TestPlaylistSmartResolvesByName(t *testing.T) {
	d := newTestPlaylistDaemon(t, "ocean-blue.png", "forest.png", "ocean-deep.png")
	m := d.playlists
	id := m.create("Ocean")
	m.update(id, "kind", "smart")
	m.update(id, "source", "ocean")
	if got := playlistCount(m, id); got != 2 {
		t.Fatalf("smart count = %d, want 2 (ocean-*)", got)
	}
}
