# PS5GreenApple v2 — "NEXUS that really boots" patch spec

**Owner:** ui-builder · **Verifies via:** `make host` + `make shots` (headless dump
backend) — never via unverified PS5 claims. Target repo:
`third_party/PS5GreenApple` (clone with `agents/init.sh`).

## Goal

PS5GreenApple v2.0.1 ships a NEXUS hub that re-themes the desktop per OS choice and
honestly states *no OS actually boots from it*. This spec turns the hub into the
**Stage A half of the real boot flow**: the hub stages a boot intent; the Linux
stage (Stage B, `bootchain/kexec/nexus-boot-select.sh`) consumes it and kexecs.

```
[FW userland · SDL2]                    [Linux stage · ps5-linux-loader]
NEXUS app confirm dialog                        nexus-bootd (systemd unit)
  → nexus_write_select()  ─── /data/NEXUS/boot-select.json ───▶  reads + dispatches
  → honest status line                       ├─ chain M (macOS, PROVEN)
  → Boot Camp shows real volumes             ├─ chain L (linux:<flavor>, READY)
                                             └─ chain W (windows, RESEARCH)
```

`/data` is visible to both stages on the same console storage, so a JSON file is
the contract. The SDL2 app **never** boots anything itself — it has no kernel
access, and that stays true.

## Patch 1 — new file `src/nexus_boot.c` (+ `src/nexus_boot.h`)

```c
/* One tiny JSON emitter; no dependencies, fixed schema:
   {"version":1,"target":"macos|windows|linux","flavor":"arch|ubuntu|…",
    "staged_at":"<iso8601>","staged_by":"PS5GreenApple v2.1"}          */
int  nexus_write_select(const char *data_dir,
                        const char *target, const char *flavor,
                        char *errbuf, size_t errlen);
/* Writes /data/NEXUS/boot-select.json atomically:
   write boot-select.json.tmp → fsync → rename. Returns 0 on success. */
int  nexus_read_last_status(const char *data_dir,
                            char *out, size_t outlen); /* tail of boot-log.txt */
```

Rules: atomic rename (a hub crash mid-write must never leave a half file),
embedded strings only (the repo already embeds Liberation fonts — same style),
no dynamic allocation beyond stdio buffers.

## Patch 2 — `src/app_nexus.c` (hub confirm flow)

1. Keep the existing OS grid and confirm dialog untouched visually.
2. Replace the "instant desktop re-theming" action with:
   `nexus_write_select("/data", target, flavor, …)`.
3. Status line under the confirmed card becomes one of:
   - `STAGED · will boot on next Linux-stage run` (after successful write)
   - `STAGE FAILED · check /data writable` (write error — surface `errbuf`)
   - `SIMULATED · this flavor has no PS5 kernel staged` (flavor preset missing on
     the boot USB — read from the same table `chainload-linux.sh` uses)
4. The old instant re-theme stays available as **pure cosmetic feedback** behind
   Settings → "Theme preview (cosmetic only)" — honesty preserved, delight kept.

## Patch 3 — `src/app_bootcamp.c` (real volumes, real staging)

1. Volume detection changes from fixed mock entries to a backend call:
   ```c
   /* backend_dump.c AND backend_sdl2.c gain: */
   int backend_list_volumes(bootcamp_volume_cb cb, void *user);
   ```
   Linux/dump backend: parse `popen("lsblk -rno NAME,FSTYPE,LABEL,SIZE,MOUNTPOINT")`.
   PS5 SDL2 backend: same popen against the Linux stage when running under
   `ps5-linux-loader` guest context; when running on bare FW userland (no shell),
   list `/mnt/usb0`, `/data` directly — and label the row `LIMITED · no block
   info in FW userland`.
2. Rows show: label · fs · size · mount state · **action**:
   - `MOUNT` / `UNMOUNT` (calls `mount(8)` via popen on Linux stage only)
   - `STAGE AS BOOT TARGET` (enabled when an OS chain can consume the volume:
     APFS→macOS row is `SOURCE ONLY · chain M boots via stage1`, NTFS with
     `EFI/Boot/bootmgfw.efi` → `STAGEABLE (chain W · RESEARCH)`, ext4 with a
     PS5-built `bzImage` → `STAGEABLE (chain L · READY)`)
3. The internal NVMe row keeps its magenta `LOCKED BY POLICY` chip (upstream
   blocks internal SSD on purpose).

## Patch 4 — Terminal built-in `nexus-status`

Add to the existing offline builtins table in `src/app_terminal.c`:
`nexus-status` → prints the staged selection + the last 8 lines of
`/data/NEXUS/boot-log.txt` (written by `nexus-boot-select.sh`). Users can see
*why* a boot did not happen from the comfort of the hub.

## Patch 5 — Settings honesty block

NEXUS section in `app_settings.c` gains a static truth table (same vocabulary as
the repo docs): `macOS PROVEN (upstream, FW 13.42) · Linux READY · Windows
RESEARCH · audio/WiFi/BT/power RESEARCH`. No feature may claim more.

## Patch 6 — CI / dump backend

Extend `scripts/demo-script.txt` so `make shots` produces three new PNGs:
`nexus-stage-ok.png`, `nexus-stage-fail.png`, `bootcamp-volumes.png`. These are
the visual baselines for BackstopJS (`tools/backstop/`).

## Definition of done

- `make host && make shots` green with the three new PNGs.
- `nexus_write_select` unit pass: valid write, atomic-rename after simulated crash
  (kill during write), unwritable dir → error surfaced.
- No string in the app claims a boot happened; staged ≠ booted.
- Upstream honesty line in the hub is replaced by the real status lines above.
