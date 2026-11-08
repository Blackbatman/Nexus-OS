# TEST-REPORT-001 — full harness run (beta team, three lenses)

- **Date:** 2026-11-09 · **Scope:** repo scaffold, no third_party clones
- **Lenses:** functional (L0–L4) + hostile-input (L2 hardening cases embedded) · visual = demo parse + JS check (BackstopJS baselines deferred until F17 UI patches land)

## Summary: **45 passed / 0 failed / 0 skipped** (final)

| Lens layer | Result |
| --- | --- |
| L0 syntax (18 shell, 3 python) | 21/21 PASS |
| L1 selftests (MADT, gate, voice) | 3/3 PASS |
| L2 behavior (dry-runs, guards, hostile inputs, MADT binary reparse) | 11/11 PASS |
| L3 data (3 JSON, colorscheme, gate policy default-deny) | 5/5 PASS |
| L4 demo (HTML parse, size, extracted-JS node check) | 3/3 PASS |
| Extra (placeholder sweep, C host syntax) | 2/2 PASS |

## Findings during this run (all fixed in this cycle)

| ID | Severity | Lens | Finding | Root cause | Fix |
| --- | --- | --- | --- | --- | --- |
| F-001 | blocker | functional | `madt_fake.py` crashed on any build: `pack expected 10 items (got 9)` | ACPI header struct format had an extra `I`; Creator ID is a 4-byte string, not uint32 | format `<4sIBB6s8sI4sI` (36 bytes verified) |
| F-002 | major | hostile-input | `"nexus boot arch"` parsed as unknown | boot grammar required the word "linux" before a flavor | flavor token now implies linux target (confidence 0.88) |
| F-003 | major | hostile-input | `--flavor windows95 --dry-run` slipped through with empty kernel path | `presets()` die ran inside command-substitution subshell; exit status lost | top-level flavor whitelist case before preset lookup |
| F-004 | minor | functional | placeholder sweep false-positived on prose ("upstream TODO" in docs) | pattern too broad | tightened the unfinished-marker list; docs reworded |
| F-005 | minor | functional | chain scripts unusable for CI dry-runs (died on missing kexec/artifacts) | guards not dry-run aware | dry-run mode now warns instead of dying; real mode keeps hard fails |

## MADT binary verification (evidence)

```
wrote /tmp/madt.bin: 398 bytes, checksum OK
entries: {0: 16, 1: 1, 2: 2, 4: 16, 5: 1}   # 16×LAPIC, IOAPIC, 2×ISO, 16×NMI, addr-override
signature: b'APIC' | length field: 398 | actual: 398
```

## Gate selftest coverage (evidence)

8 scenarios: policy allow · default-deny queue · operator approval · unknown
guest · `../../etc/shadow` traversal rejection · bad action · operator denial ·
malformed JSON 400.

## Regressions filed

None — `feature_list.json` F01–F16 remain `passes: true` with evidence lines.
F17 (GreenApple v2 code patches) blocked on `agents/init.sh` clone;
F18 blocked on operator hardware approval. Both documented there.

## Verdict

Scaffold is QA-green. Remaining risk is exactly where the docs say it is:
real-hardware behavior (F18) and the v2 code patches against the cloned repo
(F17).
