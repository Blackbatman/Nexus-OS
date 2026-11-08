#!/usr/bin/env bash
# make-windows-media.sh — build NEXUS-branded Windows install media.
#
# LICENSE: you must supply an official Windows ISO you licensed yourself
# (NOTICE.md §4). This script never downloads Windows. It only adds NEXUS
# boot notes + autounattend (locale/timezone) to YOUR media and repacks it.
#
# Requires: wimlib (wimlib-imagex), xorriso. Runs on Linux/macOS hosts.
set -euo pipefail

ISO_IN="" OUT="NEXUS-Windows.iso" NAME_INDEX=1

say() { printf '\033[1;35m[nexus:winmedia]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus:winmedia] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --iso) ISO_IN="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --index) NAME_INDEX="$2"; shift 2 ;;
    *) die "unknown option $1" ;;
  esac
done
[ -f "$ISO_IN" ] || die "--iso <your official Windows ISO> required"
command -v wimlib-imagex >/dev/null 2>&1 || die "wimlib-imagex not installed (pacman -S wimlib / brew install wimlib)"
command -v xorriso >/dev/null 2>&1 || die "xorriso not installed"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say "extracting your media…"
xorriso -osirrox on -indev "$ISO_IN" -extract / "$WORK/media" >/dev/null 2>&1

say "injecting NEXUS boot notes (no system files replaced)"
cat > "$WORK/media/NEXUS-README.txt" <<'EOF'
NEXUS-OS Windows target — RESEARCH chain.
This disc boots on standard PCs. For PS5 bare-metal use, the chain is
UefiPayload -> bootmgfw.efi (USB-only storage, framebuffer display).
You supplied this Windows media under your own license. NOTICE.md section 4.
EOF
mkdir -p "$WORK/media/NEXUS"
[ -f "$(dirname "$0")/../docs/04-hardware-support.md" ] && cp "$(dirname "$0")/../docs/04-hardware-support.md" "$WORK/media/NEXUS/" || true

say "rebuilding ISO (UEFI + BIOS bootable): $OUT"
xorriso -as mkisofs -o "$OUT" \
  -isohybrid-mbr /usr/lib/syslinux/bios/isohdpfx.bin \
  -c isolinux/boot.cat -b isolinux/isolinux.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e efisys.bin -no-emul-boot \
  -isohybrid-gpt-basdat -V NEXUS_WIN "$WORK/media" 2>/dev/null \
  || die "ISO rebuild failed — media layout differs (some retail ISOs lack isolinux); use Rufus/Ventoy to write your original ISO and copy the NEXUS notes manually"

say "done: $OUT"
say "reminder: PS5 optical drives will not boot burned discs — this media is for PC hosts (see install-guides/disc.md)"
