#!/usr/bin/env python3
"""voice_cmd.py — NEXUS-OS DIC (DualSense Integrated Command Interface).

Offline voice control for the hub. Speech-to-text runs locally via whisper.cpp
(no cloud); intent parsing is deterministic so the beta team can fuzz it.

Pipeline: DualSense mic (or any ALSA mic) → wav → whisper.cpp → this parser →
action JSON on stdout (and optionally POSTed to the gate / hub endpoint).

Usage:
  voice_cmd.py --selftest                       # no mic, no model needed
  voice_cmd.py --file say.wav                   # transcribe + parse
  voice_cmd.py --text "nexus boot arch"         # parse text directly
  voice_cmd.py --listen                         # arecord loop (needs mic)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

# ------------------------------------------------------------------ intents
LINUX_FLAVORS = ("arch", "ubuntu", "fedora", "debian", "cachyos", "nobara", "mint", "omarchy")
POWERS = ("rest", "restart", "shutdown")

WAKE = re.compile(r"^\s*(?:hey\s+)?nexus\b[,!.]?\s*", re.I)
BOOT_RE = re.compile(r"\b(?:boot|launch|start)\b", re.I)
FLAVOR_RE = re.compile(r"\b(?P<flavor>" + "|".join(LINUX_FLAVORS) + r")\b", re.I)
TARGET_RE = re.compile(r"\b(?P<target>macos|mac|windows|win|linux)\b", re.I)

GRAMMAR = {
    "power":  re.compile(r"\b(?:power|system)\b.*\b(?P<power>" + "|".join(POWERS) + r")\b", re.I),
    "gate":   re.compile(r"\bgate\b.*\b(?P<gate>approve|deny)\b(?:.*\b(?:id\s*)?(?P<rid>\d+)\b)?", re.I),
    "status": re.compile(r"\b(?:status|what.?s.?booting|nexus.?status)\b", re.I),
}


def parse(text: str) -> dict:
    """Deterministic intent parse. Returns an action dict (never a shell string)."""
    clean = WAKE.sub("", text or "").strip()
    if not clean:
        return {"intent": "none", "reason": "empty after wake word"}
    if BOOT_RE.search(clean):
        tm = TARGET_RE.search(clean)
        fm = FLAVOR_RE.search(clean)
        if tm:
            t = (tm.group("target") or "").lower()
            target = {"mac": "macos", "win": "windows"}.get(t, t)
            action = {"intent": "boot", "target": target}
            if target == "linux":
                action["flavor"] = (fm.group("flavor").lower() if fm else "arch")
            action["confidence"] = 0.93
            return action
        if fm:  # "boot arch" — a flavor implies the linux target
            return {"intent": "boot", "target": "linux",
                    "flavor": fm.group("flavor").lower(), "confidence": 0.88}
        # bare "boot" (possibly injection-shaped) — target left null on purpose
        return {"intent": "boot", "target": None, "confidence": 0.4,
                "note": "no target parsed; hub shows the OS grid instead"}
    m = GRAMMAR["power"].search(clean)
    if m:
        return {"intent": "power", "power": m.group("power").lower(), "confidence": 0.9,
                "note": "clean-power features are RESEARCH — hub shows honest status"}
    m = GRAMMAR["gate"].search(clean)
    if m:
        out = {"intent": "gate", "gate": m.group("gate").lower(), "confidence": 0.95}
        if m.group("rid"):
            out["request_id"] = int(m.group("rid"))
        return out
    if GRAMMAR["status"].search(clean):
        return {"intent": "status", "confidence": 0.9}
    return {"intent": "unknown", "text": clean, "confidence": 0.0}


def transcribe(wav_path: str) -> str:
    """whisper.cpp via NEXUS_WHISPER env (path to the main binary + model)."""
    binary = os.environ.get("NEXUS_WHISPER")
    model = os.environ.get("NEXUS_WHISPER_MODEL")
    if not binary or not os.path.exists(binary):
        raise FileNotFoundError(
            "whisper.cpp not configured — set NEXUS_WHISPER=/path/to/whisper-cli "
            "and NEXUS_WHISPER_MODEL=/path/to/ggml-small.bin (offline, no cloud)")
    with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as tmp:
        out = tmp.name
    subprocess.run([binary, "-m", model, "-f", wav_path, "-otxt", "-of", out[:-4]],
                   check=True, capture_output=True)
    with open(out) as fh:
        return fh.read().strip()


def selftest() -> int:
    cases = [
        ("nexus boot arch", {"intent": "boot", "target": "linux", "flavor": "arch"}),
        ("NEXUS, boot macOS", {"intent": "boot", "target": "macos"}),
        ("hey nexus boot windows", {"intent": "boot", "target": "windows"}),
        ("nexus power rest", {"intent": "power", "power": "rest"}),
        ("nexus gate approve", {"intent": "gate", "gate": "approve"}),
        ("nexus gate approve id 12", {"intent": "gate", "gate": "approve", "request_id": 12}),
        ("nexus status", {"intent": "status"}),
        ("boot; rm -rf /", {"intent": "boot"}),  # injection-shaped: target stays null, no shell string
        ("", {"intent": "none"}),
        ("  ", {"intent": "none"}),
    ]
    failures = []
    for text, expect in cases:
        got = parse(text)
        for k, v in expect.items():
            if got.get(k) != v:
                failures.append(f"{text!r}: expected {k}={v}, got {got}")
    # injection must never produce a shell-unsafe action
    got = parse("boot arch; rm -rf /")
    if got.get("intent") == "boot" and "rm" in json.dumps(got):
        failures.append("injection text leaked into action")
    if failures:
        for f in failures:
            print(f"SELFTEST FAIL: {f}")
        return 1
    print("SELFTEST PASS: 10 DIC intent scenarios OK (boot/power/gate/status/wake/none/injection)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="NEXUS-OS DIC voice command parser")
    ap.add_argument("--text", help="parse a text utterance")
    ap.add_argument("--file", help="transcribe a wav via whisper.cpp then parse")
    ap.add_argument("--listen", action="store_true", help="arecord loop (mic required)")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if args.text is not None:
        print(json.dumps(parse(args.text), indent=2))
        return 0
    if args.file:
        try:
            text = transcribe(args.file)
        except FileNotFoundError as exc:
            print(f"WARN: {exc}", file=sys.stderr)
            return 2
        print(json.dumps(parse(text), indent=2))
        return 0
    if args.listen:
        print("listen mode: Ctrl+C to stop; each 4s utterance is parsed")
        while True:
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                wav = tmp.name
            subprocess.run(["arecord", "-D", "pulse", "-f", "S16_LE", "-r", "16000",
                            "-d", "4", wav], check=False, capture_output=True)
            try:
                text = transcribe(wav)
            except FileNotFoundError as exc:
                print(f"WARN: {exc}", file=sys.stderr)
                return 2
            action = parse(text)
            print(json.dumps(action))
            os.unlink(wav)
        return 0
    ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
