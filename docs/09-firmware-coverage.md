# 09 — Firmware Coverage & Exploit Research Registry (verified 2026-11-09)

This registry extends the repo audit (`docs/01-repo-audit.md`) with the
**firmware-exploit layer**: the public research that decides *which PS5
firmware revisions* NEXUS-OS can target. Every repo below was fetched and read
on 2026-11-09. Nothing is invented; unproven claims stay labeled **RESEARCH**.

The headline: **FW 13.60 is now the highest fully jailbroken firmware** (scene
consensus, October 2026), which raises the NEXUS-OS support ceiling from the
13.42 proven baseline to **13.60** — and pushes 14.00/14.10 into a tracked
RESEARCH watch.

## 1. Firmware coverage matrix

| Firmware | Userland entry | Kernel R/W | Hypervisor | NEXUS-OS stance |
| --- | --- | --- | --- | --- |
| FW 6.xx and older | PPPwn-family (ucred triple-free, public) | Scene standard | — | **SUPPORTED** (entry operator-run) |
| FW 7.00 – 12.02 | Relapse browser → kernel | Relapse `aio_multi_wait` UAF | Byepervisor "should work" per upstream (untested this low) | **SUPPORTED** (entry operator-run) |
| FW 13.00 | Relapse | Relapse | Byepervisor: listed supported upstream, untested | **SUPPORTED** (entry operator-run) |
| FW 13.20 | Relapse | Relapse | Byepervisor: supported | **SUPPORTED** (entry operator-run) |
| **FW 13.42** | Relapse | Relapse | Byepervisor (13.20-class) | **PROVEN BASELINE** — Chain M (macOS) demonstrated here by `rodri0x/ps5-hackintosh` |
| **FW 13.60** | Relapse | Relapse | **Byepervisor-Reborn: supported** | **NEW NEXUS CEILING** — public kernel dump exists; fully jailbroken per scene |
| FW 14.00 | **RESEARCH** | **none public** — Relapse kernel bug patched | Byepervisor "modifiable" per upstream — unproven | **RESEARCH WATCH** (F20) |
| FW 14.10 | **RESEARCH** | **none public** | **none public** — S3-resume HV path also patched | **RESEARCH WATCH** (F20) |

Operator decision points that fall out of this matrix:

- A 13.60 console is **NEXUS-eligible today** (kernel R/W + hypervisor R/W +
  public kernel dump), but Sony has **blocked FW < 14.10 from PSN since
  2026-10-13** — a 13.60 console is effectively offline-PSN. Say this out loud
  to any operator choosing a console for NEXUS-OS.
- A 14.10 console (required for PSN, and for GTA 6 per scene reporting) is
  **not** NEXUS-eligible until the scene publishes a 14.x kernel chain.
- BootROM keys leaked 2025-12-31 (affecting all ~95.3M PS5 consoles) but no
  public exploit chain builds on them yet — tracked, not counted.

## 2. Verified research repositories (added 2026-11-09)

| Repo | Verified reality | Role in NEXUS-OS |
| --- | --- | --- |
| `ntfargo/Relapse-Exploit` | 2.7k★, updated 2026-09-30, JavaScript 99.7%. Two-stage exploit chain for **FW 7.00–13.60**: browser stage (JSC info leaks + structured-clone object pool mismatch → typedarray corruption) then kernel stage (address leak + `aio_multi_wait` UAF race → kernel read/write). Ships payloads, HTML entry page, Python server. | The **primary jailbreak entry** for every NEXUS-OS target ≥ 7.00. Never shipped here (NOTICE §2); operator-run, approval-gated. `docs/03` step 0 and the install guides point here by firmware. |
| `PS5Dev/Byepervisor-Reborn` | 534★, latest commit by ChendoChap 2026-10-12 (`ea04f71`, "Second Commit"), C 93.8%. Hypervisor exploit: during S3 resume `startup_mp` (hypercall `0x0f`) runs on core 0 to wake APs 1–15 with an **insecure NPT configuration**, so shellcode executes with hypervisor-address-space R/W including all VMCBs. Upstream supports **13.60 / 13.20** (13.00 untested), claims reachability to 6.xx and modifiability for 14.00. Self-described "base exploit for developers, not useful to regular users in its current release state". | The **hypervisor research layer** for 13.x targets. Two RESEARCH levers for us: clean FW return / power transitions (roadmap Phase 4 item 2) and an HV-enforced isolation story for nested-OS-on-PS5 experiments. Both unproven; both approval-gated (F20). |
| `soniciso1/ps5-hv-writeups` (`s3-resume-startup_mp-ap-launch.md`) | Technical write-up of the mechanism above: on S3 resume the hypervisor clears the `startup_mp` bitmap, all cores start at `cur_npt = 0` (host view), only the BSP flips to the GameOS NPT, and hypercall `0x0f` stays callable during the resume window — a compromised kernel can launch an AP at an attacker-chosen RIP/CR3 with hypervisor RAM mapped, then read/write all 16 live GameOS VMCBs and walk `pcpus[]` for virtual→physical translation. Classifies as CWE-665 / CWE-863; notes VMCB fields NESTED_CTRL +0x90, NESTED_CR3 +0xb0, Control2 +0xb8. Static proof on FW 10.00; mechanism survives in 13.60 but needs dynamic alias derivation (`hv_heap_offset` moved). | The **theory reference** behind Byepervisor-Reborn. It is also the first credible public mechanism relevant to our clean-shutdown gap: whoever controls VMCB NPT state during resume/transitions controls how guests re-enter FW. Feeds the Phase 4 power work as background READING, not as a solution. |
| `ZigZagBoi1/PS5-14.10-Research` | 473★, updated 2026-11-06. Large-scale empirical research corpus: 2,901 probe scripts (2,798 Lua, 57 JS, 46 HTML), 3,245 result captures, 231 technical documents; dirs `probes/`, `results/`, `evidence/`, `docs/`, `tools/`. Two attack vectors tracked: a Lua 5.1 loader and WebKit vulnerabilities (primary focus: FontFaceSet UAF). **Kernel R/W on 14.10 not yet demonstrated.** | The **FW 14.10 watchtower**. When its status flips, F20 flips, and NEXUS-OS gains a new supported ceiling. Until then it is the dataset that keeps our matrix honest. |
| `ZigZagBoi1/PS5-14.10-Research` → `PS5-FW-14.10-Jailbreak-Status-Report.md` | Status report compiled 2026-10-16. Establishes: highest fully jailbroken FW = **13.60**; 14.00 (2026-09-16/17) patched the Relapse kernel bug; 14.10 (2026-10-01) additionally patched the S3-resume hypervisor bug; no public userland/kernel/HV exploit, offsets, kernel dump, or HEN layer for 14.x; private work may exist (Sonic-Iso, SaudiDos, Jordy) but nothing public. Also documents the 2026 scene model: bugs reported to Sony via HackerOne, published after patching. | The **coverage truth source** this registry's matrix cites. Re-read it (and re-fetch the repos) before every F20 review. |
| `kuzibelit/PS5-14.00-14.10-Jailbreak-PoC` | 50★, 4 forks. Experimental C research (`aio_lapse_exploit.c`) probing AIO-related kernel behavior on 14.00/14.10: request handling, concurrent deletion, object lifetime, memory reuse. The README **explicitly states this is not a finished jailbreak** and the code alone does not demonstrate a working 14.x exploit. | A **kernel-research signal** on the post-13.60 AIO surface — the same subsystem family Relapse used. Monitoring only; never described anywhere as "14.x jailbreak". |
| `pastawithpesto/PS5-14.10-Jailbreak-Research` | 356★, 29 forks, updated 2026-10-25, JS 76.3% / HTML 20.4%. Active WebKit research targeting **CVE-2026-43720**, a Canvas `getContext()` reentrant use-after-free: probe pages deployed to the PS5 browser, exploit-chain HTML, beacon server, probe deployment tooling, source-audit reports. | The **WebKit entry research** for 14.x. If a 14.x userland entry ships, our `docs/03` step 0 and install guides extend to it exactly the way they extended for Relapse. |

## 3. What this changes for NEXUS-OS

1. **Support ceiling: 13.42 → 13.60.** The Chain M/L/W mechanics are unchanged —
   they all execute in the Linux stage *after* entry — so a 13.60 console works
   if the entry layer (Relapse, plus Byepervisor where HV R/W matters) is
   operator-supplied per upstream docs. The proven macOS baseline stays 13.42
   until someone reproduces Chain M on 13.60; until then that specific pairing
   is **READY, not PROVEN**.
2. **New research lever: hypervisor R/W on 13.x.** Byepervisor-Reborn is the
   first public HV primitive in our stack. It is upstream-labeled a developer
   base, not a tool. We track it for two RESEARCH threads only:
   (a) clean FW return / power transitions — the long-standing "shutdown/restart
   broken" gap in `docs/04-hardware-support.md`;
   (b) HV-level isolation underpinning for nested-OS experiments on the PS5
   itself (a hardware answer to what `nested-os/` does on hosts).
   Neither is claimed working; both are approval-gated.
3. **14.x becomes a tracked watch, not a target.** F20 owns it. NEXUS-OS code
   stays firmware-agnostic where it can: the kexec chains, hub, and gate never
   embed firmware offsets, so when the scene ships a 14.x entry we inherit it
   by documentation, not by code surgery.
4. **Per-FW offsets never ship here.** Relapse-style offsets stop at 13.60
   upstream; our repo contains none of them and must never contain them
   (NOTICE §2). The registry only records *which firmware ranges are covered*.

## 4. Timeline (all from the cited status report unless marked "observed")

| Date | Event |
| --- | --- |
| 2025-12-31 | BootROM keys leaked (all ~95.3M consoles); no public chain built on them yet |
| 2026-07-24 | FW 13.60 released — becomes the last fully jailbreakable firmware |
| 2026-09-06 | Jordy publishes the Relapse kernel bug write-up |
| 2026-09-16/17 | FW 14.00 released — patches the `aio_multi_wait` kernel bug |
| 2026-09-29 | Sonic-Iso releases standalone Relapse implementation |
| 2026-09-30 | `ntfargo/Relapse-Exploit` last update (observed) |
| 2026-10-01 | FW 14.10 released — additionally patches the S3-resume HV path |
| 2026-10-12 | `PS5Dev/Byepervisor-Reborn` latest commit `ea04f71` (observed) |
| 2026-10-13 | Sony begins blocking FW < 14.10 from PSN |
| 2026-10-16 | ZigZagBoi1 FW 14.10 status report compiled |
| 2026-10-25 | `pastawithpesto/PS5-14.10-Jailbreak-Research` last update (observed) |
| 2026-11-06 | `ZigZagBoi1/PS5-14.10-Research` last update (observed) |
| 2026-11-09 | This registry compiled; NEXUS-OS ceiling moved to 13.60 (F19) |

## 5. Rules this registry operates under

- **No exploit code ships in NEXUS-OS.** The registry is documentation; entry
  points run upstream in the operator's hands (NOTICE §2, CLAUDE.md gates).
- **Every real-hardware entry run is approval-gated** — see CLAUDE.md
  "Approval gates" and `docs/05-agent-team-charter.md`.
- **Re-verify before trusting.** Scene state moves monthly; re-fetch all seven
  repos (and the status report) at every F20 review and re-date this file.
- **Honest labels only.** "SUPPORTED" above means *entry exists publicly and
  the OS chains below it are engineered*; it never claims a specific OS
  booted on a specific firmware until F18 hardware evidence exists.
