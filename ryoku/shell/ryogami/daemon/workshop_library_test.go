package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func writeWEProject(t *testing.T, dir string, doc map[string]interface{}) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	b, err := json.Marshal(doc)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "project.json"), b, 0o644); err != nil {
		t.Fatal(err)
	}
}

func touch(t *testing.T, path string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestDetectSteamRoot(t *testing.T) {
	homeDir := "/home/tester"
	flatpak := filepath.Join(homeDir, ".var/app/com.valvesoftware.Steam/.local/share/Steam")

	got := detectSteamRoot(homeDir, func(p string) bool {
		return p == filepath.Join(flatpak, "steamapps")
	})
	if got != flatpak {
		t.Fatalf("flatpak root: got %q want %q", got, flatpak)
	}

	native := filepath.Join(homeDir, ".local/share/Steam")
	if got := detectSteamRoot(homeDir, func(string) bool { return false }); got != native {
		t.Fatalf("fallback root: got %q want %q", got, native)
	}

	if got := detectSteamRoot(homeDir, func(string) bool { return true }); got != native {
		t.Fatalf("native precedence: got %q want %q", got, native)
	}
}

func TestProjectDependency(t *testing.T) {
	cases := []struct {
		name    string
		doc     map[string]interface{}
		wantID  string
		wantHas bool
		wantErr bool
	}{
		{"plain", map[string]interface{}{"type": "scene"}, "", false, false},
		{"string dep", map[string]interface{}{"dependency": "100", "preset": map[string]interface{}{"a": 1}}, "100", true, false},
		{"number dep", map[string]interface{}{"dependency": float64(100), "preset": map[string]interface{}{"a": 1}}, "100", true, false},
		{"dep no preset", map[string]interface{}{"dependency": "100"}, "", false, true},
		{"preset no dep", map[string]interface{}{"preset": map[string]interface{}{"a": 1}}, "", false, true},
		{"zero dep", map[string]interface{}{"dependency": "0", "preset": map[string]interface{}{"a": 1}}, "", false, true},
		{"non-digit dep", map[string]interface{}{"dependency": "12a", "preset": map[string]interface{}{"a": 1}}, "", false, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			id, has, err := projectDependency(tc.doc)
			if (err != nil) != tc.wantErr {
				t.Fatalf("err=%v wantErr=%v", err, tc.wantErr)
			}
			if err != nil {
				return
			}
			if id != tc.wantID || has != tc.wantHas {
				t.Fatalf("got (%q,%v) want (%q,%v)", id, has, tc.wantID, tc.wantHas)
			}
		})
	}
}

func TestResolveProjectPresetChain(t *testing.T) {
	lib := t.TempDir()
	parent := filepath.Join(lib, "100")
	writeWEProject(t, parent, map[string]interface{}{
		"type":  "scene",
		"title": "Parent",
		"general": map[string]interface{}{
			"properties": map[string]interface{}{
				"tint": map[string]interface{}{"type": "color", "value": "1 1 1", "text": "Tint"},
			},
		},
	})
	touch(t, filepath.Join(parent, "scene.pkg"))

	child := filepath.Join(lib, "200")
	writeWEProject(t, child, map[string]interface{}{
		"dependency": "100",
		"preset":     map[string]interface{}{"tint": "0 0 0"},
	})

	project, err := resolveProject(child)
	if err != nil {
		t.Fatalf("resolve: %v", err)
	}
	tint, ok := project.declarations()["tint"].(map[string]interface{})
	if !ok {
		t.Fatalf("tint declaration missing: %#v", project.declarations())
	}
	if tint["value"] != "0 0 0" {
		t.Fatalf("preset override not applied: value=%v", tint["value"])
	}

	weType, err := validateProject(child)
	if err != nil || weType != "scene" {
		t.Fatalf("validate child: type=%q err=%v", weType, err)
	}
}

func TestResolveProjectMissingDependency(t *testing.T) {
	lib := t.TempDir()
	child := filepath.Join(lib, "200")
	writeWEProject(t, child, map[string]interface{}{
		"dependency": "999",
		"preset":     map[string]interface{}{"a": 1},
	})
	if _, err := resolveProject(child); err == nil {
		t.Fatal("expected error for missing dependency item")
	}
}

func TestValidateProjectTypes(t *testing.T) {
	root := t.TempDir()

	scene := filepath.Join(root, "1")
	writeWEProject(t, scene, map[string]interface{}{"type": "scene"})
	if _, err := validateProject(scene); err == nil {
		t.Fatal("scene without package should fail")
	}
	touch(t, filepath.Join(scene, "gifscene.pkg"))
	if ty, err := validateProject(scene); err != nil || ty != "scene" {
		t.Fatalf("scene: type=%q err=%v", ty, err)
	}

	video := filepath.Join(root, "2")
	writeWEProject(t, video, map[string]interface{}{"type": "video", "file": "clip.mp4"})
	if _, err := validateProject(video); err == nil {
		t.Fatal("video without file should fail")
	}
	touch(t, filepath.Join(video, "clip.mp4"))
	if ty, err := validateProject(video); err != nil || ty != "video" {
		t.Fatalf("video: type=%q err=%v", ty, err)
	}

	for _, bad := range []string{"web", "application"} {
		dir := filepath.Join(root, bad)
		writeWEProject(t, dir, map[string]interface{}{"type": bad})
		if _, err := validateProject(dir); err == nil {
			t.Fatalf("%s project should be rejected", bad)
		}
	}
}

func TestSafeItemJoin(t *testing.T) {
	root := t.TempDir()
	touch(t, filepath.Join(root, "clip.mp4"))
	if err := os.MkdirAll(filepath.Join(root, "sub"), 0o755); err != nil {
		t.Fatal(err)
	}
	touch(t, filepath.Join(root, "sub", "deep.mp4"))

	if p, ok := safeItemJoin(root, "clip.mp4"); !ok || p == "" {
		t.Fatalf("in-root join rejected: %q %v", p, ok)
	}
	if p, ok := safeItemJoin(root, "sub/deep.mp4"); !ok || p == "" {
		t.Fatalf("nested join rejected: %q %v", p, ok)
	}
	if _, ok := safeItemJoin(root, "../escape"); ok {
		t.Fatal("parent traversal accepted")
	}
	if _, ok := safeItemJoin(root, "/etc/passwd"); ok {
		t.Fatal("absolute path accepted")
	}
}

func TestValidWeID(t *testing.T) {
	for _, id := range []string{"123", "3808523371"} {
		if !validWeID(id) {
			t.Fatalf("%q should be valid", id)
		}
	}
	for _, id := range []string{"", ".", "..", "-1", "a/b", "a\\b", "x..y"} {
		if validWeID(id) {
			t.Fatalf("%q should be invalid", id)
		}
	}
}
