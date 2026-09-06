#!/usr/bin/env sh
# Sign the Ryoku theme extension for Zen / Firefox.
#
# Zen is a branded release build (MOZ_REQUIRE_SIGNING on): it will not load an
# unsigned extension, and xpinstall.signatures.required is honoured only in dev
# builds. So the palette-follow theme can be auto-installed only after AMO has
# signed it. Signing is a one-time, credentialed step a maintainer runs; the API
# key never leaves this machine. Mint an unlisted-signing key at
#
#   https://addons.mozilla.org/developers/addon/api/key/
#
# then export it and run this from a source checkout:
#
#   export WEB_EXT_API_KEY='user:12345:67'
#   export WEB_EXT_API_SECRET='...'
#   sh ryoku/browser/sign.sh
#
# It writes ryoku-theme.xpi next to this script. The ryoku-desktop package
# installs that file to /usr/share/ryoku/browser/, and `ryoku doctor` then adds
# the extension to Zen's enterprise policy automatically (see the reconcile_zen
# reconciler). Without the xpi nothing breaks: the policy simply omits it.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

if [ -z "${WEB_EXT_API_KEY:-}" ] || [ -z "${WEB_EXT_API_SECRET:-}" ]; then
	echo "sign.sh: set WEB_EXT_API_KEY and WEB_EXT_API_SECRET (an AMO unlisted key)." >&2
	echo "         https://addons.mozilla.org/developers/addon/api/key/" >&2
	exit 2
fi

webext="web-ext"
command -v web-ext >/dev/null 2>&1 || webext="npx --yes web-ext"

sh build.sh

rm -rf web-ext-artifacts
# shellcheck disable=SC2086  # $webext may be "npx --yes web-ext", two words on purpose.
$webext sign \
	--channel=unlisted \
	--source-dir=dist/firefox \
	--artifacts-dir=web-ext-artifacts \
	--api-key="$WEB_EXT_API_KEY" \
	--api-secret="$WEB_EXT_API_SECRET"

signed=$(find web-ext-artifacts -maxdepth 1 -name '*.xpi' 2>/dev/null | head -1)
[ -n "$signed" ] || { echo "sign.sh: AMO returned no signed xpi" >&2; exit 1; }
cp "$signed" ryoku-theme.xpi
echo "sign.sh: wrote $here/ryoku-theme.xpi"
echo "sign.sh: ship it (ryoku-desktop installs it; doctor wires it into Zen)."
