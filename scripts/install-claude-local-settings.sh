#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_DIR="$ROOT_DIR/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"
HELPER_PATH="$ROOT_DIR/scripts/claude-api-key-helper.sh"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: .env not found. Create it first: cp .env.example .env"
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

mkdir -p "$SETTINGS_DIR"

cat > "$SETTINGS_FILE" <<JSON
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "apiKeyHelper": "$HELPER_PATH",
  "model": "${CLAUDE_DEFAULT_MODEL:-local-coder-quality}",
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:${GATEWAY_PORT:-4000}",
    "ANTHROPIC_MODEL": "${CLAUDE_DEFAULT_MODEL:-local-coder-quality}"
  }
}
JSON

echo "Created $SETTINGS_FILE"
echo "Use /status inside Claude Code to confirm apiKeyHelper and env are active."
