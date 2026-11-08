# NOTICE — Legal, Licensing, and Honest Warnings

Read this before running anything in this repository on real hardware.

## 1. What this project is

NEXUS-OS is **research and interoperability software** for consoles and computers that
**you own**. It exists to study how operating systems boot on nonstandard AMD Zen 2
hardware and to give a single owner multi-OS choice on their own machine. It is not a
piracy tool: nothing here downloads, decrypts, or distributes commercial games, system
firmware images, or licensed OS media.

Repository license: **GPL-3.0** (root `LICENSE`). Components originating in NEXUS-OS
were first published under MIT and are redistributed here under GPL-3.0 (MIT permits
the incorporation); third-party upstream components keep their own licenses — see §6.

## 2. PlayStation / Sony

- Jailbreaking a PS5 violates the PSN Terms of Service. Consequences include permanent
  console bans, loss of online play, and voided warranties. You accept that risk alone.
- The jailbreak entry points referenced (PPPwn-family kernel exploits,
  `ntfargo/Relapse-Exploit` for FW 7.00–13.60, `PS5Dev/Byepervisor-Reborn` for the
  13.x hypervisor layer, `ps5-payload-dev/elfldr`) are public research artifacts of
  their respective authors.
  NEXUS-OS ships **configuration and orchestration around** them, not the exploits
  themselves — no exploit code, no firmware offsets, ever.
- Never boot NEXUS-OS chains with pirated content, and never on a console you do not own.

## 3. Apple / macOS

- Apple's software license agreements permit macOS to run on Apple hardware. Running
  macOS bare-metal on a PS5 (the `rodri0x/ps5-hackintosh` path) or in a KVM guest on
  non-Apple hardware is a **license gray zone**. Apple does not authorize it.
- This project's posture: include the engineering, clearly labeled, **for personal
  research on hardware you own**, with no Apple binaries redistributed. Users must
  supply their own legally obtained macOS installer media and accept the EULA risk.
- The supported clean path for macOS guests is `nested-os/terminal-mac` on **Apple
  silicon** using Apple's own Virtualization framework, which is squarely inside
  Apple's license terms.

## 4. Microsoft / Windows

- NEXUS-OS does **not** distribute Windows. `packaging/windows-media/` requires an
  **official Windows ISO you obtained and licensed yourself**. Windows guests in
  `nested-os/windows-terminal/` likewise require your own licensed media and product
  key. Virtualized use must comply with Microsoft's licensing terms.

## 5. Firmware / security research tools

- `morluto/rea`, `radareorg/radare2`, and `storytold/craft-anything` are used here
  strictly for **analyzing artifacts you own** (payloads you built, kernels you boot)
  to make boot chains more robust. Do not point them at anti-piracy systems or other
  people's proprietary binaries.

## 6. Third-party licenses (attribution required downstream)

| Upstream | License | Used for |
| --- | --- | --- |
| `rodri0x/ps5-hackintosh` | MIT (+ GPL-2.0 exception on Ethernet kext) | Boot chain reference |
| `Blackbatman/PS5GreenApple` | Upstream license of that repo | NEXUS hub / Boot Camp base |
| `ps5-payload-dev/elfldr`, `ftpsrv` | GPL-3.0 | Payload delivery |
| `TheOfficialFloW` PPPwn-family | Upstream license | Jailbreak entry research |
| `ntfargo/Relapse-Exploit` | Upstream license | Jailbreak entry research (FW 7.00–13.60) — not shipped |
| `PS5Dev/Byepervisor-Reborn`, `soniciso1/ps5-hv-writeups` | Upstream license | Hypervisor research context (13.x) — not shipped |
| `ZigZagBoi1/PS5-14.10-Research`, `pastawithpesto/PS5-14.10-Jailbreak-Research`, `kuzibelit/PS5-14.00-14.10-Jailbreak-PoC` | Upstream licenses | FW 14.x research watch — not shipped |
| PS5 Linux loader / kernel patches | GPL-2.0 (kernel) | Linux stage |
| `morluto/rea` | Upstream license | RE orchestration |
| `radareorg/radare2` | GPL-3.0 | Binary analysis |
| `garris/BackstopJS` | MIT | Visual regression |
| `storytold/craft-anything` | MIT / Apache-2.0 | Inspect→rebuild→compare loop |
| `xai-org/grok-build` | Apache-2.0 | Coding agent CLI |
| `govijr/terminal-mac` | Upstream license | macOS-in-terminal guest |
| `Leviidev/Henge` | Upstream license | macOS emulation research bridge |
| OpenCore (acidanthera) | Upstream license | EFI boot orchestration |
| KDE Plasma | GPL/LGPL | Desktop environment |
| Linux kernel | GPL-2.0 | NEXUS-OS Linux flavor |

## 7. Warranty

Everything here is provided **as is, without warranty of any kind**. Booting experimental
chains can crash hardware states, corrupt USB storage, or leave a console in a state that
requires a power cycle. The beta team tests what can be tested without a console; the
rest is flagged `RESEARCH` on purpose. Honest labels are a feature, not an apology.
