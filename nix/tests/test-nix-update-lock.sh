#!/usr/bin/env bash
set -euo pipefail

helper=${RYOKU_NIX_UPDATE_TEST_HELPER:?}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
lock="$work/update.lock"

exec 8>"$lock"
flock -n 8

for verb in update 'track stable'; do
    read -r -a args <<<"$verb"
    log="$work/${args[0]}.log"
    if RYOKU_NIX_LOCK_PATH="$lock" XDG_RUNTIME_DIR="$work" bash "$helper" "${args[@]}" >"$log" 2>&1; then
        printf 'expected %s to refuse the held mutation lock\n' "$verb" >&2
        exit 1
    fi
    grep -Fq 'another Ryoku Nix update or channel switch is already running' "$log"
done

printf 'nix-update-lock: PASS\n'
