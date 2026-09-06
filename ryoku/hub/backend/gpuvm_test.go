package main

import "testing"

func TestParseVMFlags(t *testing.T) {
	f := parseVMFlags([]string{"--name", "win11", "--os", "windows", "--disk-gb", "80", "--force", "--iso=/tmp/w.iso"})
	if f["name"] != "win11" || f["os"] != "windows" || f["disk-gb"] != "80" {
		t.Errorf("valued flags misparsed: %#v", f)
	}
	if f["force"] != "true" {
		t.Errorf("bare flag should be %q, got %q", "true", f["force"])
	}
	if f["iso"] != "/tmp/w.iso" {
		t.Errorf("--k=v form misparsed: %q", f["iso"])
	}
}

func TestValidVMName(t *testing.T) {
	for _, ok := range []string{"win11", "arch-gaming", "vm_1"} {
		if err := validVMName(ok); err != nil {
			t.Errorf("%q should be valid: %v", ok, err)
		}
	}
	for _, bad := range []string{"", "has space", "slash/name", "bad;rm"} {
		if err := validVMName(bad); err == nil {
			t.Errorf("%q should be rejected", bad)
		}
	}
}

func TestDefaultRAMMB(t *testing.T) {
	if got := defaultRAMMB(&Capability{RamTotalMB: 32768}); got != 16384 {
		t.Errorf("half of 32 GiB = %d, want 16384", got)
	}
	// floor at 4 GiB on a tiny host, rounded to a whole GiB.
	if got := defaultRAMMB(&Capability{RamTotalMB: 4096}); got < 4096 {
		t.Errorf("default RAM %d fell below the 4 GiB floor", got)
	}
	if got := defaultRAMMB(nil); got%1024 != 0 {
		t.Errorf("default RAM %d must be a whole number of GiB", got)
	}
}
