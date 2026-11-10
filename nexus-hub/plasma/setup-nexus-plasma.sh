#!/usr/bin/env bash
# setup-nexus-plasma.sh — apply the NEXUS Metro look to a KDE Plasma session.
# Top panel + global menu · centered icons-only dock · animations off · blur glass.
#
# Modes:
#   (default)     colorscheme + motion discipline + glass + panel layout
#   --full        also installs the F23 identity package: desktoptheme,
#                 look-and-feel (KSplash), Konsole scheme, wallpapers
#   --no-panels   skip plasmashell scripting (config files only)
#   --undo        remove NEXUS Metro config + installed files (Breeze default)
#
# Supports Plasma 6 first (kwriteconfig6/qdbus6) with Plasma 5 fallbacks.
# Run inside the target session (Linux host or PS5-Linux Plasma stage).
# Plymouth + SDDM need root — see docs/14-nexus-metro-identity.md § Apply.
set -euo pipefail

SCHEME_DIR="$HOME/.local/share/color-schemes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMA_ROOT="$SCRIPT_DIR"
APPLY_PANELS=1
FULL=0
UNDO=0

say() { printf '\033[1;35m[nexus-plasma]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus-plasma] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

case "${XDG_CURRENT_DESKTOP:-}" in
  KDE|kde) ;;
  *) say "WARN: XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-unset}' — not a Plasma session; config files will still be written." ;;
esac

for arg in "$@"; do
  case "$arg" in
    --no-panels) APPLY_PANELS=0 ;;
    --full)      FULL=1 ;;
    --undo)      UNDO=1 ;;
    *) die "unknown option $arg (supported: --full, --no-panels, --undo)" ;;
  esac
done

# ---------------------------------------------------------------- tool resolve
KW=""
for c in kwriteconfig6 kwriteconfig5; do
  command -v "$c" >/dev/null 2>&1 && { KW="$c"; break; }
done
[ -n "$KW" ] || die "kwriteconfig6/5 not found — is Plasma installed?"
QDBUS=""
for c in qdbus6 qdbus-qt6 qdbus-qt5 qdbus; do
  command -v "$c" >/dev/null 2>&1 && { QDBUS="$c"; break; }
done
[ "$APPLY_PANELS" = "1" ] && [ -z "$QDBUS" ] && die "no qdbus found; re-run with --no-panels to skip panel layout"

kw() { # kw <file> <group> <key> <value>
  "$KW" --file "$1" --group "$2" --key "$3" "$4"
}

# ------------------------------------------------------------------ undo mode
if [ "$UNDO" = "1" ]; then
  say "removing NEXUS Metro files and restoring Breeze defaults…"
  rm -f  "$SCHEME_DIR/NEXUSMetro.colors"
  rm -rf "$HOME/.local/share/plasma/desktoptheme/NexusMetro"
  rm -rf "$HOME/.local/share/plasma/look-and-feel/com.nexusos.metro"
  rm -rf "$HOME/.local/share/wallpapers/NEXUSMetro"
  rm -f  "$HOME/.local/share/konsole/NEXUSMetro.colorscheme"
  rm -f  "$HOME/.local/share/konsole/NexusMetro.profile"
  kw kdeglobals General ColorScheme "BreezeLight"
  kw kdeglobals KDE AnimationDurationFactor "1"
  say "colorscheme restored to BreezeLight; Plymouth/SDDM revert:"
  say "  sudo plymouth-set-default-theme -R bgrt && sudo update-initramfs -u"
  say "  sudo rm -rf /usr/share/sddm/themes/nexus-metro"
  exit 0
fi

# ------------------------------------------------------------ 1. colorscheme
mkdir -p "$SCHEME_DIR"
cp "$PLASMA_ROOT/NEXUSMetro.colors" "$SCHEME_DIR/NEXUSMetro.colors"
kw kdeglobals General ColorScheme "NEXUSMetro"
kw kdeglobals KDE widgetStyle "breeze"
say "colorscheme NEXUSMetro installed + selected"

# ------------------------------------------------------- 2. motion discipline
# Kill global animation duration (all UI effects become instant) — keeps modest
# hardware snappy; glass + blur stay, motion goes.
kw kdeglobals KDE AnimationDurationFactor "0"
kw kdeglobals KDE widgetStyle "breeze"
# Launcher: no icon animation
kw klauncherrc General ForceAnimation "false"
say "animations disabled (AnimationDurationFactor=0)"

# ----------------------------------------------------------------- 3. glass
# Blur enabled; decoration translucency is carried by the colorscheme.
kw kwinrc Plugins blurEnabled "true"
kw kwinrc Plugins forceblurEnabled "false"   # optional 3rd-party; off by default
kw kwinrc Compositing OpenGLIsUnsafe "false"
say "KWin blur enabled (glass panels)"

# ------------------------------------------------------ 4. identity package
if [ "$FULL" = "1" ]; then
  DEST="$HOME/.local/share"
  mkdir -p "$DEST/plasma/desktoptheme" "$DEST/plasma/look-and-feel" \
           "$DEST/konsole" "$DEST/wallpapers"
  cp -r "$PLASMA_ROOT/desktoptheme/NexusMetro" "$DEST/plasma/desktoptheme/"
  cp -r "$PLASMA_ROOT/look-and-feel/com.nexusos.metro" "$DEST/plasma/look-and-feel/"
  cp -r "$PLASMA_ROOT/wallpapers/NEXUSMetro" "$DEST/wallpapers/"
  cp "$PLASMA_ROOT/konsole/NEXUSMetro.colorscheme" "$DEST/konsole/"
  cp "$PLASMA_ROOT/konsole/NexusMetro.profile" "$DEST/konsole/"
  say "identity package installed: desktoptheme + look-and-feel + wallpapers + konsole"
  if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
    plasma-apply-lookandfeel -a com.nexusos.metro 2>/dev/null \
      && say "look-and-feel com.nexusos.metro applied (KSplash active)" \
      || say "WARN: plasma-apply-lookandfeel failed; defaults file is in place, applies at next login"
  else
    say "plasma-apply-lookandfeel absent — package applies at next login"
  fi
  WP="$DEST/wallpapers/NEXUSMetro/contents/images/1920x1080.png"
  if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WP" 2>/dev/null \
      && say "NEXUS Metro wallpaper applied" \
      || say "WARN: wallpaper not applied; pick '$WP' in Display settings"
  else
    say "set wallpaper manually: $WP"
  fi
  say "Plymouth boot animation + SDDM need root (docs/14 § Apply):"
  say "  sudo cp -r $PLASMA_ROOT/boot-splash/plymouth/nexus-ignition /usr/share/plymouth/themes/"
  say "  sudo plymouth-set-default-theme -R nexus-ignition"
  say "  sudo cp -r $PLASMA_ROOT/sddm/nexus-metro /usr/share/sddm/themes/"
fi

# ----------------------------------------------------------- 5. panel layout
if [ "$APPLY_PANELS" = "1" ]; then
  JS='
// NEXUS Metro layout: top panel (global menu + tray + clock), centered dock.
for (const p of panels()) { p.remove(); }
const top = new Panel("top");
top.location = "top"; top.height = 34; top.floating = false; top.alignment = "center";
top.addWidget("org.kde.plasma.appmenu");          // global menu
top.addWidget("org.kde.plasma.panelspacer");
const clock = top.addWidget("org.kde.plasma.digitalclock");
top.addWidget("org.kde.plasma.systemtray");
const dock = new Panel("bottom");
dock.location = "bottom"; dock.height = 64; dock.floating = true; dock.alignment = "center";
const tasks = dock.addWidget("org.kde.plasma.icontasks");   // icons-only dock
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", []);
print("NEXUS layout applied");
'
  say "applying panel layout via plasmashell scripting…"
  "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS" \
    || die "plasmashell scripting failed (running session required)"
  say "top panel: global menu · clock · tray"
  say "dock     : centered, floating, icons-only"
fi

# ------------------------------------------------------------------ 6. done
say "NEXUS Metro applied. Reload plasmashell if needed:"
say "  systemctl --user restart plasma-plasmashell.service   (or log out/in)"
say "Undo: setup-nexus-plasma.sh --undo"
