# macOS targets — bare-metal PS5 (chain M) and VM guests

Two macOS paths ship with NEXUS-OS. Legal posture per `NOTICE.md` §3.

## 1. Bare-metal on PS5 — chain M (upstream PROVEN)

Target: **launch-model PS5, FW 13.42**. Chain (adapted from
`rodri0x/ps5-hackintosh`):

```
ps5-linux-loader → Linux → kexec_file_load(stage1, crash) → sysrq-c
→ stage1 (identity map, IOMMU off) → EDK2 UefiPayload
→ OpenCore (Sony ACPI dumped+patched) → boot.efi → XNU 21.6.0 → Monterey 12.7.6
```

- You provide macOS Monterey 12.7.6 media and an APFS USB SSD (upstream boots
  from USB; internal NVMe stays locked).
- OpenCore config + ACPI patching: follow `third_party/ps5-hackintosh/opencore/`
  after `agents/init.sh`; ACPI generation helper here: `bootchain/acpi/madt_fake.py`.
- Run `bootchain/kexec/chainload-macos.sh --dry-run` first; the real hop needs
  the explicit crash-confirm flag.

## 2. macOS on macOS — terminal-mac guest (Apple-licensed path)

On an Apple silicon Mac: `nested-os/terminal-mac/run-mac-guest.sh` launches a
real macOS guest via Apple's Virtualization.framework (the `govijr/terminal-mac`
model) — squarely inside Apple's license terms. This is the clean demo/dev path
for the hub UI against a real macOS desktop in a terminal window.

## "macOS ARM64 / Intel" versions (what is honest here)

- **Intel/x86**: chain M is x86-64 macOS on the PS5's Zen 2 SoC — that IS the
  Intel-class target, on the bare metal.
- **ARM64**: macOS/ARM (Apple Silicon) cannot run on x86 hardware; the honest
  ARM64 story is the **terminal-mac guest on M-series Macs** (and the research
  Henge bridge on iOS/iPadOS). We state this instead of faking a build.

## Known gaps carried from upstream (not hidden)

WiFi/BT (NXP IW620) no driver · HDMI audio off (USB audio works) · no GPU
acceleration (Cyan Skillfish) · no clean shutdown/restart · USB boot disk may
vanish mid-session. All tracked in `docs/04-hardware-support.md` and the
roadmap — the beta team's hardware matrix files update them.
