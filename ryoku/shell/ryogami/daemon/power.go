package main

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const powerPollInterval = 10 * time.Second

// A variable so a test can point it at a fixture tree.
var powerSupplyRoot = "/sys/class/power_supply"

// Peripheral batteries (scope Device) are skipped: only the machine's own counts.
func parsePowerState(root string) (onBattery, present bool, percent int, havePercent bool) {
	ents, err := os.ReadDir(root)
	if err != nil {
		return
	}
	for _, e := range ents {
		dir := filepath.Join(root, e.Name())
		if !strings.EqualFold(readTrimmed(filepath.Join(dir, "type")), "Battery") {
			continue
		}
		if strings.EqualFold(readTrimmed(filepath.Join(dir, "scope")), "Device") {
			continue
		}
		present = true
		if strings.EqualFold(readTrimmed(filepath.Join(dir, "status")), "Discharging") {
			onBattery = true
		}
		if !havePercent {
			if c, err := strconv.Atoi(readTrimmed(filepath.Join(dir, "capacity"))); err == nil {
				percent, havePercent = c, true
			}
		}
	}
	return
}

func readTrimmed(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func powerOnBattery() bool {
	on, _, _, _ := parsePowerState(powerSupplyRoot)
	return on
}

func batteryPresent() bool {
	_, present, _, _ := parsePowerState(powerSupplyRoot)
	return present
}

func batteryPercent() (int, bool) {
	_, present, pct, have := parsePowerState(powerSupplyRoot)
	return pct, present && have
}

func (d *daemon) pickerGpuEnv() []string {
	if os.Getenv("DRI_PRIME") != "" {
		return nil
	}
	pref := d.settingString("performance.gpuPreference")
	if pref == "auto" {
		if d.batterySaverActive() {
			pref = "low"
		} else {
			return nil
		}
	}
	switch pref {
	case "high":
		// DRI_PRIME only steers Mesa; the NVIDIA driver takes its own offload switches.
		if fileExists("/proc/driver/nvidia/version") {
			return []string{"__NV_PRIME_RENDER_OFFLOAD=1", "__VK_LAYER_NV_optimus=NVIDIA_only", "__GLX_VENDOR_LIBRARY_NAME=nvidia"}
		}
		return []string{"DRI_PRIME=1"}
	case "low":
		return []string{"DRI_PRIME=0"}
	}
	return nil
}

func (d *daemon) watchPower() {
	last := powerOnBattery()
	d.broadcastPower(last)
	for {
		time.Sleep(powerPollInterval)
		now := powerOnBattery()
		if now == last {
			continue
		}
		last = now
		d.broadcastPower(now)
		d.reevaluatePause()
	}
}

func (d *daemon) broadcastPower(onBattery bool) {
	pct, havePct := batteryPercent()
	data := map[string]interface{}{
		"onBattery":   onBattery,
		"present":     batteryPresent(),
		"saverActive": onBattery && d.settingBool("performance.batterySaver"),
	}
	if havePct {
		data["percent"] = pct
	}
	d.broadcast("ryogami.power.changed", data)
}

func init() {
	registerAvailability("battery", func(d *daemon) bool { return batteryPresent() })
	onStart(func(d *daemon) { go d.watchPower() })
}
