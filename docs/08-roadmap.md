# 08 — Roadmap

Phase discipline: each phase ends when its features are `passes: true` in
`agents/feature_list.json` — hardware phases additionally need F18 evidence.

## Phase 0 — Foundation (DONE in this scaffold)

Harness (7 agents + feature_list + init.sh) · bootchain scripts with dry-runs ·
MADT generator · permission gate + selftests · guest runners · web demo ·
Plasma theme · packaging scripts + guides · docs suite · test harness green.

## Phase 1 — GreenApple v2 real-boot wiring (code)

- F17: DONE (see `docs/11-greapple-v2-impl.md`) — patches implemented,
  unit-tested (37 checks), shot pipeline verified, harness-checked. Remaining
  polish: apply upstream as PS5GreenApple v2.1 (user push), BackstopJS
  baselines for the four new PNGs.
- `nexus-bootd` systemd unit + selector polish on the Linux stage ISO.

## Phase 2 — Chain L to "boots for real"

- Stage PS5-built kernels for all 8 flavors on the boot USB.
- Automate the ritual: scripted boot-select → verify → kexec, with ktty capture.

## Phase 3 — Chain M automation + chain W spike

- Script the full macOS ritual end-to-end (upstream item #4), disk-vanish
  debugging (item #1), Ethernet throughput work (item #3).
- Chain W spike: UefiPayload + bootmgfw on QEMU model first, PS5 later.

## Phase 4 — The mandated hardware gaps

Ordered by user mandate vs feasibility:

1. **Audio**: HDMI audio path on chain M (upstream item #6 adjacent) — USB
   audio already works.
2. **Power/restart/rest**: clean FW return (upstream item #5) — the last
   blocker for "power just works".
3. **BT via USB dongle** (upstream item #6) — ships before IW612 research.
4. **WiFi (NXP IW612-class)**: longest pole; needs chip RE + driver work.
5. **GPU acceleration (Cyan Skillfish)**: upstream item #2; biggest payoff.

## Phase 5 — The polish the brief asked for

- Hub demo ↔ real hub parity (every demo surface backed by a real state).
- DIC voice grammar v2 (arbitrary app launch), gate approvals from the couch.
- BackstopJS baselines in CI; RE sweep on every release artifact.

## Phase 6 — Firmware horizon (opened 2026-11-09, feature F19/F20)

The scene ceiling moved: FW 13.60 is fully jailbroken (Relapse chain +
Byepervisor-Reborn HV). Registry and matrix: `docs/09-firmware-coverage.md`.

- **13.60 track**: validate Chains M/L/W on a 13.60 console (F18 extension);
  document the Relapse + Byepervisor entry ritual per upstream; keep offsets
  out of this repo forever.
- **HV research threads** (RESEARCH, approval-gated): clean FW return / power
  transitions using hypervisor R/W; HV-enforced isolation for nested-OS-on-PS5
  experiments. Read `soniciso1/ps5-hv-writeups` first.
- **14.x watch (F20)**: re-review `ZigZagBoi1/PS5-14.10-Research` (+ status
  report), `pastawithpesto/PS5-14.10-Jailbreak-Research` (CVE-2026-43720),
  `kuzibelit/PS5-14.00-14.10-Jailbreak-PoC` monthly; when a public 14.x kernel
  chain ships, extend `docs/03` step 0 and re-date the coverage matrix.

## Explicitly out of scope forever

Firmware dumping/key handling · game piracy · fake status labels · anything
that touches a console the operator does not own.
