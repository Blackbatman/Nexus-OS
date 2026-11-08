#!/usr/bin/env bash
# chainload-macos.sh — Chain M: macOS Monterey 12.7.6 via crash-kexec hop (PROVEN path).
#
# Mirrors the rodri0x/ps5-hackintosh chain on a launch-model PS5 at FW 13.42:
#   Linux → kexec_file_load(stage1 as crash kernel) → sysrq-c → stage1
#         → EDK2 UefiPayload → OpenCore → boot.efi → XNU 21.6.0
#
# SAFETY: this intentionally crashes the running Linux session. Refuses to run
# without --i-know-this-crashes-the-host. --dry-run is always safe.
set -euo pipefail

DRY_RUN=0
CONFIRM=0
STAGE1="${NEXUS_STAGE1:-/mnt/usb0/nexus/stage1/stage1.elf}"
KTLOG="${NEXUS_KTLOG:-/tmp/ktty.log}"

say() { printf '\033[1;35m[nexus:chainM]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus:chainM] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --stage1) STAGE1="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --i-know-this-crashes-the-host) CONFIRM=1; shift ;;
    *) die "unknown option $1" ;;
  esac
done

if [ "$DRY_RUN" = "1" ]; then
  # Dry-run is always safe: warn on missing pieces instead of failing (CI/beta).
  command -v kexec >/dev/null 2>&1 || say "dry-run WARN: kexec(8) not present on this host (it exists in the Linux stage)"
  [ -f "$STAGE1" ] || say "dry-run WARN: stage1 artifact not staged: $STAGE1 (build via bootchain/stage1 + upstream bringup)"
else
  command -v kexec >/dev/null 2>&1 || die "kexec(8) not found in this stage"
  [ -f "$STAGE1" ] || die "stage1 artifact not found: $STAGE1 (build via bootchain/stage1 + upstream bringup)"
fi

say "chain M (macOS crash-hop) — upstream-PROVEN on FW 13.42 launch model"
say "stage1  : $STAGE1"
say "plan    : kexec -p stage1 → enable sysrq → sysrq-c"
say "warning : IOMMU is disabled downstream by stage1 (upstream design; DMA unguarded)"
say "warning : no GPU accel (Cyan Skillfish), no WiFi/BT (NXP IW620), no HDMI audio (USB audio works)"

if [ "$DRY_RUN" = "1" ]; then
  say "dry-run: would run: kexec -p '$STAGE1' --append 'nexus_stage1' ; echo 1 > /proc/sys/kernel/sysrq ; echo c > /proc/sysrq-trigger"
  say "dry-run: nothing executed. Host survives."
  exit 0
fi

[ "$CONFIRM" = "1" ] || die "refusing to crash the host without --i-know-this-crashes-the-host"

[ "$(id -u)" = "0" ] || die "must be root in the Linux stage"

say "staging stage1 as crash kernel…"
kexec -p "$STAGE1" --append "nexus_stage1" || die "kexec -p failed (kernel too old for kexec_file_load -p?)"

echo 1 > /proc/sys/kernel/sysrq
say "arming crash hop (sysrq-c) — console log goes to $KTLOG"
sleep 1
echo c > /proc/sysrq-trigger

# If we are still alive, the hop did not happen.
die "still alive after sysrq-c — crash kernel was not taken; check kexec -p output and kernel config (CONFIG_CRASH_DUMP, CONFIG_KEXEC_FILE)"
