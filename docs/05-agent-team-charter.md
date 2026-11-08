# 05 — Agent Team Charter

Two teams, one operating rhythm, and approval gates between them and the
real world. (Pattern source: the operator's Claude-team + long-run-harness
playbooks; enforced by `CLAUDE.md` and `.claude/agents/`.)

## Team A — Dev (build)

| Role | File | Owns | Handoff rule |
| --- | --- | --- | --- |
| **Architect** | `architect.md` | scope, sequencing, quality bars, gates | delegates everything else; verifies returns |
| **Planner** | `planner.md` | `feature_list.json` grooming | features must be single-session + checkable |
| **Reverse-Engineer** | `reverse-engineer.md` | REA + radare2 sweeps | stops on any suspect symbol in boot stages |
| **Kernel Builder** | `kernel-builder.md` | bootchain, stage1, UEFI/OpenCore, ACPI | never runs against real hardware |
| **UI Builder** | `ui-builder.md` | web demo, Plasma, GreenApple v2 patches | proof = dump-backend PNGs, never PS5 claims |
| **Integration Builder** | `integration-builder.md` | guests, gate, packaging, voice | `--check-env` before every real run |

## Team B — Beta (break)

Three independent lenses, run by **two different agent runtimes** (Claude Code
and Grok Build cross-check each other's fixes):

1. **Functional** — full `run-tests.sh`; every FAIL re-run in isolation.
2. **Hostile-input** — fuzz `madt_fake.py`, gate daemon, chain scripts, voice
   parser; traversal, malformed JSON, injection text, absurd sizes.
3. **Visual** — hub demo baselines (BackstopJS; sandbox fallback differ).

Findings land in `beta-team/reports/TEST-REPORT-NNN.md` with severity and a
suggested owner; regressions flip `feature_list.json` entries **with quoted
evidence**. Beta QA never fixes product code — it breaks and reports.

## The rhythm (one session = one verified feature)

```
read progress notes → smoke test → pick ONE failing feature → implement
→ verify (tests must pass, evidence quoted) → update feature_list → commit
→ leave notes → repeat
```

Anti-patterns banned by charter: building the whole project in one session;
declaring success at first compile; leaving `passes: true` without evidence;
weakening a test to pass; claiming hardware results nobody captured.

## Approval gates (human in the loop, non-negotiable)

Publishing anything · spending money · real PS5 hardware runs (F18) ·
jailbreak entry execution · destructive ops · network fetches outside
`agents/init.sh`. The gate list lives in `CLAUDE.md`; both runtimes' agents
are bound to it.

## Escalation ladder

`QA finding → owner agent → architect → operator` — and sideways:
`reverse-engineer → architect` immediately on suspect binaries, no waiting
for the report cycle.
