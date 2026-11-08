# 11 — F17: GreenApple v2 real code patches (implementation record)

**Feature:** F17 in `agents/feature_list.json` · **Spec:**
`nexus-hub/greapple-v2/README.md` · **Owner:** ui-builder · **State machine
contract:** `agents/state-machines.json` SM-01 (Boot Intent Contract) and
SM-05 (Boot Camp Volume Row) from the F21 registry.

This is the first NEXUS-OS feature that ships **real C code** instead of a
plan: the fake "instant desktop re-theming" in PS5GreenApple v2.0.1 is
replaced by the Stage-A half of the actual boot flow. The SDL2 app writes
`/data/NEXUS/boot-select.json` (atomic, versioned, honest); the NEXUS Linux
stage (`bootchain/kexec/nexus-boot-select.sh`) reads it and dispatches. The
app never boots anything — it has no kernel access, and that stays true.

## Deliverable layout

| Path | What it is |
| --- | --- |
| `patches/PS5GreenApple/greapple-v2.1.patch` | The complete patch (2,002 lines) against upstream `Blackbatman/PS5GreenApple` commit `10b98b3` (v2.0.1). |
| `third_party/PS5GreenApple/` | Your working clone with the patches applied (created by `agents/init.sh`, gitignored — never shipped). |

Apply on any fresh clone:

```bash
git clone --depth 1 https://github.com/Blackbatman/PS5GreenApple
cd PS5GreenApple
git apply /path/to/patches/PS5GreenApple/greapple-v2.1.patch
make host && make nexus-unit && make shots
```

`beta-team/run-tests.sh` runs exactly this chain (patch-apply check → host
build → unit tests → shots) whenever the clone exists, and skips cleanly
when it does not.

## What the patch contains (spec → code)

**Patch 1 — `src/nexus_boot.c` + `src/nexus_boot.h` (new files).** One tiny
JSON emitter + reader, no dependencies, fixed schema
`{"version":1,"target":…,"flavor"?…,"staged_at","staged_by"}`. Writes are
atomic: `boot-select.json.tmp` → `fflush` → `fsync` → `rename` (+ best-effort
directory fsync), so a hub crash mid-write can never leave a half-written
intent and the previous intent always survives a failed stage (SM-01
invariant 1). The writer validates exactly what the reader enforces: unknown
targets, `linux`-without-flavor, unknown flavors, and flavor-on-non-linux are
rejected *before* touching the disk. Also hosts the shared lsblk walker and
the guarded stage helper (below).

**Patch 2 — `src/app_nexus.c`.** "INITIATE ENVIRONMENT" (instant re-theme +
window close) is now **"STAGE FOR NEXT BOOT"**: it stages the intent, keeps
the window open, and shows exactly one of the spec status lines —

* `STAGED · will boot on next Linux-stage run` (green) + chain note
  (`chain M · PROVEN upstream (FW 13.42…)`, `chain W · RESEARCH…`,
  `chain L · READY · flavor …`)
* `SIMULATED · this flavor has no PS5 kernel staged` (amber) — nothing is
  written; the guard mirrors `chainload-linux.sh`'s preset table
  (`<base>/linux/<flavor>/vmlinuz`, base `/mnt/usb0` on PS5) so a doomed
  intent never reaches the selector
* `STAGE FAILED · check /data writable` (red) with the real errno text

The header lie ("THEME PERSONA PICKER") and the "SIMULATION LAYER ACTIVE"
data stream are replaced: the footer now prints the live staged intent
(`BOOT INTENT // target=linux flavor=omarchy age=0s`). On open, the hub
surfaces any previously staged intent **with its age** — registry finding
F-C (last-staged-wins) made visible. The old re-theme survives as pure
cosmetic feedback behind Settings → "Theme preview (cosmetic only)"
(default **off**; persisted as `theme_preview=` in settings.ini).

**Patch 3 — `backend_list_volumes()` in `backend_dump.c` +
`backend_sdl2.c`, consumed by a rewritten `src/app_bootcamp.c`.** The dump
backend parses real `lsblk -rno NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT` output
(escape-aware positional parser, unit-tested). The SDL2 backend decides at
runtime: under a shell (Linux-stage guest / desktop) the same lsblk walk;
on bare FW userland it stat-probes `/mnt/usb0`, `/mnt/usb1`, `/data` and
flags rows `LIMITED · no block info in FW userland` (SM-05 `LIMITED_FW`).
Boot Camp now renders the real rows with SM-05 chips — `UNMOUNTED`,
`MOUNTED`, `STAGEABLE · chain L · READY` (ext4 + PS5-built bzImage),
`STAGEABLE · chain W · RESEARCH` (NTFS carrying `EFI/Boot/bootmgfw.efi`),
`SOURCE ONLY · chain M via stage1` (APFS), magenta `LOCKED BY POLICY`
(internal NVMe, blocked upstream on purpose) — plus per-row `MOUNT` /
`UNMOUNT` (popen `mount(8)`, Linux stage only) and `STAGE`, which writes
the boot intent through the same guarded path as the hub. The two old
"simulated handoff" cards are gone; the shell-preview showcase remains,
still labeled cosmetic.

**Patch 4 — `nexus-status` terminal builtin** (`src/app_terminal.c`):
prints the staged intent summary and the last 8 lines of
`/data/NEXUS/boot-log.txt` — the selector's own decisions — so a user can
see *why* a boot did not happen from inside the hub.

**Patch 5 — Settings honesty block** (`src/app_settings.c`): static truth
table in the docs' vocabulary — `macOS PROVEN (FW 13.42) · Linux READY ·
Windows RESEARCH · audio/WiFi/BT/power RESEARCH` — and the theme-preview
toggle. Window grown to 980×820 to fit.

**Patch 6 — shot pipeline** (`scripts/demo-script.txt` +
`scripts/demo-stage-fail.txt`, `Makefile`): `make shots` now also produces
`nexus-stage-ok.png`, `nexus-stage-simulated.png`, `nexus-stage-fail.png`,
`bootcamp-volumes.png` and `14j-nexus-status-terminal.png`. The fail shot
works deterministically even as root: `NEXUS_DATA_DIR` (host builds only)
points at a regular *file*, so every mkdir inside fails with `ENOTDIR`.
`make nexus-unit` builds `tests/test_nexus_boot.c`.

## State-registry conformance (F17 × F21)

* SM-01: every transition the hub can cause is in the registry — stage
  (`NO_INTENT→STAGED_VALID`), re-stage (last-staged-wins), invalid intents
  never leave the writer, dispatch is reader-only. Finding F-A is honored,
  not fixed silently: version≠1 intents are *surfaced* as
  `SCHEMA MISMATCH` / `IGNORED INTENT`, and the schema is not extended.
* SM-05: Boot Camp rows implement the registry states 1:1, including both
  terminal paths the upstream repo can hit (`LOCKED_BY_POLICY`,
  `LIMITED_FW`).
* One staged-status vocabulary everywhere: `nexus_stage_guarded()` is the
  single implementation used by the hub, Boot Camp, and the unit tests —
  UX, DX, and AX all read the same words.

## Verification evidence

* `make nexus-unit`: 37/37 checks — valid write, atomic rename after a
  simulated crash (stale `.tmp` cleaned, previous intent intact),
  unwritable dir error surfaced, all writer rejections, reader round-trip,
  boot-log tail (8 lines), schema-mismatch flagging, flavor table mirror,
  lsblk parser edge cases.
* `make host && make shots`: all 29 PNGs rendered; the four new ones
  visually inspected (STAGED/SIMULATED/STAGE FAILED lines, real volume
  rows, terminal builtin output all correct).
* End-to-end cross-repo proof: the intent written by the app —
  `{"version":1,"target":"linux","flavor":"omarchy","staged_at":…,
  "staged_by":"PS5GreenApple v2.1"}` — is accepted by the real
  `nexus-boot-select.sh` (harness check: *hub-written intent accepted by
  the NEXUS reader*).
* Fresh-clone reproducibility: `git clone` → `git apply --check` →
  `make host` → `make nexus-unit` all green inside the harness.
* Out of scope by design (no SDK here): PS5 ELF build (`make` with
  `PS5_PAYLOAD_SDK`), `make sim`/`make windows` (no SDL2/mingw in this
  environment) — code is `-Wall -Wextra` clean under the host compiler;
  run `agents/init.sh` on a machine with those toolchains before the next
  upstream release cut.

## Upstream note

The patch touches only code + scripts + `.gitignore` (two new make
fixtures). `Blackbatman/PS5GreenApple`'s own harness files
(`feature_list.json`, `claude-progress.txt`) are intentionally untouched —
sync those in the upstream repo when the patch is applied there as v2.1.
