#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
PID_FILE="$ROOT_DIR/.llama-server.pid"

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
  elif [[ -f "$ROOT_DIR/.env.example" ]]; then
    set -a
    source "$ROOT_DIR/.env.example"
    set +a
  fi

  : "${LLAMA_SERVER_PORT:=8080}"
  : "${LLAMA_SERVER_HOST:=127.0.0.1}"
  : "${LLAMA_CTX_SIZE:=4096}"
  : "${LLAMA_GPU_LAYERS:=999}"
  : "${LLAMA_MODEL_PATH:=}"
  : "${LLAMA_HF_REPO:=bartowski/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M}"
  : "${LLAMA_EXTRA_ARGS:=}"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing command: $cmd"
    exit 1
  fi
}

llama_bin() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  local brew_prefix
  brew_prefix="$(brew --prefix 2>/dev/null || true)"
  if [[ -n "$brew_prefix" && -x "$brew_prefix/bin/$name" ]]; then
    echo "$brew_prefix/bin/$name"
    return 0
  fi

  return 1
}

resolve_model_args() {
  if [[ -n "$LLAMA_MODEL_PATH" ]]; then
    if [[ ! -f "$LLAMA_MODEL_PATH" ]]; then
      echo "ERROR: LLAMA_MODEL_PATH does not exist: $LLAMA_MODEL_PATH"
      exit 1
    fi
    echo "-m" "$LLAMA_MODEL_PATH"
  else
    echo "-hf" "$LLAMA_HF_REPO"
  fi
}

print_runtime_summary() {
  echo "[config] host=$LLAMA_SERVER_HOST port=$LLAMA_SERVER_PORT ctx=$LLAMA_CTX_SIZE ngl=$LLAMA_GPU_LAYERS"
  if [[ -n "$LLAMA_MODEL_PATH" ]]; then
    echo "[config] model=local:$LLAMA_MODEL_PATH"
  else
    echo "[config] model=hf:$LLAMA_HF_REPO"
  fi
}
