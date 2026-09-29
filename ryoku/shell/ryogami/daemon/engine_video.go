package main

import (
	"encoding/json"
	"path/filepath"
)

// Written through setSetting so shell.json keeps a single writer.
func (d *daemon) syncShellVideoEngine() {
	var shellVal string
	switch d.settingString("paper.videoEngine") {
	case "ryogami":
		shellVal = "ryogami"
	case "in_shell":
		shellVal = "in_shell"
	default:
		return
	}
	if err := d.setSetting("wallpaper.video_engine", shellVal); err == nil {
		return
	}
	patchShellVideoEngine(shellVal)
}

func patchShellVideoEngine(v string) {
	path := filepath.Join(ryokuConfigDir(), "shell.json")
	raw := map[string]json.RawMessage{}
	loadJSON(path, &raw)
	wall := map[string]interface{}{}
	if w, ok := raw["wallpaper"]; ok {
		_ = json.Unmarshal(w, &wall)
	}
	wall["video_engine"] = v
	wb, err := json.Marshal(wall)
	if err != nil {
		return
	}
	raw["wallpaper"] = wb
	out, err := json.MarshalIndent(raw, "", "  ")
	if err != nil {
		return
	}
	saveRaw(path, out)
}

func init() {
	onStart(func(d *daemon) { d.syncShellVideoEngine() })
	watchSetting("paper.videoEngine", func(d *daemon, _ string, _ interface{}) {
		d.syncShellVideoEngine()
	})
}
