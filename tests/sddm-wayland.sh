#!/usr/bin/env bash
# Verify the installer writes a native Qt Wayland greeter configuration.
set -euo pipefail

repo=${RYOKU_PATH:-$(cd "$(dirname "$0")/.." && pwd)}
setup=$repo/ryoku/lockscreen/sddm/setup

fail() { printf 'sddm-wayland: %s\n' "$*" >&2; exit 1; }

out=$(RYOKU_DRYRUN=1 "$setup" --dry-run)
grep -Fxq 'qt5-wayland' "$repo/system/packages/base.packages" ||
  fail "base package set omits the Qt5 Wayland plugin needed by Qt5 SDDM"
grep -Fq "  'qt5-wayland'" "$repo/release/packages/ryoku-desktop/PKGBUILD" ||
  fail "ryoku-desktop omits the Qt5 Wayland plugin needed by existing systems"
grep -Fq "  'qt6-5compat'" "$repo/release/packages/ryoku-desktop/PKGBUILD" ||
  fail "ryoku-desktop must retain Qt6 compatibility imports"
for line in \
  '[General]' \
  'DisplayServer=wayland' \
  'GreeterEnvironment=QT_QPA_PLATFORM=wayland' \
  '[Wayland]' \
  'CompositorCommand='; do

  grep -Fq "$line" <<<"$out" || fail "SDDM setup omits $line"
done

# The login screen draws its pointer from the freedesktop "default" cursor theme
# when SDDM's Wayland greeter ignores XCURSOR_THEME; the setup must establish
# that fallback (Inherits the shipped Bibata set) so the pointer is never blank.
# Grep the source, not the dry-run: on a CI box that already has a default theme
# the setup correctly skips the write.
grep -Fq '/usr/share/icons/default' "$setup" ||
  fail "SDDM setup does not establish the default cursor theme (login screen has no pointer)"
grep -Fq 'Inherits=Bibata-Modern-Ice' "$setup" ||
  fail "SDDM setup default cursor theme does not inherit the shipped Bibata set"

printf 'sddm-wayland: PASS\n'
