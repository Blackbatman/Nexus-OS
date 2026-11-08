# Nested OS — "an OS inside the OS, separately, unless permitted"

The NEXUS-OS isolation layer. Guests run on host machines (Apple silicon for the
macOS guest; any KVM host for Windows), fully separated from each other and from
the host filesystem by the **Permission Gate** — a default-deny broker.

## Model

```
┌────────────────────────┐     ┌────────────────────────┐
│ terminal-mac guest     │     │ windows-guest (QEMU)   │
│ (Apple Virtualization) │     │ (KVM + swtpm)          │
└───────────┬────────────┘     └───────────┬────────────┘
            │  every cross-boundary request │
            ▼                               ▼
   ┌─────────────────────────────────────────────┐
   │ gate-daemon (127.0.0.1:7421, default deny)  │
   │ policy.json → allow rules · approval queue  │
   │ every decision logged (JSONL)               │
   └─────────────────────────────────────────────┘
```

- **No host folder shares are attached to guests by default.** The QEMU command
  line mounts nothing; terminal-mac's workspace is the only bind it sees.
- A guest that wants `~/nexus-workspace/<other-guest>/…` gets `waiting_approval`
  → you approve or deny (web demo's Permission Gate panel mirrors this flow).
- Every decision — allow, deny, queued, approved — lands in the gate log.

## Files

| Path | What |
| --- | --- |
| `permission-gate/gate-daemon.py` | the daemon + 8-scenario selftest |
| `permission-gate/policy.json` | per-guest allow roots (edit sparingly) |
| `terminal-mac/run-mac-guest.sh` | `--check-env` / launch, Apple-licensed path |
| `windows-terminal/run-windows-guest.sh` | `--check-env` / launch, your licensed ISO |

## Quick start

```bash
python3 nested-os/permission-gate/gate-daemon.py --selftest   # prove the gate
python3 nested-os/permission-gate/gate-daemon.py              # run it

nested-os/terminal-mac/run-mac-guest.sh --check-env           # Apple silicon Mac
nested-os/windows-terminal/run-windows-guest.sh --check-env   # KVM host

# then launch for real (see each script's header for flags)
```

## Henge bridge (research)

`henge-bridge/` documents the experimental path of exposing the same gate API to
`Leviidev/Henge` macOS guests running on iOS/iPadOS hardware — same default-deny
broker, same approval UX. RESEARCH status: no proven hardware path yet.
