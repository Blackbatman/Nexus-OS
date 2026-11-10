# 14 — NEXUS Metro Identity (Mass Effect × Cyberpunk 2077 hybrid)

The desktop must not look like a themed distro — it must look like NEXUS-OS.
This document pins the design language so every surface (boot, greeter,
splash, desktop, terminal, hub) renders from one system.

Legal frame: the identity is *inspired by* the aesthetics of Mass Effect
(BioWare/EA) and Cyberpunk 2077 (CD Projekt Red) — relay geometry, glass
panels, glitch ticks. No copyrighted asset, logo, font, or name from either
game is reproduced. NOTICE.md §2 discipline applies to the visual layer too.

## Palette

| Token | Hex | Role | Inheritance |
| --- | --- | --- | --- |
| `deep-space` | `#070B18` | global background | colorscheme BackgroundNormal (7,11,24) |
| `panel-glass` | `#0D1424` @86% | panels, cards, dialogs | desktoptheme colors |
| `relay-cyan` | `#35E0FF` | focus, glow, links, selection | DecorationFocus (53,224,255) |
| `relay-dim` | `#1A6078` | secondary strokes, borders | konsole Color6 |
| `cyber-yellow` | `#FCEE0A` | glitch ticks, accents | ForegroundNeutral (255,184,77 family) |
| `n7-red` | `#FF2A6D` | negative/alert | ForegroundNegative (255,42,109) |
| `mint` | `#3DFFA2` | positive/OK | ForegroundPositive (61,255,162) |
| `text` | `#D7E6F2` | foreground | ForegroundNormal (215,230,242) |
| `silver` | `#D8DCE4` | macOS node | boot orbit node 1 |
| `hub-blue` | `#4CC2FF` | Windows node | boot orbit node 2 |

## Motifs

1. **The relay ring** — double concentric arcs with counter-rotation and
   six spokes (Mass Effect mass-relay geometry). It appears in the boot
   animation, the KSplash, the logo, and the wallpapers.
2. **The seven dies** — a cluster of seven rounded dies igniting in
   sequence: the FW 7.00 → 13.60 support lineage made visual.
3. **Glitch ticks** — short cyber-yellow bars and rare RGB-split snaps
   (Cyberpunk 2077). Used at *ignition moments only* (boot frames 30–33,
   die flash), never in steady-state UI.
4. **Hex lattice** — faint hexagonal grid on backgrounds, ≤5% opacity.
5. **Metro discipline** — flat panels, icons-only dock, zero animation
   duration (`AnimationDurationFactor=0`): glass and glow carry the look,
   motion does not (modest-hardware rule from the hub brief).

## The IGNITION boot animation (unique, generated, deterministic)

48 frames @ 25 fps, rendered by
`nexus-hub/plasma/boot-splash/plymouth/nexus-ignition/generate-frames.py`
(PIL + numpy, no network, no assets):

| Frames | Phase | What happens |
| --- | --- | --- |
| 00–07 | wake | hex lattice fades in, scanline sweeps, a cyan spark grows |
| 08–17 | ignite | the seven dies light in sequence, each with a yellow tick |
| 18–29 | spin-up | relay ring arcs sweep in and counter-rotate around the dies |
| 30–33 | glitch | wordmark lands via RGB-split snap (red/cyan/blue offsets) |
| 34–47 | identity | NEXUS wordmark + "ONE CONSOLE. EVERY OS." + three OS nodes take orbit (silver=macOS, blue=Windows, mint=Linux), core breathes |

Delivery surfaces:
- **Plymouth** (`boot-splash/plymouth/nexus-ignition/`): `.plymouth` +
  `nexus-ignition.script` cycle the 48 pre-rendered frames, drive a thin
  progress bar from the boot-progress signal, fade out on quit. Install:
  `sudo cp -r nexus-ignition /usr/share/plymouth/themes/ &&
  sudo plymouth-set-default-theme -R nexus-ignition`.
- **KSplash** (look-and-feel `com.nexusos.metro`): the same ring breathes
  around the logo while the Plasma session loads.
- **Previews**: `docs/assets/boot-animation-preview.gif` (in-repo) and the
  MP4/GIF shipped with the release notes.

No other open-source OS project boots with this sequence — it is generated
from the NEXUS palette and tells the NEXUS story (seven dies = FW lineage;
three orbit nodes = one console, every OS).

## Component inventory (all under `nexus-hub/plasma/`)

| Surface | Path | Notes |
| --- | --- | --- |
| Color scheme | `NEXUSMetro.colors` | pre-existing, now paired with the package |
| Plasma theme | `desktoptheme/NexusMetro/` | glass 9-slice panel/tooltip/dialog SVGs + theme colors + metadata.json |
| Look and feel | `look-and-feel/com.nexusos.metro/` | defaults (scheme, blur, no-anim, panel sizes), KSplash QML |
| SDDM greeter | `sddm/nexus-metro/` | Main.qml + wallpaper background + logo |
| Wallpapers | `wallpapers/NEXUSMetro/` | Core (desktop, 1920/2560) + Lock variants, metadata.desktop |
| Konsole | `konsole/NEXUSMetro.colorscheme` + `NexusMetro.profile` | terminal in the same glass/cyan language |
| Boot animation | `boot-splash/plymouth/nexus-ignition/` | 48 frames + script + progress sprites + generator |

## Apply

```
bash nexus-hub/plasma/setup-nexus-plasma.sh            # colors + panels (session)
bash nexus-hub/plasma/setup-nexus-plasma.sh --full     # + theme package, wallpaper, splash
sudo cp -r nexus-hub/plasma/boot-splash/plymouth/nexus-ignition /usr/share/plymouth/themes/
sudo plymouth-set-default-theme -R nexus-ignition      # firmware-stage boot animation
sudo cp -r nexus-hub/plasma/sddm/nexus-metro /usr/share/sddm/themes/
```

Undo: `setup-nexus-plasma.sh --undo` (restores Breeze + removes NEXUS config
keys); Plymouth revert via `plymouth-set-default-theme -R bgrt`.
