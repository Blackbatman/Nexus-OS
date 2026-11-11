#!/usr/bin/env python3
"""mkcpio.py — deterministic newc-format cpio writer for the NEXUS live stage.

The initramfs for the QEMU bootable ISO is assembled from files that must be
archived without depending on a system cpio binary (unprivileged builds,
reproducible CI). This module writes the SVR4 "newc" ASCII format the Linux
kernel expects (Documentation/driver-api/early-userspace/ buffer-format.rst).

Entry tuple: (name: str, mode: int, data: bytes, link: str|None)
  - regular file : data is bytes
  - directory    : data is b""  (mode 0o755)
  - symlink      : link is the target string (mode 0o777)

Usage:
  python3 mkcpio.py --out initramfs.cpio < manifest.tsv     # build
  python3 mkcpio.py --selftest                              # roundtrip check
"""
from __future__ import annotations

import sys

MAGIC = b"070701"
TRAILER = "TRAILER!!!"
S_IFREG, S_IFDIR, S_IFLNK, S_IFCHR, S_IFBLK = (0o100000, 0o40000, 0o120000,
                                               0o020000, 0o060000)


def _hdr(ino: int, mode: int, uid: int, gid: int, nlink: int, mtime: int,
         filesize: int, namesize: int, rdevmajor: int = 0, rdevminor: int = 0) -> bytes:
    fields = (ino, mode, uid, gid, nlink, mtime, filesize,
              0, 0, rdevmajor, rdevminor, namesize, 0)  # dev maj/min = 0
    return MAGIC + b"".join(f"{f:08X}".encode() for f in fields)


def _pad(buf: bytearray, align: int = 4) -> None:
    while len(buf) % align:
        buf.append(0)


def write_cpio(entries, out, mtime: int = 0) -> None:
    """entries: iterable of (name, mode, data, link[, rdevmajor, rdevminor]);
    writes archive to `out` path. Device nodes carry empty data and their
    major/minor in the rdev header fields (newc spec)."""
    buf = bytearray()
    for ino, ent in enumerate(entries, start=1):
        name, mode, data, link = ent[0], ent[1], ent[2], ent[3]
        rj, rn = (ent[4], ent[5]) if len(ent) > 5 else (0, 0)
        if link is not None:
            data, mode = link.encode(), S_IFLNK | 0o777
        elif mode & 0o170000 == 0:            # no file type bits given
            mode = S_IFREG | (mode & 0o7777)
        name_b = name.encode()
        if name.startswith("/"):
            name_b = name_b[1:]
        hdr = _hdr(ino, mode, 0, 0, 1, mtime, len(data), len(name_b) + 1, rj, rn)
        buf += hdr + name_b + b"\0"
        _pad(buf)
        buf += data
        _pad(buf)
    buf += _hdr(0, 0, 0, 0, 1, mtime, 0, len(TRAILER) + 1) + TRAILER.encode() + b"\0"
    _pad(buf)
    with open(out, "wb") as f:
        f.write(buf)


def parse_cpio(buf: bytes):
    """Minimal newc parser used by the selftest (and by nobody else)."""
    out, pos = [], 0
    while True:
        if buf[pos:pos + 6] != MAGIC:
            raise ValueError(f"bad magic at {pos}: {buf[pos:pos+6]!r}")
        f = [int(buf[pos + 6 + i * 8: pos + 14 + i * 8], 16) for i in range(13)]
        namesize, filesize, mode = f[11], f[6], f[1]
        pos += 110
        name = buf[pos: pos + namesize - 1].decode()
        pos += namesize
        pos += (4 - pos % 4) % 4
        data = buf[pos: pos + filesize]
        pos += filesize
        pos += (4 - pos % 4) % 4
        if name == TRAILER:
            return out
        out.append((name, mode, data))


def entries_from_dir(root: str, nodes=None):
    """Walk `root` (a staged initramfs tree) in deterministic sorted order.
    Directories get mode 0755, files keep their exec bit, symlinks are
    preserved as symlinks. `nodes` adds device nodes as (path, char?,
    major, minor, mode) — the kernel needs /dev/console to exist before
    devtmpfs is mounted. Returns the (name, mode, data, link) tuples."""
    import os
    ents = []
    root = root.rstrip("/")
    for cur, dirs, files in os.walk(root):
        dirs.sort()
        rel = os.path.relpath(cur, root)
        if rel != ".":
            ents.append((rel.replace(os.sep, "/"), S_IFDIR | 0o755, b"", None))
        for fn in sorted(files):
            p = os.path.join(cur, fn)
            name = os.path.relpath(p, root).replace(os.sep, "/")
            if os.path.islink(p):
                ents.append((name, 0o777, b"", os.readlink(p)))
            else:
                st = os.stat(p)
                mode = 0o755 if st.st_mode & 0o111 else 0o644
                with open(p, "rb") as f:
                    ents.append((name, mode, f.read(), None))
    for path, is_char, major, minor, mode in (nodes or []):
        dev_type = 0o020000 if is_char else 0o060000
        ents.append((path, dev_type | mode, b"", None, major, minor))
    return ents


def selftest() -> int:
    import tempfile, os
    tmp = tempfile.mkdtemp()
    arc = os.path.join(tmp, "t.cpio")
    ents = [
        ("dir", 0o755, b"", None),
        ("bin/sh", 0o755, b"#!payload", None),
        ("bin/busybox-link", 0o777, b"", "/bin/busybox"),
        ("etc/release", 0o644, "NEXUS-OS live stage\n".encode(), None),
    ]
    write_cpio(ents, arc, mtime=1700000000)
    buf = open(arc, "rb").read()
    back = parse_cpio(buf)
    assert len(back) == 4, back
    names = [n for n, _, _ in back]
    assert names == ["dir", "bin/sh", "bin/busybox-link", "etc/release"], names
    assert dict((n, d) for n, _, d in back)["bin/sh"] == b"#!payload"
    # symlink roundtrip: data holds the target, mode says LNK
    m = dict((n, m) for n, m, _ in back)["bin/busybox-link"]
    assert m & 0o170000 == S_IFLNK, oct(m)
    assert dict((n, d) for n, _, d in back)["bin/busybox-link"] == b"/bin/busybox"
    # trailing record exists after entries
    assert buf.rstrip(b"\0").endswith(TRAILER.encode())
    # device node roundtrip: rdev fields land in the header, no data
    arc2 = os.path.join(tmp, "d.cpio")
    write_cpio([("dev/console", S_IFCHR | 0o600, b"", None, 5, 1)], arc2)
    back2 = parse_cpio(open(arc2, "rb").read())
    assert back2[0][0] == "dev/console" and back2[0][1] & 0o170000 == S_IFCHR, back2
    print("mkcpio selftest ok: 4 entries roundtrip + trailer + devnode")
    return 0


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    args = sys.argv[1:]
    if "--from-dir" in args:
        root = args[args.index("--from-dir") + 1]
        out = args[args.index("--out") + 1]
        nodes = []
        if "--nodes" in args:
            for spec in args[args.index("--nodes") + 1].split(","):
                path, kind, major, minor, mode = spec.split(":")
                nodes.append((path, kind == "c", int(major), int(minor), int(mode, 8)))
        ents = entries_from_dir(root, nodes)
        write_cpio(ents, out)
        print(f"mkcpio: wrote {out} from {root} ({len(ents)} entries)")
        sys.exit(0)
    if "--out" not in args or args.index("--out") + 1 >= len(args):
        print(__doc__)
        sys.exit(2)
    out = args[args.index("--out") + 1]
    ents = []
    for line in sys.stdin.read().splitlines():
        parts = line.split("\t")
        if not parts or parts == [""]:
            continue
        name, mode, data = parts[0], int(parts[1], 8), parts[2].encode() if parts[2] else b""
        link = parts[3] if len(parts) > 3 and parts[3] else None
        ents.append((name, mode, data, link))
    write_cpio(ents, out)
    print(f"mkcpio: wrote {out} ({len(ents)} entries)")
