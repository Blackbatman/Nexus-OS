# 06 — Testing Plan (beta team)

## Layers

| Layer | What | Tool | Where |
| --- | --- | --- | --- |
| L0 Syntax | every `.sh` parses; every `.py` compiles | `bash -n`, `py_compile` | `beta-team/run-tests.sh` |
| L1 Selftests | MADT gen, gate daemon, voice parser | `--selftest` flags | same |
| L2 Behavior | dry-runs of all chain scripts + selector; artifact-missing paths | `--dry-run`, sandbox dirs | same |
| L3 Data | JSON/YAML/XML validity (feature list, policy, backstop, autounattend) | python json/xml | same |
| L4 Visual | hub demo regression vs baseline | BackstopJS / PIL differ | `tools/backstop/run-visual-check.sh` |
| L5 RE | build sweeps + drift diffs of stage artifacts | REA + radare2 | `tools/rea-adapter`, `tools/radare2` |
| L6 Hardware | chains M/L/W on launch-model PS5 @13.42 baseline (+ optional 13.60 console for the raised ceiling, entry per docs/09); ktty logs; matrix update | **APPROVAL GATED (F18)** — runbook `docs/12-hardware-validation.md`, harness `tools/hwtest/` (capture / validate / delta) | operator |

## run-tests.sh contract

- `--quick`: L0+L1 (init.sh smoke uses this).
- full run: L0–L4 + unfinished-placeholder marker sweep in deliverables.
- Output: PASS/FAIL table to stdout **and** `reports/TEST-REPORT-NNN.md`
  (beta QA protocol: findings re-run in isolation, severity, owner).

## Hostile-input corpus (L2 hardening)

- `madt_fake.py`: cores 0/-1/999999 · non-integer · corrupted-checksum blob
- `gate-daemon.py`: unknown guest · traversal `../../etc/shadow` · bad action ·
  double-approve · malformed JSON · concurrent queue pressure
- `chainload-*.sh`: missing artifacts · spaces/quotes in paths · empty select
  file · contradictory flags · non-root on privileged paths
- `voice_cmd.py`: empty · 10 KB · mixed case · `boot arch; rm -rf /`

## Visual baselines

Accepted baselines live in `tools/backstop/backstop_data/bitmaps_reference/`.
Baseline drift > 1% mean-pixel change fails the check. Deliberate UI changes
re-baseline with a note in the report — never silently.

## Hardware test matrix (L6, when approved)

Per chain: boot attempt, wall time, last-good step, ktty tail, hardware deltas
→ append row to `docs/04-hardware-support.md` with the log reference. A chain
is only ever upgraded to READY/PROVEN by hardware evidence, never by review.

The full procedure — console tracks (T1 13.42 baseline / T2 13.60 ceiling /
T3 14.x watch), attempt matrix, checkpoint tables, verdict rules
(PASS/PARTIAL/FAIL) and the delta taxonomy — lives in
`docs/12-hardware-validation.md`; the operator tools are `tools/hwtest/`
(`capture-ktty.sh`, `validate-logs.py`, `delta-report.py`, all self-tested
in `beta-team/run-tests.sh`).
