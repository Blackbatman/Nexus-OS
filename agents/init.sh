#!/usr/bin/env bash
# NEXUS-OS workspace initializer — run once before the first agent session.
# Clones upstream references into third_party/, verifies host tooling, seeds notes.
# APPROVAL GATE: network fetches happen only here, only into third_party/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TP="$ROOT/third_party"
mkdir -p "$TP"

log() { printf '\033[1;36m[nexus-init]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------- tool checks
missing=()
for bin in git python3 bash node; do
  if ! command -v "$bin" >/dev/null 2>&1; then missing+=("$bin"); fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  log "MISSING required tools: ${missing[*]} — install them and re-run."
  exit 1
fi
log "host tools OK (git, python3, bash, node)"

# Optional tools — warn only, never block.
for bin in r2 radiff2 jq gcc; do
  command -v "$bin" >/dev/null 2>&1 || log "note: '$bin' not found (some features degrade)"
done

# ------------------------------------------------------- upstream references
# Each is a public research/artifact repo. Read NOTICE.md before use.
# Firmware-exploit repos are cloned for STUDY ONLY — no exploit code or offsets
# are ever copied into NEXUS-OS deliverables (NOTICE §2, docs/09-firmware-coverage.md §5).
repos=(
  "https://github.com/rodri0x/ps5-hackintosh"
  "https://github.com/Blackbatman/PS5GreenApple"
  "https://github.com/ps5-payload-dev/elfldr"
  "https://github.com/ps5-payload-dev/ftpsrv"
  "https://github.com/TheOfficialFloW/PPPwn"
  "https://github.com/govijr/terminal-mac"
  "https://github.com/Leviidev/Henge"
  # firmware exploit research layer (FW 7.00-13.60 entry + 14.x watch)
  "https://github.com/ntfargo/Relapse-Exploit"
  "https://github.com/PS5Dev/Byepervisor-Reborn"
  "https://github.com/soniciso1/ps5-hv-writeups"
  "https://github.com/ZigZagBoi1/PS5-14.10-Research"
  "https://github.com/pastawithpesto/PS5-14.10-Jailbreak-Research"
  "https://github.com/kuzibelit/PS5-14.00-14.10-Jailbreak-PoC"
)
for url in "${repos[@]}"; do
  name="$(basename "$url")"
  if [ -d "$TP/$name/.git" ]; then
    log "exists: third_party/$name (skipping clone)"
  elif [ "${NEXUS_NO_NET:-0}" = "1" ]; then
    log "NEXUS_NO_NET=1 set — skipping clone of $name"
  else
    log "cloning $url"
    git clone --depth 1 "$url" "$TP/$name" || log "WARN: clone failed for $name (continue without it)"
  fi
done

# ------------------------------------------------------------ sanity builds
if [ -f "$TP/PS5GreenApple/Makefile" ]; then
  log "PS5GreenApple present — you can build its host backend: make -C $TP/PS5GreenApple host shots"
else
  log "PS5GreenApple not present — F17 (v2 code patches) stays blocked until cloned"
fi

# --------------------------------------------------------------- smoke tests
log "running beta-team quick smoke"
if bash "$ROOT/beta-team/run-tests.sh" --quick; then
  log "smoke PASS"
else
  log "smoke FAIL — read beta-team/reports/ before starting sessions"
fi

# ------------------------------------------------------------- progress seed
NOTES="$ROOT/agents/claude-progress.txt"
if [ ! -f "$NOTES" ]; then
  {
    echo "# claude-progress.txt — append-only session notes"
    echo "# format: [date] agent: did / broke / next"
    echo "[$(date -u +%F)] init.sh: workspace initialized; feature_list seeded (F01-F20); next: pick F17 (GreenApple v2 patches) after clone, or any READY feature."
  } > "$NOTES"
  log "seeded agents/claude-progress.txt"
fi

log "done. Start the harness: claude (or grok) → 'Read CLAUDE.md and follow the harness.'"
