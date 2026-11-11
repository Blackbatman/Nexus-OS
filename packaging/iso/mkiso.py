#!/usr/bin/env python3
"""mkiso.py — assemble the NEXUS live-stage ISO (ISO9660 + El Torito).

Thin, defensive wrapper over pycdlib: plain ISO9660 level 1 (all names are
8.3 so no Rock Ridge/Joliet is needed), no-emulation El Torito boot from
ISOLINUX.BIN with the boot info table ISOLINUX requires.

Usage:
  python3 mkiso.py --out image.iso --manifest manifest.tsv
    manifest line: <local-path>\\t<iso-path>   (iso path like /ISOLINUX.BIN;1)
"""
from __future__ import annotations

import sys


def build(out: str, files) -> int:
    import pycdlib
    iso = pycdlib.PyCdlib()
    iso.new(interchange_level=1, vol_ident="NEXUS_LIVE_STAGE")
    made_dirs = set()
    for local, iso_path in files:
        # pycdlib requires every parent directory to exist before add_file
        parent = iso_path.rsplit("/", 1)[0]
        while parent and parent not in made_dirs:
            iso.add_directory(parent)
            made_dirs.add(parent)
            parent = parent.rsplit("/", 1)[0] if "/" in parent else ""
        iso.add_file(local, iso_path=iso_path)
    boot = None
    for _, iso_path in files:
        if iso_path.upper().endswith("ISOLINUX.BIN;1"):
            boot = iso_path
            break
    if boot is None:
        raise SystemExit("mkiso: manifest has no ISOLINUX.BIN;1 boot file")
    try:
        iso.add_eltorito(boot, boot_info_table=True)
    except TypeError:  # older pycdlib without boot_info_table kw
        iso.add_eltorito(boot)
    iso.write(out)
    iso.close()
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--out" not in args or "--manifest" not in args:
        print(__doc__)
        sys.exit(2)
    out = args[args.index("--out") + 1]
    man = args[args.index("--manifest") + 1]
    files = []
    for line in open(man, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        local, isopath = line.split("\t")
        files.append((local, isopath))
    sys.exit(build(out, files))
