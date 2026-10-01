#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/caching.sh"
exec python3 "$(dirname "$0")/focus_daemon.py"
