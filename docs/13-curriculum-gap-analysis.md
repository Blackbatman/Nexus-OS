# 13 — Curriculum Gap Analysis: "Write your own Operating System" vs NEXUS-OS

Sources analyzed (2026-11-11, F22):

- YouTube playlist `PLHh55M_Kq4OApWScZyPl5HhgsTJS9MZ6M` — **"Write your own
  Operating System"**, 34 episodes, ~663k views; source codes and forum at
  wyoos.org.
- wyoos.org course catalog — **Kernel Development** (the playlist, with
  Appendix A: Networking and Appendix B: Hard Drive), plus **Linux From
  Scratch**, **Linux Kernel**, **Compiler Construction**, **Kerberos**,
  **Network Design**.

The series builds a full x86 OS from the boot sector up: segments and the
GDT, port I/O, interrupts, keyboard and mouse drivers, driver abstractions,
PCI and base-address registers, VGA graphics, a GUI framework, desktop and
windows, multitasking, the heap, a complete network stack (Ethernet → ARP →
IPv4 → ICMP → UDP → TCP → HTTP), ATA drives, syscalls and POSIX, partition
tables and FAT32.

NEXUS-OS does not write a kernel — Linux, macOS and Windows bring their own.
But the *layers* that series teaches are exactly the layers NEXUS crosses
during every handoff, and they were **implicit, never probed**. That was the
overlooked part. This document maps every layer to its NEXUS component and
records what changed.

## Layer mapping (34 episodes + site catalog → NEXUS-OS)

| # | Series layer | Episodes | NEXUS-OS counterpart | Status before F22 | Action |
| --- | --- | --- | --- | --- | --- |
| 1 | Segments / GDT | 3 | kexec hands the target a clean GDT; nothing inherited | implicit in chain scripts | **SM-12** makes the reset contract explicit |
| 2 | Port I/O | 4 | kernel territory (delegated) | delegated | none (documented here) |
| 3 | Interrupts / IDT | 5 | APIC shape of the Linux stage never checked | **overlooked** | `probe-platform.sh interrupts` |
| 4 | Keyboard / Mouse drivers | 6–7 | DualSense HID over USB-BT (tools/voice path) | covered by F05/F06 | none |
| 5 | Driver abstractions | 8–9 | nested-OS guest runners | covered | none |
| 6 | PCI enumeration | 10–11 | PS5 APU/GPU/NVMe visibility in the Linux stage | **overlooked** | `probe-platform.sh pci` |
| 7 | Graphics mode (VGA) | 12 | GOP framebuffer handoff (UefiPayload → kexec → OS) | **overlooked** | `probe-platform.sh framebuffer` |
| 8 | GUI framework / desktop / windows | 13–14 | NEXUS Metro identity (KDE Plasma) | colorscheme only | full identity package — `docs/14` |
| 9 | Multitasking | 15 | kernel territory (delegated) | delegated | none |
| 10 | Heap / dynamic memory | 16 | kernel territory (delegated) | delegated | none |
| 11 | Networking stack | 17–18, A01–A09 | NIC bring-up before update/repair flows | **overlooked** | `probe-platform.sh network` |
| 12 | Hard drives | 19, B01 | partition visibility on the stage | **overlooked** | `probe-platform.sh storage` |
| 13 | Syscalls / POSIX | 20 | kernel territory (delegated) | delegated | none |
| 14 | Partition table / FAT32 | B01–B03 | ESP integrity precondition of every chain | partial (artifact checks only) | `probe-platform.sh storage` (EFI runtime + blocks) |
| 15 | site: Linux From Scratch | — | NEXUS Linux stage customization (Phase 2 kernel staging) | not referenced | queued in `docs/15` |
| 16 | site: Linux Kernel | — | debug-kernel option for T1/T2 tracks (docs/12) | not referenced | queued in `docs/15` |
| 17 | site: Compiler Construction | — | cross-build hygiene for patches/ | not referenced | queued in `docs/15` |
| 18 | site: Kerberos | — | no domain auth in scope | out of scope | none |
| 19 | site: Network Design | — | docs/04 networking section | covered | none |

## What F22 adds

1. **`tools/hwtest/probes/probe-platform.sh`** — five read-only probes
   (pci, framebuffer, interrupts, storage, network), one JSON object per
   line, `--dry-run` and `--selftest`. Operators run it inside the NEXUS
   Linux stage and archive the output with the ktty session; it turns the
   playlist's bring-up layers into F18 evidence.
2. **SM-12 "Handoff State Reset Contract"** (12th machine in
   `agents/state-machines.json` + `docs/10`) — the series teaches that an OS
   owns its tables from reset; NEXUS's analog is that every chain kexec
   hands the target a *clean slate* and any residue (stale fb mapping, APIC
   error, storage surprise) is detected and logged, never booted through.
3. **The NEXUS Metro identity package** (`docs/14`) — the series' GUI
   episodes build a desktop from raw pixels; NEXUS instead claims a
   *bespoke identity on Plasma*: unique boot animation, splash, greeter,
   wallpapers, palette. That is the design answer to episodes 12–14.

## Explicitly not adopted

- Writing our own kernel/GDT/interrupt handlers — redundant and dangerous
  next to kexec + three production kernels; the reset contract (SM-12) is
  the safe boundary.
- 32-bit BIOS-era assumptions — the PS5 chain is UEFI/x86-64 only
  (GOP, not VGA; NVMe/AHCI, not ATA).
- Kerberos/domain content — out of scope for a console OS launcher.
