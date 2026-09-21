#!/usr/bin/env bash
# Hermetic test for localsend.sh receive: the consent gate. Every incoming
# transfer is held at prepare-upload until the shell answers ACCEPT/DECLINE on
# stdin. ACCEPT -> 200 + sessionId; DECLINE or silence -> 403, and with no token
# issued the /upload step can never transfer the bytes.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/ryoku/shell/scripts/localsend.sh"
PORT=53317
fail=0

# Skip cleanly if the receive port is already taken (e.g. a live receiver on a
# running desktop), so this never red-fails against a real session.
if (exec 3<>"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null; then
  echo "localsend-receive: SKIP (port $PORT already in use)"
  exit 0
fi
for bin in python3 curl openssl awk; do
  command -v "$bin" >/dev/null 2>&1 || { echo "localsend-receive: SKIP ($bin missing)"; exit 0; }
done

work=$(mktemp -d)
cleanup() { [ -n "${rxpid:-}" ] && kill "$rxpid" 2>/dev/null; exec 9>&- 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT
export HOME="$work"
mkdir -p "$work/.cache" "$work/stash"

mkfifo "$work/in"
# Hold the FIFO open read+write so the receiver's stdin never sees EOF and our
# verdict writes have somewhere to land. RDWR open does not block on a FIFO.
exec 9<>"$work/in"

RYOKU_LS_ACCEPT_TIMEOUT=2 STASH_DIR="$work/stash" \
  bash "$SCRIPT" receive "Test RX" <"$work/in" >"$work/out" 2>/dev/null &
rxpid=$!

offer='{"info":{"alias":"Tester","fingerprint":"abc"},"files":{"f1":{"id":"f1","fileName":"hi.txt","size":2,"fileType":"text/plain"}}}'
prepare() {  # prepare <codefile> <bodyfile>
  curl -sk -o "$2" -w '%{http_code}' --max-time 12 \
    -X POST "https://127.0.0.1:$PORT/api/localsend/v2/prepare-upload" \
    -H "Content-Type: application/json" -d "$offer" >"$1"
}

# The receiver's stdout grows across cases; truncating a file the server holds
# open would punch sparse NULs into it, so gate on the running OFFER count and
# read with grep -a (treat as text regardless).
offers=0
wait_offer() {
  local _
  offers=$((offers + 1))
  for _ in $(seq 1 100); do
    [ "$(grep -ac '^OFFER' "$work/out")" -ge "$offers" ] && return 0
    sleep 0.1
  done
  return 1
}
latest_sid() { grep -a "^OFFER" "$work/out" | tail -1 | awk -F'\t' '{print $4}'; }

ready=0
for _ in $(seq 1 100); do grep -aq "^READY" "$work/out" && { ready=1; break; }; sleep 0.1; done
if [ "$ready" != 1 ]; then echo "::error::receiver never became READY"; exit 1; fi

# Case 1: ACCEPT opens the gate.
prepare "$work/c1" "$work/b1" & cp=$!
if ! wait_offer; then echo "::error::no OFFER announced"; fail=1; fi
sid=$(latest_sid)
if [ -n "$sid" ]; then printf 'ACCEPT\t%s\n' "$sid" >&9; else echo "::error::no sid in OFFER"; fail=1; fi
wait "$cp"
if [ "$(cat "$work/c1")" = "200" ] && grep -q '"sessionId"' "$work/b1"; then
  echo "  ok: ACCEPT opens the gate (200 + sessionId)"
else
  echo "::error::FAIL: ACCEPT -> code $(cat "$work/c1"), body $(cat "$work/b1")"; fail=1
fi

# Case 2: DECLINE refuses the transfer.
prepare "$work/c2" "$work/b2" & cp=$!
if wait_offer; then printf 'DECLINE\t%s\n' "$(latest_sid)" >&9; else echo "::error::no OFFER for decline"; fail=1; fi
wait "$cp"
if [ "$(cat "$work/c2")" = "403" ]; then
  echo "  ok: DECLINE refuses the transfer (403)"
else
  echo "::error::FAIL: DECLINE -> $(cat "$work/c2")"; fail=1
fi

# Case 3: no answer auto-declines after the timeout.
prepare "$work/c3" "$work/b3" & cp=$!
wait "$cp"
if [ "$(cat "$work/c3")" = "403" ]; then
  echo "  ok: silence auto-declines (403)"
else
  echo "::error::FAIL: timeout -> $(cat "$work/c3")"; fail=1
fi

# Case 4: upload without a valid token is refused, so declined bytes never land.
uc=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 12 \
  -X POST "https://127.0.0.1:$PORT/api/localsend/v2/upload?sessionId=x&fileId=f1&token=bogus" \
  --data-binary "hi")
if [ "$uc" = "403" ]; then
  echo "  ok: upload without a token is refused (403)"
else
  echo "::error::FAIL: bogus upload -> $uc"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "localsend-receive: all checks passed"
else
  echo "localsend-receive: FAILED"; exit 1
fi
