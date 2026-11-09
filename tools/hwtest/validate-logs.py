#!/usr/bin/env python3
"""validate-logs.py — F18 checkpoint validator for NEXUS-OS hardware runs.

Takes the artifacts of one operator boot attempt (a ktty log, optionally the
nexus-bootd dispatch log) plus a metadata JSON, checks them against the
per-chain checkpoint tables from docs/12-hardware-validation.md, and prints:

  * a verdict JSON  (machine-readable, goes into reports/)
  * a docs/04 markdown row snippet (hardware-support matrix evidence line)

Verdict rules (docs/12 §6):
  PASS     every required checkpoint matched, in order, and >=1 post-handoff
           evidence line matched
  PARTIAL  every required checkpoint matched but zero post-handoff evidence
           (the hop started, hand-off died early)
  FAIL     a required checkpoint is missing/out of order, or a FAIL marker
           fired, or the log is empty
No verdict ever upgrades a chain in docs/04 on its own — the beta QA owner
re-reviews the raw log before any matrix row lands (docs/06 L6).

Usage:
  validate-logs.py --chain M --ktty ktty.log [--bootlog boot-log.txt]
                   --meta meta.json [--out verdict.json]
  validate-logs.py --chain L --ktty ktty.log --meta meta.json --quiet
  validate-logs.py --selftest

This tool ships NO exploit code, offsets or payloads (NOTICE.md §2). It only
reads logs the operator already captured.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*m|\x1b")  # raw ESC prefixes used by the chain scripts

# --------------------------------------------------------------------------
# Checkpoint tables (docs/12 §5).  Required = our own emitted markers, in
# order.  Evidence = post-hand-off lines from upstream components (stage1,
# EDK2/OpenCore, XNU, Linux kernel, Windows Boot Manager) — any-of sets.
# --------------------------------------------------------------------------
CHAINS: dict = {
    "M": {
        "name": "macOS crash-kexec hop (Monterey 12.7.6)",
        "dispatch": r"\[nexus-bootd\].*dispatch .* chainload-macos\.sh \(chain M",
        "required": [
            ("banner", r"\[nexus:chainM\] chain M \(macOS crash-hop\)"),
            ("stage1-path", r"\[nexus:chainM\] stage1\s+: \S+"),
            ("plan", r"\[nexus:chainM\] plan\s+: kexec -p stage1"),
            ("staging", r"\[nexus:chainM\] staging stage1 as crash kernel"),
            ("arming", r"\[nexus:chainM\] arming crash hop \(sysrq-c\)"),
        ],
        "evidence": [
            r"UefiPayload", r"EDK2", r"OpenCore", r"boot\.efi",
            r"XNU|Darwin", r"\bMacOS\b", r"apfs",
        ],
    },
    "L": {
        "name": "Linux direct kexec (8-flavor roster)",
        "dispatch": r"\[nexus-bootd\].*dispatch .* chainload-linux\.sh \(chain L, flavor (\S+?), READY\)",
        "required": [
            ("banner", r"\[nexus:chainL\] chain L \(Linux direct kexec\) — flavor: (\S+)"),
            ("kernel", r"\[nexus:chainL\] kernel\s+: \S+"),
            ("initrd", r"\[nexus:chainL\] initrd\s+: \S+"),
            ("append", r"\[nexus:chainL\] append\s+: \S+"),
            ("exec", r"\[nexus:chainL\] kernel staged; executing"),
        ],
        "evidence": [
            r"Linux version \d", r"Run /init", r"systemd\[1\]",
            r"Freeing unused kernel", r"ps5|sony|amdgpu|cyan",
        ],
        "flavor_group": 1,
    },
    "W": {
        "name": "Windows research hand-off (UefiPayload → bootmgfw)",
        "dispatch": r"\[nexus-bootd\].*dispatch .* chainload-windows\.sh \(chain W",
        "required": [
            ("banner", r"\[nexus:chainW\] chain W \(Windows\) — RESEARCH GRADE"),
            ("payload", r"\[nexus:chainW\] uefipayload\s+: \S+"),
            ("volume", r"\[nexus:chainW\] win volume\s+: \S+"),
            ("limits", r"\[nexus:chainW\] limits\s+: USB-only storage"),
        ],
        "evidence": [
            r"nexus_uefi_handoff", r"bootmgfw", r"BdsDxe", r"UEFI",
            r"WinLoader|BOOTMGR", r"Windows Boot Manager",
        ],
    },
}

FAIL_MARKERS = [r"\[nexus-bootd\] FAIL", r"\[nexus:chainM\] FAIL",
                r"\[nexus:chainL\] FAIL", r"\[nexus:chainW\] FAIL"]

REQUIRED_META = ("chain", "firmware", "entry", "console_model", "operator", "date")
ALLOWED_ENTRIES = ("relapse", "byepervisor-reborn", "pppwn-family", "other")


def normalize(text: str) -> str:
    return ANSI.sub("", text)


def read_log(path: str) -> str:
    return normalize(Path(path).read_text(errors="replace"))


def validate(chain_id: str, ktty: str, bootlog, meta: dict) -> dict:
    problems = []
    if chain_id not in CHAINS:
        return {"verdict": "FAIL", "chain": chain_id,
                "problems": [f"unknown chain '{chain_id}' (known: M L W)"]}

    spec = CHAINS[chain_id]
    for key in REQUIRED_META:
        if not str(meta.get(key, "")).strip():
            problems.append(f"meta missing field: {key}")
    if meta.get("entry") not in ALLOWED_ENTRIES:
        problems.append(f"meta.entry must be one of {ALLOWED_ENTRIES} (got {meta.get('entry')!r})")

    full = read_log(ktty)
    if bootlog:
        full += "\n" + read_log(bootlog)
    if not full.strip():
        return {"verdict": "FAIL", "chain": chain_id, "meta": meta,
                "problems": problems + ["log is empty — capture ran before the attempt?"]}

    # dispatch line (from nexus-bootd, usually in the boot log)
    disp = re.search(spec["dispatch"], full)
    if not disp:
        problems.append("required: nexus-bootd dispatch line for chain " + chain_id)

    flavor = None
    if "flavor_group" in spec and disp:
        flavor = disp.group(spec["flavor_group"])

    # required checkpoints, in order
    cursor = 0
    last_good = None
    for name, pattern in spec["required"]:
        m = re.search(pattern, full[cursor:])
        if not m:
            problems.append("required checkpoint missing/out-of-order after "
                            f"'{last_good or 'start'}': {name}")
            break
        last_good = name
        cursor += m.start()

    # failure markers anywhere
    fails = [p for p in FAIL_MARKERS if re.search(p, full)]
    if fails:
        problems.append(f"FAIL marker present: {fails[0]}")

    # post-hand-off evidence (any-of)
    evidence_hits = [pat for pat in spec["evidence"] if re.search(pat, full)]

    if fails or problems:
        verdict = "FAIL"
    elif evidence_hits:
        verdict = "PASS"
    else:
        verdict = "PARTIAL"
        problems.append("no post-handoff evidence line matched (hop started, hand-off died early)")

    return {
        "verdict": verdict,
        "chain": chain_id,
        "chain_name": spec["name"],
        "flavor": flavor,
        "last_good_checkpoint": last_good,
        "evidence_hits": evidence_hits,
        "problems": problems,
        "meta": meta,
    }


def docs04_row(res: dict) -> str:
    """One evidence line in the docs/04 maintenance-rule format."""
    m = res["meta"]
    fw = m.get("firmware", "?")
    entry = m.get("entry", "?")
    flavor = f" flavor={res['flavor']}" if res.get("flavor") else ""
    ev = ",".join(res.get("evidence_hits") or ["none"])
    tail = res.get("last_good_checkpoint") or "no-required-checkpoint"
    return (f"chain {res['chain']}{flavor} @FW {fw} ({entry}): verdict={res['verdict']} "
            f"last-good={tail} evidence=[{ev}] — log pending beta QA review (F18)")


def _meta(chain: str, flavor=None, entry: str = "relapse") -> dict:
    m = {
        "chain": chain,
        "firmware": "13.42",
        "entry": entry,
        "console_model": "CFI-1015A launch model",
        "operator": "beta-qa",
        "date": "2026-11-09",
        "notes": "synthetic selftest log",
    }
    if flavor:
        m["flavor"] = flavor
    return m


def selftest() -> int:
    """Synthetic logs for all three chains plus failure shapes. Offline."""
    import os
    import tempfile

    chain_m_ok = (
        "[nexus-bootd] dispatch: chain M (macOS) — PROVEN path\n"
        "\x1b[1;35m[nexus-bootd]\x1b[0m dispatch → chainload-macos.sh (chain M, PROVEN upstream)\n"
        "\x1b[1;35m[nexus:chainM]\x1b[0m chain M (macOS crash-hop) — upstream-PROVEN on FW 13.42 launch model\n"
        "[nexus:chainM] stage1  : /mnt/usb0/nexus/stage1/stage1.elf\n"
        "[nexus:chainM] plan    : kexec -p stage1 → enable sysrq → sysrq-c\n"
        "[nexus:chainM] staging stage1 as crash kernel…\n"
        "[nexus:chainM] arming crash hop (sysrq-c) — console log goes to /tmp/ktty.log\n"
        "EDK2 [UEFI] UefiPayload: loading OpenCore\n"
        "boot.efi: XNU Darwin kernel start\n"
    )
    chain_m_partial = chain_m_ok.split("EDK2")[0]
    chain_l_ok = (
        "\x1b[1;35m[nexus-bootd]\x1b[0m dispatch → chainload-linux.sh (chain L, flavor mint, READY)\n"
        "[nexus:chainL] chain L (Linux direct kexec) — flavor: mint  [READY]\n"
        "[nexus:chainL] kernel : /mnt/usb0/linux/mint/vmlinuz\n"
        "[nexus:chainL] initrd : /mnt/usb0/linux/mint/initrd.img\n"
        "[nexus:chainL] append : root=UUID=nexus-mint rw quiet\n"
        "[nexus:chainL] kernel staged; executing (this terminates this Linux session)\n"
        "Linux version 6.9.0-ps5 (builder@nexus)\n"
        "Run /init as init process\n"
        "systemd[1]: Reached target Graphical Interface.\n"
    )
    chain_m_fail = (
        "\x1b[1;35m[nexus:chainM]\x1b[0m chain M (macOS crash-hop) — upstream-PROVEN on FW 13.42 launch model\n"
        "\x1b[1;31m[nexus:chainM] FAIL\x1b[0m kexec -p failed (kernel too old?)\n"
    )
    w_ok = (
        "[nexus-bootd] dispatch → chainload-windows.sh (chain W, RESEARCH)\n"
        "[nexus:chainW] chain W (Windows) — RESEARCH GRADE, not upstream-proven\n"
        "[nexus:chainW] uefipayload : /mnt/usb0/nexus/uefi/UefiPayload.fd\n"
        "[nexus:chainW] win volume  : /mnt/usb1 (bootmgfw.efi present)\n"
        "[nexus:chainW] limits      : USB-only storage · framebuffer display · USB input · your license\n"
        "BdsDxe: loading BOOT\\EFI\\bootmgfw.efi\n"
        "Windows Boot Manager starting\n"
    )
    bad_meta = _meta("M"); bad_meta.pop("operator")

    cases = [
        ("M ok", "M", chain_m_ok, None, _meta("M"), "PASS"),
        ("M partial (no handoff evidence)", "M", chain_m_partial, None, _meta("M"), "PARTIAL"),
        ("L ok", "L", chain_l_ok, None, _meta("L", flavor="mint"), "PASS"),
        ("M fail marker", "M", chain_m_fail, None, _meta("M"), "FAIL"),
        ("M empty log", "M", "", None, _meta("M"), "FAIL"),
        ("M bad entry", "M", chain_m_ok, None, _meta("M", entry="magic"), "FAIL"),
        ("W ok", "W", w_ok, None, _meta("W"), "PASS"),
        ("M missing meta field", "M", chain_m_ok, None, bad_meta, "FAIL"),
    ]

    ok = True
    for label, chain, blob, boot, meta, expect in cases:
        with tempfile.TemporaryDirectory() as td:
            k = os.path.join(td, "ktty.log")
            Path(k).write_text(blob)
            res = validate(chain, k, boot, dict(meta))
        got = res["verdict"]
        status = "PASS" if got == expect else "FAIL"
        if got != expect:
            ok = False
        print(f"{status}  selftest {label}: expect={expect} got={got} "
              f"({res.get('problems') or ['clean']})")
    print("SELFTEST:", "all cases behaved as expected" if ok else "MISMATCH — fix before operator use")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="F18 checkpoint validator (docs/12)")
    ap.add_argument("--chain", choices=sorted(CHAINS), help="chain id: M, L or W")
    ap.add_argument("--ktty", help="ktty log path (raw console capture)")
    ap.add_argument("--bootlog", help="optional nexus-bootd boot log (boot-log.txt)")
    ap.add_argument("--meta", help="metadata JSON (chain, firmware, entry, console_model, operator, date)")
    ap.add_argument("--out", help="write verdict JSON here as well")
    ap.add_argument("--quiet", action="store_true", help="no markdown row to stdout")
    ap.add_argument("--selftest", action="store_true", help="offline synthetic cases")
    a = ap.parse_args()

    if a.selftest:
        return selftest()
    if not (a.chain and a.ktty and a.meta):
        ap.error("--chain, --ktty and --meta are required (or use --selftest)")

    meta = json.loads(Path(a.meta).read_text())
    res = validate(a.chain, a.ktty, a.bootlog, meta)
    blob = json.dumps(res, indent=1)
    if a.out:
        Path(a.out).write_text(blob + "\n")
    print(blob)
    if not a.quiet:
        print("docs/04 row:\n  " + docs04_row(res))
    return 0 if res["verdict"] in ("PASS", "PARTIAL") else 2


if __name__ == "__main__":
    sys.exit(main())
