#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
MLX_PID_FILE="$LOG_DIR/mlx-server.pid"

mkdir -p "$LOG_DIR"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

wait_for_docker() {
  local retries=60

  if docker info >/dev/null 2>&1; then
    return 0
  fi

  echo "[start] Docker daemon not ready. Attempting to open Docker Desktop..."
  open -a Docker >/dev/null 2>&1 || true

  for ((i=1; i<=retries; i++)); do
    if docker info >/dev/null 2>&1; then
      echo "[start] Docker daemon is ready"
      return 0
    fi
    sleep 2
  done

  echo "ERROR: Docker daemon is not reachable after waiting."
  return 1
}

echo "[start] Checking Docker"
if ! wait_for_docker; then
  exit 1
fi

# --- MLX-LM Server ---
MLX_PORT="${MLX_SERVER_PORT:-8000}"
MLX_PATH="${MLX_SERVER_PATH:-/Users/sithukyaw/work/local-mac-ai}"
MLX_MODEL_ID="${MLX_MODEL:-mlx-community/Qwen3.5-35B-A3B-4bit}"

if [[ -f "$MLX_PID_FILE" ]] && ps -p "$(cat "$MLX_PID_FILE")" >/dev/null 2>&1; then
  echo "[start] mlx_lm.server already running with PID $(cat "$MLX_PID_FILE")"
else
  if [[ ! -d "$MLX_PATH/.venv" ]]; then
    echo "ERROR: MLX venv not found at $MLX_PATH/.venv"
    echo "Set up the local-mac-ai project first: cd $MLX_PATH && python3 -m venv .venv && pip install -r requirements.txt"
    exit 1
  fi

  echo "[start] Launching mlx_lm.server on port $MLX_PORT (DEBUG logging)"
  echo "  Model: $MLX_MODEL_ID"
  echo "  Logs:  $LOG_DIR/mlx-server.log"
  echo "  Stream: tail -f $LOG_DIR/mlx-server.log"
  nohup "$MLX_PATH/.venv/bin/python" -m mlx_lm server \
    --model "$MLX_MODEL_ID" \
    --port "$MLX_PORT" \
    --log-level DEBUG \
    > "$LOG_DIR/mlx-server.log" 2>&1 &
  echo $! > "$MLX_PID_FILE"

  # Wait for server to be ready
  echo -n "[start] Waiting for mlx_lm.server..."
  for ((i=1; i<=30; i++)); do
    if curl -s "http://localhost:$MLX_PORT/v1/models" >/dev/null 2>&1; then
      echo " ready!"
      break
    fi
    echo -n "."
    sleep 2
  done

  if ! curl -s "http://localhost:$MLX_PORT/v1/models" >/dev/null 2>&1; then
    echo " FAILED (check $LOG_DIR/mlx-server.log)"
    exit 1
  fi
fi

echo "[start] Starting gateway container"
docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ROOT_DIR/.env" up -d

echo "[start] Done. Run ./scripts/healthcheck.sh"
