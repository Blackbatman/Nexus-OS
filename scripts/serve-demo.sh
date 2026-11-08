#!/usr/bin/env bash
# serve-demo.sh — serve the NEXUS hub web demo on localhost.
# Usage: scripts/serve-demo.sh [port]
set -euo pipefail
PORT="${1:-8080}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "NEXUS hub demo → http://localhost:$PORT  (Ctrl+C to stop)"
python3 -m http.server "$PORT" --directory "$ROOT/nexus-hub/web-demo"
