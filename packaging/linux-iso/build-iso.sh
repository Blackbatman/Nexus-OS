#!/usr/bin/env bash
# build-iso.sh — build the NEXUS-OS Linux live ISO via mkarchiso.
# Requires: an Arch Linux host (or container) with archiso installed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${NEXUS_ISO_OUT:-$HERE/../../../dist}"
WORK="${NEXUS_ISO_WORK:-$HERE/../../../build/iso}"

command -v mkarchiso >/dev/null 2>&1 || {
  echo "mkarchiso not found — run on an Arch host: pacman -S archiso" >&2
  exit 2
}

mkdir -p "$OUT" "$WORK"
# Overlay the airootfs overlay (NEXUS motd, gate unit, bootctl stubs)
cp -a "$HERE/airootfs-overlay/." "$HERE/airootfs/" 2>/dev/null || true

mkarchiso -v -w "$WORK" -o "$OUT" "$HERE"
echo "ISO written under $OUT — see packaging/install-guides/usb.md to make a live USB"
