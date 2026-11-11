#!/usr/bin/env bash
# fetch-deps.sh — pull the live-stage toolchain WITHOUT root (unprivileged
# apt-download + dpkg -x into a private prefix). Needed because the ISO build
# (build-iso.sh) requires: a Linux kernel image, static busybox + bash, and
# the ISOLINUX boot loader — none of which this repo ships.
#
#   packaging/iso/fetch-deps.sh [--qemu] [--out build/deps]
#
#   --qemu     also fetch a private qemu-system-x86_64 (for --smoke on
#              hosts without qemu installed)
#   --out DIR  dependency prefix (default: <repo>/build/deps)
#
# Everything lands under DIR/<name>/x/… (dpkg -x layout). build-iso.sh
# auto-probes system paths first, then this prefix. Requires: apt, dpkg,
# network access to the Debian/Ubuntu mirror configured on the host.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${HERE}/../../build/deps"
QEMU=0
while [ $# -gt 0 ]; do
  case "$1" in
    --qemu) QEMU=1 ;;
    --out)  OUT="$2"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
mkdir -p "$OUT"
export DEBIAN_FRONTEND=noninteractive

dl() { # dl <package…> — download (no root) and dpkg -x into OUT/<first-pkg>/x
  local dest="$OUT/$1/x"
  mkdir -p "$dest"
  ( cd "$dest" && apt-get download "$@" >/dev/null 2>&1 )
  local f
  for f in "$dest"/*.deb; do
    [ -e "$f" ] || continue
    dpkg -x "$f" "$dest"
    rm -f "$f"
  done
  echo "fetched: $*"
}

say() { printf '[fetch-deps] %s\n' "$*"; }

# ── kernel: newest vmlinuz from the versioned linux-image package ───────────
if [ ! -d "$OUT/kernel/x/boot" ]; then
  META_DEP="$(apt-cache show linux-image-amd64 2>/dev/null | awk '/^Depends:/{print $2; exit}')"
  [ -n "$META_DEP" ] || META_DEP="$(apt-cache show linux-image-generic 2>/dev/null | awk '/^Depends:/{print $2; exit}')"
  [ -n "$META_DEP" ] || { say "no linux-image meta package found"; exit 1; }
  say "kernel meta dependency: $META_DEP"
  rm -rf "$OUT/kernel"
  mkdir -p "$OUT/kernel/x"
  ( cd "$OUT/kernel/x" && apt-get download "$META_DEP" >/dev/null 2>&1 )
  for f in "$OUT/kernel/x"/*.deb; do
    [ -e "$f" ] || continue
    dpkg -x "$f" "$OUT/kernel/x"
    rm -f "$f"
  done
  echo "fetched: $META_DEP -> $OUT/kernel"
fi

# ── static shells ────────────────────────────────────────────────────────────
[ -e "$OUT/busybox-static/x/usr/bin/busybox" ] || dl busybox-static
[ -e "$OUT/bash-static/x/usr/bin/bash-static" ] || dl bash-static

# ── ISOLINUX ────────────────────────────────────────────────────────────────
if [ ! -e "$OUT/isolinux/x/usr/lib/ISOLINUX/isolinux.bin" ]; then
  dl isolinux
fi
if [ ! -e "$OUT/syslinux-common/x/usr/lib/syslinux/modules/bios/ldlinux.c32" ]; then
  dl syslinux-common
fi

# ── optional private qemu ────────────────────────────────────────────────────
if [ "$QEMU" = "1" ] && [ ! -e "$OUT/qemu/qemu-wrapper.sh" ]; then
  say "resolving qemu-system-x86_64 dependency closure (no recommends)…"
  PKGS="$(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts \
        --no-breaks --no-replaces --no-enhances qemu-system-x86 seabios 2>/dev/null \
        | grep '^[a-zA-Z0-9]' | sort -u)"
  mkdir -p "$OUT/qemu/x"
  ( cd "$OUT/qemu/x" && apt-get download $PKGS >/dev/null 2>&1 )
  for f in "$OUT/qemu/x"/*.deb; do
    [ -e "$f" ] || continue
    dpkg -x "$f" "$OUT/qemu/x"
    rm -f "$f"
  done
  LIBD="$OUT/qemu/x/usr/lib/x86_64-linux-gnu:$OUT/qemu/x/lib/x86_64-linux-gnu"
  {
    echo '#!/bin/sh'
    echo 'DIR="$(cd "$(dirname "$0")" && pwd)"'
    echo "LD_LIBRARY_PATH=$LIBD exec \"\$DIR/x/usr/bin/qemu-system-x86_64\" -L \"\$DIR/x/usr/share/qemu\" -L \"\$DIR/x/usr/share/seabios\" -L \"\$DIR/x/usr/share\" \"\$@\""
  } > "$OUT/qemu/qemu-wrapper.sh"
  chmod +x "$OUT/qemu/qemu-wrapper.sh"
fi

say "dependencies ready under $OUT"
[ -e "$OUT/kernel/x/boot" ] && ls "$OUT/kernel/x/boot" | sed 's/^/[fetch-deps]   /'
exit 0
