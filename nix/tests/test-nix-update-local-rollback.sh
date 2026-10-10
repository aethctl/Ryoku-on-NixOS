#!/usr/bin/env bash
set -euo pipefail

helper=${RYOKU_NIX_UPDATE_TEST_HELPER:?}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

remote="$work/remote.git"
source="$work/source"
flake="$work/flake"
bin="$work/bin"
mkdir -p "$flake" "$bin"

git init --bare -q "$remote"
git clone -q "$remote" "$source"
git -C "$source" config user.name test
git -C "$source" config user.email test@example.invalid
printf '1\n' >"$source/VERSION"
git -C "$source" add VERSION
git -C "$source" commit -qm initial
git -C "$source" branch -M main
git -C "$source" push -q -u origin main
old_head=$(git -C "$source" rev-parse HEAD)

other="$work/other"
git clone -q "$remote" "$other"
git -C "$other" config user.name test
git -C "$other" config user.email test@example.invalid
git -C "$other" checkout -q main
printf '2\n' >"$other/VERSION"
git -C "$other" add VERSION
git -C "$other" commit -qm update
git -C "$other" push -q origin main

cat >"$flake/flake.lock" <<JSON
{"nodes":{"root":{"inputs":{"ryoku":"ryoku"}},"ryoku":{"original":{"type":"path","path":"$source"},"locked":{"type":"path","path":"$source"}}},"root":"root","version":7}
JSON
cp "$flake/flake.lock" "$work/lock.before"

cat >"$bin/sudo" <<'SH'
#!/usr/bin/env bash
exec "$@"
SH
cat >"$bin/nix" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = eval ]; then
    printf '["testhost"]\n'
    exit 0
fi
if [ "${1:-} ${2:-}" = 'flake update' ]; then
    exit 0
fi
if [ "${1:-}" = build ]; then
    exit 42
fi
exit 1
SH
cat >"$bin/nixos-rebuild" <<'SH'
#!/usr/bin/env bash
exit 99
SH
chmod +x "$bin"/*

if PATH="$bin:$PATH" \
   RYOKU_NIX_FLAKE="$flake" \
   RYOKU_NIX_HOST=testhost \
   RYOKU_NIX_SUDO="$bin/sudo" \
   RYOKU_NIX_VERSION=1 \
   XDG_RUNTIME_DIR="$work" \
   bash "$helper" update >"$work/out" 2>&1; then
    printf 'expected simulated build failure\n' >&2
    exit 1
fi

[ "$(git -C "$source" rev-parse HEAD)" = "$old_head" ] || {
    printf 'local checkout was not restored after failed update\n' >&2
    cat "$work/out" >&2
    exit 1
}
cmp -s "$work/lock.before" "$flake/flake.lock" || {
    printf 'flake.lock was not restored after failed update\n' >&2
    exit 1
}

grep -Fq 'Restoring the previous Ryoku local checkout.' "$work/out"
printf 'nix-update-local-rollback: PASS\n'
