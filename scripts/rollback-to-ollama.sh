#!/bin/bash
# Rollback to Ollama-based setup
# Usage: ./scripts/rollback-to-ollama.sh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECKPOINT="$ROOT_DIR/config/checkpoints/ollama-setup"

echo "Rolling back to Ollama setup..."
cp "$CHECKPOINT/router.yaml" "$ROOT_DIR/config/router.yaml"
cp "$CHECKPOINT/.env" "$ROOT_DIR/.env"
cp "$CHECKPOINT/settings.local.json" "$ROOT_DIR/.claude/settings.local.json"
cp "$CHECKPOINT/settings.global.json" "$HOME/.claude/settings.json"

cd "$ROOT_DIR"
docker compose -f docker/docker-compose.yml --env-file .env up -d --force-recreate
echo "Rolled back. Gateway restarted with Ollama config."
echo "Model: ollama_chat/qwen3.5:35b (think: false)"
