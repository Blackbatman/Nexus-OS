#!/usr/bin/env bash
# run-windows-guest.sh — launch a licensed Windows guest in a terminal via QEMU/KVM.
#
# YOU supply the Windows ISO and license (NOTICE.md §4). The guest is isolated:
# no host filesystem share is attached — cross-guest/host transfer goes through
# the permission gate daemon only (default deny).
#
# Usage:
#   run-windows-guest.sh --check-env
#   run-windows-guest.sh --iso /path/to/Win11.iso [--disk 64G] [--name nexus-win]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKDIR="$HOME/nexus-workspace/win"
GATE_URL="${NEXUS_GATE:-http://127.0.0.1:7421}"
ISO="" DISK="64G" NAME="nexus-win" MEM="8G" SMP="8" CHECK_ONLY=0

say() { printf '\033[1;35m[nexus:win-guest]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus:win-guest] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --check-env) CHECK_ONLY=1; shift ;;
    --iso) ISO="$2"; shift 2 ;;
    --disk) DISK="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --mem) MEM="$2"; shift 2 ;;
    --smp) SMP="$2"; shift 2 ;;
    *) die "unknown option $1" ;;
  esac
done

# ------------------------------------------------------------- environment
[ -e /dev/kvm ] || { [ "$CHECK_ONLY" = "1" ] && { say "check-env: /dev/kvm missing — KVM acceleration unavailable on this host"; exit 0; } || die "/dev/kvm not available (enable VT-x/AMD-V, add yourself to kvm group)"; }
command -v qemu-system-x86_64 >/dev/null 2>&1 || { [ "$CHECK_ONLY" = "1" ] && { say "check-env: qemu-system-x86_64 missing"; exit 0; } || die "qemu-system-x86_64 not installed"; }
command -v swtpm >/dev/null 2>&1 || { [ "$CHECK_ONLY" = "1" ] && { say "check-env: swtpm missing (Windows 11 wants TPM 2.0)"; exit 0; } || die "swtpm not installed (Win11 TPM requirement)"; }
[ "$CHECK_ONLY" = "1" ] && { say "check-env PASS: /dev/kvm + qemu + swtpm present"; exit 0; }

[ -n "$ISO" ] || die "--iso required (your own licensed Windows media — NOTICE.md §4)"
[ -f "$ISO" ] || die "ISO not found: $ISO"
case "$ISO" in *[Ee][Vv][Aa][Ll]*|*";"*) die "suspicious ISO path refused" ;; esac

mkdir -p "$WORKDIR"
DISK_IMG="$WORKDIR/$NAME.qcow2"
if [ ! -f "$DISK_IMG" ]; then
  say "creating $DISK ($DISK)"
  qemu-img create -f qcow2 "$DISK_IMG" "$DISK" >/dev/null
fi

# gate: reachable?
if curl -fsS --max-time 2 "$GATE_URL/policy" >/dev/null 2>&1; then
  say "permission gate reachable — this guest has NO host shares; transfers need explicit approval"
else
  say "WARN: gate daemon not running — start nested-os/permission-gate/gate-daemon.py first"
fi

# swtpm (Win11 TPM 2.0)
TPM_DIR="$WORKDIR/tpm"
mkdir -p "$TPM_DIR"
swtpm socket --tpmstate dir="$TPM_DIR" --ctrl type=unixio,path="$TPM_DIR/swtpm-sock" --tpm2 --daemon

say "launching $NAME (mem $MEM, smp $SMP) — display via SDL/GTK window, audio via PA"
exec qemu-system-x86_64 \
  -name "$NAME" \
  -enable-kvm -cpu host -smp "$SMP" -m "$MEM" \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
  -device virtio-vga-gl -display sdl,gl=on \
  -audiodev pa,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0 \
  -chardev socket,id=chrtpm,path="$TPM_DIR/swtpm-sock" \
  -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -drive file="$DISK_IMG",if=virtio,format=qcow2 \
  -cdrom "$ISO" \
  -boot d
