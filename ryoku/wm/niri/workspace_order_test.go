package main

import "testing"

func TestWorkspaceRowsFollowOutputAndIndexNotLifetimeID(t *testing.T) {
	s := session{workspaces: []niriWorkspace{
		{ID: 2, Idx: 2, Output: "DP-1"}, {ID: 40, Idx: 1, Output: "DP-1"}, {ID: 1, Idx: 1, Output: "HDMI-A-1"},
	}}
	rows := s.workspaceFrame()
	if rows[0].ID != "40" || rows[1].ID != "2" || rows[2].ID != "1" {
		t.Fatal(rows)
	}
}
