package main

import (
	"fmt"
	"os/exec"
	"strings"
)

const defaultPaletteBridgeSource = "/usr/share/ryoku/palette-bridge"

func (d *daemon) paletteBridgeSource() string {
	src := strings.TrimSpace(d.settingString("paletteBridgeSource"))
	if src == "" {
		return defaultPaletteBridgeSource
	}
	return src
}

func hubPaletteBridge(args ...string) (string, error) {
	full := append([]string{"palette-bridge"}, args...)
	out, err := exec.Command("ryoku-hub", full...).CombinedOutput()
	if err != nil {
		msg := strings.TrimSpace(string(out))
		if msg == "" {
			msg = err.Error()
		}
		return "", fmt.Errorf("palette bridge: %s", msg)
	}
	return strings.TrimSpace(string(out)), nil
}

func init() {
	registerAction("PaletteBridgeSetup", func(d *daemon, _ map[string]interface{}) (interface{}, error) {
		if _, err := hubPaletteBridge("install", d.paletteBridgeSource()); err != nil {
			return nil, err
		}
		if _, err := hubPaletteBridge("service", "enable"); err != nil {
			return nil, err
		}
		return map[string]interface{}{"ok": true}, nil
	})
	registerAction("PaletteBridgeRestart", func(d *daemon, _ map[string]interface{}) (interface{}, error) {
		if _, err := hubPaletteBridge("service", "restart"); err != nil {
			return nil, err
		}
		return map[string]interface{}{"ok": true}, nil
	})
	registerAction("PaletteBridgeRemove", func(d *daemon, _ map[string]interface{}) (interface{}, error) {
		if _, err := hubPaletteBridge("service", "disable"); err != nil {
			return nil, err
		}
		return map[string]interface{}{"ok": true}, nil
	})

	registerAvailability("paletteBridge", func(d *daemon) bool {
		_, err := exec.LookPath("ryoku-hub")
		return err == nil
	})
}
