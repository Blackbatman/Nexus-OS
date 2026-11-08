# NEXUS Metro — KDE Plasma theme pack

The Linux flavor of NEXUS-OS (and any Plasma session on the PS5-Linux stage) gets
the Mass Effect × CyberPunk look with **nothing flashy enough to slow modest
hardware**: glass + blur stay, motion goes.

## What the setup script does

| Step | Keys touched | Effect |
| --- | --- | --- |
| 1 | `kdeglobals [General] ColorScheme` | installs + selects `NEXUSMetro.colors` (dark glass, cyan selection) |
| 2 | `kdeglobals [KDE] AnimationDurationFactor=0`, `klauncherrc ForceAnimation=false` | all micro-animations instant — the "stays snappy" rule |
| 3 | `kwinrc [Plugins] blurEnabled=true` | glass blur behind panels/windows |
| 4 | plasmashell scripting | **top panel**: `org.kde.plasma.appmenu` (global menu) + digital clock + system tray; **bottom dock**: floating, centered, icons-only task manager |

Layout matches the brief: top panel + centered dock + global menu + glass.

## Requirements

- KDE Plasma 6 (preferred) or 5.27+; Wayland session recommended
- `kwriteconfig6/5`, `qdbus` — the script auto-detects both generations

## Run

```bash
./nexus-hub/plasma/setup-nexus-plasma.sh              # full apply
./nexus-hub/plasma/setup-nexus-plasma.sh --no-panels  # colors/blur only (no session scripting)
systemctl --user restart plasma-plasmashell.service   # if panels need a nudge
```

## PS5 Linux stage notes

- Start a Plasma (Wayland) session from the NEXUS Linux stage, then run the script.
- DualSense works as a pointer/navigable input via the mainline `hid-playstation`
  driver (kernel ≥ 5.12) — controller-first navigation is preserved; keyboard and
  mouse remain first-class.
- The dock's icons-only task manager keeps focus behavior predictable with a
  gamepad: one press = one app, no hover dependence.

## Undo

```bash
rm -f ~/.local/share/color-schemes/NEXUSMetro.colors
kwriteconfig6 --file kdeglobals --group General --key ColorScheme "BreezeLight"
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor "1"
# panels: right-click each panel → remove (script does not manage backups by design)
```

## Optional (documented, not installed by default)

- `LightlyShaders` / `Rounded Corners` KWin effects for curved glass corners
- Kvantum engine for deeper translucency in Qt apps
Both are third-party effects; the base theme intentionally relies on stock Plasma
so a PS5-Linux install needs nothing from external stores.
