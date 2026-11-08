# CLAUDE.md — NEXUS-OS Agent Harness

You are an agent working inside NEXUS-OS, an open research platform for multi-OS
bare-metal boot on a jailbroken PS5 (macOS proven chain, Windows research chain,
Linux direct kexec) plus isolated nested-OS guests on host machines. Read this file
fully before doing anything else.

## Mission

Ship one **verified** feature at a time from `agents/feature_list.json` toward the goal:
a PS5 where the NEXUS hub buttons really kexec real operating systems, and a host
ecosystem where macOS/Windows guests are isolated behind a permission gate.

## Golden rules (from the long-run harness playbook)

1. **One feature per session.** Pick exactly one `passes: false` feature from
   `agents/feature_list.json`, implement it, verify it end-to-end, mark it
   `passes: true`, commit. Never try to build everything in one session.
2. **Read the notes first.** At session start, read `agents/claude-progress.txt`
   and the tail of `git log`. The notes are your memory, not your context window.
3. **Verify before claiming.** Run `beta-team/run-tests.sh` (or the relevant
   feature's own test) and show the passing output **before** you update
   `feature_list.json`. A feature is done when its check passes, not when the code
   is written.
4. **Leave notes.** At session end, append what you did, what broke, and what the
   next session should do to `agents/claude-progress.txt`.
5. **Honest labels.** Anything unproven on real hardware stays labeled `RESEARCH`.
   Never silently upgrade a claim (e.g. "boots" → only if a real PS5 log proves it).

## Approval gates (non-negotiable)

You must pause and ask the human operator before:

- Publishing anything (releases, posts, domain names, app stores)
- Spending money (API keys, hosting, hardware purchases)
- Destructive operations (`rm -rf` outside `build/`, disk writes, firmware flashes)
- Running anything against real PS5 hardware or real jailbreak entry points
- Touching any repo or machine that is not under `nexus-os/` or `third_party/`

Everything else — local builds, tests, simulators, screenshots — proceed freely.

## Tool loop (use all of it)

| Tool | Use it for | Entry |
| --- | --- | --- |
| **REA** (`morluto/rea`) | Analyzing payloads/ELFs/kmods you build; session reports | `tools/rea-adapter/rea-session.sh` |
| **radare2** | Deep ELF structure diffs between boot stages | `tools/radare2/analyze-payload.sh`, `symbol-diff.sh` |
| **BackstopJS** | Visual regression on the hub UI and Plasma theme mock | `tools/backstop/` |
| **craft-anything** | Study→rebuild→compare loops against upstream UIs | `craft-anything-cli` via MCP or CLI |
| **grok-build** (`xai-org/grok-build`) | Alternate coding-agent runtime (ACP) | `grok` CLI in this repo root |
| **statecheck** | Validating the explicit state-machine registry (states, guards, determinism, sources) | `tools/statecheck/statecheck.py` on `agents/state-machines.json` |
| **ps5-payload-sdk** | Cross-building PS5 .elf payloads | `packaging/ps5-elf/` |

## Team roster (subagents)

Delegate via the agent definitions in `.claude/agents/`:

| Agent | File | Owns |
| --- | --- | --- |
| Architect | `.claude/agents/architect.md` | Orchestration, scope, quality bars |
| Planner | `.claude/agents/planner.md` | `feature_list.json` grooming, task slicing |
| Reverse-Engineer | `.claude/agents/reverse-engineer.md` | REA/radare2 passes, stage1 analysis |
| Kernel Builder | `.claude/agents/kernel-builder.md` | Boot chain, kexec, ACPI, UEFI/OpenCore |
| UI Builder | `.claude/agents/ui-builder.md` | Hub web demo, Plasma theme, GreenApple v2 UI |
| Integration Builder | `.claude/agents/integration-builder.md` | Nested OS, permission gate, packaging |
| Beta QA | `.claude/agents/beta-qa.md` | Test harness, stress passes, reports |

Beta QA is **three independent passes** (functional, hostile-input, visual) —
see `.claude/agents/beta-qa.md` § Three Lenses.

## Session protocol (the 6-step loop)

1. Read `agents/claude-progress.txt` + `git log --oneline -5`.
2. Smoke-test: `beta-team/run-tests.sh --quick` (or the feature's own check).
3. Pick ONE failing feature from `agents/feature_list.json`.
4. Implement + test end-to-end until its check passes. If you touch a component
   with a registered state machine, read `docs/10-state-machines.md` and keep
   `agents/state-machines.json` in the same commit as the behavior change.
5. Update `feature_list.json` (`passes: true`, evidence line) and commit.
6. Append notes to `agents/claude-progress.txt`. Keep it short and factual.

Do not stop because the session is long; stop when the feature is **verified** or you
hit an approval gate.
