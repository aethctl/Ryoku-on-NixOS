#!/bin/bash
SCHEME="RyogamiMatugen"
ALT="${SCHEME}Alt"
SCHEME_DIR="$HOME/.local/share/color-schemes"

command -v plasma-apply-colorscheme >/dev/null || exit 0

cp "$SCHEME_DIR/$SCHEME.colors" "$SCHEME_DIR/$ALT.colors" 2>/dev/null
sed -i "s/^Name=.*/Name=$ALT/" "$SCHEME_DIR/$ALT.colors" 2>/dev/null

CURRENT=$(grep '^ColorScheme=' "$HOME/.config/kdeglobals" | cut -d= -f2)

if [ "$CURRENT" = "$ALT" ]; then
    plasma-apply-colorscheme "$SCHEME"
else
    plasma-apply-colorscheme "$ALT"
fi