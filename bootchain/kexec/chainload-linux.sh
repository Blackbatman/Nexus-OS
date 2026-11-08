#!/usr/bin/env bash
# chainload-linux.sh — Chain L: direct kexec into a Linux kernel (READY path).
#
# The 8-flavor Linux roster of the NEXUS hub becomes real here: each flavor is a
# preset of kernel/initrd paths and command line. Kernels MUST be built for PS5
# hardware (upstream ps5-linux / ps5-linux-loader work); a stock distro kernel
# lacks the SoC bring-up patches and will not boot.
#
# Usage:
#   chainload-linux.sh --flavor arch [--kernel PATH --initrd PATH --append "…"]
#   chainload-linux.sh --flavor arch --dry-run
set -euo pipefail

DRY_RUN=0
FLAVOR=""
KERNEL=""
INITRD=""
APPEND=""

say() { printf '\033[1;35m[nexus:chainL]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus:chainL] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

# Flavor presets: PS5-built kernel layouts on the NEXUS boot USB (example contract).
# /mnt/usb0 is the PS5-Linux-stage convention for the boot USB stick.
presets() {
  case "$1" in
    arch)     echo "/mnt/usb0/linux/arch/vmlinuz|/mnt/usb0/linux/arch/initramfs-linux.img|root=/dev/sda2 rw quiet loglevel=4" ;;
    ubuntu)   echo "/mnt/usb0/linux/ubuntu/vmlinuz|/mnt/usb0/linux/ubuntu/initrd.img|root=UUID=nexus-ubuntu rw quiet splash" ;;
    fedora)   echo "/mnt/usb0/linux/fedora/vmlinuz|/mnt/usb0/linux/fedora/initramfs.img|root=UUID=nexus-fedora rw" ;;
    debian)   echo "/mnt/usb0/linux/debian/vmlinuz|/mnt/usb0/linux/debian/initrd.img|root=UUID=nexus-debian ro quiet" ;;
    cachyos)  echo "/mnt/usb0/linux/cachyos/vmlinuz|/mnt/usb0/linux/cachyos/initramfs.img|root=/dev/sda2 rw nowatchdog" ;;
    nobara)   echo "/mnt/usb0/linux/nobara/vmlinuz|/mnt/usb0/linux/nobara/initrd.img|root=UUID=nexus-nobara rw" ;;
    mint)     echo "/mnt/usb0/linux/mint/vmlinuz|/mnt/usb0/linux/mint/initrd.img|root=UUID=nexus-mint rw quiet" ;;
    omarchy)  echo "/mnt/usb0/linux/omarchy/vmlinuz|/mnt/usb0/linux/omarchy/initrd.img|root=/dev/sda2 rw" ;;
    *) die "unknown flavor '$1' (known: arch ubuntu fedora debian cachyos nobara mint omarchy)" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --flavor)  FLAVOR="$2"; shift 2 ;;
    --kernel)  KERNEL="$2"; shift 2 ;;
    --initrd)  INITRD="$2"; shift 2 ;;
    --append)  APPEND="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) die "unknown option $1" ;;
  esac
done

[ -n "$FLAVOR" ] || die "--flavor required"
case "$FLAVOR" in
  arch|ubuntu|fedora|debian|cachyos|nobara|mint|omarchy) ;;
  *) die "unknown flavor '$FLAVOR' (known: arch ubuntu fedora debian cachyos nobara mint omarchy)" ;;
esac
IFS='|' read -r P_K P_I P_A <<< "$(presets "$FLAVOR")"
KERNEL="${KERNEL:-$P_K}"
INITRD="${INITRD:-$P_I}"
APPEND="${APPEND:-$P_A}"

if [ "$DRY_RUN" = "1" ]; then
  # Dry-run is always safe and always runnable (CI/beta team): warn, don't die.
  command -v kexec >/dev/null 2>&1 || say "dry-run WARN: kexec(8) not present on this host (it exists in the Linux stage)"
  [ -f "$KERNEL" ] || say "dry-run WARN: kernel artifact not staged: $KERNEL"
  [ -f "$INITRD" ] || say "dry-run WARN: initrd artifact not staged: $INITRD"
else
  command -v kexec >/dev/null 2>&1 || die "kexec(8) not found in this stage"
  [ -f "$KERNEL" ] || die "kernel not found: $KERNEL"
  [ -f "$INITRD" ] || die "initrd not found: $INITRD"
fi

say "chain L (Linux direct kexec) — flavor: $FLAVOR  [READY]"
say "kernel : $KERNEL"
say "initrd : $INITRD"
say "append : $APPEND"

if [ "$DRY_RUN" = "1" ]; then
  say "dry-run: would run: kexec -l '$KERNEL' --initrd '$INITRD' --command-line '$APPEND' && kexec -e"
  say "dry-run: nothing executed."
  exit 0
fi

kexec -l "$KERNEL" --initrd "$INITRD" --command-line "$APPEND"
say "kernel staged; executing (this terminates this Linux session)"
exec kexec -e
