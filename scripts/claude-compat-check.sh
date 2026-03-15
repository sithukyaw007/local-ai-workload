#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

gateway_port="${GATEWAY_PORT:-4000}"
gateway_key="${LITELLM_MASTER_KEY:-local-ai-workload}"
payload='{"model":"local-coder-quality","max_tokens":24,"messages":[{"role":"user","content":"Reply with exactly: compat-ok"}]}'

status_auth=$(curl -s -o /tmp/claude_compat_auth.out -w "%{http_code}" \
  "http://localhost:${gateway_port}/v1/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${gateway_key}" \
  -H "anthropic-version: 2023-06-01" \
  -d "$payload")

status_xkey=$(curl -s -o /tmp/claude_compat_xkey.out -w "%{http_code}" \
  "http://localhost:${gateway_port}/v1/messages" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${gateway_key}" \
  -H "anthropic-version: 2023-06-01" \
  -d "$payload")

models_status=$(curl -s -o /tmp/claude_compat_models.out -w "%{http_code}" \
  "http://localhost:${gateway_port}/v1/models" \
  -H "x-api-key: ${gateway_key}")

echo "messages_auth_status=${status_auth}"
echo "messages_x_api_key_status=${status_xkey}"
echo "models_x_api_key_status=${models_status}"

echo "--- snippet messages_auth ---"
head -c 300 /tmp/claude_compat_auth.out; echo

echo "--- snippet messages_x_api_key ---"
head -c 300 /tmp/claude_compat_xkey.out; echo

if [[ "$status_auth" == "200" && "$status_xkey" == "200" && "$models_status" == "200" ]]; then
  echo "COMPATIBILITY_OK: LiteLLM-only path works for Claude protocol endpoints."
  exit 0
fi

echo "COMPATIBILITY_FAIL: consider enabling Anthropic adapter in front of LiteLLM."
exit 1
