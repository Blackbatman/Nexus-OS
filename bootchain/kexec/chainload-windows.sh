#!/usr/bin/env bash
# chainload-windows.sh — Chain W: Windows via UefiPayload → bootmgfw.efi (RESEARCH path).
#
# Status: RESEARCH-GRADE. Unlike Chain M (macOS, upstream-proven) and Chain L
# (Linux, READY), nobody has publicly proven Windows on PS5 bare metal. The chain
# shape is: stage1 → UefiPayload (UEFI environment) → Windows Boot Manager
# (bootmgfw.efi on the GPT USB disk) → winload.efi.
#
# Known limits (do not hide from the user):
#   - storage must be USB (internal NVMe is locked by upstream design)
#   - display runs on basic framebuffer only (no GPU accel)
#   - input via USB keyboard/mouse; DualSense unproven on this chain
#   - licensing: you must supply your own Windows media (NOTICE.md §4)
set -euo pipefail

DRY_RUN=0
UEFIPAYLOAD="${NEXUS_UEFIPAYLOAD:-/mnt/usb0/nexus/uefi/UefiPayload.fd}"
WINVOL="${NEXUS_WINVOL:-/mnt/usb1}"   # GPT USB volume holding EFI/Boot/bootmgfw.efi

say() { printf '\033[1;35m[nexus:chainW]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus:chainW] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --uefipayload) UEFIPAYLOAD="$2"; shift 2 ;;
    --win-volume)  WINVOL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die "unknown option $1" ;;
  esac
done

if [ "$DRY_RUN" = "1" ]; then
  # Dry-run is always safe: warn on missing pieces instead of failing (CI/beta).
  [ -f "$UEFIPAYLOAD" ] || say "dry-run WARN: UefiPayload image not staged: $UEFIPAYLOAD (build via bootchain/stage1 + EDK2 UefiPayloadPkg)"
  BMGF="$WINVOL/EFI/Boot/bootmgfw.efi"
  [ -f "$BMGF" ] || say "dry-run WARN: Windows Boot Manager not staged at $BMGF (your licensed Windows USB volume — NOTICE.md §4)"
else
  [ -f "$UEFIPAYLOAD" ] || die "UefiPayload image not found: $UEFIPAYLOAD (build via bootchain/stage1 + EDK2 UefiPayloadPkg)"
  BMGF="$WINVOL/EFI/Boot/bootmgfw.efi"
  [ -f "$BMGF" ] || die "Windows Boot Manager not found at $BMGF — mount your licensed Windows USB volume (NOTICE.md §4)"
fi

say "chain W (Windows) — RESEARCH GRADE, not upstream-proven"
say "uefipayload : $UEFIPAYLOAD"
say "win volume  : $WINVOL (bootmgfw.efi present)"
say "plan        : kexec -p stage1-style hop is replaced by UefiPayload boot of the EFI app"
say "limits      : USB-only storage · framebuffer display · USB input · your license"

if [ "$DRY_RUN" = "1" ]; then
  say "dry-run: would run: nexus_uefi_handoff --payload '$UEFIPAYLOAD' --entry EFI/Boot/bootmgfw.efi"
  say "dry-run: nothing executed. (nexus_uefi_handoff ships with the stage1 build.)"
  exit 0
fi

if [ ! -x "$(command -v nexus_uefi_handoff || true)" ]; then
  die "nexus_uefi_handoff not installed — build it from bootchain/stage1 (RESEARCH component)"
fi

exec nexus_uefi_handoff --payload "$UEFIPAYLOAD" --entry "EFI/Boot/bootmgfw.efi"
