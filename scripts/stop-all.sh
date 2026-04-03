#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MLX_PID_FILE="$ROOT_DIR/logs/mlx-server.pid"

echo "[stop] Stopping gateway container"
docker compose -f "$ROOT_DIR/docker/docker-compose.yml" --env-file "$ROOT_DIR/.env" down || true

if [[ -f "$MLX_PID_FILE" ]]; then
  PID="$(cat "$MLX_PID_FILE")"
  if ps -p "$PID" >/dev/null 2>&1; then
    echo "[stop] Stopping mlx_lm.server PID $PID"
    kill "$PID" || true
  fi
  rm -f "$MLX_PID_FILE"
fi

echo "[stop] Done"
