# stage1 — crash-kernel / UefiPayload bridge

**Status: RESEARCH (needs real PS5 to iterate; upstream reference is proven).**

stage1 is the small piece of code that turns an intentional kernel crash
(`sysrq-c`) into a controlled hand-off: it runs in the crash-kernel context,
builds an identity map, disables the AMD IOMMU (upstream design — required
because the UefiPayload must touch devices the IOMMU would block), and prepares
the UEFI environment that EDK2's UefiPayloadPkg takes over. After that, OpenCore
(or `bootmgfw.efi` for the Windows research chain) runs as if the machine had a
normal firmware.

## What is here vs upstream

This directory documents NEXUS-OS's integration contract; the stage1 source
itself comes from the upstream `bringup/` work (clone via `agents/init.sh`):

```
third_party/ps5-hackintosh/bringup/   # crash-kexec stage 1, ktty console, debug tools
third_party/ps5-hackintosh/uefi/      # EDK2 UefiPayloadPkg build + HOB/bundle builder
third_party/ps5-hackintosh/opencore/  # OpenCore config + Sony ACPI (dumped, patched)
```

NEXUS-OS additions (owned here):

1. `nexus_uefi_handoff` — the hand-off entry the Windows research chain calls
   (see `bootchain/kexec/chainload-windows.sh`); wraps UefiPayload launch with
   NEXUS logging and an explicit `--entry` app selection.
2. Boot-log integration — every stage emits `nexus:` prefixed lines so the
   beta team can parse a single log across FW userland → Linux → stage1 → EFI.
3. Artifact contract — stage1 builds land at
   `/mnt/usb0/nexus/stage1/stage1.elf` (the default `NEXUS_STAGE1`).

## Build prerequisites (on the Linux build host)

- Upstream `bringup/` toolchain (see third_party/ps5-hackintosh README)
- EDK2 + `UefiPayloadPkg` for the UEFI stage
- kexec-tools ≥ 2.0.20 with `kexec_file_load` support in the **running** PS5
  Linux kernel (`CONFIG_KEXEC_FILE=y`, `CONFIG_CRASH_DUMP=y`)

## Build order

1. Build stage1: follow upstream `bringup/` — output: `stage1.elf`.
2. Build UefiPayload: upstream `uefi/` — output: `UefiPayload.fd`.
3. Copy both to the boot USB under `/mnt/usb0/nexus/…` per the paths above.
4. `bootchain/kexec/chainload-macos.sh --dry-run` must pass with both present.

## Non-goals / honest limits

- No Sony firmware or keys are included, generated, or discussed here.
- IOMMU-disabled downstream is an upstream security trade-off (DMA unguarded);
  NEXUS-OS keeps it because Chain M is proven that way. Changing it is a
  research project, listed in `docs/08-roadmap.md`.
- Clean shutdown/restart after a chain run is unsolved upstream; power features
  stay labeled RESEARCH (see `docs/04-hardware-support.md`).
