#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

wait_for_docker() {
  local retries=60
  local i

  if docker info >/dev/null 2>&1; then
    return 0
  fi

  echo "[bootstrap] Docker daemon not ready. Attempting to open Docker Desktop..."
  open -a Docker >/dev/null 2>&1 || true

  for ((i=1; i<=retries; i++)); do
    if docker info >/dev/null 2>&1; then
      echo "[bootstrap] Docker daemon is ready"
      return 0
    fi
    sleep 2
  done

  echo "ERROR: Docker daemon is not reachable after waiting."
  return 1
}

echo "[bootstrap] local-ai-workload root: $ROOT_DIR"
echo "[bootstrap] setup scripts dir: $ROOT_DIR/scripts"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker command not found. Install Docker Desktop first."
  exit 1
fi

if ! wait_for_docker; then
  exit 1
fi

if [[ -x "$ROOT_DIR/scripts/setup_docker_vllm_metal.sh" ]]; then
  echo "[bootstrap] Running scripts/setup_docker_vllm_metal.sh"
  "$ROOT_DIR/scripts/setup_docker_vllm_metal.sh"
else
  echo "[bootstrap] WARNING: $ROOT_DIR/scripts/setup_docker_vllm_metal.sh not executable or missing"
fi

if [[ -x "$ROOT_DIR/scripts/setup_ai_toolkit.sh" ]]; then
  echo "[bootstrap] Running scripts/setup_ai_toolkit.sh"
  "$ROOT_DIR/scripts/setup_ai_toolkit.sh"
else
  echo "[bootstrap] WARNING: $ROOT_DIR/scripts/setup_ai_toolkit.sh not executable or missing"
fi

echo "[bootstrap] Completed. Next: ./scripts/start-all.sh"
