# 10 — State Machines: Making the Implicit Explicit

Every non-trivial program is a state machine; most are never announced.
This document announces ours. On 2026-11-09 the codebase was swept for
*implicit* state machines — behavior that tracks a state (a flag, an enum,
a file, a queue) without declaring its states, transitions, and failure
paths in one place. Eleven were found across NEXUS-OS and the PS5GreenApple
app. They are now specified here (for humans) and in
`agents/state-machines.json` (for agents), validated by
`tools/statecheck/statecheck.py` on every harness run.

Why this matters along all three axes:

- **UX** — the states a user can observe (STAGED, WAITING_APPROVAL, FAIL_LOUD)
  are now named identically in the hub, the scripts, and the docs. A state
  that has a name can be displayed honestly; a transition that has a guard
  can be explained when it refuses you.
- **DX** — one canonical reference replaces archaeology across `desktop.c`,
  `gate-daemon.py`, three chain scripts, and a JSON contract. Change review
  becomes: *which machine did you touch, and does the registry still pass?*
- **AX** — agents read `agents/state-machines.json` instead of re-deriving
  behavior from source every session; the validator turns "the registry is
  stale" from a silent drift into a red check.

Method: transitions were extracted by reading the behavior code, not by
intention — every transition cites its source. Where the sweep found a gap
(a declared feature that isn't enforced, a contract field nobody checks),
it is recorded as a **finding**, not silently fixed: findings change
behavior, and behavior changes here are deliberate acts, not side effects.

## Inventory

| ID | Machine | Component | Kind |
| --- | --- | --- | --- |
| SM-01 | Boot Intent Contract | hub → `boot-select.json` → `nexus-bootd` | file contract + dispatch |
| SM-02 | Hub App Lifecycle | PS5GreenApple `desktop.c` | UI shell lifecycle |
| SM-03 | Boot Animation Phase | PS5GreenApple `boot.c` | timed sub-machine |
| SM-04 | OS Persona Router | PS5GreenApple `desktop_set_os_target` | cosmetic router |
| SM-05 | Boot Camp Volume Row | PS5GreenApple `app_bootcamp.c` (per row) | classification |
| SM-06 | Permission Gate Request | `nested-os/permission-gate/gate-daemon.py` | security decision |
| SM-07 | Voice Intent Parse | `tools/voice/voice_cmd.py` | deterministic parser |
| SM-08 | Chain Arming Guards | `bootchain/kexec/chainload-*.sh` | safety interlock |
| SM-09 | Hub Demo Boot Modal | `nexus-hub/web-demo/index.html` | simulation surface |
| SM-10 | Feature Harness Session | `agents/feature_list.json` + `CLAUDE.md` | process |
| SM-11 | Workspace Init | `agents/init.sh` | bootstrap |
| SM-12 | Handoff State Reset Contract | `bootchain/kexec/` + `tools/hwtest/probes/` | handoff safety |

The full machine-readable form (states, terminals, every transition with its
guard and source, invariants, findings) lives in `agents/state-machines.json`
— 12 machines, 77 transitions, checked by the harness. What follows is the
human digest: each machine's shape and what was learned from it.

## SM-01 — Boot Intent Contract (the spine)

Three writers, one reader, one file. The hub (`nexus_write_select`, greapple-v2
Patch 1), the standalone payload (`packaging/ps5-elf/nexus_boot.c`), and the
test fixtures all write `/data/NEXUS/boot-select.json`; only
`nexus-boot-select.sh` reads it, validates, and dispatches. States:
`NO_INTENT → STAGED_VALID → DISPATCHED → CHAIN_RUNNING → HANDOFF`, with
`STAGED_INVALID → FAIL_LOUD` as the loud exit. Guards: JSON parses, target in
{macos, windows, linux}, linux requires a flavor.

Learned: the durability rule is **last-staged-wins** — the file persists
across Linux-stage runs, so a stale intent re-dispatches on the next stage
boot. That is a deliberate design (crash-resilient, simple), but it must be
visible: the hub's status line should show `staged_at` age. Also learned: the
reader ignores the schema's own `version` field (**F-A**). Both are findings,
recorded and deliberately left to an owner's decision.

## SM-02 — Hub App Lifecycle

`DS_BOOT → DS_RUN ⇄ DS_SLEEP → DS_SHUTDOWN → EXITED`. The enum is declared
(`desktop.h`); the transitions were implicit — six scattered assignment sites
in `desktop.c` (init, boot-done, sleep menu, wake click, shutdown call, exit
draw). Invariants worth keeping: the main loop exits *only* through
`DS_SHUTDOWN` (all four resource-disposal steps always run), and no handler
touches hardware state outside the sandboxed frame.

## SM-03 — Boot Animation Phase

`IDLE → PLAYING → DONE`, with `boot_skip` as the user's escape hatch. Small,
but it owns the `DS_BOOT → DS_RUN` hand-off in SM-02 — a bug here hangs the
boot screen. `DONE` fires exactly once (the `S_active` flag), which is the
kind of guarantee that deserves to be written down.

## SM-04 — OS Persona Router

The three-persona canvas switch (`PERSONA_MAC/WIN/LINUX`, single-frame
re-style). Historically sensitive: in v2.0.1 this router *was* the fake boot.
Greapple-v2 Patch 2 demotes it to cosmetic feedback behind a Settings toggle.
The registry encodes the demotion itself as a state-machine fact agents must
respect: persona changes must never be displayable as staging (SM-04 and
SM-01 are different machines).

## SM-05 — Boot Camp Volume Row (per row)

`DETECTED → MOUNTED ⇄ UNMOUNTED → {STAGEABLE_L, STAGEABLE_W, SOURCE_ONLY_M}`,
plus `LOCKED_BY_POLICY` (internal NVMe, permanent) and `LIMITED_FW` (bare
firmware userland, no block info). The load-bearing invariant: **STAGE AS BOOT
TARGET is enabled only when a declared chain can consume the volume** — never
a dead button, never a lying one.

## SM-06 — Permission Gate Request

The security-critical machine:
`RECEIVED → {ALLOWED, DENIED, WAITING_APPROVAL}`, and only an explicit human
`/approve{true|false}` moves a queued request to `RESOLVED_*`. Guards in
order: unknown guest → deny; unknown action → deny; traversal → deny; rule
match → allow; else → queue. Invariants: the gate refuses to construct with
any default other than `deny`; every decision is logged; malformed HTTP JSON
never becomes a request. Finding **F-B**: `approval_timeout_minutes` is
declared in policy but not enforced — the queue is deliberately unbounded
until a human acts. Any future timeout must be an operator decision that
logs an expiry event; it must never silently resolve a request.

## SM-07 — Voice Intent Parse

A priority parser wearing a state machine's clothes. `LISTEN` fans out to
eight terminal intents; **the guard order is the precedence** (boot variants,
then power, gate, status, else unknown). Invariants that fuzzing depends on:
the parser emits action JSON, never shell strings, and injection-shaped input
lands in `INTENT_BOOT_BARE` with `target: null` — enforced by selftest case 8.
Editing the regexes without preserving guard order is the one way to break
this machine silently; now it is written down.

## SM-08 — Chain Arming Guards (×3 scripts, one shape)

`INVOKED → VALIDATED → GUARDED → EXECUTED → HANDOFF_OR_HOP`, with `FAIL_LOUD`
hanging off every guard and `DRYRUN_DONE` as the always-safe parallel exit.
Chain M is the strictest: artifact check → `--i-know-this-crashes-the-host` →
root check → kexec −p → sysrq-c → and `STILL_ALIVE_FAIL` if the hop did not
take. The class invariant: **no script touches machine state before all
guards pass**, and `--dry-run` warns instead of failing so CI can run it.
These scripts are the reason "the console that fails to boot still tells you
why" is true.

## SM-09 — Hub Demo Boot Modal (simulation)

`MODAL_CLOSED → STEPPING → DONE_BANNER` (with early close). The demo may
simulate, but its labels mirror the real chains — the invariant is that the
demo may never out-claim the registry. Finding **F-E**: the macOS modal shows
7 steps while docs/03 specifies chain M as steps 0–8; the meanings align, the
granularity does not. Parity is a display choice; drift in *meaning* would be
a bug.

## SM-10 — Feature Harness Session

`QUEUED → IN_PROGRESS → {VERIFIED, BLOCKED_APPROVAL}`, with
`IN_PROGRESS → QUEUED` when a session ends unverified. The harness rules from
`CLAUDE.md` become transitions with guards: one feature per session;
verification requires quoted passing output *before* `feature_list.json` is
edited; approval-gated work parks in `BLOCKED_APPROVAL` rather than sneaking
past.

## SM-11 — Workspace Init

`UNINITIALIZED → TOOLS_OK → REPOS_PRESENT → {SMOKE_PASS, SMOKE_FAIL}`.
Fail-fast on missing required tools, warn-only on optional ones, network
fetches only into `third_party/`, smoke = the quick harness. Simple — but it
is the first machine every new contributor (human or agent) meets, so it is
documented rather than assumed.

## SM-12 — Handoff State Reset Contract

Added by F22 (`docs/13`): the OS-dev curriculum's deepest lesson — an OS owns
its GDT, IDT, page tables and APIC from reset — maps onto NEXUS as a
boundary rule. kexec hands every target a **clean slate**; nothing crosses
except kernel, initramfs, cmdline. Before the exec,
`tools/hwtest/probes/probe-platform.sh` checks the five bring-up layers
(PCI, framebuffer, interrupts, storage, network); residue is probed, logged
via delta-report, and either cleared or fails loudly — never booted through.
States: `COLD_ENTRY → TARGET_SELECTED → {STATE_PROBED ⇄ RESIDUE_DETECTED} →
{HANDOFF_CLEAN, FAIL_LOUD}`.

Learned: the reset guarantee was already true in the chain scripts but was
implicit; the probes turn it from an assumption into per-session evidence
archived next to the ktty capture.

## Findings register

| ID | Finding | Disposition |
| --- | --- | --- |
| F-A | Boot-intent reader ignores the `version` field | Recorded; reserved forward-compat check for an owner decision |
| F-B | Gate `approval_timeout_minutes` declared, not enforced | Recorded; queue is intentionally human-bounded |
| F-C | Last-staged-wins durability of `boot-select.json` | Documented as deliberate; hub should surface `staged_at` age |
| F-E | Demo modal (7 steps) vs docs/03 chain M (steps 0–8) granularity mismatch | Recorded; meaning-aligned, display-only |

Audit hygiene note: a suspected sixth finding (malformed ANSI escapes in the
chain scripts' `say()`/`die()`) was **withdrawn at byte-level verification** —
the source was correct; a display layer had eaten the `1;35m`/`[0m` tokens.
The rule this taught: tool output is evidence, but bytes are proof — inspect
with `od -c` before filing a defect.

## Maintenance protocol (for agents)

1. Touching a component with a registered machine? Read its entry in
   `agents/state-machines.json` first; keep guard order and invariants.
2. Added or changed a transition? Update the registry **and** this document
   in the same commit, citing the new source.
3. Run `python3 tools/statecheck/statecheck.py agents/state-machines.json`
   (the harness does it for you). A red registry blocks the feature, same as
   any failing test.
4. New implicit state machine discovered anywhere in the repo? Register it —
   the next sweep should find fewer, not more.
