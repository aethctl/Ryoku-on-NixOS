package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"ryoku-cli/internal/sys"
	"testing"
)

const canonicalSidebarsJSON = `{
	"motion": "standard",
	"left": {
		"enabled": true,
		"cards": ["system", "notifications", "weather", "media", "capture", "stage"],
		"width": 1040,
		"height": 1000,
		"heightMode": "fixed",
		"maxHeight": 85,
		"position": "center",
		"pinned": false,
		"presentations": {}
	},
	"right": {
		"enabled": true,
		"cards": ["usage", "tools", "chat"],
		"width": 1040,
		"height": 1000,
		"heightMode": "fixed",
		"maxHeight": 85,
		"position": "center",
		"pinned": false,
		"presentations": {}
	}
}`

func TestMigrateSidebarRework(t *testing.T) {
	tests := []struct {
		name    string
		in      string
		want    string
		changed bool
		wantErr bool
	}{
		{
			name:    "retired leaves removed and defaults seeded",
			in:      `{"frameBars":{"version":1,"menus":{"quick-settings":{"anchor":"left","modules":["home","stage"]},"wallpaper":{"anchor":"bottom"}},"surfaces":{"stash":{"anchor":"right","panes":["stash"]},"future":{"anchor":"top"}},"dock":{"pinned":["firefox"]}},"fontScale":1.3}`,
			want:    `{"frameBars":{"version":1,"menus":{"wallpaper":{"anchor":"bottom"}},"surfaces":{"future":{"anchor":"top"}},"dock":{"pinned":["firefox"]}},"fontScale":1.3,"sidebars":` + canonicalSidebarsJSON + `}`,
			changed: true,
		},
		{
			name:    "missing frame bars seeds defaults",
			in:      `{"weatherLocation":"Oslo","fontScale":0.96}`,
			want:    `{"weatherLocation":"Oslo","fontScale":0.96,"sidebars":` + canonicalSidebarsJSON + `}`,
			changed: true,
		},
		{
			name: "legacy width moves only to Controls and empty lists survive",
			in:   `{"frameBars":{"menus":{"quick-settings":{},"theme":{"anchor":"right"}},"surfaces":{"stash":{},"system":{"anchor":"right"}}},"sidebars":{"width":512,"motion":"calm","depth":false,"push":false,"parallax":1.2,"wallpaperSlide":1.3,"left":{"enabled":false,"cards":[]},"right":{"enabled":true,"cards":[]},"extension":{"future":true}},"custom":{"nested":[1,2,3]}}`,
			want: `{"frameBars":{"menus":{"theme":{"anchor":"right"}},"surfaces":{"system":{"anchor":"right"}}},"sidebars":{
				"motion":"calm",
				"left":{"enabled":false,"cards":[],"width":512,"height":1000,"heightMode":"fixed","maxHeight":85,"position":"center","pinned":false,"presentations":{}},
				"right":{"enabled":true,"cards":[],"width":1040,"height":1000,"heightMode":"fixed","maxHeight":85,"position":"center","pinned":false,"presentations":{}},
				"extension":{"future":true}
			},"custom":{"nested":[1,2,3]}}`,
			changed: true,
		},
		{
			name:    "quick-settings leaf retires while empty sidebar object is normalized",
			in:      `{"frameBars":{"menus":{"quick-settings":{"future":true}},"surfaces":{"future":{"anchor":"top"}}},"sidebars":{}}`,
			want:    `{"frameBars":{"menus":{},"surfaces":{"future":{"anchor":"top"}}},"sidebars":` + canonicalSidebarsJSON + `}`,
			changed: true,
		},
		{
			name:    "stash leaf retires while empty sidebar object is normalized",
			in:      `{"frameBars":{"menus":{"theme":{"anchor":"right"}},"surfaces":{"stash":{"future":true}}},"sidebars":{}}`,
			want:    `{"frameBars":{"menus":{"theme":{"anchor":"right"}},"surfaces":{}},"sidebars":` + canonicalSidebarsJSON + `}`,
			changed: true,
		},
		{
			name:    "current store is unchanged",
			in:      `{"frameBars":{"menus":{"theme":{"anchor":"right"}},"surfaces":{"future":{"anchor":"top"}}},"sidebars":` + canonicalSidebarsJSON + `,"custom":{"nested":[1,2,3]}}`,
			changed: false,
		},
		{
			name:    "invalid json errors",
			in:      `not json`,
			wantErr: true,
		},
		{
			name:    "null top level errors",
			in:      `null`,
			wantErr: true,
		},
		{
			name:    "malformed retired parent errors",
			in:      `{"frameBars":{"menus":"not-an-object"}}`,
			wantErr: true,
		},
		{
			name:    "malformed surface parent errors",
			in:      `{"frameBars":{"surfaces":"not-an-object"}}`,
			wantErr: true,
		},
		{
			name:    "malformed side config errors",
			in:      `{"sidebars":{"left":"not-an-object"}}`,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out, changed, err := migrateSidebarRework([]byte(tt.in))
			if tt.wantErr {
				if err == nil {
					t.Fatal("migration succeeded, want error")
				}
				return
			}
			if err != nil {
				t.Fatalf("migration failed: %v", err)
			}
			if changed != tt.changed {
				t.Fatalf("changed = %v, want %v", changed, tt.changed)
			}
			if !tt.changed {
				if out != nil {
					t.Fatalf("no-op migration returned output: %s", out)
				}
				return
			}

			var got, want map[string]any
			if err := json.Unmarshal(out, &got); err != nil {
				t.Fatalf("migrated JSON does not parse: %v", err)
			}
			if err := json.Unmarshal([]byte(tt.want), &want); err != nil {
				t.Fatalf("test expectation does not parse: %v", err)
			}
			var original map[string]any
			if err := json.Unmarshal([]byte(tt.in), &original); err != nil {
				t.Fatal(err)
			}
			originalSides, _ := original["sidebars"].(map[string]any)
			for _, side := range []string{"left", "right"} {
				prior, _ := originalSides[side].(map[string]any)
				actual, _ := got["sidebars"].(map[string]any)[side].(map[string]any)
				expected, _ := want["sidebars"].(map[string]any)[side].(map[string]any)
				for _, key := range []string{"width", "height"} {
					if _, supplied := prior[key]; supplied || (side == "left" && key == "width" && originalSides["width"] != nil) {
						continue
					}
					delete(actual, key)
					delete(expected, key)
				}
			}
			if !reflect.DeepEqual(got, want) {
				t.Errorf("migrated store = %#v, want %#v", got, want)
			}

			if second, changed, err := migrateSidebarRework(out); err != nil || changed || second != nil {
				t.Errorf("second migration must be a no-op: changed=%v out=%s err=%v", changed, second, err)
			}
		})
	}
}

func TestMigrateSidebarReworkMovesWidthWhenLeftSideIsMissing(t *testing.T) {
	out, changed, err := migrateSidebarRework([]byte(`{"sidebars":{"width":444,"right":{"enabled":true,"cards":[],"width":601}}}`))
	if err != nil || !changed {
		t.Fatalf("migration failed: changed=%v err=%v", changed, err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatal(err)
	}
	sidebars := cfg["sidebars"].(map[string]any)
	left := sidebars["left"].(map[string]any)
	right := sidebars["right"].(map[string]any)
	if left["width"] != float64(444) {
		t.Errorf("left width = %v, want migrated 444", left["width"])
	}
	if right["width"] != float64(601) {
		t.Errorf("right width = %v, want preserved 601", right["width"])
	}
	if cards := right["cards"].([]any); len(cards) != 0 {
		t.Errorf("right cards = %v, want intentional empty list", cards)
	}
	if _, present := sidebars["width"]; present {
		t.Error("legacy global width survived migration")
	}
}

func TestMigrateSidebarReworkRetiresNativeGeometry(t *testing.T) {
	raw := []byte(`{"sidebars":{"left":{"cards":["media"],"width":612,"position":"top-left","geometry":{"DP-1":{"x":2,"y":3,"width":380,"height":520}}},"right":{"cards":[],"position":"bottom-right","pinned":true}},"other":{"keep":7}}`)
	out, changed, err := migrateSidebarRework(raw)
	if err != nil || !changed {
		t.Fatalf("migration failed: changed=%v err=%v", changed, err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(out, &cfg); err != nil {
		t.Fatal(err)
	}
	sides := cfg["sidebars"].(map[string]any)
	left, right := sides["left"].(map[string]any), sides["right"].(map[string]any)
	if _, present := left["geometry"]; present {
		t.Fatal("retired native-window geometry survived")
	}
	if left["position"] != "top" || right["position"] != "bottom" {
		t.Fatalf("edge alignment was not migrated: left=%v right=%v", left["position"], right["position"])
	}
	if left["width"] != float64(612) || !reflect.DeepEqual(left["cards"], []any{"media"}) || right["pinned"] != true {
		t.Fatal("migration lost authored dimensions, contents or keep-open preference")
	}
	if !reflect.DeepEqual(cfg["other"], map[string]any{"keep": float64(7)}) {
		t.Fatal("migration changed unrelated settings")
	}
	if second, changed, err := migrateSidebarRework(out); err != nil || changed || second != nil {
		t.Fatalf("migration is not idempotent: changed=%v out=%s err=%v", changed, second, err)
	}
}

func TestReconcileSidebarRework(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}

	if r := reconcileSidebarRework(false); r.status != recOK {
		t.Fatalf("missing shell.json: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}

	stored := `{"frameBars":{"menus":{"quick-settings":{"modules":["home"]},"theme":{"anchor":"right"}},"surfaces":{"stash":{"anchor":"right"},"future":{"anchor":"top"}}},"theme":"paper"}`
	if err := os.WriteFile(path, []byte(stored), 0o644); err != nil {
		t.Fatal(err)
	}
	if r := reconcileSidebarRework(true); r.status != recWouldFix {
		t.Fatalf("check with retired records: status=%s detail=%q, want todo", r.status.label(), r.detail)
	}
	if got, err := os.ReadFile(path); err != nil || string(got) != stored {
		t.Fatalf("check-only changed shell.json: got=%q err=%v", got, err)
	}
	if r := reconcileSidebarRework(false); r.status != recFixed {
		t.Fatalf("fix with retired records: status=%s detail=%q, want fixed", r.status.label(), r.detail)
	}

	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		t.Fatalf("rewritten shell.json does not parse: %v", err)
	}
	frameBars := cfg["frameBars"].(map[string]any)
	menus := frameBars["menus"].(map[string]any)
	if _, present := menus["quick-settings"]; present {
		t.Error("fix left the retired quick-settings menu in place")
	}
	if _, present := menus["theme"]; !present {
		t.Error("fix removed a sibling menu")
	}
	surfaces := frameBars["surfaces"].(map[string]any)
	if _, present := surfaces["stash"]; present {
		t.Error("fix left the retired stash surface in place")
	}
	if _, present := surfaces["future"]; !present {
		t.Error("fix removed a sibling surface")
	}
	if cfg["theme"] != "paper" {
		t.Errorf("fix changed an unrelated top-level key: %v", cfg["theme"])
	}
	if r := reconcileSidebarRework(false); r.status != recOK {
		t.Fatalf("clean store: status=%s detail=%q, want ok", r.status.label(), r.detail)
	}
}
