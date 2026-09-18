#!/usr/bin/env bash
# qsbar-size-probe: a stored QS Bar scale changes its live shell height.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
src="$repo/ryoku/shell/quickshell/shell"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Ryoku" "$work/shell/modules" "$work/cfg/ryoku"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
ln -s "$repo/ryoku/shell/framebars" "$work/Ryoku/FrameBars"
for child in "$src"/*; do
    name="$(basename "$child")"
    [[ "$name" == modules ]] && continue
    ln -s "$child" "$work/shell/$name"
done
for child in "$src/modules"/*; do
    ln -s "$child" "$work/shell/modules/$(basename "$child")"
done
cp "$here/qsbar-size-probe.qml" "$work/shell/probe.qml"

cat >"$work/cfg/ryoku/shell.json" <<'JSON'
{"qsbar":{"barScale":1.5}}
JSON

XDG_CONFIG_HOME="$work/cfg" \
QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
timeout 20 qs -p "$work/shell/probe.qml" >"$work/probe.log" 2>&1 || true

if ! grep -q QSBAR-SIZE-PROBE-PASS "$work/probe.log"; then
    echo "qsbar-size-probe: FAILED" >&2
    sed -n '1,120p' "$work/probe.log" >&2
    exit 1
fi

echo "qsbar-size-probe: persisted scale changes the live bar height"
