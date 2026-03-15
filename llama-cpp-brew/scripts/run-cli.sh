#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

load_env
require_cmd brew

LLAMA_CLI_BIN="$(llama_bin llama-cli || true)"
if [[ -z "$LLAMA_CLI_BIN" ]]; then
  echo "ERROR: llama-cli not found. Run scripts/install.sh first."
  exit 1
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

CMD=( "$LLAMA_CLI_BIN" "${MODEL_ARGS[@]}" -ngl "$LLAMA_GPU_LAYERS" -c "$LLAMA_CTX_SIZE" -cnv )
if [[ -n "$LLAMA_EXTRA_ARGS" ]]; then
  CMD+=( "${EXTRA_ARGS[@]}" )
fi
CMD+=( "$@" )

exec "${CMD[@]}"
