#!/usr/bin/env bash
# capture-ktty.sh — F18 operator-side log capture (runs in the NEXUS Linux stage).
#
# Packages ONE boot attempt's evidence into a session directory:
#   sessions/<SESSION_ID>/
#     ktty.log       the console log of the attempt (chain M writes $NEXUS_KTLOG,
#                    default /tmp/ktty.log; chain L/W: kernel/handoff console)
#     boot-log.txt   nexus-bootd decision log (NEXUS_BOOTLOG, default
#                    /data/NEXUS/boot-log.txt) — the dispatch + note() lines
#     meta.json      the validated metadata the validators require
#     sha256sums.txt integrity of everything above
#
# RULES (docs/12): run this AFTER the attempt (the session the chain kexecs
# away from is gone), never before; this tool only archives files, it never
# touches the kernel, the exploit entry, or anything NOTICE.md §2 forbids.
#
# Usage:
#   capture-ktty.sh --chain M --firmware 13.42 --entry relapse \
#                   --console "CFI-1015A launch model" --operator NAME \
#                   [--flavor mint] [--session-id HW-...] [--note "..."]
#                   [--ktty PATH] [--bootlog PATH] [--out DIR]
#   capture-ktty.sh --dry-run   # prints the plan, writes nothing
set -euo pipefail

CHAIN="" FIRMW="" ENTRY="" CONSOLE="" OPER="" FLAVOR="" SID="" NOTE=""
KTLOG="${NEXUS_KTLOG:-/tmp/ktty.log}"
BOOTLOG="${NEXUS_BOOTLOG:-/data/NEXUS/boot-log.txt}"
OUTDIR="sessions"
DRY=0

die() { printf '\033[1;31m[hwtest] FAIL\033[0m %s\n' "$*" >&2; exit 1; }
say() { printf '\033[1;35m[hwtest]\033[0m %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --chain)     CHAIN="$2"; shift 2 ;;
    --flavor)    FLAVOR="$2"; shift 2 ;;
    --firmware)  FIRMW="$2"; shift 2 ;;
    --entry)     ENTRY="$2"; shift 2 ;;
    --console)   CONSOLE="$2"; shift 2 ;;
    --operator)  OPER="$2"; shift 2 ;;
    --session-id) SID="$2"; shift 2 ;;
    --note)      NOTE="$2"; shift 2 ;;
    --ktty)      KTLOG="$2"; shift 2 ;;
    --bootlog)   BOOTLOG="$2"; shift 2 ;;
    --out)       OUTDIR="$2"; shift 2 ;;
    --dry-run)   DRY=1; shift ;;
    *) die "unknown option $1" ;;
  esac
done

if [ "$DRY" = "1" ]; then
  say "dry-run: would create $OUTDIR/<session>/ with ktty.log, boot-log.txt, meta.json, sha256sums.txt"
  say "dry-run: chain=$CHAIN flavor=${FLAVOR:-none} firmware=$FIRMW entry=$ENTRY console=$CONSOLE operator=$OPER"
  say "dry-run: ktty source=$KTLOG bootlog source=$BOOTLOG (missing sources are recorded as absent, not fatal)"
  exit 0
fi

[ "$CHAIN" = "M" ] || [ "$CHAIN" = "L" ] || [ "$CHAIN" = "W" ] \
  || die "--chain must be M, L or W"
case "$ENTRY" in
  relapse|byepervisor-reborn|pppwn-family|other) ;;
  *) die "--entry must be relapse | byepervisor-reborn | pppwn-family | other (docs/09 naming)" ;;
esac
[ -n "$FIRMW" ]  || die "--firmware required (e.g. 13.42)"
[ -n "$CONSOLE" ] || die "--console required (e.g. CFI-1015A launch model)"
[ -n "$OPER" ]   || die "--operator required"


[ -f "$KTLOG" ] || die "ktty log not found: $KTLOG (capture ran before the attempt? see docs/12 §4)"

SID="${SID:-HW-$(date -u +%F)-$(date -u +%H%M%S)}"
SESS="$OUTDIR/$SID"
mkdir -p "$SESS"

cp "$KTLOG" "$SESS/ktty.log"
if [ -f "$BOOTLOG" ]; then
  cp "$BOOTLOG" "$SESS/boot-log.txt"
else
  printf 'boot log absent at capture time (source: %s)\n' "$BOOTLOG" > "$SESS/boot-log.txt"
  say "WARN: $BOOTLOG not found — recorded as absent"
fi

python3 - "$SESS/meta.json" "$CHAIN" "$FLAVOR" "$FIRMW" "$ENTRY" "$CONSOLE" "$OPER" "$SID" "$NOTE" <<'PY'
import json, sys
out, chain, flavor, fw, entry, console, oper, sid, note = sys.argv[1:10]
meta = {
    "session_id": sid, "chain": chain,
    "flavor": flavor or "", "firmware": fw, "entry": entry,
    "console_model": console, "operator": oper,
    "date": sid[3:13] if sid.startswith("HW-") else "unknown",
    "ktty_session": out.rsplit("/", 1)[0] + "/" + sid,
    "notes": note or "",
}
json.dump(meta, open(out, "w"), indent=1)
PY

( cd "$SESS" && sha256sum ktty.log boot-log.txt meta.json > sha256sums.txt )

say "session captured: $SESS"
say "next: python3 $(dirname "$0")/validate-logs.py --chain $CHAIN --ktty $SESS/ktty.log --bootlog $SESS/boot-log.txt --meta $SESS/meta.json"
say "then: python3 $(dirname "$0")/delta-report.py --form <filled form> (docs/04 evidence)"
