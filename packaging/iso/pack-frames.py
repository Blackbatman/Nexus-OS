#!/usr/bin/env python3
"""pack-frames.py — pack the IGNITION PNG frames into a framebuffer .frb pack.

The QEMU live stage plays the 48-frame IGNITION boot animation (docs/14,
nexus-hub/plasma/boot-splash/plymouth/nexus-ignition/frames/) directly on the
Linux framebuffer. A framebuffer write is a raw pixel dump, so the packer
pre-converts the PNGs once at build time:

  .frb format (little-endian):
    offset 0  magic "NXFB"
    offset 4  u8 version (1)
    offset 5  u8 format (1 = RGB565)
    offset 6  u16 frame count
    offset 8  u16 width
    offset 10 u16 height
    offset 12 u16 reserved
    offset 14 frames: count * width * height * 2 bytes RGB565

Frames are resized (Lanczos) to --width keeping aspect. The player
(nexfblit.c) centers each frame on the active framebuffer mode.

Usage:
  python3 pack-frames.py --src <png-dir> --out ignition.frb [--width 768]
  python3 pack-frames.py --selftest
"""
from __future__ import annotations

import argparse
import glob
import os
import struct
import sys

MAGIC = b"NXFB"
FMT_RGB565 = 1


def rgb565(r: int, g: int, b: int) -> int:
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def pack(png_dir: str, out_path: str, width: int = 768, every: int = 1) -> int:
    from PIL import Image
    files = sorted(glob.glob(os.path.join(png_dir, "f*.png")))[::every]
    if not files:
        raise SystemExit(f"pack-frames: no f*.png in {png_dir}")
    frames = []
    for p in files:
        im = Image.open(p).convert("RGB")
        if im.width != width:
            height = max(1, round(im.height * width / im.width))
            im = im.resize((width, height), Image.LANCZOS)
        frames.append(im)
    w, h = frames[0].width, frames[0].height
    body = bytearray()
    for im in frames:
        assert im.size == (w, h), "frame size drift"
        px = im.tobytes()  # RGB triples
        arr = bytearray(w * h * 2)
        for i in range(w * h):
            v = rgb565(px[3 * i], px[3 * i + 1], px[3 * i + 2])
            arr[2 * i] = v & 0xFF
            arr[2 * i + 1] = v >> 8
        body += arr
    hdr = MAGIC + struct.pack("<BBHHHH", 1, FMT_RGB565, len(frames), w, h, 0)
    with open(out_path, "wb") as f:
        f.write(hdr + bytes(body))
    print(f"pack-frames: {len(frames)} frames {w}x{h} -> {out_path} "
          f"({os.path.getsize(out_path) // 1024} KiB)")
    return 0


def selftest() -> int:
    import tempfile
    from PIL import Image
    tmp = tempfile.mkdtemp()
    for i, color in enumerate([(255, 0, 0), (0, 255, 0)]):
        Image.new("RGB", (8, 4), color).save(os.path.join(tmp, f"f{i:02d}.png"))
    out = os.path.join(tmp, "t.frb")
    pack(tmp, out, width=8)
    buf = open(out, "rb").read()
    assert buf[:4] == MAGIC
    ver, fmt, count, w, h, _res = struct.unpack("<BBHHHH", buf[4:14])
    assert (ver, fmt, count, w, h) == (1, 1, 2, 8, 4), (ver, fmt, count, w, h)
    f0 = buf[14:16]
    v0 = f0[0] | (f0[1] << 8)
    assert (v0 >> 11) << 3 >= 248 and ((v0 >> 5) & 0x3F) << 2 <= 8, "red frame"
    f1 = buf[14 + w * h * 2:][:2]
    v1 = f1[0] | (f1[1] << 8)
    assert ((v1 >> 5) & 0x3F) << 2 >= 252 and (v1 >> 11) << 3 <= 8, "green frame"
    print("pack-frames selftest ok: header + RGB565 roundtrip")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--src")
    ap.add_argument("--out")
    ap.add_argument("--width", type=int, default=768)
    ap.add_argument("--every", type=int, default=1, help="keep every Nth frame")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        sys.exit(selftest())
    if not a.src or not a.out:
        ap.error("--src and --out required")
    sys.exit(pack(a.src, a.out, a.width, a.every))
