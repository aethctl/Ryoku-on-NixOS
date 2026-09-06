package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"github.com/godbus/dbus/v5"
)

// powerprofiles.go owns the power-profile daemon integration: it reads the
// active profile and the ordered profile list from power-profiles-daemon over
// the system bus, streams them to QML on the "powerprofiles" state topic, and
// sets the active profile on request. The bus name, object path, and interface
// are the freedesktop PowerProfiles spec, reproduced as-is; they are
// third-party protocol, not reference API. Contract 06 sec 2.9 / contract 11
// sec 3.1 (power profiles): the list is service order with no client sort, and
// "Unknown" maps to the balanced icon on the QML side.
const (
	ppBusName = "org.freedesktop.UPower.PowerProfiles"
	ppPath    = "/org/freedesktop/UPower/PowerProfiles"
	ppIface   = "org.freedesktop.UPower.PowerProfiles"
)

// powerProfilesState holds the one system-bus connection and the topic the
// active-profile and profile-list frames publish to.
type powerProfilesState struct {
	conn  *dbus.Conn
	obj   dbus.BusObject
	topic *stateTopic

	applyTimer   *time.Timer // debounce for re-applying the active profile after a ppd switch
	applyMu      sync.Mutex  // serialises applies so overlapping fires never race
	lastApplyErr string      // profile whose apply last failed; logged once per change

	// restoreDone: a PropertiesChanged before restore-on-login finishes is ppd's
	// boot default, not a user pick. acFlipNs: unix-nanos of the last AC flip; a
	// change within autoSwitchWindow of it is automatic, not a pick.
	restoreDone atomic.Bool
	acFlipNs    atomic.Int64
}

// startPowerProfiles brings the power-profile integration up, registers the
// topic and the setProfile call, watches PropertiesChanged, and publishes the
// first frame. A missing system bus or absent daemon disables the feature
// without failing the daemon (the QML view simply stays empty).
func (d *daemon) startPowerProfiles() {
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		log.Printf("ryoku-shell: power profiles disabled: %v", err)
		return
	}
	p := &powerProfilesState{
		conn:  conn,
		obj:   conn.Object(ppBusName, dbus.ObjectPath(ppPath)),
		topic: d.registerTopic("powerprofiles"),
	}
	d.pp = p
	// Capture the saved choice before wiring signals: a boot-time
	// PropertiesChanged could rewrite the store before restore reads it.
	saved := readPersistedProfile()

	if err := conn.AddMatchSignal(
		dbus.WithMatchObjectPath(dbus.ObjectPath(ppPath)),
		dbus.WithMatchInterface("org.freedesktop.DBus.Properties"),
		dbus.WithMatchMember("PropertiesChanged"),
	); err != nil {
		log.Printf("ryoku-shell: power profiles signal match failed: %v", err)
	}
	sigs := make(chan *dbus.Signal, 8)
	conn.Signal(sigs)
	go func() {
		for range sigs {
			p.publish()
			p.scheduleApply()
			p.maybePersistActive()
		}
		if p.applyTimer != nil {
			p.applyTimer.Stop()
		}
	}()

	d.registerCall("powerprofiles.setProfile", func(raw json.RawMessage) (any, error) {
		var a struct {
			Profile string `json:"profile"`
		}
		if err := json.Unmarshal(raw, &a); err != nil {
			return nil, err
		}
		return nil, p.setProfile(a.Profile)
	})

	// Restore the profile the user last chose. power-profiles-daemon resets to a
	// platform default on reboot (and can boot differently on AC vs battery), so
	// without this the desktop forgets a balanced/performance pick every restart.
	if saved != "" && saved != p.activeProfile() {
		if err := p.setProfile(saved); err != nil {
			log.Printf("ryoku-shell: restore power profile %q: %v", saved, err)
		}
	}
	p.restoreDone.Store(true)

	p.publish()
}

// publish marshals the whole power-profile state and hands it to the topic,
// which drops it if byte-identical to the last frame.
func (p *powerProfilesState) publish() {
	if p.topic == nil {
		return
	}
	frame, err := json.Marshal(map[string]any{
		"active_profile": p.activeProfile(),
		"profiles":       p.profiles(),
	})
	if err != nil {
		return
	}
	p.topic.publish(frame)
}

// activeProfile reads the current profile name ("power-saver"/"balanced"/
// "performance"), empty when the property is unreadable.
func (p *powerProfilesState) activeProfile() string {
	v, err := p.obj.GetProperty(ppIface + ".ActiveProfile")
	if err != nil {
		return ""
	}
	s, _ := v.Value().(string)
	return s
}

// profiles reads the ordered profile list. The daemon returns an array of
// dicts; the "Profile" key of each carries the name. Order is the daemon's
// (service order); no client sort.
func (p *powerProfilesState) profiles() []string {
	v, err := p.obj.GetProperty(ppIface + ".Profiles")
	if err != nil {
		return nil
	}
	return profileNames(v.Value())
}

// setProfile writes the active-profile property. An empty or unknown name is
// rejected before the bus call so a bad request never reaches the daemon.
func (p *powerProfilesState) setProfile(name string) error {
	if name == "" {
		return fmt.Errorf("empty profile")
	}
	known := false
	for _, n := range p.profiles() {
		if n == name {
			known = true
			break
		}
	}
	if !known {
		return fmt.Errorf("unknown profile: %s", name)
	}
	return p.obj.Call("org.freedesktop.DBus.Properties.Set", 0,
		ppIface, "ActiveProfile", dbus.MakeVariant(name)).Err
}

// persistedProfilePath is the daemon-owned store for the user's last explicit
// power-profile choice, kept beside power.json but separate so a ryoku-power
// write of the CPU knobs never clobbers it (and vice versa).
func persistedProfilePath() string {
	dir := ryokuConfigDir()
	if dir == "" {
		return ""
	}
	return filepath.Join(dir, "power-profile.json")
}

// persistProfile records an explicit user profile choice so it can be restored
// after a reboot. Only the user path calls this; autoprofile's transient
// on-battery switch must not overwrite the saved preference.
func (p *powerProfilesState) persistProfile(name string) {
	if name == "" {
		return
	}
	if path := persistedProfilePath(); path != "" {
		_ = writeJSONFile(path, map[string]string{"profile": name})
	}
}

const autoSwitchWindow = 6 * time.Second

// persistDecision reports whether active should be saved as the user's choice.
// Pure, so the guard is unit-tested without a bus or clock.
func persistDecision(active string, restoreDone, onBattery, saverFeature bool, sinceACFlip time.Duration) bool {
	switch {
	case active == "" || !restoreDone:
		return false
	case active == ppSaver && onBattery && saverFeature:
		return false // autoprofile's battery switch, not a choice
	case sinceACFlip < autoSwitchWindow:
		return false // automatic reaction to plugging or unplugging
	default:
		return true
	}
}

// noteACFlip records that AC just plugged or unplugged.
func (p *powerProfilesState) noteACFlip() { p.acFlipNs.Store(time.Now().UnixNano()) }

// maybePersistActive saves the current profile as the user's choice on any path
// (the bar widget shells out to powerprofilesctl, not this daemon), skipping the
// changes persistDecision flags as automatic. Runs on every PropertiesChanged.
func (p *powerProfilesState) maybePersistActive() {
	active := p.activeProfile()
	sinceFlip := time.Duration(1) << 62
	if ns := p.acFlipNs.Load(); ns != 0 {
		sinceFlip = time.Since(time.Unix(0, ns))
	}
	st := readPowerState()
	onBattery := st.present && st.discharging
	if persistDecision(active, p.restoreDone.Load(), onBattery, perfFlag("autoPowerSaverOnBattery"), sinceFlip) {
		p.persistProfile(active)
	}
}

// readPersistedProfile returns the user's last saved profile, or "" when none is
// stored or it is unreadable.
func readPersistedProfile() string {
	path := persistedProfilePath()
	if path == "" {
		return ""
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	var s struct {
		Profile string `json:"profile"`
	}
	if json.Unmarshal(b, &s) != nil {
		return ""
	}
	return s.Profile
}

// profileNames extracts profile names from the raw Profiles property value
// (aa{sv}). It is pure so the extraction is unit-tested without a live bus.
func profileNames(v any) []string {
	rows, ok := v.([]map[string]dbus.Variant)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(rows))
	for _, row := range rows {
		if pv, ok := row["Profile"]; ok {
			if name, ok := pv.Value().(string); ok && name != "" {
				out = append(out, name)
			}
		}
	}
	return out
}

// applyProfileCmd re-applies a profile's definition through ryoku-power. It is a
// package var so a test can record calls without spawning the helper.
var applyProfileCmd = func(profile string) error {
	return exec.Command("ryoku-power", "apply-profile", profile).Run()
}

// powerConfigPath is ~/.config/ryoku/power.json, the CPU/battery knob store the
// Machine page and ryoku-power write. Empty when the home dir is unknowable.
func powerConfigPath() string {
	dir := ryokuConfigDir()
	if dir == "" {
		return ""
	}
	return filepath.Join(dir, "power.json")
}

// applyDelay is the debounce window before re-applying the active profile, from
// applyDelayMs in power.json (400ms on a missing, absent, or non-positive value).
func applyDelay() time.Duration {
	const def = 400 * time.Millisecond
	b, err := os.ReadFile(powerConfigPath())
	if err != nil {
		return def
	}
	var m struct {
		ApplyDelayMs int `json:"applyDelayMs"`
	}
	if json.Unmarshal(b, &m) != nil || m.ApplyDelayMs <= 0 {
		return def
	}
	return time.Duration(m.ApplyDelayMs) * time.Millisecond
}

// shouldApplyProfile returns the profile to re-apply, or "" to leave the hardware
// alone. Pure, so the safety guard is unit-tested without a bus or exec: an empty
// active profile, a power.json with no "profiles" block, or no entry for the
// active profile all yield "", so the hook execs nothing and never prompts a user
// who has not defined a profile.
func shouldApplyProfile(cfg []byte, active string) string {
	if active == "" {
		return ""
	}
	var m struct {
		Profiles map[string]json.RawMessage `json:"profiles"`
	}
	if json.Unmarshal(cfg, &m) != nil {
		return ""
	}
	if _, ok := m.Profiles[active]; !ok {
		return ""
	}
	return active
}

// scheduleApply debounces re-applying the active profile. ppd writes its own
// governor/EPP/platform_profile when the profile changes, so applying the user's
// definition immediately would be overwritten; the delay lets ppd settle first.
// A burst of PropertiesChanged coalesces into one apply by restarting the timer.
//
// The profile is resolved when the timer fires, not when it is scheduled: at
// signal time ppd may not have published the new ActiveProfile yet, and reading
// it then would apply the outgoing profile's definition over the incoming one.
func (p *powerProfilesState) scheduleApply() {
	if p.applyTimer != nil {
		p.applyTimer.Stop()
	}
	p.applyTimer = time.AfterFunc(applyDelay(), func() { p.applyActiveProfile(p.activeProfile()) })
}

// applyActiveProfile writes the user's definition for active to sysfs via
// ryoku-power. It runs on the timer goroutine, never the signal goroutine, so a
// slow or prompting helper cannot stall signal handling. It no-ops (never execs)
// when the profile is not configured, and logs a failure at most once per profile.
func (p *powerProfilesState) applyActiveProfile(active string) {
	cfg, _ := os.ReadFile(powerConfigPath())
	if shouldApplyProfile(cfg, active) == "" {
		return
	}
	p.applyMu.Lock()
	defer p.applyMu.Unlock()
	if err := applyProfileCmd(active); err != nil {
		if p.lastApplyErr != active {
			p.lastApplyErr = active
			log.Printf("ryoku-shell: apply-profile %q failed: %v", active, err)
		}
		return
	}
	p.lastApplyErr = ""
}

// saverActive reports whether Power Saver should shape the desktop: the active
// power profile is power-saver and the user left "Follow the power profile" on
// (performance.json powerProfileEffects, default on). Without a power-profiles
// connection it reads false. Read by the palette / widget / visualiser unload
// gates to reclaim memory while the machine is asking for frugality.
func (d *daemon) saverActive() bool {
	if d.pp == nil || !perfFlagDefault("powerProfileEffects", true) {
		return false
	}
	return d.pp.activeProfile() == ppSaver
}
