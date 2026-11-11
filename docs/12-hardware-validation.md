# 12 — Hardware Validation Matrix (F18 operator runbook)

This document turns the L6 layer of `docs/06-testing-plan.md` into a
concrete, repeatable procedure. **Nothing here runs by itself**: every
hardware step is approval-gated (`agents/feature_list.json` rules), executed
by a human operator on a real console, and documented with the tools in
`tools/hwtest/`. A chain is only ever upgraded to READY/PROVEN in
`docs/04-hardware-support.md` by evidence captured this way — never by
review (docs/04 maintenance rule).

## 1. Console tracks

| Track | Console | Firmware | Entry | HV layer | What it proves |
| --- | --- | --- | --- | --- | --- |
| **T1 (baseline)** | Launch model (CFI-10xx), drive stocked | **13.42** | Relapse | optional Byepervisor (13.20-class) | Chain M PROVEN-path reproduction; chain L on all 8 flavors; chain W research attempt |
| **T2 (ceiling)** | Any model listed by Relapse/Byepervisor-Reborn | **13.60** | Relapse | Byepervisor-Reborn (supported) | The raised NEXUS ceiling: same matrix at 13.60 + HV observations (clean-FW-return experiments stay RESEARCH) |
| **T3 (watch)** | Spare console only | 14.00/14.10 | none public | none | **NO RUNS** — entry does not exist publicly (docs/09 §RESEARCH WATCH, F20). If a public 14.x chain ships, this document is extended first, runs after |

Rules that do not bend:

1. **No exploit code is shipped or flashed by NEXUS-OS.** The operator runs
   the public upstream entry (Relapse browser page / Byepervisor payload)
   themselves, per `NOTICE.md` §2 and `docs/03` step 0. Our tools only
   archive logs of what already happened.
2. **Approval gate**: each track run is proposed (console, FW, chain, date)
   and approved before power-on. The proposal references this section.
3. **Brick-safety honesty**: chain M intentionally crashes the running
   Linux session (`--i-know-this-crashes-the-host`). Rest-mode and clean
   FW return are unsolved upstream; the operator expects a manual
   power-cycle after every chain-M attempt and keeps the boot USB
   (`/mnt/usb0/nexus/...`) plugged for recovery.

## 2. What is validated per chain

| Chain | Script | Upstream basis | Current label | What a PASS upgrades |
| --- | --- | --- | --- | --- |
| **M** | `bootchain/kexec/chainload-macos.sh` | rodri0x/ps5-hackintosh (crash-kexec → UefiPayload → OpenCore → boot.efi → XNU) | PROVEN *upstream* | NEXUS-OS demonstration on the exact track hardware (T1: PROVEN; T2: first M-run at 13.60) |
| **L** | `bootchain/kexec/chainload-linux.sh` | ps5-linux-loader + 8-flavor preset table | READY | per-flavor boot evidence + hardware deltas (docs/04 rows) |
| **W** | `bootchain/kexec/chainload-windows.sh` | UefiPayload → `bootmgfw.efi` (licensed media, NOTICE §4) | RESEARCH | a REAL attempt record — any result (PASS/PARTIAL/FAIL) is a valid F18 finding |

## 3. Attempt matrix (minimum for track sign-off)

T1 (13.42): M ×1 · L ×3 flavors (one Arch-family, one Debian-family, one
rpm/os-style — pick from the 8) · W ×1.
T2 (13.60): M ×1 · L ×2 flavors · W ×1 — *plus* one Byepervisor-Reborn
load/unload cycle logged as an HV observation (not a boot chain).
Repeat attempts are new sessions; every session gets its own `HW-…` id.

## 4. Evidence protocol (capture-ktty.sh)

One **session** = one boot attempt. Artifacts:

```
sessions/<HW-id>/
  ktty.log        # console log of the attempt (chain M: $NEXUS_KTLOG, default /tmp/ktty.log)
  boot-log.txt    # nexus-bootd decision log (NEXUS_BOOTLOG, default /data/NEXUS/boot-log.txt)
  meta.json       # chain, flavor, firmware, entry, console_model, operator, date, notes
  sha256sums.txt  # integrity of the above
```

Order of operations (the capture runs **after** the attempt — the chain
kexecs the capture host away otherwise):

1. Operator powers the console through the approved entry (their own
   upstream tooling), reaches the NEXUS Linux stage, lets the hub write
   `boot-select.json` (PS5GreenApple v2.1: NEXUS page → STAGE FOR NEXT BOOT),
   then runs `nexus-boot-select.sh` with the chain script's own logging on.
2. The attempt happens (or fails). **Whatever happened, it is a finding.**
3. Re-enter the Linux stage, run:

```bash
tools/hwtest/capture-ktty.sh --chain M --firmware 13.42 --entry relapse \
    --console "CFI-1015A launch model" --operator <name> \
    [--flavor <f>] [--note "openCore visible, no acc yet"]
```

4. Validate immediately:

```bash
tools/hwtest/validate-logs.py --chain M --ktty sessions/<id>/ktty.log \
    --bootlog sessions/<id>/boot-log.txt --meta sessions/<id>/meta.json \
    --out sessions/<id>/verdict.json
```

5. Fill the delta form and render the docs/04 snippet:

```bash
python3 tools/hwtest/delta-report.py --template sessions/<id>/delta.json
# operator fills it …
python3 tools/hwtest/delta-report.py --form sessions/<id>/delta.json --append-check
```

## 5. Checkpoints (what validate-logs.py matches)

The validator matches the markers the chain scripts actually emit (raw ESC
wrapping tolerated), in order, then looks for **post-handoff evidence** —
lines only the downstream component can print:

| Chain | Required (in order) | Post-handoff evidence (any-of) |
| --- | --- | --- |
| M | `[nexus-bootd] dispatch …chain M` → `[nexus:chainM] chain M (macOS crash-hop)` → `stage1 :` → `plan :` → `staging stage1` → `arming crash hop` | `UefiPayload` / `EDK2` / `OpenCore` / `boot.efi` / `XNU|Darwin` / `apfs` |
| L | dispatch `(chain L, flavor <f>, READY)` → banner → `kernel :` → `initrd :` → `append :` → `kernel staged; executing` | `Linux version` / `Run /init` / `systemd[1]` / `ps5|amdgpu|cyan` |
| W | dispatch `…chain W` → banner → `uefipayload :` → `win volume :` → `limits :` | `nexus_uefi_handoff` / `bootmgfw` / `BdsDxe` / `Windows Boot Manager` |

Any `[nexus:*] FAIL` / `[nexus-bootd] FAIL` marker forces FAIL with the
marker quoted. A verdict of **PARTIAL** (all required matched, zero
hand-off evidence) is the normal "hop started, hand-off died early" shape
and is treated as a **finding, not a failure of the tooling**.

## 6. Verdict rules

| Verdict | Meaning | Matrix consequence |
| --- | --- | --- |
| **PASS** | all required checkpoints in order + ≥1 handoff evidence | beta QA re-reviews the raw log, then docs/04 row lands with the session id |
| **PARTIAL** | our markers complete, no downstream evidence | docs/04 row lands as "attempt documented, hand-off died at <last-good>"; no label change |
| **FAIL** | missing/out-of-order checkpoint, FAIL marker, empty log | docs/04 row lands as a finding; the label never degrades silently — a regression is an explicit row |

No verdict is self-executing: `validate-logs.py` output is evidence, and a
human (beta QA owner) moves the matrix row. This is the docs/06 L6
contract, unchanged.

## 7. Hardware delta taxonomy

The delta form (`delta-report.py`) uses exactly these statuses — same
words as docs/04:

- `works` — behaved normally for a full session (evidence required)
- `partial` — worked with documented limitations (state them)
- `absent` — present in hardware, did not work (evidence required; honest)
- `untested` — not exercised this run (must say why)
- `n/a` — component does not exist on this chain (e.g. WiFi on chain M)

Components: display, gpu_accel, audio_hdmi, audio_usb, wifi, bluetooth,
ethernet, input_dualsense, input_usb, storage_internal_nvme, storage_usb,
power_restart, power_rest_mode, voice_dic — the docs/04 mandatory list
plus the storage/policy rows the chains actually differ on.

## 8. Filing and retention

- Sessions live on the boot USB under `sessions/` and are synced to the
  beta-team `reports/` after QA review.
- `docs/04-hardware-support.md` rows cite the session id + verdict JSON.
- Logs are plain text; strip operator-identifying network names before
  sharing outside the team. Never commit exploit payloads or keys from the
  entry tooling into this repo (NOTICE §2 — logs describe, they do not ship).

## 9. Approval ledger

| Date | Approver | Scope | Record |
| --- | --- | --- | --- |
| 2026-11-11 | Blackbatman (repo owner) | **T1 + T2 approved** for operator runs ("I approve F18 hardware tracks"). Per-session proposal ritual (§1 rule 2) still applies to every run. **T3 unchanged: watch-only** — approval cannot create a 14.x entrypoint (docs/09 §RESEARCH WATCH, F20). | `tools/hwtest/APPROVAL.json` |

A future T3 approval is only meaningful **after** a public 14.x chain exists
and §1 is extended for it (F20 monthly re-review).
