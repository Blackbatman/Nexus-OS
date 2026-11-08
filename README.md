# NEXUS-OS

**One console. Three operating systems. Zero pretending.**

NEXUS-OS is an open research platform that turns a **jailbroken PlayStation 5** into a
multi-OS bare-metal machine — plus a host-side ecosystem where macOS and Windows run as
isolated guests inside your terminal, gated behind explicit user permission.

**Firmware coverage:** supported entry range **FW 7.00 – 13.60** (Relapse exploit chain,
Byepervisor-Reborn hypervisor on 13.20/13.60). The macOS chain is *proven* on FW 13.42;
FW 13.60 is the scene's jailbreak ceiling as of October 2026 and our new support ceiling.
FW 14.00/14.10 have **no public kernel exploit** and are a tracked RESEARCH watch
(`docs/09-firmware-coverage.md`, feature F20).

It is the direct evolution of two lines of work:

1. **`rodri0x/ps5-hackintosh`** — proved the hard part: on a launch-model PS5 (FW 13.42)
   the chain *Linux → crash-kexec → EDK2 UefiPayload → OpenCore → macOS Monterey 12.7.6*
   boots bare-metal on the Zen 2 SoC today.
2. **`Blackbatman/PS5GreenApple`** — proved the front end: the **NEXUS hub** and
   **Boot Camp** UI (SDL2 homebrew, software-rendered, FW 3.00–13.60). Its one honest
   flaw is printed on its own screen: *no OS actually boots from it yet*.

NEXUS-OS closes that gap: the buttons **really kexec**, the chains **really chainload**,
and everything that is not yet proven is labeled honestly instead of faked.

---

## Status at a glance

| Capability | State | Where |
| --- | --- | --- |
| Firmware entry 7.00–13.60 (Relapse + Byepervisor-Reborn on 13.x) | **Entry documented** — operator-run, approval-gated; never shipped here | `docs/09-firmware-coverage.md` |
| macOS Monterey 12.7.6 bare-metal on PS5 | **Proven upstream** (FW 13.42, launch model) | `docs/03-boot-chain.md`, adapted from `rodri0x/ps5-hackintosh` |
| Linux multi-flavor boot (8 distros) | **Direct kexec path** — simplest real target | `bootchain/kexec/chainload-linux.sh` |
| Windows 11 boot | **Research-grade** (UefiPayload → bootmgfw.efi, USB-only, no GPU accel) | `bootchain/kexec/chainload-windows.sh` |
| NEXUS Hub v2 (real kexec wiring) | **Spec complete** — patch plan against PS5GreenApple | `nexus-hub/greapple-v2/` |
| KDE Plasma "NEXUS Metro" theme | **Setup script + colorscheme** (top panel, centered dock, global menu, glass) | `nexus-hub/plasma/` |
| Nested OS harness (macOS in terminal, Windows in terminal) | **Runnable harness** + permission gate | `nested-os/` |
| Voice control (DIC — DualSense Integrated Command Interface) | **Module + local whisper.cpp design** | `tools/voice/` |
| Packaging (.elf payload, Arch ISO, Windows media, USB/FTP/disc) | **Scripts + guides** | `packaging/` |
| Explicit state machines (11 audited, registry + validator) | **Specified** — every implicit FSM named, guarded, and CI-checked | `docs/10-state-machines.md`, `agents/state-machines.json`, `tools/statecheck/` |
| WiFi/BT (NXP IW620), HDMI audio, GPU accel, clean power | **Not solved upstream — tracked honestly** | `docs/04-hardware-support.md` |

---

## Repository map

```
nexus-os/
├── CLAUDE.md                  # AI-team harness entry point
├── .claude/agents/            # 7 specialist agents (Planner, RE, Kernel, UI, Integration, Beta QA, Architect)
├── agents/                    # feature_list.json + state-machines.json + init.sh + progress notes (long-run harness)
├── bootchain/                 # kexec/chainload scripts, ACPI MADT fake generator, stage1 notes
├── nexus-hub/
│   ├── web-demo/              # interactive NEXUS Hub UI demo (open in any browser)
│   ├── plasma/                # KDE Plasma NEXUS Metro theme pack + setup script
│   └── greapple-v2/           # PS5GreenApple patch spec: make NEXUS/Boot Camp really boot
├── nested-os/                 # terminal-mac guest, Windows-in-terminal guest, permission-gate daemon
├── tools/                     # REA adapter, radare2 analyzers, BackstopJS visual regression, statecheck, voice, DualSense
├── packaging/                 # ps5-payload-sdk ELF build, Arch ISO profile, Windows media, install guides
├── beta-team/                 # test matrix + run-tests.sh + reports
└── docs/                      # audit, architecture, boot chains, hardware matrix, charter, testing, legal, roadmap, firmware coverage, state machines
```

## Quickstart

```bash
# 0) Read the reality check first
less docs/02-architecture.md

# 1) Initialize the workspace (clones upstream repos into third_party/, builds host sims)
./agents/init.sh

# 2) Run the beta-team test harness
./beta-team/run-tests.sh

# 3) Open the hub demo
xdg-open nexus-hub/web-demo/index.html     # or scripts/serve-demo.sh

# 4) Theme a KDE Plasma 6 session as NEXUS Metro (Linux host / PS5 Linux stage)
./nexus-hub/plasma/setup-nexus-plasma.sh

# 5) Build artifacts (each explains its own prerequisites)
packaging/ps5-elf/build.sh                 # PS5 .elf payload via ps5-payload-sdk
packaging/linux-iso/build-iso.sh           # NEXUS-OS Linux live ISO (Arch-based)
packaging/windows-media/make-windows-media.sh   # requires YOUR official Windows ISO
```

## The three boot chains (summary)

```
                    ┌──────────────────────────────────────────────────────────┐
  Jailbreak entry   │  FW 7.00–13.60: Relapse chain (browser → aio kernel RW)  │
  (operator-run,    │  13.20/13.60 HV layer: Byepervisor-Reborn (S3-resume)    │
   approval-gated,  │  FW ≤ 12.00-era: PPPwn-family (ucred triple-free)        │
   never shipped)   │  → ps5-payload-dev/elfldr (port 9021)                    │
                    │  FW 14.x: no public kernel exploit — RESEARCH watch      │
                    └───────────────────────────┬──────────────────────────────┘
                                                ▼
  Stage A (FW userland)   PS5GreenApple v2 / nexus_boot.elf  ── writes boot-select.json
                                                ▼
  Stage B (Linux stage)   ps5-linux-loader → NEXUS Linux orchestrator (nexus-bootd)
                     ┌─────────────┼─────────────────────────────┐
                     ▼             ▼                             ▼
  Chain M (macOS)  kexec_file_load -p stage1 → sysrq-c → UefiPayload
                   → OpenCore (patched Sony ACPI) → boot.efi → XNU 21.6.0   [PROVEN]
  Chain L (Linux)  kexec -l <bzImage+initrd> → kexec -e                     [READY]
  Chain W (Win)    UefiPayload → bootmgfw.efi → winload.efi                 [RESEARCH]
```

## The agent teams

This repository ships its own development and QA organism (the "Claude team" pattern):

- **Team A — Dev**: Architect (orchestrator), Planner, Reverse-Engineer (REA + radare2),
  Kernel Builder, UI Builder, Integration Builder.
- **Team B — Beta**: three QA agents that run `beta-team/run-tests.sh`, visual regression
  (BackstopJS), and hostile-input stress passes; findings flow back into
  `agents/feature_list.json` until every feature passes.

Start it with your preferred agent CLI (Claude Code or `grok` via `craft-anything`):

```bash
claude                     # or: grok
> Read CLAUDE.md and follow the harness.
```

Publishing releases, spending money, or touching real hardware is **approval-gated** —
the agents must ask you first.

## Credits (the standing on the shoulders)

- `rodri0x/ps5-hackintosh` — the proven macOS chain, crash-kexec stage 1, OpenCore work
- `Blackbatman/PS5GreenApple` — NEXUS hub, Boot Camp, host/dump backends
- `ntfargo/Relapse-Exploit` — FW 7.00–13.60 jailbreak chain (browser + aio kernel RW)
- `PS5Dev/Byepervisor-Reborn` (ChendoChap) — S3-resume hypervisor exploit for 13.x
- `soniciso1/ps5-hv-writeups` — the S3-resume MP/AP-launch mechanism write-up
- `ZigZagBoi1/PS5-14.10-Research`, `pastawithpesto/PS5-14.10-Jailbreak-Research`,
  `kuzibelit/PS5-14.00-14.10-Jailbreak-PoC` — the FW 14.x research watchtower
- `ps5-payload-dev/elfldr` + `ftpsrv` (John Törnblom) — payload delivery (ports 9021/2121)
- `TheOfficialFloW` — PPPwn-family kernel exploits
- PS5 Linux loader & kernel work — the Linux stage everything depends on
- `morluto/rea` (MCP RE tooling), `radareorg/radare2`, `garris/BackstopJS`,
  `storytold/craft-anything`, `xai-org/grok-build` — the AI tooling loop
- `govijr/terminal-mac`, `Leviidev/Henge` — nested macOS paths

See `NOTICE.md` before using anything here. This is **research software for hardware you
own**. It will void warranties and can get consoles banned. No piracy is involved or
endorsed.

## License

This repository is licensed **GPL-3.0** (see root `LICENSE`). Third-party upstream
components keep their own licenses — attribution table in `NOTICE.md` §6.
