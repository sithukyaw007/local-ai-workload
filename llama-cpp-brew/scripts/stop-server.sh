#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

load_env

if [[ ! -f "$PID_FILE" ]]; then
  echo "[server] no pid file found"
  exit 0
fi

pid="$(cat "$PID_FILE" || true)"
if [[ -z "$pid" ]]; then
  rm -f "$PID_FILE"
  echo "[server] stale pid file removed"
  exit 0
fi

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid"
  sleep 1
  if kill -0 "$pid" >/dev/null 2>&1; then
    kill -9 "$pid"
  fi
  echo "[server] stopped pid $pid"
else
  echo "[server] process not running, cleaning pid file"
fi

rm -f "$PID_FILE"
