#!/usr/bin/env python3
"""madt_fake.py — ACPI MADT (APIC) table generator for NEXUS-OS / OpenCore hand-off.

Generates a valid ACPI System Description Table (signature "APIC") describing the
PS5's CPU topology (8 Zen 2 cores / 16 SMT threads by default), the IO APIC, and
NMI routing — the shape OpenCore expects when Sony's dumped tables are patched or
replaced during the UefiPayload hand-off (see docs/03-boot-chain.md).

References: ACPI Specification 6.x, Multiple APIC Description Table (MADT).
This file produces configuration data only; it touches nothing outside --out.

Usage:
  python3 madt_fake.py --cores 8 --threads 2 --out madt.bin
  python3 madt_fake.py --selftest
"""
from __future__ import annotations

import argparse
import struct
import sys

MADT_SIGNATURE = b"APIC"
LAPIC_ADDR = 0xFEE00000
IOAPIC_ADDR = 0xFEC00000

# MADT entry types
T_LAPIC = 0            # Processor Local APIC        (len 8)
T_IOAPIC = 1           # I/O APIC                    (len 12)
T_ISO = 2              # Interrupt Source Override   (len 10)
T_LAPIC_NMI = 4        # Local APIC NMI              (len 6)
T_LAPIC_ADDR_OVR = 5   # Local APIC Address Override (len 12)
T_X2APIC = 9           # Local x2APIC                (len 16)

FLAGS_ENABLED = 0x1
FLAGS_ONLINE_CAPABLE = 0x2  # ACPI 6.3+


def _checksum(data: bytes) -> int:
    return (-sum(data)) & 0xFF


def _header(length: int, oem_id: bytes, oem_table_id: bytes) -> bytes:
    """36-byte ACPI SDT header."""
    hdr = struct.pack(
        "<4sIBB6s8sI4sI",
        MADT_SIGNATURE,          # Signature        (4s)
        length,                  # Length           (I)
        5,                       # Revision         (B)
        0,                       # Checksum         (B) — patched later
        oem_id[:6].ljust(6, b" "),   # OEM ID       (6s)
        oem_table_id[:8].ljust(8, b" "),  # OEM Table ID (8s)
        1,                       # OEM Revision     (I)
        b"NEXU",                 # Creator ID       (4s)
        0x2026_0001,             # Creator Revision (I)
    )
    return hdr


def _entry(etype: int, payload: bytes) -> bytes:
    return struct.pack("<BB", etype, 2 + len(payload)) + payload


def lapic_entries(topology: list[tuple[int, int]], online_capable: bool = False) -> bytes:
    """topology: list of (acpi_uid, apic_id)."""
    flags = FLAGS_ENABLED | (FLAGS_ONLINE_CAPABLE if online_capable else 0)
    out = b""
    for uid, apic_id in topology:
        out += _entry(T_LAPIC, struct.pack("<III", uid, apic_id, flags))
    return out


def x2apic_entries(topology: list[tuple[int, int]]) -> bytes:
    out = b""
    for uid, apic_id in topology:
        out += _entry(T_X2APIC, struct.pack("<IIII", 0, apic_id, FLAGS_ENABLED, uid))
    return out


def ioapic_entry() -> bytes:
    return _entry(T_IOAPIC, struct.pack("<BxII", 2, IOAPIC_ADDR, 0))


def iso_entries() -> bytes:
    """ISA interrupt source overrides (standard PC shape; PS5 follows it)."""
    out = b""
    out += _entry(T_ISO, struct.pack("<BBIH", 0, 0, 2, 0x0000))  # ISA IRQ0 -> GSI2, default polarity
    out += _entry(T_ISO, struct.pack("<BBIH", 0, 9, 9, 0x000D))  # ISA IRQ9 -> GSI9, active-low level
    return out


def nmi_entries(thread_count: int, lint: int = 1, flags: int = 0x000D) -> bytes:
    """NMI on LINT for every processor UID (watchdog/NMI button shape)."""
    out = b""
    for uid, _ in [(u, u) for u in range(thread_count)]:
        out += _entry(T_LAPIC_NMI, struct.pack("<BHB", uid, flags, lint))
    return out


def build_madt(
    cores: int = 8,
    threads: int = 2,
    oem_id: bytes = b"NEXUSOS",
    oem_table_id: bytes = b"PS5MADT",
    use_x2apic: bool = False,
) -> bytes:
    if cores < 1 or threads < 1:
        raise ValueError("cores and threads must be >= 1")
    if cores * threads > 256:
        raise ValueError("refusing to describe more than 256 threads")
    total_threads = cores * threads
    topology = [(uid, uid) for uid in range(total_threads)]

    body = b""
    if use_x2apic:
        body += lapic_entries(topology)          # legacy entries for APIC-mode safety
        body += x2apic_entries(topology)
    else:
        body += lapic_entries(topology)
    body += ioapic_entry()
    body += iso_entries()
    body += nmi_entries(total_threads)
    body += _entry(T_LAPIC_ADDR_OVR, struct.pack("<Q", LAPIC_ADDR))

    total = 36 + len(body)
    hdr = _header(total, oem_id, oem_table_id)
    blob = bytearray(hdr + body)
    blob[9] = _checksum(bytes(blob))  # offset 9 = Checksum field
    return bytes(blob)


def parse_and_verify(blob: bytes) -> dict:
    """Re-parse a MADT blob and verify structure + checksum (used by --selftest)."""
    if len(blob) < 36:
        raise ValueError("shorter than ACPI header")
    sig, length, _rev, csum = struct.unpack_from("<4sIBB", blob, 0)
    if sig != MADT_SIGNATURE:
        raise ValueError(f"bad signature {sig!r}")
    if length != len(blob):
        raise ValueError(f"length field {length} != actual {len(blob)}")
    if _checksum(blob) != 0:
        raise ValueError("checksum mismatch")
    entries: list[tuple[int, int]] = []
    off = 36
    while off < len(blob):
        etype, elen = struct.unpack_from("<BB", blob, off)
        if elen < 2 or off + elen > len(blob):
            raise ValueError(f"bad entry length {elen} at {off}")
        entries.append((etype, elen))
        off += elen
    if off != len(blob):
        raise ValueError("trailing bytes after entries")
    counts: dict[int, int] = {}
    for etype, _ in entries:
        counts[etype] = counts.get(etype, 0) + 1
    return {"checksum": "OK", "length": length, "entry_counts": counts}


def selftest() -> int:
    failures = []
    # default topology
    blob = build_madt()
    info = parse_and_verify(blob)
    if info["entry_counts"].get(T_LAPIC) != 16:
        failures.append(f"expected 16 LAPIC entries, got {info['entry_counts']}")
    if info["entry_counts"].get(T_IOAPIC) != 1:
        failures.append("missing IO APIC entry")
    # x2apic variant
    info2 = parse_and_verify(build_madt(use_x2apic=True))
    if info2["entry_counts"].get(T_X2APIC) != 16:
        failures.append("x2APIC entries wrong count")
    # negative/absurd arguments must raise
    for bad in ({"cores": 0}, {"threads": -1}, {"cores": 999, "threads": 9}):
        try:
            build_madt(**bad)
            failures.append(f"bad args accepted: {bad}")
        except ValueError:
            pass
    # corrupted checksum must be detected
    corrupted = bytearray(build_madt())
    corrupted[9] ^= 0xFF
    try:
        parse_and_verify(bytes(corrupted))
        failures.append("corrupted checksum not detected")
    except ValueError:
        pass

    if failures:
        for f in failures:
            print(f"SELFTEST FAIL: {f}")
        return 1
    print("SELFTEST PASS: checksum, lengths, entry counts, corruption detection OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate ACPI MADT for NEXUS-OS boot chains")
    ap.add_argument("--cores", type=int, default=8, help="physical cores (PS5: 8)")
    ap.add_argument("--threads", type=int, default=2, help="threads per core (PS5: 2, SMT)")
    ap.add_argument("--x2apic", action="store_true", help="also emit Local x2APIC entries")
    ap.add_argument("--oem-id", type=str, default="NEXUSOS")
    ap.add_argument("--oem-table-id", type=str, default="PS5MADT")
    ap.add_argument("--out", type=str, help="output binary path")
    ap.add_argument("--selftest", action="store_true", help="run built-in tests and exit")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    blob = build_madt(
        cores=args.cores,
        threads=args.threads,
        oem_id=args.oem_id.encode(),
        oem_table_id=args.oem_table_id.encode(),
        use_x2apic=args.x2apic,
    )
    info = parse_and_verify(blob)
    if args.out:
        with open(args.out, "wb") as fh:
            fh.write(blob)
        print(f"wrote {args.out}: {len(blob)} bytes, checksum {info['checksum']}")
        print(f"entries: {info['entry_counts']}")
    else:
        print(blob.hex())
    return 0


if __name__ == "__main__":
    sys.exit(main())
