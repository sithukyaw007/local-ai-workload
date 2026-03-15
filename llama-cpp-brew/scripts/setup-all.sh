#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/install.sh"
"$SCRIPT_DIR/start-server.sh"
"$SCRIPT_DIR/healthcheck.sh"

echo "[setup] Complete. Use scripts/run-cli.sh for terminal chat."
