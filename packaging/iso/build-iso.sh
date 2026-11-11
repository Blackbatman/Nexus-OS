#!/usr/bin/env bash
# build-iso.sh — assemble the NEXUS-OS QEMU live-stage ISO (F24, docs/16).
#
# Produces a BIOS-bootable ISO9660 (ISOLINUX, El Torito) containing:
#   · the Debian kernel picked by NEXUS_ISO_KERNEL / host /boot / fetch-deps
#   · an initramfs with: static busybox+bash, a pruned CPython runtime,
#     nexfblit (framebuffer IGNITION player), the 48-frame IGNITION pack,
#     the NEXUS hub TUI, and the real repo tooling (bootchain dry-run,
#     statecheck, hwtest probes, permission gate)
#
# The build is unprivileged and self-contained: dependencies come from the
# system or from fetch-deps.sh (apt-get download + dpkg -x, no root).
#
#   packaging/iso/build-iso.sh [--out DIR] [--smoke] [--no-anim]
#                              [--every N] [--width W]
#
#   --smoke     boot the ISO headless in QEMU and require the IGNITION +
#               hub markers on the serial console (needs qemu-system-x86_64)
#   --no-anim   skip the frame pack (ASCII IGNITION only, smaller initramfs)
#   --every N   keep every Nth IGNITION frame (48 default, 24 with N=2)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$REPO/dist"
BUILD="$REPO/build"
SMOKE=0; NOANIM=0; EVERY=1; WIDTH=512
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --smoke) SMOKE=1; shift ;;
    --no-anim) NOANIM=1; shift ;;
    --every) EVERY="$2"; shift 2 ;;
    --width) WIDTH="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\033[nexus-iso]\033 %s\n' "$*"; }
die() { printf '\033[nexus-iso] FAIL\033 %s\n' "$*" >&2; exit 1; }
DEPS="$BUILD/deps"

# ── 1 · toolchain resolution (env → system → fetch-deps prefix) ─────────────
find_first() { for p in "$@"; do [ -e "$p" ] && { printf '%s' "$p"; return 0; }; done; return 1; }

KERNEL_IMG="${NEXUS_ISO_KERNEL:-$(find_first $(ls -1 /boot/vmlinuz-* 2>/dev/null | sort -V | tail -1) \
  "$DEPS"/kernel/x/boot/vmlinuz-* 2>/dev/null || true)}"
[ -n "$KERNEL_IMG" ] && [ -e "$KERNEL_IMG" ] || die "no kernel image (set NEXUS_ISO_KERNEL or run fetch-deps.sh)"

BUSYBOX_BIN="${NEXUS_ISO_BUSYBOX:-$(find_first /usr/bin/busybox "$DEPS/busybox-static/x/usr/bin/busybox" || true)}"
[ -n "$BUSYBOX_BIN" ] || die "no busybox (run fetch-deps.sh)"
grep -q 'statically linked' <(file -b "$BUSYBOX_BIN") || die "busybox at $BUSYBOX_BIN is not static"

BASH_BIN="${NEXUS_ISO_BASH:-$(find_first "$DEPS/bash-static/x/usr/bin/bash-static" /usr/bin/bash-static || true)}"
[ -n "$BASH_BIN" ] || die "no static bash (run fetch-deps.sh)"

ISOLINUX_BIN="${NEXUS_ISO_ISOLINUX:-$(find_first /usr/lib/ISOLINUX/isolinux.bin "$DEPS/isolinux/x/usr/lib/ISOLINUX/isolinux.bin" || true)}"
LDLINUX_C32="${NEXUS_ISO_LDLINUX:-$(find_first /usr/lib/syslinux/modules/bios/ldlinux.c32 "$DEPS/syslinux-common/x/usr/lib/syslinux/modules/bios/ldlinux.c32" || true)}"
[ -n "$ISOLINUX_BIN" ] && [ -n "$LDLINUX_C32" ] || die "isolinux.bin/ldlinux.c32 missing (run fetch-deps.sh)"

PYBASE="$(ls -1 /usr/bin/python3.[0-9]* 2>/dev/null | grep -v config | sort -V | tail -1 || true)"
[ -n "$PYBASE" ] || PYBASE="$(find_first /usr/local/bin/python3 || true)"
[ -n "$PYBASE" ] || die "no python3 runtime to embed"

command -v gcc >/dev/null 2>&1 || die "gcc needed to build nexfblit (CC env supported)"
CC="${CC:-gcc}"

say "kernel   : $KERNEL_IMG"
say "busybox  : $BUSYBOX_BIN (static)"
say "bash     : $BASH_BIN (static)"
say "python   : $PYBASE"
say "isolinux : $ISOLINUX_BIN"

# ── 2 · stage assembly ───────────────────────────────────────────────────────
STAGE="$BUILD/iso-stage"
rm -rf "$STAGE" "$BUILD/initramfs.cpio" "$BUILD/iso-files"
mkdir -p "$STAGE"

cp -a "$HERE/overlay/." "$STAGE/"
chmod 755 "$STAGE/init" "$STAGE/opt/nexus/hub.sh" "$STAGE/opt/nexus/ascii-ignition.sh"

mkdir -p "$STAGE/bin" "$STAGE/opt/nexus/lib" "$STAGE/opt/nexus/anim"
cp "$BUSYBOX_BIN" "$STAGE/bin/busybox"
ln -s busybox "$STAGE/bin/sh"
# pre-create every busybox applet symlink (no runtime /proc dependency)
for applet in $("$BUSYBOX_BIN" --list); do
  [ -e "$STAGE/bin/$applet" ] || ln -s busybox "$STAGE/bin/$applet"
done
cp "$BASH_BIN" "$STAGE/bin/bash"

mkdir -p "$STAGE/usr/local/bin"
"$CC" -O2 -s -static -o "$STAGE/usr/local/bin/nexfblit" "$HERE/src/nexfblit.c" \
  || die "nexfblit build failed"
say "nexfblit : built (static)"

# pruned CPython runtime (stdlib only, stdlib path preserved)
PYVER="$("$PYBASE" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
mkdir -p "$STAGE/usr/bin" "$STAGE/usr/lib"
cp "$PYBASE" "$STAGE/usr/bin/python3.$PYVER"
ln -s "python3.$PYVER" "$STAGE/usr/bin/python3"
if [ -d "/usr/lib/python$PYVER" ]; then
  python3 - "$PYVER" "$STAGE" <<'PY'
import shutil, sys
ver, stage = sys.argv[1], sys.argv[2]
src = f"/usr/lib/python{ver}"
dst = f"{stage}/usr/lib/python{ver}"
ignore = shutil.ignore_patterns(
    "__pycache__", "test*", "idlelib", "tkinter", "turtledemo", "turtle.py",
    "pydoc_data", "ensurepip", "lib2to3", "site-packages", "config-*",
    "dist-packages", "EXTERNALLY-MANAGED")
shutil.copytree(src, dst, ignore=ignore)
print(f"[nexus-iso] stdlib: {src} -> {dst}")
PY
else
  say "WARN: no stdlib at /usr/lib/python$PYVER — hub features degrade to ASCII"
fi
# dynamic loader + library closure of the interpreter (keeps exact paths)
mkdir -p "$STAGE/lib64" "$STAGE/usr/lib/x86_64-linux-gnu" "$STAGE/lib/x86_64-linux-gnu"
ldd "$PYBASE" 2>/dev/null | awk '{print $3}' | while read -r lib; do
  [ -f "$lib" ] || continue
  case "$lib" in
    /lib64/*) mkdir -p "$STAGE/lib64"; cp -L "$lib" "$STAGE/lib64/" ;;
    /usr/lib/x86_64-linux-gnu/*) cp -L "$lib" "$STAGE/usr/lib/x86_64-linux-gnu/" ;;
    /lib/x86_64-linux-gnu/*) cp -L "$lib" "$STAGE/lib/x86_64-linux-gnu/" ;;
    *) cp -L "$lib" "$STAGE/usr/lib/x86_64-linux-gnu/" ;;
  esac
done
for so in ld-linux-x86-64.so.2; do
  SRC="$(ls /lib64/$so* 2>/dev/null | head -1 || true)"
  [ -n "$SRC" ] && cp -L "$SRC" "$STAGE/lib64/"
done
say "python   : embedded ($PYVER + stdlib + loader closure)"

# real repo tooling, dry-run guards intact
mkdir -p "$STAGE/opt/nexus/repo"
for d in bootchain tools nested-os agents; do
  cp -a "$REPO/$d" "$STAGE/opt/nexus/repo/$d"
done
mkdir -p "$STAGE/opt/nexus/repo/docs"
for f in "$REPO"/docs/1[2346]-*.md; do
  [ -f "$f" ] && cp "$f" "$STAGE/opt/nexus/repo/docs/"
done
for f in NOTICE.md README.md; do
  [ -f "$REPO/$f" ] && cp "$REPO/$f" "$STAGE/opt/nexus/repo/$f"
done
find "$STAGE/opt/nexus/repo" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true

# IGNITION frame pack (docs/14 frames → RGB565 .frb)
if [ "$NOANIM" != "1" ]; then
  FRAMES="$REPO/nexus-hub/plasma/boot-splash/plymouth/nexus-ignition/frames"
  python3 "$HERE/pack-frames.py" --src "$FRAMES" --out "$STAGE/opt/nexus/anim/ignition.frb" \
    --width "$WIDTH" --every "$EVERY" || die "frame pack failed"
else
  say "anim     : skipped (--no-anim) — ascii ignition only"
fi

VERSION="${NEXUS_ISO_VERSION:-$(git -C "$REPO" describe --tags --always 2>/dev/null || echo 0.2.0-beta-dev)}"
mkdir -p "$STAGE/etc"
printf 'NEXUS-OS %s — LIVE STAGE (QEMU)\none console, every OS · docs/14 NEXUS Metro identity\n' "$VERSION" > "$STAGE/etc/nexus-release"
printf 'NEXUS-OS live stage \n' > "$STAGE/etc/issue"

# ── 3 · initramfs ─────────────────────────────────────────────────────────────
python3 "$HERE/mkcpio.py" --from-dir "$STAGE" --out "$BUILD/initramfs.cpio" \
  --nodes 'dev/console:c:5:1:600,dev/null:c:1:3:666,dev/tty:c:5:0:666,dev/ttyS0:c:4:64:600,dev/fb0:c:29:0:600'
gzip -9c "$BUILD/initramfs.cpio" > "$BUILD/iso-files-tmp.gzip"
say "initramfs: $(du -h "$BUILD/initramfs.cpio" | cut -f1) unpacked, $(du -h "$BUILD/iso-files-tmp.gzip" | cut -f1) gzipped"

# ── 4 · ISO (pycdlib: ISO9660 L1 + El Torito, boot info table) ───────────────
mkdir -p "$BUILD/iso-files/isolinux" "$OUT"
cp "$ISOLINUX_BIN"  "$BUILD/iso-files/isolinux/ISOLINUX.BIN"
cp "$LDLINUX_C32"   "$BUILD/iso-files/isolinux/LDLINUX.C32"
cp "$HERE/isolinux.cfg" "$BUILD/iso-files/isolinux/ISOLINUX.CFG"
cp "$HERE/nexus.msg"    "$BUILD/iso-files/isolinux/NEXUS.MSG"
mv "$BUILD/iso-files-tmp.gzip" "$BUILD/iso-files/isolinux/INITRD.GZ"
cp "$KERNEL_IMG"    "$BUILD/iso-files/isolinux/BOOT.VMZ"

: > "$BUILD/iso-manifest.tsv"
while IFS= read -r f; do
  base="$(basename "$f")"
  printf '%s\t/ISOLINUX/%s;1\n' "$f" "$base" >> "$BUILD/iso-manifest.tsv"
done < <(find "$BUILD/iso-files/isolinux" -maxdepth 1 -type f | sort)

ISO="$OUT/NEXUS-OS-${VERSION}-live-stage-amd64.iso"
python3 "$HERE/mkiso.py" --out "$ISO" --manifest "$BUILD/iso-manifest.tsv"
say "iso      : $ISO ($(du -h "$ISO" | cut -f1))"

# ── 5 · optional QEMU smoke boot ─────────────────────────────────────────────
if [ "$SMOKE" = "1" ]; then
  QEMU_BIN="${NEXUS_ISO_QEMU:-$(find_first "$DEPS/qemu/qemu-wrapper.sh" || true)}"
  [ -n "$QEMU_BIN" ] || QEMU_BIN="$(command -v qemu-system-x86_64 || true)"
  [ -n "$QEMU_BIN" ] || die "--smoke: no qemu-system-x86_64 (install it or fetch-deps.sh --qemu)"
  LOG="$OUT/nexus-iso-smoke.log"
  rm -f "$LOG"
  say "smoke    : booting headless (TCG, up to 300 s)…"
  "$QEMU_BIN" -m 1024 -cdrom "$ISO" -boot d -display none -no-reboot \
    -serial "file:$LOG" >/dev/null 2>&1 &
  QPID=$!
  OK=0
  for _ in $(seq 1 100); do   # 100 × 3 s
    sleep 3
    kill -0 "$QPID" 2>/dev/null || break
    if grep -q '\[nexus-iso\] IGNITION complete' "$LOG" 2>/dev/null \
       && grep -q '\[nexus-iso\] hub ready' "$LOG" 2>/dev/null; then
      OK=1; break
    fi
  done
  kill "$QPID" 2>/dev/null || true
  wait "$QPID" 2>/dev/null || true
  if [ "$OK" = "1" ]; then
    say "smoke    : PASS — IGNITION + hub markers present ($LOG)"
    grep '\[nexus-iso\]' "$LOG" | head -12 | sed 's/^/[nexus-iso]     /'
  else
    say "smoke    : FAIL — markers missing"
    [ -f "$LOG" ] && tail -20 "$LOG" >&2
    exit 1
  fi
fi

say "done."
