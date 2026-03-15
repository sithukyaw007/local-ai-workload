#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

load_env

echo "[install] Checking prerequisites"
require_cmd xcode-select
require_cmd curl

if ! xcode-select -p >/dev/null 2>&1; then
  echo "ERROR: Xcode Command Line Tools not found. Run: xcode-select --install"
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: Homebrew is not installed. Install from https://brew.sh"
  exit 1
fi

echo "[install] Installing llama.cpp via Homebrew"
brew install llama.cpp

echo "[install] Verifying binaries"
LLAMA_CLI_BIN="$(llama_bin llama-cli || true)"
LLAMA_SERVER_BIN="$(llama_bin llama-server || true)"

if [[ -z "$LLAMA_CLI_BIN" || -z "$LLAMA_SERVER_BIN" ]]; then
  echo "ERROR: llama-cli or llama-server not found in PATH after brew install"
  exit 1
fi

echo "[install] llama-cli: $LLAMA_CLI_BIN"
echo "[install] llama-server: $LLAMA_SERVER_BIN"
"$LLAMA_CLI_BIN" --version | head -n 3 || true

echo "[install] Preparing local env file"
if [[ ! -f "$ROOT_DIR/.env" ]]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  echo "[install] Created $ROOT_DIR/.env"
else
  echo "[install] Found existing $ROOT_DIR/.env (kept unchanged)"
fi

echo "[install] Done"
