#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found."
  exit 1
fi

if ! command -v security >/dev/null 2>&1; then
  echo "ERROR: security command not found (macOS Keychain required)."
  exit 1
fi

new_key="$(openssl rand -hex 24)"
service="$(grep -E '^CLAUDE_API_KEYCHAIN_SERVICE=' "$ENV_FILE" | cut -d'=' -f2- || true)"
if [[ -z "$service" ]]; then
  service="local-ai-workload-gateway-key"
fi

tmp_file="$(mktemp)"
awk -v key="$new_key" '
  BEGIN { updated=0 }
  /^LITELLM_MASTER_KEY=/ { print "LITELLM_MASTER_KEY=" key; updated=1; next }
  { print }
  END { if (updated==0) print "LITELLM_MASTER_KEY=" key }
' "$ENV_FILE" > "$tmp_file"
mv "$tmp_file" "$ENV_FILE"

security delete-generic-password -s "$service" >/dev/null 2>&1 || true
security add-generic-password -a "$USER" -s "$service" -w "$new_key" >/dev/null

set -a
source "$ENV_FILE"
set +a

docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ENV_FILE" up -d --force-recreate

echo "Rotated gateway key and recreated gateway container."
echo "Keychain service: $service"
echo "Run ./scripts/healthcheck.sh to verify."
