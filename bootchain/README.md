# Boot Chain

Three chains from "jailbroken" to "operating system". Status words are load-bearing.

| Chain | Target | Status | Entry script |
| --- | --- | --- | --- |
| M | macOS Monterey 12.7.6 | **PROVEN** upstream (FW 13.42, launch model) | `kexec/chainload-macos.sh` |
| L | Linux ×8 flavors | **READY** (direct kexec; needs PS5-built kernels) | `kexec/chainload-linux.sh` |
| W | Windows 11 | **RESEARCH** (no public proof; USB-only, framebuffer) | `kexec/chainload-windows.sh` |

```
Jailbreak entry, per firmware (operator-run, APPROVAL GATED — docs/09-firmware-coverage.md):
  FW 7.00–13.60: Relapse-Exploit (browser → aio kernel RW)   · 13.20/13.60: Byepervisor-Reborn HV
  FW ≤ 12.00 era: PPPwn-family                                · FW 14.x: no public entry (F20 watch)
   → ps5-payload-dev/elfldr (port 9021)
   → PS5GreenApple v2 / nexus_boot.elf   [Stage A — FW userland]
       writes /data/NEXUS/boot-select.json
   → ps5-linux-loader → NEXUS Linux stage [Stage B]
       nexus-boot-select.sh (kexec/nexus-boot-select.sh)
         ├─ chain L: kexec -l <PS5-built bzImage+initrd> → kexec -e
         ├─ chain M: kexec -p stage1 → sysrq-c → UefiPayload → OpenCore → XNU
         └─ chain W: UefiPayload → bootmgfw.efi → winload.efi
```

## Directory

- `acpi/madt_fake.py` — working ACPI MADT generator (8c/16t topology, checksummed,
  self-tested). Used when patching/replacing Sony's dumped tables for OpenCore.
- `kexec/chainload-*.sh` — one script per chain; **every script supports `--dry-run`**
  and validates artifacts before touching machine state. Chain M additionally
  refuses to run without `--i-know-this-crashes-the-host` because the crash hop is
  by design a controlled kernel panic.
- `kexec/nexus-boot-select.sh` — consumes `boot-select.json` written by the hub
  (Stage A) and dispatches; appends every decision to the boot log.
- `stage1/` — the crash-kernel/UefiPayload bridge (see `stage1/README.md`).

## Safety rules baked into the scripts

1. No script touches a real machine state without explicit flags (`--dry-run` is the
   default-able, and Chain M needs a second explicit flag).
2. Missing artifacts fail loudly **before** any kexec call.
3. Every decision is appended to a boot log (`/data/NEXUS/boot-log.txt` or
   `/tmp/nexus-boot-log.txt` in dry mode) — a console that fails to boot still
   tells you why.
