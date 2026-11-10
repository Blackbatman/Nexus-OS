# 15 — Next Steps (both repos, 2026-11-11)

Owner view after F22 (curriculum gap closure) and F23 (NEXUS Metro identity).
Ordering follows the zero-breakage rule: every step ends with
`beta-team/run-tests.sh` green and, where code changes, a documented delta.

## Repo 1 — Blackbatman/Nexus-OS

### Now (this session, done)

- F22: `docs/13` gap analysis, `tools/hwtest/probes/probe-platform.sh`
  (pci/framebuffer/interrupts/storage/network), SM-12 handoff reset contract.
- F23: IGNITION boot animation (Plymouth + previews), NEXUS Metro identity
  package (desktoptheme, look-and-feel + KSplash, SDDM, wallpapers, Konsole),
  `setup-nexus-plasma.sh --full/--undo`.

### Next 5 (ordered)

1. **ISO assembly** — build the NEXUS Linux stage ISO (archiso profile under
   `packaging/`), embedding: Plymouth `nexus-ignition`, SDDM theme, Plasma
   package, `probe-platform.sh`, `nexus-bootd` unit. Definition of done:
   boots in QEMU to the Metro desktop; harness stays green.
2. **Probes into the F18 runbook** — add a `probe-platform.sh all` step to
   `docs/12` T1/T2 checklists so every hardware session carries the five
   JSON lines next to the ktty capture.
3. **BackstopJS visual baselines** — pin the Metro look: screenshots of the
   hub demo + generated frames; CI fails on drift (Phase 5 item, cheap now).
4. **Hub ↔ theme parity** — web-demo adopts the exact palette tokens from
   `docs/14` (it already matches; assert it in tests).
5. **v0.2.0-beta release** — tag after 1–3; release.yml packages the new
   assets automatically. Keep v0.1.0-beta as prerelease until the ISO boots
   in QEMU.

### Standing items

- F18 hardware tracks (T1/T2/T3) remain **approval-gated**: say the word and
  the operator ritual in `docs/12` starts.
- F20: monthly 14.x research re-review (next: 2026-12-09).
- Rotate the exposed PAT (third reminder — it is in chat history).

## Repo 2 — Blackbatman/PS5GreenApple

1. **v2.1.0 alignment** — `third_party/PS5GreenApple` carries greapple-v2
   (merged upstream); keep the NEXUS-OS patch file as the historical record
   and re-run `make host && make nexus-unit && make shots` on every release
   tag of that repo.
2. **Metro inside the hub app** — port the boot animation phases (SM-03) to
   the SDL renderer: die ignition → ring → wordmark; palette from `docs/14`
   so app boot and OS boot feel like one system.
3. **boot-select UX polish** — surface `staged_at` age on the status line
   (SM-01 finding F-C) and a confirm beep before write (SM-08 tie-in).
4. **Shots pipeline in its CI** — run `make shots` on tag builds and attach
   PNGs to the GitHub release (mirrors what release.yml does for NEXUS-OS).
5. **Docs cross-link** — reference `docs/14-nexus-metro-identity.md` from
   its README so both repos declare one design language.

## Definition of done for this phase

Harness green on both repos · ISO boots to Metro in QEMU · probes archived
with every F18 session · one design language across boot, greeter, desktop,
terminal, hub.
