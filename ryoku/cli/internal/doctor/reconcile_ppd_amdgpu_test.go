package doctor

import (
	"strings"
	"testing"
)

const ppdActionsFixture = `  Name: trickle_charge
  Description: Configure power supply to trickle charge
  Enabled: True

  Name: amdgpu_panel_power
  Description: Panel Power Savings (may affect color quality)
  Enabled: %s

  Name: amdgpu_dpm
  Description: Adjust GPU dynamic power management
  Enabled: %s
`

func ppdOut(abm, dpm string) string {
	return strings.Replace(strings.Replace(ppdActionsFixture, "%s", abm, 1), "%s", dpm, 1)
}

func TestPpdActionEnabled(t *testing.T) {
	out := ppdOut("False", "True")
	if ppdActionEnabled(out, "amdgpu_panel_power") {
		t.Fatal("panel_power False parsed as enabled")
	}
	if !ppdActionEnabled(out, "amdgpu_dpm") {
		t.Fatal("dpm True parsed as disabled")
	}
	if ppdActionEnabled(out, "missing_action") {
		t.Fatal("absent action parsed as enabled")
	}
}

func TestPlanPpdAmdgpu(t *testing.T) {
	t.Run("silent without amdgpu panel", func(t *testing.T) {
		r := planPpdAmdgpu(ppdAmdgpuState{amdgpuDrivesPanel: false, actionsOut: ppdOut("True", "True")})
		if r.status != recOK {
			t.Fatalf("status = %v, want ok", r.status)
		}
	})

	t.Run("silent without ppd", func(t *testing.T) {
		r := planPpdAmdgpu(ppdAmdgpuState{amdgpuDrivesPanel: true})
		if r.status != recOK {
			t.Fatalf("status = %v, want ok", r.status)
		}
	})

	t.Run("clean actions pass", func(t *testing.T) {
		r := planPpdAmdgpu(ppdAmdgpuState{amdgpuDrivesPanel: true, actionsOut: ppdOut("False", "False")})
		if r.status != recOK {
			t.Fatalf("status = %v, want ok", r.status)
		}
	})

	t.Run("enabled dpm warns about saver lag", func(t *testing.T) {
		r := planPpdAmdgpu(ppdAmdgpuState{amdgpuDrivesPanel: true, actionsOut: ppdOut("False", "True")})
		if r.status != recWarn || !strings.Contains(r.detail, "power-saver") {
			t.Fatalf("result = %v %q", r.status, r.detail)
		}
	})

	t.Run("enabled abm warns about colours", func(t *testing.T) {
		r := planPpdAmdgpu(ppdAmdgpuState{amdgpuDrivesPanel: true, actionsOut: ppdOut("True", "False")})
		if r.status != recWarn || !strings.Contains(r.detail, "ABM") {
			t.Fatalf("result = %v %q", r.status, r.detail)
		}
	})

	t.Run("both enabled warn once", func(t *testing.T) {
		r := planPpdAmdgpu(ppdAmdgpuState{amdgpuDrivesPanel: true, actionsOut: ppdOut("True", "True")})
		if r.status != recWarn || !strings.Contains(r.detail, "amdgpu_dpm and amdgpu_panel_power") {
			t.Fatalf("result = %v %q", r.status, r.detail)
		}
	})
}
