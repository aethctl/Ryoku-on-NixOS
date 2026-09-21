package wm

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// A daemon can construct its Client before the compositor's provider is
// answering. Caps must not cache that failure for the process lifetime: the
// first probe errors, and the next one, once the provider is up, succeeds and
// carries the real capabilities. This is the latent fault behind a session that
// had no night light for its whole life because it asked caps one beat too early.
func TestCapsReprobesAfterFailedProbe(t *testing.T) {
	dir := t.TempDir()
	counter := filepath.Join(dir, "count")

	// The fake provider fails its first caps invocation and succeeds after, keyed
	// on a counter file so each exec of the script advances the state.
	prov := filepath.Join(dir, "ryoku-wm-testwm")
	script := strings.NewReplacer("@COUNT@", counter).Replace(`#!/usr/bin/env bash
set -u
count="@COUNT@"
n=$(cat "$count" 2>/dev/null || echo 0)
printf '%s\n' "$((n + 1))" >"$count"
[[ "${1:-}" == caps ]] || exit 0
if (( n == 0 )); then
  echo "provider still coming up" >&2
  exit 1
fi
printf '%s' '{"name":"testwm","supports":["nightLight"],"nightLightProcess":"gammastep"}'
`)
	if err := os.WriteFile(prov, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	// The fake must win over any packaged provider on PATH; RYOKU_WM forces
	// detection to it without needing that compositor's session.
	t.Setenv("PATH", dir+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("RYOKU_WM", "testwm")

	c := Open()

	if _, err := c.Caps(); err == nil {
		t.Fatal("first caps probe should fail while the provider is not answering")
	}

	caps, err := c.Caps()
	if err != nil {
		t.Fatalf("second caps probe should succeed once the provider answers: %v", err)
	}
	if caps.NightLightProcess != "gammastep" {
		t.Fatalf("reprobe did not pick up the real caps: %+v", caps)
	}
	if !c.Can(CapNightLight) {
		t.Fatal("night light capability should read true after a successful reprobe")
	}
}
