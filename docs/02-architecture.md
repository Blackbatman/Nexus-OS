# 02 — Architecture

NEXUS-OS is three cooperating planes plus a QA organism. The rule that shapes
everything: **each plane only claims what it can verify.**

## Plane 1 — FW userland (Stage A): the hub

SDL2 homebrew on a jailbroken PS5 (ps5-payload-sdk build → `nexus_boot.elf` /
PS5GreenApple v2). No kernel access — by design. Its whole real power is one
honest file: `/data/NEXUS/boot-select.json`. NEXUS and Boot Camp write the
user's intent there; Cluster Telemetry and Settings keep their upstream roles.

```
[PS5 · jailbroken FW userland]
  PS5GreenApple v2 (NEXUS hub, Boot Camp, Settings)
      └─ nexus_write_select() → /data/NEXUS/boot-select.json
```

## Plane 2 — Linux stage (Stage B): the orchestrator

`ps5-linux-loader` boots a patched PS5 Linux. There, NEXUS-OS is real software
with kernel authority:

```
[PS5 · PS5-Linux stage]
  nexus-bootd (consumes boot-select.json)
      ├─ chain L  kexec -l <PS5-built bzImage+initrd> → kexec -e          READY
      ├─ chain M  kexec -p stage1 → sysrq-c → UefiPayload → OpenCore      PROVEN (upstream)
      │           → boot.efi → XNU 21.6.0 (macOS 12.7.6)
      └─ chain W  UefiPayload → bootmgfw.efi → winload.efi                RESEARCH
  + permission-gate daemon + DIC voice (whisper.cpp) + Plasma (NEXUS Metro)
```

## Plane 3 — Host/nested: the workspace

On Apple silicon and KVM hosts, the "OS inside the OS" runs behind the
**Permission Gate** (default deny, approval queue, JSONL log):

```
[Apple silicon Mac]                    [KVM host]
  terminal-mac (macOS guest)            QEMU+swtpm (Windows guest)
        └────────────┬───────────────────────┘
                     ▼
        gate-daemon 127.0.0.1:7421 (policy.json)
        allow rules · approval queue · full decision log
```

## QA organism (cross-cutting)

- `agents/feature_list.json` — the single source of truth; one verified feature
  per session; evidence mandatory.
- Beta team, three lenses: functional (`beta-team/run-tests.sh`), hostile-input
  (fuzz entry points), visual (BackstopJS / fallback differ).
- RE sweep (REA + radare2) after any boot-stage rebuild.

## Design decisions worth defending

1. **JSON file as the Stage A↔B contract** — atomic, human-readable, works
   across the FW/Linux boundary via shared storage; no new IPC needed.
2. **Every script has `--dry-run`** — the only way QA can test boot tooling
   without a console.
3. **Honesty vocabulary is enforced in code** (`SIMULATED`/`RESEARCH`/`PROVEN
   (upstream)`) — the web demo, the SDL2 hub, and the docs share one table
   (`docs/04`), so no surface can quietly out-claim another.
4. **Default-deny gate** — the policy loader refuses to start with
   `default != deny`. Isolation is not a config option.
5. **Plasma over heavier DEs, animations off** — the brief's "stays snappy on
   modest hardware": glass + blur stay, motion goes.
