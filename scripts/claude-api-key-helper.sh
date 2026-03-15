#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

service="${CLAUDE_API_KEYCHAIN_SERVICE:-local-ai-workload-gateway-key}"

# Preferred source: macOS Keychain.
if command -v security >/dev/null 2>&1; then
  if key=$(security find-generic-password -s "$service" -w 2>/dev/null); then
    printf "%s" "$key"
    exit 0
  fi
fi

# Fallback source for recovery: env-backed gateway key.
if [[ -n "${LITELLM_MASTER_KEY:-}" ]]; then
  printf "%s" "$LITELLM_MASTER_KEY"
  exit 0
fi

echo "ERROR: no API key available. Run ./scripts/claude-keychain-init.sh first." >&2
exit 1
