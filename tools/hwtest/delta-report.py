#!/usr/bin/env python3
"""delta-report.py — F18 hardware support delta form (docs/04 evidence path).

After a hardware run, the operator fills one JSON describing what each
component actually did on THIS console at THIS firmware. The tool validates
the form (component set, status enum, evidence references) and renders the
markdown snippet that docs/04-hardware-support.md expects.

Status enum (docs/12 §7):
  works     component behaved normally for a full session
  partial   worked with documented limitations (state it in "notes")
  absent    present in hardware, did not work, honest failure
  untested  not exercised this run (must say why in "notes")
  n/a       component does not exist on this chain (e.g. WiFi on chain M)

Every non-"untested" claim MUST point at evidence: a capture-ktty.sh session
directory, a screenshot reference, or a note in the session meta.

Usage:
  delta-report.py --form session-delta.json [--append-check]
  delta-report.py --template out.json      # write a blank filled form
  delta-report.py --selftest

This tool ships NO exploit code, offsets or payloads (NOTICE.md §2).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Component set mirrors the brief's mandatory list (docs/04 header) plus the
# storage/policy rows the chains actually differ on.
COMPONENTS = [
    "display", "gpu_accel", "audio_hdmi", "audio_usb",
    "wifi", "bluetooth", "ethernet",
    "input_dualsense", "input_usb",
    "storage_internal_nvme", "storage_usb",
    "power_restart", "power_rest_mode", "voice_dic",
]
STATUSES = ("works", "partial", "absent", "untested", "n/a")
REQUIRED_HEADER = ("session_id", "chain", "flavor", "firmware", "entry",
                   "console_model", "operator", "date", "ktty_session")


def _example() -> dict:
    return {
        "session_id": "HW-2026-11-09-001",
        "chain": "L",
        "flavor": "arch",
        "firmware": "13.60",
        "entry": "relapse",
        "console_model": "CFI-1015A launch model",
        "operator": "beta-qa",
        "date": "2026-11-09",
        "ktty_session": "sessions/HW-2026-11-09-001/",
        "components": {
            "display": {"status": "works",
                        "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                        "notes": "4K HDMI, amdgpu probe line present"},
            "gpu_accel": {"status": "absent",
                          "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                          "notes": "Cyan Skillfish: framebuffer only, matches docs/04"},
            "audio_hdmi": {"status": "absent",
                           "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                           "notes": "no HDMI codec probe — known gap"},
            "audio_usb": {"status": "works",
                          "evidence": "sessions/HW-2026-11-09-001/delta.json",
                          "notes": "USB DAC enumerated by PipeWire"},
            "wifi": {"status": "n/a", "evidence": "", "notes": "no driver on any chain"},
            "bluetooth": {"status": "n/a", "evidence": "", "notes": "no driver; USB dongle path"},
            "ethernet": {"status": "works",
                         "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                         "notes": "Salina ~25 MB/s link up"},
            "input_dualsense": {"status": "works",
                                "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                                "notes": "hid-playstation bound over USB"},
            "input_usb": {"status": "works", "evidence": "sessions/HW-2026-11-09-001/ktty.log", "notes": "USB KB/M"},
            "storage_internal_nvme": {"status": "n/a", "evidence": "",
                                      "notes": "locked by policy (upstream design)"},
            "storage_usb": {"status": "works", "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                            "notes": "boot USB preset table read"},
            "power_restart": {"status": "works", "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                              "notes": "kexec reboots within Linux stage"},
            "power_rest_mode": {"status": "absent", "evidence": "sessions/HW-2026-11-09-001/ktty.log",
                                "notes": "clean FW return unsolved upstream (docs/04)"},
            "voice_dic": {"status": "untested", "evidence": "",
                          "notes": "whisper.cpp not exercised this run"},
        },
    }


def validate(form: dict) -> list:
    problems = []
    for key in REQUIRED_HEADER:
        if not str(form.get(key, "")).strip():
            problems.append(f"header missing field: {key}")
    if form.get("chain") not in ("M", "L", "W"):
        problems.append("header.chain must be M, L or W")
    comps = form.get("components", {})
    missing = [c for c in COMPONENTS if c not in comps]
    if missing:
        problems.append("components missing: " + ", ".join(missing))
    extra = [c for c in comps if c not in COMPONENTS]
    if extra:
        problems.append("unknown components: " + ", ".join(extra))
    for name, row in comps.items():
        st = row.get("status")
        if st not in STATUSES:
            problems.append(f"{name}: bad status {st!r} (allowed: {STATUSES})")
        elif st in ("works", "partial", "absent") and not str(row.get("evidence", "")).strip():
            problems.append(f"{name}: status '{st}' requires an evidence reference")
        elif st == "untested" and not str(row.get("notes", "")).strip():
            problems.append(f"{name}: status 'untested' requires a note saying why")
    return problems


def render(form: dict) -> str:
    """Markdown rows in the docs/04 table style."""
    lines = [
        f"### Session {form['session_id']} — chain {form['chain']}"
        + (f" ({form['flavor']})" if form.get("flavor") else "")
        + f" @FW {form['firmware']} ({form['entry']}, {form['console_model']}, {form['date']}, operator {form['operator']})",
        "",
        "| Component | Status | Evidence / notes |",
        "| --- | --- | --- |",
    ]
    for name in COMPONENTS:
        row = form["components"][name]
        ev = row.get("evidence") or "—"
        note = row.get("notes") or ""
        note = f"{note} — {ev}" if note and ev != "—" else (note or ev)
        lines.append(f"| **{name.replace('_', ' ')}** | {row['status']} | {note} |")
    lines += ["", f"Source session: `{form['ktty_session']}` (captured with tools/hwtest/capture-ktty.sh; "
                  f"validated with tools/hwtest/validate-logs.py before any docs/04 edit)."]
    return "\n".join(lines)


def selftest() -> int:
    good = _example()
    p1 = validate(good)
    print(("PASS" if not p1 else "FAIL") + "  selftest good form: " + (str(p1) or "clean"))

    bad = _example()
    bad["components"]["display"]["status"] = "magic"
    bad["components"]["audio_usb"]["evidence"] = ""
    del bad["components"]["wifi"]
    p2 = validate(bad)
    ok2 = len(p2) == 3 and any("display" in x for x in p2) and any("audio_usb" in x for x in p2) and any("wifi" in x for x in p2)
    print(("PASS" if ok2 else "FAIL") + f"  selftest corrupted form rejected with {len(p2)} problems")

    blob = render(good)
    ok3 = "| **gpu accel** | absent |" in blob and "Source session:" in blob
    print(("PASS" if ok3 else "FAIL") + "  selftest markdown render contains status + provenance")
    print("SELFTEST:", "all cases behaved as expected" if (not p1 and ok2 and ok3) else "MISMATCH")
    return 0 if (not p1 and ok2 and ok3) else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="F18 hardware delta form (docs/04 evidence path)")
    ap.add_argument("--form", help="filled delta form JSON")
    ap.add_argument("--template", help="write the blank example form to this path and exit")
    ap.add_argument("--append-check", action="store_true",
                    help="also print the exact docs/04 append reminder line")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()

    if a.selftest:
        return selftest()
    if a.template:
        Path(a.template).write_text(json.dumps(_example(), indent=1) + "\n")
        print(f"template written: {a.template} (fill it, keep the status enum)")
        return 0
    if not a.form:
        ap.error("--form required (or --template / --selftest)")

    form = json.loads(Path(a.form).read_text())
    problems = validate(form)
    if problems:
        print("FORM INVALID:")
        for p in problems:
            print("  -", p)
        return 2
    print("FORM VALID — docs/04 snippet below (paste under the matrix, keep the date):\n")
    print(render(form))
    if a.append_check:
        print("\nReminder (docs/04 maintenance rule): matrix verdict changes need the "
              "session log reference reviewed by beta QA before they land.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
