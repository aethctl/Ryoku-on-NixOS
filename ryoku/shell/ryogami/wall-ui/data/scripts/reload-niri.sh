#!/bin/sh
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ryogami-wall"
COLOR=$(cat "$CACHE/niri-primary-color" 2>/dev/null | tr -d '[:space:]')
[ -z "$COLOR" ] && exit 0

NIRI_CFG="$HOME/.config/niri/config.kdl"
[ -f "$NIRI_CFG" ] || exit 0

sed -i "s/active-color \"#[0-9a-fA-F]*\" \/\/ matugen:active-color/active-color \"#${COLOR}\" \/\/ matugen:active-color/" "$NIRI_CFG"
