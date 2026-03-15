#!/bin/bash
set -euo pipefail

models=(
  "qwen2.5-coder:7b-instruct-q4_K_M"
  "qwen2.5:14b-instruct-q4_K_M"
)

echo "[models] Pulling Ollama models"
for model in "${models[@]}"; do
  echo "[models] ollama pull $model"
  ollama pull "$model"
done

echo "[models] Completed"
ollama list
