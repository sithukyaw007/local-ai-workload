#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="$ROOT_DIR/benchmarks"
OUT_DIR="$ROOT_DIR/logs"
OUT_FILE="$OUT_DIR/benchmark-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$OUT_DIR"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

GATEWAY_KEY="${LITELLM_MASTER_KEY:-local-ai-workload}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required. Install with: brew install jq"
  exit 1
fi

run_case() {
  local name="$1"
  local prompt_file="$2"
  local model="$3"
  local prompt
  local raw
  local body
  local latency
  local payload
  local prompt_tokens
  local completion_tokens
  local total_tokens
  prompt="$(cat "$prompt_file")"

  echo "===== $name ($model) =====" | tee -a "$OUT_FILE"

  payload=$(jq -n \
    --arg model "$model" \
    --arg prompt "$prompt" \
    '{
      model: $model,
      messages: [{ role: "user", content: $prompt }],
      temperature: 0.2,
      max_tokens: 1200
    }')

  raw=$(curl -sS -w '\n__CURL_TIME_TOTAL__:%{time_total}\n' "http://localhost:${GATEWAY_PORT:-4000}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $GATEWAY_KEY" \
    -d "$payload")

  latency=$(printf "%s\n" "$raw" | tail -n 1 | sed 's/^__CURL_TIME_TOTAL__://')
  body=$(printf "%s\n" "$raw" | sed '$d')

  prompt_tokens=$(printf "%s" "$body" | jq -r '.usage.prompt_tokens // 0')
  completion_tokens=$(printf "%s" "$body" | jq -r '.usage.completion_tokens // 0')
  total_tokens=$(printf "%s" "$body" | jq -r '.usage.total_tokens // 0')

  echo "latency_sec=$latency" | tee -a "$OUT_FILE"
  echo "usage_prompt_tokens=$prompt_tokens" | tee -a "$OUT_FILE"
  echo "usage_completion_tokens=$completion_tokens" | tee -a "$OUT_FILE"
  echo "usage_total_tokens=$total_tokens" | tee -a "$OUT_FILE"

  printf "%s" "$body" \
    | jq -r '.choices[0].message.content // .error.message // "no output"' \
    | tee -a "$OUT_FILE"

  echo "" | tee -a "$OUT_FILE"
}

run_case "Code Review" "$BENCH_DIR/code-review.txt" "local-coder-quality"
run_case "Design Critique" "$BENCH_DIR/design-critique.txt" "local-general"

echo "Benchmark log: $OUT_FILE"
