#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

load_env
require_cmd brew

LLAMA_SERVER_BIN="$(llama_bin llama-server || true)"
if [[ -z "$LLAMA_SERVER_BIN" ]]; then
  echo "ERROR: llama-server not found. Run scripts/install.sh first."
  exit 1
fi

if [[ -f "$PID_FILE" ]]; then
  old_pid="$(cat "$PID_FILE" || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" >/dev/null 2>&1; then
    echo "ERROR: llama-server already running with pid $old_pid"
    exit 1
  fi
  rm -f "$PID_FILE"
fi

print_runtime_summary
if [[ -n "$LLAMA_MODEL_PATH" ]]; then
  if [[ ! -f "$LLAMA_MODEL_PATH" ]]; then
    echo "ERROR: LLAMA_MODEL_PATH does not exist: $LLAMA_MODEL_PATH"
    exit 1
  fi
  MODEL_ARGS=( -m "$LLAMA_MODEL_PATH" )
else
  MODEL_ARGS=( -hf "$LLAMA_HF_REPO" )
fi

# shellcheck disable=SC2206
EXTRA_ARGS=( )
if [[ -n "$LLAMA_EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  EXTRA_ARGS=( $LLAMA_EXTRA_ARGS )
fi

CMD=( "$LLAMA_SERVER_BIN" "${MODEL_ARGS[@]}" -ngl "$LLAMA_GPU_LAYERS" -c "$LLAMA_CTX_SIZE" --host "$LLAMA_SERVER_HOST" --port "$LLAMA_SERVER_PORT" )
if [[ -n "$LLAMA_EXTRA_ARGS" ]]; then
  CMD+=( "${EXTRA_ARGS[@]}" )
fi
CMD+=( "$@" )

"${CMD[@]}" >/tmp/llama-cpp-server.log 2>&1 &

echo $! > "$PID_FILE"

sleep 1
if kill -0 "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  echo "[server] started pid $(cat "$PID_FILE")"
  echo "[server] logs: /tmp/llama-cpp-server.log"
  echo "[server] health: http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/health"
else
  echo "ERROR: server failed to start"
  exit 1
fi
