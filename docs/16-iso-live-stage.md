# 16 — QEMU Live-Stage ISO (F24)

A self-contained, **BIOS-bootable ISO** that boots any QEMU/x86_64 machine
into the NEXUS Linux stage: the IGNITION boot animation, the NEXUS Metro
identity, and the real NEXUS hub tooling — dry-run safe, unprivileged
build, QEMU-verified on every build.

It is the executable answer to three standing requirements:

1. "Follow the .md to get the OS up and running" → the stage boots and runs
   the actual repo tooling (boot-select contract, statecheck, probes,
   permission gate).
2. "Desktop must match the Nexus Hub theme" → the hub TUI remaps the
   console's 16 palette registers to the exact docs/14 tokens; the same
   Mass Effect × Cyberpunk 2077 hybrid identity as the Plasma package.
3. "Boot animation must be unique" → the **48-frame IGNITION sequence**
   (seven dies → relay ring → RGB-split glitch → wordmark + tagline + three
   OS orbit nodes) plays on the real framebuffer via `nexfblit`, with an
   ASCII twin mirrored to the serial console as evidence. Plymouth carries
   the same frames on installed systems.

## Layout

```
packaging/iso/
  build-iso.sh          # orchestrator (--smoke = headless QEMU gate)
  fetch-deps.sh         # unprivileged deps: apt-get download + dpkg -x
  mkcpio.py             # deterministic newc cpio writer (--selftest)
  pack-frames.py        # IGNITION PNGs → RGB565 .frb pack (--selftest)
  mkiso.py              # pycdlib glue: ISO9660 L1 + El Torito
  src/nexfblit.c        # framebuffer player (16/24/32 bpp)
  isolinux.cfg          # boot menu (nexus / verbose / shell)
  nexus.msg             # ISOLINUX splash (plain text — syslinux has no ANSI)
  overlay/
    init                # first userspace (busybox sh)
    opt/nexus/hub.sh    # the hub TUI (menu 1-7/0)
    opt/nexus/lib/metro.sh      # palette remap + motifs + wordmark
    opt/nexus/ascii-ignition.sh # serial twin of IGNITION
    opt/nexus/lib/nxshrc        # shell env
```

## What is inside the ISO (25 MB)

| Layer | Content |
| --- | --- |
| Bootloader | ISOLINUX 6.04 + El Torito no-emulation + boot info table |
| Kernel | Debian 6.12 amd64 (`CONFIG_FB_VESA=y`, fbcon built-in — no modules needed) |
| initramfs | static busybox (272 applets pre-linked) + static bash + pruned CPython 3.13 + stdlib + loader closure |
| Animation | `ignition.frb` — 48 frames @ 512×512 RGB565, played by nexfblit at 10 fps |
| Identity | docs/14 palette remapped into the 16 console registers (deep-space `#070B18` … relay-cyan `#35E0FF`) |
| Tooling | `bootchain/`, `tools/statecheck/`, `tools/hwtest/` (incl. F22 probes), `nested-os/permission-gate/`, state registry — the real repo scripts, dry-run guards intact |

## Build

```bash
packaging/iso/fetch-deps.sh          # kernel/busybox/bash/isolinux → build/deps (no root)
packaging/iso/fetch-deps.sh --qemu   # + private qemu-system-x86_64 for --smoke
packaging/iso/build-iso.sh --smoke   # dist/NEXUS-OS-<ver>-live-stage-amd64.iso
packaging/build.sh iso-qemu          # same via the packaging entrypoint
```

System paths (`/boot/vmlinuz-*`, `/usr/bin/busybox`, …) are probed first, so
on an apt host you can also `apt-get install` the packages instead of
`fetch-deps.sh`. `--no-anim` skips the frame pack (ASCII IGNITION only);
`--every 2` halves the animation payload.

## Verification (definition of done)

`build-iso.sh --smoke` boots the ISO headless and **fails** unless the
serial console shows, in order:

```
[nexus-iso] stage up: kernel <ver>, N cpu, fb:yes
[nexus-iso] IGNITION: framebuffer pack (48 frames, docs/14)
[nexus-iso] IGNITION complete
[nexus-iso] permission-gate daemon: up (127.0.0.1:7421, default deny)
[nexus-iso] hub ready — handing console to the NEXUS hub
```

Interactive verification (QMP screendumps) confirmed: ISOLINUX splash,
IGNITION on the framebuffer, hub menu with the NEXUS wordmark, theme
showcase with live palette swatches, boot manager chain table
(M PROVEN upstream · L READY 8 flavors · W RESEARCH).

## Boot menu

| Entry | Cmdline | Use |
| --- | --- | --- |
| `nexus` (default, 2 s) | `quiet loglevel=3` | normal live stage |
| `verbose` | `loglevel=7` | kernel debugging |
| `shell` | `nexus=shell` | rescue shell (skips hub + animation) |

## Safety

The stage never writes to real disks: boot actions run through the chain
scripts' `--dry-run` guards, the hub stages intents to `/tmp` only, and
the permission-gate daemon enforces default-deny for the nested-guest
policy surface (SM-06). `NOTICE.md` §2 discipline applies: the ISO ships
no exploit code — it is the NEXUS Linux stage, not the PS5 entry.

## What this is not (v0.3 path)

The ISO does not carry a Plasma desktop session — a full desktop live ISO
needs a distro base (archiso profile: `packaging/linux-iso/`, buildable on
an Arch host). The stage delivers the boot experience, the hub, and the
identity layer; SDDM/KSplash/Plymouth packages from `nexus-hub/plasma/`
apply to installed systems.

## Reproducibility record (2026-11-12)

Two independent environments have produced a passing `--smoke` boot:

| Environment | Host python | Embedded | QEMU | Result |
| --- | --- | --- | --- | --- |
| GitHub Actions `ubuntu-latest` (run 42955909181) | 3.12 distro | 3.12 | 10.x apt | PASS |
| Debian 13 (trixie), non-root, uv/venv host | 3.12 (uv venv) | 3.13 distro | 10.0.13 private closure | PASS |

The Debian build exercised two portability fixes, both behavior-preserving
on the CI path:

1. `packaging/build.sh` `iso-deps` forwarded `"$@"` verbatim, leaking the
   subcommand itself into `fetch-deps.sh` (`unknown arg: iso-deps`). CI never
   hit it because the workflow calls `fetch-deps.sh` directly; now fixed to
   forward `"${@:2}"`.
2. `build-iso.sh` hardcoded `/usr/lib/python$VER` for the embedded stdlib.
   Probing moved to `sysconfig.get_paths()["stdlib"]` of the interpreter that
   is actually embedded, so distro, uv and venv layouts all resolve; the
   harness went 91/0/2 → **93/0/1** locally (both `iso:` artifact checks now
   run on `dist/`).
