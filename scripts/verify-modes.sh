#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/mode-verification-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

GATEWAY_PORT="${GATEWAY_PORT:-4000}"
GATEWAY_KEY="${LITELLM_MASTER_KEY:-local-ai-workload}"
FAILURES=0

log() {
  echo "$1" | tee -a "$LOG_FILE"
}

check_http_200() {
  local label="$1"
  local cmd="$2"
  local code
  code=$(eval "$cmd")
  if [[ "$code" == "200" ]]; then
    log "[ok] $label -> status 200"
  else
    log "[fail] $label -> status $code"
    FAILURES=$((FAILURES + 1))
  fi
}

wait_for_gateway() {
  local retries=30
  local i
  local code

  for ((i=1; i<=retries; i++)); do
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${GATEWAY_PORT}/health/liveliness" || true)
    if [[ "$code" == "200" ]]; then
      log "[ok] gateway readiness -> status 200"
      return 0
    fi
    sleep 2
  done

  log "[fail] gateway readiness -> timeout waiting for status 200"
  FAILURES=$((FAILURES + 1))
  return 1
}

check_mode_flags() {
  local mode="$1"
  local expected_cloud
  local expected_offline
  local cloud
  local offline

  if [[ "$mode" == "offline" ]]; then
    expected_cloud="false"
    expected_offline="true"
  else
    expected_cloud="true"
    expected_offline="false"
  fi

  cloud=$(grep -E '^ENABLE_CLOUD_FALLBACK=' "$ROOT_DIR/.env" | cut -d'=' -f2- || true)
  offline=$(grep -E '^CLAUDE_OFFLINE_MODE=' "$ROOT_DIR/.env" | cut -d'=' -f2- || true)

  if [[ "$cloud" == "$expected_cloud" && "$offline" == "$expected_offline" ]]; then
    log "[ok] mode flags ($mode) -> ENABLE_CLOUD_FALLBACK=$cloud, CLAUDE_OFFLINE_MODE=$offline"
  else
    log "[fail] mode flags ($mode) -> got ENABLE_CLOUD_FALLBACK=$cloud, CLAUDE_OFFLINE_MODE=$offline"
    FAILURES=$((FAILURES + 1))
  fi
}

run_mode() {
  local mode="$1"
  log ""
  log "===== MODE: $mode ====="

  "$ROOT_DIR/scripts/claude-mode.sh" "$mode" | tee -a "$LOG_FILE"
  check_mode_flags "$mode"

  docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ROOT_DIR/.env" up -d --force-recreate >/dev/null

  wait_for_gateway || return 0

  check_http_200 "gateway liveliness" "curl -s -o /dev/null -w '%{http_code}' http://localhost:${GATEWAY_PORT}/health/liveliness"
  check_http_200 "gateway models" "curl -s -o /dev/null -w '%{http_code}' -H 'x-api-key: ${GATEWAY_KEY}' http://localhost:${GATEWAY_PORT}/v1/models"

  local anthropic_payload
  anthropic_payload='{"model":"local-coder-quality","max_tokens":24,"messages":[{"role":"user","content":"Reply with exactly: mode-ok"}]}'
  check_http_200 "anthropic messages local-coder-quality" "curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -H 'x-api-key: ${GATEWAY_KEY}' -H 'anthropic-version: 2023-06-01' -d '${anthropic_payload}' http://localhost:${GATEWAY_PORT}/v1/messages"

  local openai_payload
  openai_payload='{"model":"local-general","messages":[{"role":"user","content":"Reply with exactly: general-ok"}],"max_tokens":24,"temperature":0.2}'
  check_http_200 "chat completions local-general" "curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -H 'Authorization: Bearer ${GATEWAY_KEY}' -d '${openai_payload}' http://localhost:${GATEWAY_PORT}/v1/chat/completions"

  if [[ "$mode" == "hybrid" ]]; then
    if grep -Eq '^CLOUD_API_KEY=.+' "$ROOT_DIR/.env"; then
      local cloud_payload
      cloud_payload='{"model":"cloud-fallback","messages":[{"role":"user","content":"Reply with exactly: cloud-ok"}],"max_tokens":24,"temperature":0.2}'
      check_http_200 "hybrid cloud-fallback" "curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -H 'Authorization: Bearer ${GATEWAY_KEY}' -d '${cloud_payload}' http://localhost:${GATEWAY_PORT}/v1/chat/completions"
    else
      log "[skip] hybrid cloud-fallback -> CLOUD_API_KEY not set"
    fi
  fi
}

log "Mode verification log: $LOG_FILE"
run_mode offline
run_mode hybrid

log ""
if [[ "$FAILURES" -eq 0 ]]; then
  log "RESULT: PASS"
  exit 0
else
  log "RESULT: FAIL (failures=$FAILURES)"
  exit 1
fi
