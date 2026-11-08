#!/usr/bin/env bash
# nexus-boot-select.sh — The NEXUS hub's missing half: the thing that actually boots.
#
# PS5GreenApple v2 (see nexus-hub/greapple-v2/) writes the user's choice to
# /data/NEXUS/boot-select.json. This orchestrator runs in the NEXUS Linux stage
# (after ps5-linux-loader), reads it, and dispatches to the right chain script.
# Every decision is logged so a dead console still tells the truth.
#
# Usage:
#   nexus-boot-select.sh [--select PATH] [--dry-run] [--verbose]
set -euo pipefail

SELECT="${NEXUS_SELECT:-/data/NEXUS/boot-select.json}"
LOG="${NEXUS_BOOTLOG:-/data/NEXUS/boot-log.txt}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
VERBOSE=0

say()  { printf '\033[1;35m[nexus-bootd]\033[0m %s\n' "$*"; }
note() { printf '[nexus-bootd] %s\n' "$*" >> "$LOG_DRY"; }
die()  { printf '\033[1;31m[nexus-bootd] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

LOG_DRY="$LOG"
if [ "$DRY_RUN" = "0" ] && [ ! -w "$(dirname "$LOG")" ] 2>/dev/null; then
  LOG_DRY="/tmp/nexus-boot-log.txt"
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --select)  SELECT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    *) die "unknown option $1" ;;
  esac
done

command -v python3 >/dev/null 2>&1 || die "python3 required in the Linux stage (JSON parsing)"
[ -f "$SELECT" ] || die "no selection file at $SELECT — the hub did not write one (open NEXUS and pick a target)"

TARGET="$(python3 - "$SELECT" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
except Exception as exc:
    print(f"__ERROR__ invalid JSON in selection file: {exc}")
    sys.exit(0)
t = data.get("target", "")
if t not in ("macos", "windows", "linux"):
    print(f"__ERROR__ unknown target {t!r}")
    sys.exit(0)
flavor = data.get("flavor", "")
if t == "linux" and flavor:
    print(f"linux:{flavor}")
else:
    print(t)
PY
)" || true

case "$TARGET" in
  __ERROR__*) die "$TARGET" ;;
  macos)
    note "$(date -u '+%F %T') dispatch: chain M (macOS) — PROVEN path"
    say "dispatch → chainload-macos.sh (chain M, PROVEN upstream)"
    if [ "$VERBOSE" = "1" ]; then say "stage1: \$NEXUS_STAGE1 default /mnt/usb0/nexus/stage1/stage1.elf"; fi
    [ "$DRY_RUN" = "1" ] && exec bash "$DIR/chainload-macos.sh" --dry-run
    exec bash "$DIR/chainload-macos.sh" --i-know-this-crashes-the-host
    ;;
  windows)
    note "$(date -u '+%F %T') dispatch: chain W (Windows) — RESEARCH path"
    say "dispatch → chainload-windows.sh (chain W, RESEARCH)"
    [ "$DRY_RUN" = "1" ] && exec bash "$DIR/chainload-windows.sh" --dry-run
    exec bash "$DIR/chainload-windows.sh"
    ;;
  linux:*)
    FLAVOR="${TARGET#linux:}"
    note "$(date -u '+%F %T') dispatch: chain L (Linux:$FLAVOR) — READY path"
    say "dispatch → chainload-linux.sh (chain L, flavor $FLAVOR, READY)"
    if [ "$DRY_RUN" = "1" ]; then
      exec bash "$DIR/chainload-linux.sh" --flavor "$FLAVOR" --dry-run
    fi
    exec bash "$DIR/chainload-linux.sh" --flavor "$FLAVOR"
    ;;
  linux)
    die "target=linux without flavor — the hub must write {\"target\":\"linux\",\"flavor\":\"arch\"}"
    ;;
  *)
    die "unparsed selection: '$TARGET'"
    ;;
esac
