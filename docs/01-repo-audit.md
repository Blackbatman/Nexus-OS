# 01 — Upstream Repo Audit (verified 2026-11-09)

Every repository named in the NEXUS-OS brief was fetched and read. This is what
actually exists and how it is used. No repo was invented; nothing here rests on
a mythical dependency. The firmware-exploit layer (Relapse, Byepervisor-Reborn,
the 14.x research corpus) has its own registry: **`docs/09-firmware-coverage.md`**.

| Repo | Verified reality | Role in NEXUS-OS |
| --- | --- | --- |
| `rodri0x/ps5-hackintosh` | 105★. Booting **macOS Monterey 12.7.6 bare-metal** on a launch-model PS5 (FW 13.42): `bringup/` crash-kexec stage 1, `uefi/` EDK2 UefiPayloadPkg, `opencore/` Sony ACPI patched, `kexts/` Ethernet ("Salina" NIC, ~25 MB/s). Works: 16 threads, 2560×1440, USB, USB-SSD APFS, Ethernet. Doesn't: WiFi/BT (NXP IW620), HDMI audio, GPU (Cyan Skillfish), shutdown/restart, internal SSD. | The proven **Chain M**. `bootchain/` + `docs/03` adapt its chain; its roadmap gaps are our roadmap. |
| `Blackbatman/PS5GreenApple` (user's) | v2.0.1, FW 3.00–13.60. SDL2 homebrew DE, software renderer, 1080p ARGB. Apps: Finder/Terminal/TextEdit/About/Cluster Telemetry/Settings/**NEXUS**/**Boot Camp**/Credits. Backends: PS5 SDL2, host dump (`make shots`), windowed sim. Honest state: **hub does not boot anything**. | The **Stage A** front end. `nexus-hub/greapple-v2/` is the patch spec that turns NEXUS/Boot Camp into real boot staging; **F17 implemented it** (see `patches/PS5GreenApple/greapple-v2.1.patch` + `docs/11-greapple-v2-impl.md`). |
| `morluto/rea` | "Reverse Engineer Anything" — CLI + **MCP server**; backends Hopper/Ghidra/IDA/Kuna/objdump/Rizin; ELF/PE/kmod/firmware analysis (Binwalk/Unblob); Node 22+. | RE loop over our own artifacts (`tools/rea-adapter/`). |
| `garris/BackstopJS` | Visual regression testing (Puppeteer scenarios). | Hub UI + Plasma baselines (`tools/backstop/`). |
| `radareorg/radare2` | GPL-3.0 RE framework (r2, radiff2). | Stage build sweeps + drift diffs (`tools/radare2/`). |
| `storytold/craft-anything` | Inspect→rebuild→compare engine (Rust, early alpha); CLI + MCP; drives Claude Code / Copilot / **Grok Build** via ACP. | The study/build/check loop for hub UI rebuilds. |
| `xai-org/grok-build` | `grok` — Rust TUI coding agent (Apache-2.0), ACP-compatible. | Alternate agent runtime for harness + beta stress sessions. |
| `govijr/terminal-mac` | Real macOS guest **in a terminal** on Apple silicon via Apple Virtualization; built for computer-use agents. | The Apple-licensed **nested macOS** path. |
| `Leviidev/Henge` | macOS emulator on iOS/iPadOS (A14/M1, iOS 17+), v0.1. | Research bridge for gated guests beyond the desktop (`nested-os/henge-bridge/`). |
| `ps5-payload-dev/elfldr` · `ftpsrv` | GPL-3.0, active (Oct 2026). ELF loader **port 9021**; FTP **port 2121**. | Payload delivery + network install (`packaging/install-guides/ftp.md`). |
| PPPwn-family (TheOfficialFloW) | Kernel exploit research (ucred triple-free via `__sys_netcontrol`); public PS5 coverage up to FW 12.00 era; newer FW paths exist in the scene. | **Jailbreak entry context only** — not shipped here; operator-run, approval-gated. |
| `ntfargo/Relapse-Exploit` | 2.7k★. FW **7.00–13.60** exploit chain: browser stage (JSC info leaks + structured-clone pool mismatch → typedarray corruption) + kernel stage (`aio_multi_wait` UAF race → kernel R/W). Real code (JS payloads, HTML entry, Python server). | The **primary jailbreak entry** for NEXUS-OS targets ≥ 7.00. Not shipped; documented per-FW in `docs/09-firmware-coverage.md`. |
| `PS5Dev/Byepervisor-Reborn` | 534★, ChendoChap commit 2026-10-12. Hypervisor exploit via S3-resume `startup_mp` (hypercall `0x0f`) + insecure NPT config → shellcode with HV R/W incl. VMCBs. Supports 13.60/13.20; 13.00 untested; claims reachability to 6.xx, modifiable for 14.00. Developer base, not a user tool. | **HV research layer** (F20): clean FW return and HV-isolation threads; entry prerequisite tracking for 13.x. |
| `soniciso1/ps5-hv-writeups` | The mechanism write-up behind the S3-resume bug: resume window, `cur_npt = 0` AP launch at attacker RIP/CR3, 16 GameOS VMCBs, `pcpus[]` v2p walk, CWE-665/863; static proof on 10.00, survives 13.60 with dynamic alias derivation. | **Theory reference** for the HV threads; background reading for the Phase 4 power work. |
| `ZigZagBoi1/PS5-14.10-Research` (+ status report) | 473★, updated 2026-11-06. 2,901 probes / 3,245 captures / 231 docs; Lua 5.1 loader + WebKit vectors (FontFaceSet UAF focus); kernel R/W on 14.10 **not demonstrated**. Status report (2026-10-16): 13.60 = highest fully jailbroken; 14.00/14.10 patched Relapse kernel + S3-resume HV bugs; BootROM keys leaked 2025-12-31 with no public chain. | The **FW 14.10 watchtower** and coverage truth source (F20); keeps the firmware matrix honest. |
| `kuzibelit/PS5-14.00-14.10-Jailbreak-PoC` | 50★. `aio_lapse_exploit.c` — experimental AIO-behavior research for 14.00/14.10; explicitly **not** a working jailbreak per its own README. | Kernel-research signal on the post-13.60 AIO surface; monitoring only. |
| `pastawithpesto/PS5-14.10-Jailbreak-Research` | 356★, updated 2026-10-25. WebKit research on **CVE-2026-43720** (Canvas `getContext()` reentrant UAF): probes, chain HTML, beacon server, deployment tools. | **WebKit entry research** for 14.x; extends `docs/03` step 0 when a 14.x userland lands. |
| PS5 Linux loader/kernel | Public work booting Linux on PS5; expanded FW support; Ubuntu 24.04 image; GPU maturing; DualSense works. | The **Stage B** Linux everything depends on. |

## Operator-named tester environments

`KyyPS5`, `AnyPS5`, and "Mac Terminal" were named as beta-team stress-test
environments. Fetch verification on 2026-11-09 was inconclusive for the two
GitHub names (only navigation chrome returned, no repo payload), so the audit
makes no claim about them. The harness is environment-agnostic by design:
`agents/init.sh` clones any additional repos into `third_party/`, and the
nested-guest runners (`nested-os/terminal-mac/`, `nested-os/windows-terminal/`)
already provide the "Mac Terminal" and "Windows-in-terminal" stress surfaces
the beta team's hostile-input lens targets.

## Delta NEXUS-OS adds

1. A real **boot selector**: hub → `boot-select.json` → `nexus-bootd` → three chains.
2. **Isolation**: default-deny permission gate for nested guests (nothing upstream does this).
3. **QA organism**: feature_list harness + three-lens beta team + RE sweeps — the project ships its own adversarial QA.
4. **Packaging truth-telling**: USB/FTP/disc guides that state what hardware can and cannot do.
