#!/usr/bin/env bash
# analyze-payload.sh — quick radare2 structural sweep of a NEXUS-OS artifact.
# Usage: analyze-payload.sh <elf> [outfile.md]
set -euo pipefail

ART="${1:?usage: analyze-payload.sh <elf> [outfile.md]}"
OUT="${2:-}"
[ -f "$ART" ] || { echo "artifact not found: $ART" >&2; exit 1; }
command -v r2 >/dev/null 2>&1 || { echo "radare2 not installed (apt install radare2)" >&2; exit 1; }

report() {
  echo "## r2 sweep: $ART"
  echo "sha256: $(sha256sum "$ART" | cut -d' ' -f1)"
  echo
  echo "### sections"; r2 -q -c "iS" "$ART" 2>/dev/null
  echo "### entry + info"; r2 -q -c "ie; ii~?" "$ART" 2>/dev/null
  echo "### libraries"; r2 -q -c "il" "$ART" 2>/dev/null
  echo "### first strings"; r2 -q -c "iz~.." "$ART" 2>/dev/null | head -40
  echo "### mitigations"; r2 -q -c "iR" "$ART" 2>/dev/null || true
}

if [ -n "$OUT" ]; then
  report > "$OUT"
  echo "report: $OUT"
else
  report
fi
