#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 offline|hybrid"
  exit 1
fi

mode="$1"
case "$mode" in
  offline)
    cloud_fallback="false"
    offline_mode="true"
    ;;
  hybrid)
    cloud_fallback="true"
    offline_mode="false"
    ;;
  *)
    echo "Usage: $0 offline|hybrid"
    exit 1
    ;;
esac

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found."
  exit 1
fi

tmp_file="$(mktemp)"
awk -v cf="$cloud_fallback" -v om="$offline_mode" '
  BEGIN { found_cf=0; found_om=0 }
  /^ENABLE_CLOUD_FALLBACK=/ { print "ENABLE_CLOUD_FALLBACK=" cf; found_cf=1; next }
  /^CLAUDE_OFFLINE_MODE=/ { print "CLAUDE_OFFLINE_MODE=" om; found_om=1; next }
  { print }
  END {
    if (found_cf==0) print "ENABLE_CLOUD_FALLBACK=" cf
    if (found_om==0) print "CLAUDE_OFFLINE_MODE=" om
  }
' "$ENV_FILE" > "$tmp_file"
mv "$tmp_file" "$ENV_FILE"

echo "Set mode: $mode"
echo "ENABLE_CLOUD_FALLBACK=$cloud_fallback"
echo "CLAUDE_OFFLINE_MODE=$offline_mode"
echo "Restart gateway to apply: docker compose -f docker/docker-compose.yml --env-file .env up -d --force-recreate"
