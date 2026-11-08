#!/usr/bin/env bash
# rea-session.sh — run a REA (Reverse Engineer Anything) analysis session on
# artifacts NEXUS-OS built, and store the report.
#
# REA (github.com/morluto/rea) drives Ghidra/Hopper/IDA/Rizin/objdump backends
# via CLI + MCP. Subcommand names drift between REA versions — this wrapper
# normalizes the NEXUS-OS flow and fails loudly with guidance.
#
# Usage:
#   rea-session.sh <artifact.elf|payload|kmod> [--label my-label]
#   rea-session.sh --doctor          # check REA availability + backends
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORTS="$REPO_ROOT/beta-team/reports"
mkdir -p "$REPORTS"

say() { printf '\033[1;35m[nexus:rea]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus:rea] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

rea_available() {
  command -v rea >/dev/null 2>&1 || npx --no-install rea-agents --version >/dev/null 2>&1
}

run_rea() {
  # Prefer the global CLI; fall back to npx. Requires Node 22+ per REA docs.
  if command -v rea >/dev/null 2>&1; then rea "$@"; else npx -y rea-agents "$@"; fi
}

if [ "${1:-}" = "--doctor" ]; then
  if rea_available; then say "REA available ($(rea --version 2>/dev/null || echo 'version n/a'))"; else say "REA not installed — install: npm install --global rea-agents (Node 22+)"; fi
  for be in r2 objdump rizin ghidra; do
    command -v "$be" >/dev/null 2>&1 && say "backend present: $be" || say "backend absent: $be"
  done
  exit 0
fi

ART="${1:-}"
[ -n "$ART" ] || die "usage: rea-session.sh <artifact> [--label label]  |  --doctor"
[ -f "$ART" ] || die "artifact not found: $ART"
LABEL="${3:-$(basename "$ART")}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT="$REPORTS/rea-$LABEL-$STAMP.md"

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
[ "$node_major" -ge 22 ] || say "WARN: REA wants Node 22+ (found $node_major) — continuing, expect failures"

say "analyzing $ART (sha256: $(sha256sum "$ART" | cut -c1-16)…)"
{
  echo "# REA session report — $LABEL"
  echo "- date: $(date -u +%F\ %TZ)"
  echo "- artifact: $ART"
  echo "- sha256: $(sha256sum "$ART" | cut -d' ' -f1)"
  echo
  echo "## r2 quick sweep (sections/imports/strings summary)"
  if command -v r2 >/dev/null 2>&1; then
    r2 -q -A -c "iS~?;ii~?;iz~?" "$ART" 2>/dev/null | sed 's/^/- /'
  else
    echo "- r2 not installed; REA backends (objdump/rizin) used below"
  fi
  echo
  echo "## REA output"
  # REA's native-analysis entry points; names may vary by version — try the
  # documented one first, fall back to generic analyze.
  if ! run_rea analyze "$ART" --json 2>&1; then
    echo "(rea 'analyze' subcommand unavailable in this version; consult: rea --help)"
  fi
} > "$OUT"

say "report written: $OUT"
say "next: attach it to the beta-team report and hand suspicions to the architect"
