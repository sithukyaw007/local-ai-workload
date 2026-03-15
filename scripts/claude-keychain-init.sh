#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

if ! command -v security >/dev/null 2>&1; then
  echo "ERROR: security command not found (macOS Keychain required)."
  exit 1
fi

service="${CLAUDE_API_KEYCHAIN_SERVICE:-local-ai-workload-gateway-key}"
key="${LITELLM_MASTER_KEY:-}"

if [[ -z "$key" ]]; then
  echo "ERROR: LITELLM_MASTER_KEY is empty in .env"
  exit 1
fi

security delete-generic-password -s "$service" >/dev/null 2>&1 || true
security add-generic-password -a "$USER" -s "$service" -w "$key" >/dev/null

echo "Stored gateway key in Keychain service: $service"
echo "Next: ./scripts/install-claude-local-settings.sh"
