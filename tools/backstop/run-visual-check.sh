#!/usr/bin/env bash
# run-visual-check.sh — visual regression for the NEXUS hub demo.
#
# Primary: real BackstopJS (npm install -g backstopjs; backstop test).
# Fallback (sandbox-safe, zero deps): agent-browser screenshot + Python PIL
# mean-pixel diff against the accepted baseline.
#
# Usage:
#   run-visual-check.sh --serve        # start a static server for the demo
#   run-visual-check.sh --baseline     # capture the baseline screenshot
#   run-visual-check.sh --check        # compare current vs baseline
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO="$DIR/../../nexus-hub/web-demo/index.html"
BASELINE="$DIR/backstop_data/bitmaps_reference/hub-default.png"
CURRENT="$DIR/backstop_data/bitmaps_test/hub-default.png"
mkdir -p "$(dirname "$BASELINE")" "$(dirname "$CURRENT")"

say() { printf '\033[1;35m[nexus:visual]\033[0m %s\n' "$*"; }

PORT="${NEXUS_DEMO_PORT:-8080}"
serve() {
  (cd "$(dirname "$DEMO")" && python3 -m http.server "$PORT" >/dev/null 2>&1 &)
  sleep 1
  say "serving demo at http://localhost:$PORT"
}

shot() { # shot <url> <out.png>
  if command -v agent-browser >/dev/null 2>&1; then
    agent-browser open "$1" && agent-browser screenshot --path "$2" --viewport 1920x1080
  else
    python3 - "$1" "$2" <<'PY'
import subprocess, sys, urllib.request
url, out = sys.argv[1], sys.argv[2]
urllib.request.urlopen(url, timeout=5).read()  # sanity
sys.exit(subprocess.call(["python3", "-c", "print('no headless browser available; install agent-browser or backstopjs')"]) and 3)
PY
  fi
}

case "${1:-}" in
  --serve) serve; exit 0 ;;
  --baseline) serve; shot "http://localhost:$PORT/index.html" "$BASELINE"; say "baseline captured: $BASELINE"; exit 0 ;;
  --check)
    [ -f "$BASELINE" ] || { say "no baseline — run --baseline first"; exit 2; }
    serve; shot "http://localhost:$PORT/index.html" "$CURRENT"
    python3 - "$BASELINE" "$CURRENT" <<'PY'
import sys
from PIL import Image, ImageChops
base, cur = Image.open(sys.argv[1]).convert("RGB"), Image.open(sys.argv[2]).convert("RGB")
if base.size != cur.size:
    print(f"VISUAL FAIL: size drift {base.size} -> {cur.size}"); sys.exit(1)
diff = ImageChops.difference(base, cur)
bbox = diff.getbbox()
hist = diff.convert("L").histogram()
changed = sum(hist[8:]) / (cur.size[0] * cur.size[1])
print(f"changed-pixel ratio: {changed:.4%}; bbox: {bbox}")
sys.exit(1 if changed > 0.01 else 0)
PY
    say "VISUAL PASS (≤1% pixel drift)"
    ;;
  --backstop)
    command -v backstop >/dev/null 2>&1 || { say "backstopjs not installed — use the --baseline/--check fallback"; exit 2; }
    serve
    backstop test --config "$DIR/backstop.json"
    ;;
  *) echo "usage: run-visual-check.sh --serve|--baseline|--check|--backstop"; exit 1 ;;
esac
