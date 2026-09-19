#!/usr/bin/env bash
# Regression test for ryoku-cmd-touchpad's restore verb (#207): the pad's
# disabled state is a runtime override, so boot and every config reload
# re-enable it while the flag file still reads "off" -- the user's pad moves
# after a reboot until they toggle it twice. restore must push the stored
# intent back at the compositor, silently, and stay out of the way when
# nothing was ever turned off or the WM cannot take a live toggle.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
cmd="$here/ryoku/hyprland/scripts/ryoku-cmd-touchpad"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export RYOKU_STATE_PATH="$tmp/state"
export RYOKU_TOUCHPAD_STATE_FILE="$tmp/state/touchpad.disabled"

# Fakes: the seam answers the capability question, hyprctl records evals.
mkdir -p "$tmp/bin"
# notify-send is stubbed so the verbs under test never toast on a live desktop.
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/bin/notify-send"
chmod +x "$tmp/bin/notify-send"
cat >"$tmp/bin/ryoku" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == wm && ${2:-} == status ]] && echo "Capabilities: liveConfigEval,"
exit 0
EOF
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  devices) echo '{"mice":[{"name":"elantech:03a2:0068-touchpad"},{"name":"trackpoint"}]}' ;;
  eval)    printf '%s\n' "$2" >>"$HYPRCTL_LOG" ;;
esac
exit 0
EOF
# A compositor without the live-toggle capability: hyprctl never answers.
cat >"$tmp/bin/hyprctl-nowm" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  devices) echo '{"mice":[]}' ;;
  eval)    printf '%s\n' "$2" >>"$HYPRCTL_LOG" ;;
esac
exit 0
EOF
cat >"$tmp/bin/ryoku-nowm" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == wm && ${2:-} == status ]] && echo "Capabilities: ,"
exit 0
EOF
chmod +x "$tmp"/bin/*
export PATH="$tmp/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }
export HYPRCTL_LOG="$tmp/evals"

# 1. No stored intent: restore is silent and flips nothing.
"$cmd" restore || fail "restore failed with no state"
[[ -e "$HYPRCTL_LOG" ]] && fail "restore flipped pads with no stored off"

# 2. Stored "off": every touchpad (and only the touchpad) is re-disabled.
mkdir -p "$RYOKU_STATE_PATH" && : >"$RYOKU_TOUCHPAD_STATE_FILE"
out="$("$cmd" restore 2>&1)" && [[ -z $out ]] || fail "restore was not silent: $out"
grep -q 'name = "elantech:03a2:0068-touchpad", enabled = false' "$HYPRCTL_LOG" \
  || fail "restore did not re-disable the touchpad: $(cat "$HYPRCTL_LOG")"
grep -q "trackpoint" "$HYPRCTL_LOG" && fail "restore touched a non-touchpad device"

# 3. A WM without the live toggle: honest no-op, no toast, no eval.
rm -f "$HYPRCTL_LOG"
mv "$tmp/bin/ryoku" "$tmp/bin/ryoku.off" && cp "$tmp/bin/ryoku-nowm" "$tmp/bin/ryoku"
mv "$tmp/bin/hyprctl" "$tmp/bin/hyprctl.off" && cp "$tmp/bin/hyprctl-nowm" "$tmp/bin/hyprctl"
out="$("$cmd" restore 2>&1)" && [[ -z $out ]] || fail "restore spoke on a dead-end WM: $out"
[[ -e "$HYPRCTL_LOG" ]] && fail "restore dispatched evals without the capability"
mv "$tmp/bin/ryoku.off" "$tmp/bin/ryoku" && mv "$tmp/bin/hyprctl.off" "$tmp/bin/hyprctl"

# 4. The FN key still toasts; restore is the only silent verb.
rm -f "$HYPRCTL_LOG" "$RYOKU_TOUCHPAD_STATE_FILE"
"$cmd" off >/dev/null 2>&1 || true
[[ -e "$RYOKU_TOUCHPAD_STATE_FILE" ]] || fail "off did not record the intent"

echo "touchpad-restore: boot and reload re-assert the stored intent"
