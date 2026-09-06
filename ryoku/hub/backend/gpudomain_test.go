package main

import (
	"encoding/xml"
	"strings"
	"testing"
)

func TestBuildPinPlanReservesFirstCore(t *testing.T) {
	// 4 physical cores, 2 threads each; siblings adjacent.
	cores := [][]int{{0, 1}, {2, 3}, {4, 5}, {6, 7}}
	p := buildPinPlan(cores, 0)
	if p.Emulator != "0,1" {
		t.Errorf("emulator cpuset = %q, want the first core 0,1", p.Emulator)
	}
	want := []int{2, 3, 4, 5, 6, 7}
	if len(p.Vcpus) != len(want) {
		t.Fatalf("vcpus = %v, want %v", p.Vcpus, want)
	}
	for i := range want {
		if p.Vcpus[i] != want[i] {
			t.Fatalf("vcpus = %v, want %v", p.Vcpus, want)
		}
	}
	if p.Cores != 3 || p.Threads != 2 {
		t.Errorf("topology = %dc%dt, want 3c2t", p.Cores, p.Threads)
	}
}

func TestBuildPinPlanCoreCap(t *testing.T) {
	cores := [][]int{{0, 1}, {2, 3}, {4, 5}, {6, 7}}
	p := buildPinPlan(cores, 2) // cap to 2 usable cores
	if p.Cores != 2 || len(p.Vcpus) != 4 {
		t.Errorf("capped plan = %dc %d vcpus, want 2c 4 vcpus", p.Cores, len(p.Vcpus))
	}
}

func TestBuildPinPlanTinyCPU(t *testing.T) {
	// one physical core: reserve nothing, pin both threads.
	p := buildPinPlan([][]int{{0, 1}}, 0)
	if p.Emulator != "" {
		t.Errorf("a single-core host must not reserve an emulator core, got %q", p.Emulator)
	}
	if len(p.Vcpus) != 2 || p.Cores != 1 {
		t.Errorf("tiny plan = %dc %d vcpus, want 1c 2 vcpus", p.Cores, len(p.Vcpus))
	}
}

func TestBuildDomainXMLWellFormed(t *testing.T) {
	xmlDoc := buildDomainXML(sampleSpec(true))
	dec := xml.NewDecoder(strings.NewReader(xmlDoc))
	for {
		_, err := dec.Token()
		if err != nil {
			if err.Error() == "EOF" {
				break
			}
			t.Fatalf("generated domain is not well-formed XML: %v\n%s", err, xmlDoc)
		}
	}
}

func TestBuildDomainXMLWindows(t *testing.T) {
	x := buildDomainXML(sampleSpec(true))
	must := []string{
		"<name>ryoku-win11</name>",
		"mode='host-passthrough'",
		"<hyperv mode='custom'>",
		"<hidden state='on'/>",
		"function='0x0'", "function='0x1'", // GPU + its audio function
		"managed='no'", // the Ryoku hook binds vfio
		"mem-path=/dev/kvmfr0,size=134217728,share=yes", // kvmfr 128 MiB
		"<tpm model='tpm-crb'>",                         // Windows 11 TPM
		"name='secure-boot'",                            // firmware knob present
		"<feature policy='require' name='topoext'/>",    // AMD SMT
	}
	for _, s := range must {
		if !strings.Contains(x, s) {
			t.Errorf("windows domain missing %q\n%s", s, x)
		}
	}
	if strings.Contains(x, "secure-boot'/>") && !strings.Contains(x, "enabled='no' name='secure-boot'") {
		t.Error("secure boot must ship disabled so the VM always boots")
	}
}

func TestBuildDomainXMLLinuxHasNoHyperv(t *testing.T) {
	spec := sampleSpec(true)
	spec.Windows = false
	spec.AMD = false
	x := buildDomainXML(spec)
	if strings.Contains(x, "<hyperv") {
		t.Error("a Linux guest must not carry Hyper-V enlightenments")
	}
	if strings.Contains(x, "topoext") {
		t.Error("topoext must be gated on AMD hosts")
	}
	if !strings.Contains(x, "<clock offset='utc'/>") {
		t.Error("a Linux guest should use a UTC clock")
	}
}

func TestParsePCISlot(t *testing.T) {
	cases := []struct{ in, dom, bus, dev, fn string }{
		{"0000:01:00.0", "0000", "01", "00", "0"},
		{"0000:65:00.1", "0000", "65", "00", "1"},
		{"01:00.0", "0000", "01", "00", "0"},
	}
	for _, c := range cases {
		dom, bus, dev, fn := parsePCISlot(c.in)
		if dom != c.dom || bus != c.bus || dev != c.dev || fn != c.fn {
			t.Errorf("parsePCISlot(%q) = %s:%s:%s.%s, want %s:%s:%s.%s",
				c.in, dom, bus, dev, fn, c.dom, c.bus, c.dev, c.fn)
		}
	}
}

func TestParseCPUList(t *testing.T) {
	got := parseCPUList("0-3,8-11")
	want := []int{0, 1, 2, 3, 8, 9, 10, 11}
	if len(got) != len(want) {
		t.Fatalf("parseCPUList = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("parseCPUList = %v, want %v", got, want)
		}
	}
}

func sampleSpec(windows bool) vmSpec {
	return vmSpec{
		Domain:     "ryoku-win11",
		MemMB:      16384,
		Pin:        buildPinPlan([][]int{{0, 1}, {2, 3}, {4, 5}, {6, 7}}, 0),
		Disk:       "/home/nero/.local/share/ryoku/vm/win11/disk.qcow2",
		InstallISO: "/tmp/win11.iso",
		VirtioISO:  "/usr/share/virtio-win/virtio-win.iso",
		GPU:        GPU{Slot: "0000:01:00.0", Functions: []string{"0000:01:00.0", "0000:01:00.1"}},
		KvmfrMB:    128,
		Windows:    windows,
		AMD:        true,
	}
}
