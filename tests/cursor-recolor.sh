#!/usr/bin/env bash
# Regression test for ryoku-cursor-material-recolor (#211). The tool recolours
# the Material Bibata pointer on every palette change; two bugs made every path
# a silent no-op: it read the retired hypr.json (so the theme gate never opened
# and a forced run reset the size to 24), and its accent() argv scan crashed on
# the six-character token "--full". The store moved to desktop.json under
# .desktop.cursor.*, and "DYNAMIC" (the Hub's "Follow the wallpaper" pick) is a
# role that means this theme. None of that needs the Bibata source: the gate,
# the size, and the accent scan are pure reads.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
tool="$here/release/packages/ryoku-cursor-material/ryoku-cursor-material-recolor"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp"
mkdir -p "$tmp/.config/ryoku" "$tmp/.cache/ryoku"

probe() {
  python3 - "$tool" "$@" <<'PY'
import importlib.machinery
import importlib.util
import json
import sys
from pathlib import Path

tool_path, body = sys.argv[1], sys.argv[2]
cfg = json.loads(body)
Path.home().joinpath(".config/ryoku/desktop.json").write_text(
    json.dumps(cfg.get("desktop.json", {})))
if "hypr.json" in cfg:
    Path.home().joinpath(".config/ryoku/hypr.json").write_text(
        json.dumps(cfg["hypr.json"]))
colors = Path.home() / ".cache/ryoku/colors.json"
if colors.exists():
    colors.unlink()
if "colors.json" in cfg:
    colors.write_text(json.dumps(cfg["colors.json"]))

spec = importlib.util.spec_from_loader(
    "recolor", importlib.machinery.SourceFileLoader("recolor", tool_path))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

sys.argv = [tool_path, *cfg.get("argv", [])]
print(json.dumps({
    "active_theme": m.active_theme(),
    "size": m.cursor_size(),
    "accent": m.accent(),
}))
PY
}

fail() { echo "FAIL: $*" >&2; exit 1; }

# 1. The gate opens on the concrete theme read from desktop.json's nested
#    shape, and the user's size survives (the hypr.json bug reset it to 24).
got="$(probe '{"desktop.json":{"desktop":{"cursor":{"theme":"Bibata-Material-Ryoku","size":18}}},"colors.json":{"primary":"#ff8800"}}')"
[[ $(jq -r .active_theme <<<"$got") == "Bibata-Material-Ryoku" ]] || fail "theme gate closed on a desktop.json pick: $got"
[[ $(jq -r .size <<<"$got") == 18 ]] || fail "size not read from desktop.json: $got"

# 2. "DYNAMIC" is the Hub's "Follow the wallpaper" role: it means this theme,
#    so the gate must open for it too.
got="$(probe '{"desktop.json":{"desktop":{"cursor":{"theme":"DYNAMIC","size":20}}},"colors.json":{"primary":"#ff8800"}}')"
[[ $(jq -r .active_theme <<<"$got") == "Bibata-Material-Ryoku" ]] || fail "DYNAMIC did not open the gate: $got"

# 3. A different theme keeps the tool a no-op.
got="$(probe '{"desktop.json":{"desktop":{"cursor":{"theme":"Vimix-cursors"}}},"colors.json":{"primary":"#ff8800"}}')"
[[ $(jq -r .active_theme <<<"$got") == "Vimix-cursors" ]] || fail "foreign theme leaked: $got"

# 4. The retired hypr.json must NOT be consulted any more: a theme only there
#    reads as unset, not as the material theme.
got="$(probe '{"desktop.json":{"desktop":{"cursor":{"theme":"phinger-cursors"}}},"hypr.json":{"cursor":{"theme":"Bibata-Material-Ryoku","size":42}},"colors.json":{"primary":"#ff8800"}}')"
[[ $(jq -r .active_theme <<<"$got") == "phinger-cursors" ]] || fail "still reading hypr.json: $got"
[[ $(jq -r .size <<<"$got") == 24 ]] || fail "hypr.json size leaked through: $got"

# 5. accent() must survive the flag scan: "--full" is six characters and used
#    to crash the hex parse before the palette was ever read.
got="$(probe '{"desktop.json":{"desktop":{"cursor":{"theme":"Bibata-Material-Ryoku"}}},"colors.json":{"primary":"#123456"},"argv":["--force","--full"]}')"
[[ $(jq -r .accent <<<"$got") == "#123456" ]] || fail "--full crashed or hijacked the accent: $got"

# 6. A real hex argument still overrides the palette.
got="$(probe '{"desktop.json":{"desktop":{"cursor":{"theme":"Bibata-Material-Ryoku"}}},"colors.json":{"primary":"#123456"},"argv":["--force","#abcdef"]}')"
[[ $(jq -r .accent <<<"$got") == "#abcdef" ]] || fail "hex override ignored: $got"

# 7. No palette file: the documented fallback, no crash.
got="$(probe '{"desktop.json":{"desktop":{"cursor":{"theme":"Bibata-Material-Ryoku"}}},"argv":["--force","--full"]}')"
[[ $(jq -r .accent <<<"$got") == "#e2342a" ]] || fail "missing palette did not fall back: $got"

echo "cursor-recolor: store shape, DYNAMIC role, flag scan all hold"
