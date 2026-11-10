#!/usr/bin/env bash
# probe-platform.sh — F22 platform bring-up probes for the NEXUS Linux stage.
#
# Derived from docs/13-curriculum-gap-analysis.md: the layers every OS
# bring-up goes through (PCI enumeration, video mode, interrupts, storage,
# network) were implicit in the NEXUS boot story but never probed. This tool
# makes them explicit, read-only evidence generators for the F18 sessions:
# run it inside the NEXUS Linux stage (or any Linux) and archive the output
# next to the ktty capture.
#
# Probes (all read-only, no kernel interaction, NOTICE.md §2 safe):
#   pci          bus enumeration: devices, classes (PS5 APU/GPU/NVMe visibility)
#   framebuffer  GOP handoff result: fb devices + DRM connectors
#   interrupts   APIC/IRQ table shape from /proc/interrupts
#   storage      block devices + EFI runtime presence (ESP is FAT32 — B01/B02)
#   network      interfaces + carrier state (A01-A09 stack entry point)
#
# Usage:
#   probe-platform.sh [pci|framebuffer|interrupts|storage|network|all]
#   probe-platform.sh --dry-run     # print the plan, touch nothing
#   probe-platform.sh --selftest    # validate the JSON contract, exit code
# Output: one JSON object per line (pipe to a file, archive with the session).
set -uo pipefail

PROBE="all"
DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY=1 ;;
    --selftest) PROBE="selftest" ;;
    pci|framebuffer|interrupts|storage|network|all) PROBE="$arg" ;;
    *) printf 'unknown arg: %s\nusage: probe-platform.sh [pci|framebuffer|interrupts|storage|network|all|--dry-run|--selftest]\n' "$arg" >&2; exit 1 ;;
  esac
done

jemit() { # jemit <probe> <0|1> <summary> [detail...]
  python3 - "$@" <<'PY'
import json, sys
probe, ok, summary, rest = sys.argv[1], sys.argv[2] == "1", sys.argv[3], sys.argv[4:]
print(json.dumps({"probe": probe, "ok": ok, "summary": summary,
                  "detail": [r for r in rest if r]}, ensure_ascii=True))
PY
}

probe_pci() {
  local n=0 classes=""
  if [ -d /sys/bus/pci/devices ]; then
    for d in /sys/bus/pci/devices/*; do
      [ -e "$d/class" ] || continue
      n=$((n + 1))
      cls="$(cat "$d/class" 2>/dev/null || echo unknown)"
      classes="$classes ${cls##0x}"
    done
  fi
  jemit pci "$([ "$n" -gt 0 ] && echo 1 || echo 0)" \
    "enumerated $n PCI device(s)" "classes:${classes:-none}"
}

probe_framebuffer() {
  local fbs="" conns="" ok=0
  for f in /sys/class/graphics/fb*; do
    [ -e "$f" ] || continue
    fbs="$fbs $(basename "$f")"
    ok=1
  done
  for c in /sys/class/drm/card*-*/status; do
    [ -e "$c" ] || continue
    conns="$conns $(basename "$(dirname "$c")"):$(cat "$c")"
    ok=1
  done
  jemit framebuffer "$ok" "fb:[$(echo $fbs | xargs)] drm:[$(echo $conns | xargs)]" \
    "GOP handoff evidence (graphics mode layer, playlist ep.12 analog)"
}

probe_interrupts() {
  local ok=0 apic=0 lines=0
  if [ -r /proc/interrupts ]; then
    lines=$(grep -c ':' /proc/interrupts 2>/dev/null || echo 0)
    apic=$(grep -ci 'IO-APIC\|APIC' /proc/interrupts 2>/dev/null || echo 0)
    [ "$lines" -gt 0 ] && ok=1
  fi
  jemit interrupts "$ok" "$lines IRQ line(s), $apic APIC controller line(s)" \
    "interrupt subsystem shape (playlist ep.5 analog)"
}

probe_storage() {
  local blocks="" efi=0 ok=0
  if command -v lsblk >/dev/null 2>&1; then
    blocks=$(lsblk -rno NAME,SIZE,FSTYPE 2>/dev/null | head -12 | tr '\n' ';' || true)
    [ -n "$blocks" ] && ok=1
  elif [ -r /proc/partitions ]; then
    blocks=$(tail -n +2 /proc/partitions | awk '{print $4":"$3}' | head -12 | tr '\n' ';')
    [ -n "$blocks" ] && ok=1
  fi
  [ -d /sys/firmware/efi ] && efi=1 && ok=1
  jemit storage "$ok" "blocks:[$blocks] efi_runtime:$efi" \
    "ESP/FAT32 + NVMe visibility (playlist B01/B02 analog)"
}

probe_network() {
  local ifaces="" ok=0
  for n in /sys/class/net/*; do
    [ -e "$n" ] || continue
    b=$(basename "$n")
    [ "$b" = "lo" ] && continue
    car="unknown"
    [ -r "$n/carrier" ] && car=$(cat "$n/carrier" 2>/dev/null || echo unknown)
    ifaces="$ifaces $b($car)"
    ok=1
  done
  jemit network "$ok" "ifaces:[$(echo $ifaces | xargs)]" \
    "NIC bring-up state (playlist ep.17-18 + A01-A09 analog)"
}

run_one() {
  case "$1" in
    pci)         probe_pci ;;
    framebuffer) probe_framebuffer ;;
    interrupts)  probe_interrupts ;;
    storage)     probe_storage ;;
    network)     probe_network ;;
  esac
}

if [ "$PROBE" = "selftest" ]; then
  fail=0
  for p in pci framebuffer interrupts storage network; do
    line="$(run_one "$p")"
    if python3 -c "
import json, sys
d = json.loads('''$line''')
assert set(d) == {'probe', 'ok', 'summary', 'detail'}, d
assert d['probe'] == '$p', d
" 2>/dev/null; then
      printf 'SELFTEST PASS %s: %s\n' "$p" "$line"
    else
      printf 'SELFTEST FAIL %s: %s\n' "$p" "$line"
      fail=1
    fi
  done
  exit "$fail"
fi

if [ "$DRY" = "1" ]; then
  if [ "$PROBE" = "all" ]; then
    printf 'dry-run: would emit JSON lines for probes: pci framebuffer interrupts storage network\n'
    printf 'dry-run: read-only (/sys, /proc, lsblk); no kernel, no exploit, no write\n'
  else
    printf 'dry-run: would emit one JSON line for probe: %s\n' "$PROBE"
  fi
  exit 0
fi

if [ "$PROBE" = "all" ]; then
  for p in pci framebuffer interrupts storage network; do run_one "$p"; done
else
  run_one "$PROBE"
fi
