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

check() {
  local name="$1"
  local url="$2"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)
  if [[ "$code" == "200" ]]; then
    echo "[ok]   $name -> $url"
  else
    echo "[fail] $name -> $url (status: $code)"
  fi
}

echo "[health] Running endpoint checks"
check "MLX server" "http://localhost:${MLX_SERVER_PORT:-8000}/v1/models"

check "MLX server" "http://localhost:${MLX_SERVER_PORT:-8000}/v1/models"

check "Gateway live" "http://localhost:${GATEWAY_PORT:-4000}/health/liveliness"

gateway_key="${LITELLM_MASTER_KEY:-local-ai-workload}"

gateway_models_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $gateway_key" \
  "http://localhost:${GATEWAY_PORT:-4000}/v1/models" || true)
if [[ "$gateway_models_code" == "200" ]]; then
  echo "[ok]   Gateway models -> http://localhost:${GATEWAY_PORT:-4000}/v1/models"
else
  echo "[fail] Gateway models -> http://localhost:${GATEWAY_PORT:-4000}/v1/models (status: $gateway_models_code)"
fi

anthropic_probe='{"model":"local-coder-quality","max_tokens":16,"messages":[{"role":"user","content":"health"}]}'
gateway_messages_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $gateway_key" \
  -H "anthropic-version: 2023-06-01" \
  -d "$anthropic_probe" \
  "http://localhost:${GATEWAY_PORT:-4000}/v1/messages" || true)
if [[ "$gateway_messages_code" == "200" ]]; then
  echo "[ok]   Gateway anthropic messages -> http://localhost:${GATEWAY_PORT:-4000}/v1/messages"
else
  echo "[fail] Gateway anthropic messages -> http://localhost:${GATEWAY_PORT:-4000}/v1/messages (status: $gateway_messages_code)"
fi

echo "[health] Completed"
