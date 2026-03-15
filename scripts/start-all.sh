#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
PID_FILE="$LOG_DIR/llama-server.pid"

resolve_llama_server_bin() {
  if command -v llama-server >/dev/null 2>&1; then
    command -v llama-server
    return 0
  fi

  return 1
}

wait_for_docker() {
  local retries=60
  local i

  if docker info >/dev/null 2>&1; then
    return 0
  fi

  echo "[start] Docker daemon not ready. Attempting to open Docker Desktop..."
  open -a Docker >/dev/null 2>&1 || true

  for ((i=1; i<=retries; i++)); do
    if docker info >/dev/null 2>&1; then
      echo "[start] Docker daemon is ready"
      return 0
    fi
    sleep 2
  done

  echo "ERROR: Docker daemon is not reachable after waiting."
  return 1
}

mkdir -p "$LOG_DIR"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

echo "[start] Checking Docker"
if ! wait_for_docker; then
  exit 1
fi

echo "[start] Starting Ollama service if needed"
if command -v brew >/dev/null 2>&1 && brew services list | grep -q "^ollama\s.*started"; then
  echo "[start] Ollama already running"
else
  if command -v brew >/dev/null 2>&1; then
    brew services start ollama >/dev/null 2>&1 || true
  fi
fi

MODEL_ARGS=()
if [[ -n "${LLAMA_MODEL_PATH:-}" ]]; then
  if [[ ! -f "$LLAMA_MODEL_PATH" ]]; then
    echo "[start] LLAMA_MODEL_PATH is set but file does not exist: $LLAMA_MODEL_PATH"
    echo "[start] Skipping llama-server until phase 3 model is configured."
  fi
  if [[ -f "$LLAMA_MODEL_PATH" ]]; then
    MODEL_ARGS=( -m "$LLAMA_MODEL_PATH" )
  fi
elif [[ -n "${LLAMA_HF_REPO:-}" ]]; then
  MODEL_ARGS=( --hf-repo "$LLAMA_HF_REPO" )
  if [[ -n "${LLAMA_HF_FILE:-}" ]]; then
    MODEL_ARGS+=( --hf-file "$LLAMA_HF_FILE" )
  fi
fi

if [[ -n "${LLAMA_ALIAS:-}" && ${#MODEL_ARGS[@]} -gt 0 ]]; then
  MODEL_ARGS+=( --alias "$LLAMA_ALIAS" )
fi

if [[ ${#MODEL_ARGS[@]} -gt 0 ]]; then
  LLAMA_BIN="$(resolve_llama_server_bin || true)"
  if [[ -z "$LLAMA_BIN" ]]; then
    echo "ERROR: llama-server binary not found."
    echo "Install with Homebrew: brew install llama.cpp"
    exit 1
  fi

  echo "[start] Using llama-server binary: $LLAMA_BIN"

  if [[ -f "$PID_FILE" ]] && ps -p "$(cat "$PID_FILE")" >/dev/null 2>&1; then
    echo "[start] llama-server already running with PID $(cat "$PID_FILE")"
  else
    echo "[start] Launching llama-server on port ${LLAMA_SERVER_PORT:-8080}"
    nohup "$LLAMA_BIN" \
      "${MODEL_ARGS[@]}" \
      -c "${LLAMA_CTX:-12288}" \
      -t "${LLAMA_THREADS:-8}" \
      -ngl "${LLAMA_GPU_LAYERS:-999}" \
      -b "${LLAMA_BATCH:-1024}" \
      -ub "${LLAMA_UBATCH:-512}" \
      --host 0.0.0.0 \
      --port "${LLAMA_SERVER_PORT:-8080}" \
      > "$LOG_DIR/llama-server.log" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2
  fi
else
  echo "[start] No llama model source configured."
  echo "[start] Set LLAMA_MODEL_PATH or LLAMA_HF_REPO in .env. Skipping llama-server startup."
fi

echo "[start] Starting gateway container"
docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ROOT_DIR/.env" up -d

echo "[start] Done. Run ./scripts/healthcheck.sh"
