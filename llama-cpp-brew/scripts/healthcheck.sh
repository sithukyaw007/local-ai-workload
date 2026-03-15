#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib.sh"

load_env

url="http://$LLAMA_SERVER_HOST:$LLAMA_SERVER_PORT/health"
code="$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)"
if [[ "$code" == "200" ]]; then
  echo "[ok] llama.cpp server healthy: $url"
  exit 0
fi

echo "[fail] llama.cpp server unhealthy: $url (status: $code)"
exit 1
