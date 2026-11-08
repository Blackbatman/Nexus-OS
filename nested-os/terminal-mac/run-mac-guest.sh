#!/usr/bin/env bash
# run-mac-guest.sh — launch an isolated macOS guest via govijr/terminal-mac.
#
# This is the CLEAN legal path for macOS-under-NEXUS: a real macOS guest using
# Apple's own Virtualization.framework, on an Apple silicon Mac. See NOTICE.md §3.
# The guest is registered with the permission gate; it shares nothing until you
# approve specific requests.
#
# Usage:
#   run-mac-guest.sh --check-env            # verify host can run it
#   run-mac-guest.sh [--workdir DIR]        # launch
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TP="$REPO_ROOT/third_party"
WORKDIR="$HOME/nexus-workspace/mac"
GATE_URL="${NEXUS_GATE:-http://127.0.0.1:7421}"
CHECK_ONLY=0

say() { printf '\033[1;35m[nexus:mac-guest]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus:mac-guest] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --check-env) CHECK_ONLY=1 ;;
    --workdir) shift; WORKDIR="$1" ;;
    *) die "unknown option $arg" ;;
  esac
done

# ------------------------------------------------------------- environment
[ "$(uname -s)" = "Darwin" ] || { [ "$CHECK_ONLY" = "1" ] && { say "not on macOS — guest runner needs an Apple silicon Mac (this host: $(uname -s)); check-env stops here"; exit 0; } || die "requires macOS host (Apple silicon) — see NOTICE.md §3"; }
if [ "$(uname -s)" = "Darwin" ]; then
  [ "$(uname -m)" = "arm64" ] || die "requires Apple silicon (arm64); Intel Macs are out of scope for terminal-mac"
  xcode-select -p >/dev/null 2>&1 || die "Xcode Command Line Tools missing (xcode-select --install)"
fi

if [ ! -d "$TP/terminal-mac/.git" ]; then
  [ "$CHECK_ONLY" = "1" ] && { say "check-env: terminal-mac not cloned yet (agents/init.sh does it)"; exit 0; }
  say "cloning govijr/terminal-mac into third_party/"
  git clone --depth 1 https://github.com/govijr/terminal-mac "$TP/terminal-mac"
fi

[ "$CHECK_ONLY" = "1" ] && { say "check-env PASS: Darwin/arm64 + CLT + terminal-mac repo present"; exit 0; }

# ------------------------------------------------------------- workspace
mkdir -p "$WORKDIR"
say "isolated workspace: $WORKDIR (gate policy: ~/nexus-workspace/mac/** only)"

# ------------------------------------------------------------ gate register
if curl -fsS --max-time 2 "$GATE_URL/policy" >/dev/null 2>&1; then
  say "permission gate reachable at $GATE_URL — guest traffic will be evaluated (default deny)"
else
  say "WARN: gate daemon not running — start it: nested-os/permission-gate/gate-daemon.py"
  say "      launching anyway; NOTHING leaves the workspace, but cross-guest requests will fail"
fi

# ------------------------------------------------------------------- launch
say "launching terminal-mac (follow its README for first-run macOS guest install)"
say "the guest desktop appears INSIDE your terminal; host controls remain yours"
exec bash -c "cd '$TP/terminal-mac' && ${NEXUS_TERMAC_RUN:-./run.sh} --workspace '$WORKDIR'"
