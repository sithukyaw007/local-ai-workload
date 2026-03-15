#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/claude-preflight-$(date +%Y%m%d-%H%M%S).log"
MODE="${1:-offline}"

mkdir -p "$LOG_DIR"

log() {
  echo "$1" | tee -a "$LOG_FILE"
}

check_200() {
  local label="$1"
  local url="$2"
  local header_name="${3:-}"
  local header_value="${4:-}"
  local code

  if [[ -n "$header_name" ]]; then
    code=$(curl -s -o /dev/null -w "%{http_code}" -H "$header_name: $header_value" "$url" || true)
  else
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)
  fi

  if [[ "$code" == "200" ]]; then
    log "[ok] $label -> status 200"
  else
    log "[fail] $label -> status $code"
    exit 1
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

  log "[fail] gateway readiness timeout"
  exit 1
}

need_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "[fail] missing command: $cmd"
    exit 1
  fi
}

log "Preflight log: $LOG_FILE"
log "Selected mode: $MODE"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  log "[fail] .env not found in $ROOT_DIR"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a
GATEWAY_PORT="${GATEWAY_PORT:-4000}"
GATEWAY_KEY="${LITELLM_MASTER_KEY:-local-ai-workload}"

need_cmd claude
need_cmd docker
need_cmd curl
need_cmd jq

log "[step] Start stack"
"$ROOT_DIR/scripts/start-all.sh" | tee -a "$LOG_FILE"

log "[step] Initialize keychain-backed key"
"$ROOT_DIR/scripts/claude-keychain-init.sh" | tee -a "$LOG_FILE"

log "[step] Install project-local Claude settings"
"$ROOT_DIR/scripts/install-claude-local-settings.sh" | tee -a "$LOG_FILE"

log "[step] Verify Claude protocol compatibility"
"$ROOT_DIR/scripts/claude-compat-check.sh" | tee -a "$LOG_FILE"

log "[step] Set operating mode"
if [[ "$MODE" != "offline" && "$MODE" != "hybrid" ]]; then
  log "[fail] invalid mode: $MODE (use offline or hybrid)"
  exit 1
fi
"$ROOT_DIR/scripts/claude-mode.sh" "$MODE" | tee -a "$LOG_FILE"

docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ROOT_DIR/.env" up -d --force-recreate >/dev/null

log "[step] Health checks"
wait_for_gateway
"$ROOT_DIR/scripts/healthcheck.sh" | tee -a "$LOG_FILE"
check_200 "gateway liveliness" "http://localhost:${GATEWAY_PORT}/health/liveliness"
check_200 "gateway models" "http://localhost:${GATEWAY_PORT}/v1/models" "x-api-key" "$GATEWAY_KEY"
anthropic_probe='{"model":"local-coder-quality","max_tokens":16,"messages":[{"role":"user","content":"health"}]}'
anthropic_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${GATEWAY_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d "$anthropic_probe" \
  "http://localhost:${GATEWAY_PORT}/v1/messages" || true)
if [[ "$anthropic_code" == "200" ]]; then
  log "[ok] gateway anthropic messages -> status 200"
else
  log "[fail] gateway anthropic messages -> status $anthropic_code"
  exit 1
fi

log "[step] Claude local-model smoke test (-p)"
set +e
SMOKE_OUTPUT=$(cd "$ROOT_DIR" && claude -p --no-session-persistence --allowed-tools "" --model "local-coder-quality" "Reply with exactly: claude-local-ok" 2>&1)
SMOKE_EXIT=$?
set -e
printf "%s\n" "$SMOKE_OUTPUT" | tee -a "$LOG_FILE"

if [[ "$SMOKE_EXIT" -ne 0 ]]; then
  log "[warn] quality smoke failed, retrying with local-coder-fast"
  set +e
  SMOKE_OUTPUT=$(cd "$ROOT_DIR" && claude -p --no-session-persistence --allowed-tools "" --model "local-coder-fast" "Reply with exactly: claude-local-ok" 2>&1)
  SMOKE_EXIT=$?
  set -e
  printf "%s\n" "$SMOKE_OUTPUT" | tee -a "$LOG_FILE"
  if [[ "$SMOKE_EXIT" -ne 0 ]]; then
    log "[fail] Claude smoke test failed (exit=$SMOKE_EXIT)"
    exit 1
  fi
fi

log "[ok] Claude smoke test passed"
log "RESULT: PASS"
log "Next interactive step: run 'claude' in $ROOT_DIR and execute /status"
