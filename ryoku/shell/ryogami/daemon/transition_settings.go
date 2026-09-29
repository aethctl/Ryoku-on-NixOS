package main

func (d *daemon) paperEffectName() string {
	shader := d.settingString("transition.shader")
	switch shader {
	case "", "random", "ryoku":
		return "fade"
	}
	if !validEffectName(shader) {
		return "fade"
	}
	return shader
}

// Validated here so a stray value cannot fail the whole apply.
func validEffectName(s string) bool {
	if s == "" || s[0] == '-' {
		return false
	}
	for _, c := range s {
		switch {
		case c >= 'a' && c <= 'z', c >= 'A' && c <= 'Z', c >= '0' && c <= '9',
			c == '_', c == '-', c == '.':
		default:
			return false
		}
	}
	return true
}

func (d *daemon) buildPaperTransition() *paperTransition {
	if !d.settingBool("transition.enabled") || d.effectivePerformanceMode() {
		return nil
	}
	dur := uint64(d.settingNumber("transition.durationMs"))
	if dur < 50 {
		dur = 600
	}
	if dur > 10000 {
		dur = 10000
	}
	tr := &paperTransition{Effect: d.paperEffectName(), DurationMs: dur}
	if f := int(d.settingNumber("transition.fps")); f >= 1 && f <= 1000 {
		u := uint32(f)
		tr.Fps = &u
	}
	return tr
}
