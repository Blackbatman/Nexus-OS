# 03 — Boot Chains (detail)

Status words: **PROVEN** = upstream demonstrated on hardware; **READY** =
engineering complete, needs PS5-built artifacts; **RESEARCH** = no public proof.

## Jailbreak entry by firmware (step 0 of every chain)

Entry is **operator-run and approval-gated**; NEXUS-OS never ships exploit code
(NOTICE §2). Full matrix with sources: `docs/09-firmware-coverage.md`.

| Firmware | Entry chain |
| --- | --- |
| FW 7.00 – 13.60 | `ntfargo/Relapse-Exploit`: browser stage (JSC leaks + structured-clone pool mismatch) → kernel stage (`aio_multi_wait` UAF) → kernel R/W |
| FW 13.20 / 13.60 (optional HV layer) | `PS5Dev/Byepervisor-Reborn`: S3-resume `startup_mp` hypervisor exploit → HV R/W incl. VMCBs (developer base) |
| FW ≤ 12.00 era | PPPwn-family (ucred triple-free) — the classic path |
| FW 14.00 / 14.10 | **No public kernel exploit** — RESEARCH watch (F20) |

After entry, all paths converge: kernel R/W → `elfldr` :9021 → `nexus_boot.elf`.

## Chain M — macOS Monterey 12.7.6 (PROVEN upstream, FW 13.42; 13.60 pairing READY)

The upstream proof ran on a launch-model PS5 at FW 13.42. With the Relapse entry
covering 13.60, the same chain is expected to work there — labeled **READY**, not
PROVEN, until hardware evidence lands via F18.

| Step | Actor | Detail |
| --- | --- | --- |
| 0 | Operator | Jailbreak entry per the table above (approval-gated) → `elfldr` :9021 |
| 1 | Stage A | Hub stages `boot-select.json` (target `macos`) |
| 2 | Stage B | `ps5-linux-loader` → PS5 Linux (console 2560×1440) |
| 3 | Stage B | `kexec -p stage1.elf` — stage1 registered as **crash kernel** |
| 4 | Stage B | `echo c > /proc/sysrq-trigger` — intentional crash hop |
| 5 | stage1 | identity map · AMD IOMMU disabled · UEFI hand-off prep |
| 6 | UEFI | EDK2 **UefiPayloadPkg** takes the machine |
| 7 | UEFI | **OpenCore** applies patched Sony ACPI (dumped upstream) + kernel patches |
| 8 | macOS | `boot.efi` → XNU 21.6.0 → Monterey desktop |

Guardrails in `chainload-macos.sh`: artifact checks → root check → explicit
`--i-know-this-crashes-the-host` (the hop *is* a controlled panic) → post-failure
diagnosis line if sysrq returns alive.

**OpenCore checklist** (NEXUS additions must re-verify upstream state):
ACPI: our `madt_fake.py` output matches upstream's dumped+patched table shape
(16 LAPIC, IO APIC @ 0xFEC00000, NMI LINT1, LAPIC @ 0xFEE00000). Kernel patches:
upstream `opencore/` set, unchanged. Drivers: "Salina" Ethernet kext (GPL-2.0
exception upstream). Do not add spoofing kexts "for looks" — cosmetic CPU/memory
misreporting is an open upstream item, not ours to fake.

## Chain L — Linux ×8 flavors (READY)

`kexec -l <bzImage+initrd> --command-line <preset>` → `kexec -e`. Presets live
in `chainload-linux.sh` (arch/ubuntu/fedora/debian/cachyos/nobara/mint/omarchy).
**Constraint:** kernels must be PS5-built (upstream patched trees); a stock
distro kernel lacks SoC bring-up and will not display. The hub marks flavors
without staged kernels `SIMULATED · no PS5 kernel staged` instead of pretending.

## Chain W — Windows 11 (RESEARCH)

`UefiPayload → EFI/Boot/bootmgfw.efi → winload.efi`. Not publicly proven on
PS5. Known limits coded into the script's output: USB-only storage, framebuffer
display (no GPU accel), USB input. Requires user-licensed media (NOTICE §4).

## Failure behavior (all chains)

- Missing artifact → loud FAIL **before** any machine state changes.
- Every dispatch appended to `/data/NEXUS/boot-log.txt`.
- `--dry-run` prints the exact commands; QA runs it in CI-style tests.
