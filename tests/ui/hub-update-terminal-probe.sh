#!/usr/bin/env bash
# hub-update-terminal-probe: Hub updates keep interactive prompts in Kitty.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
source="$here/../../ryoku/hub/quickshell/pages/UpdatesPage.qml"
launch="$(sed -n '/function startUpdate()/,/^    }/p' "$source")"

[[ "$launch" == *'Spawn.run(["kitty", "-e", "sh", "-c", "exec ryoku update"])'* ]] || {
    echo "hub-update-terminal-probe: expected Kitty to execute ryoku update directly" >&2
    exit 1
}
[[ "$launch" != *'RYOKU_UPDATE_UI'* ]] || {
    echo "hub-update-terminal-probe: Hub update must not wait for a hidden Hub prompt" >&2
    exit 1
}

echo "hub-update-terminal-probe: update prompts remain visible in Kitty"
