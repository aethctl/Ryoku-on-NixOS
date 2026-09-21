#!/usr/bin/env bash
# Regression test for ryoku-cmd-brightness: the DDC/CI branch must not walk
# every i2c bus when no external monitor is connected. `ddcutil detect` is the
# freeze (#176): on a hybrid laptop it touches 28 i2c buses for over 11s, and
# i2c traffic on the display controller is what locks the whole session on a
# brightness keypress. Gate it on a connected non-panel DRM connector (a sysfs
# read), the same protection 755ed028 added to the sidebar but not to this key
# handler. RYOKU_DRM_PATH lets the connector set be faked.
#
# It must also cache the detected buses per connected-external set, so a docked
# user's repeated presses do not re-walk i2c every time, while a plug/unplug
# (a changed set) refreshes the walk.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
script="$here/ryoku/hyprland/scripts/ryoku-cmd-brightness"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# A fake ddcutil that counts how many times detect (the i2c walk) ran.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/ddcutil" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == detect ]]; then echo detect >>"$DDC_RAN"; fi
exit 0
EOF
chmod +x "$tmp/bin/ddcutil"

# Fake the panel side too, so the test never touches a real backlight.
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/bin/brightnessctl"
printf '#!/usr/bin/env bash\nexit 1\n' >"$tmp/bin/ryoku-hw-backlight"
chmod +x "$tmp/bin/brightnessctl" "$tmp/bin/ryoku-hw-backlight"

# connectors <set> -- build a fake DRM tree for a named connector set.
connectors() {
  rm -rf "$tmp/drm"; mkdir -p "$tmp/drm"
  case "$1" in
    panel-only)
      mkdir -p "$tmp/drm/card0-eDP-1"; echo connected >"$tmp/drm/card0-eDP-1/status" ;;
    external)
      mkdir -p "$tmp/drm/card0-eDP-1" "$tmp/drm/card1-HDMI-A-1"
      echo connected >"$tmp/drm/card0-eDP-1/status"
      echo connected >"$tmp/drm/card1-HDMI-A-1/status" ;;
    disconnected-external)
      mkdir -p "$tmp/drm/card0-eDP-1" "$tmp/drm/card1-HDMI-A-1"
      echo connected >"$tmp/drm/card0-eDP-1/status"
      echo disconnected >"$tmp/drm/card1-HDMI-A-1/status" ;;
  esac
}

# press <xdg-runtime-dir> -- one brightness keypress, echoing the detect count.
press() {
  local rt="$1"
  mkdir -p "$rt"
  : >"$tmp/ddc_ran"
  PATH="$tmp/bin:$PATH" DDC_RAN="$tmp/ddc_ran" XDG_RUNTIME_DIR="$rt" \
    RYOKU_DRM_PATH="$tmp/drm" "$script" +5 >/dev/null 2>&1 || true
  wc -l <"$tmp/ddc_ran" | tr -d ' '
}

# 1. Panel-only: the walk must be skipped entirely.
connectors panel-only
n="$(press "$tmp/rt1")"
[[ $n == 0 ]] || { echo "FAIL: panel-only walked i2c ($n); want 0" >&2; exit 1; }

# 2. External present but disconnected: still skipped.
connectors disconnected-external
n="$(press "$tmp/rt2")"
[[ $n == 0 ]] || { echo "FAIL: disconnected external walked i2c ($n); want 0" >&2; exit 1; }

# 3. Connected external: the walk runs once.
connectors external
n="$(press "$tmp/rt3")"
[[ $n == 1 ]] || { echo "FAIL: connected external walked $n times; want 1" >&2; exit 1; }

# 4. A second press on the same dock reuses the cache: no new walk.
n="$(press "$tmp/rt3")"
[[ $n == 0 ]] || { echo "FAIL: repeat press re-walked i2c ($n); want 0 (cached)" >&2; exit 1; }

# 5. A different connected-external set (hotplug) refreshes the walk.
connectors external
mkdir -p "$tmp/drm/card2-DP-1"; echo connected >"$tmp/drm/card2-DP-1/status"
n="$(press "$tmp/rt3")"
[[ $n == 1 ]] || { echo "FAIL: changed dock set did not re-walk ($n); want 1" >&2; exit 1; }

echo "PASS: ryoku-cmd-brightness gates the i2c walk and caches it per dock set"
