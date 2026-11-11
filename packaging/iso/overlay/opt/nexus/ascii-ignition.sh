#!/bin/bash
# ascii-ignition.sh — NEXUS Metro IGNITION, terminal delivery surface.
#
# Console fallback / serial-echo twin of the 48-frame IGNITION boot animation
# (docs/14): wake -> seven dies ignite -> relay ring spin-up -> RGB-split
# glitch snap -> wordmark + tagline + three OS orbit nodes. Uses only
# cp437-safe glyphs + the 16-color remapped palette (metro.sh), so it renders
# identically on fbcon and on a serial console.
#
# Usage: ascii-ignition.sh [--fps 8] [--dev /dev/ttyS0|stdout]
set -u
if ! . /opt/nexus/lib/metro.sh 2>/dev/null; then
  C_RED=31; C_MINT=32; C_YEL=33; C_DIM=36; C_TXT=37
  C_SRED=91; C_SMINT=92; C_SYEL=93; C_SDIM=90; C_CYAN=96; C_WHT=97
  nexus_wordmark() { printf '\033[96mN E X U S - O S\033[0m\n'; }
fi

FPS=8; STEP=$((100 / 8))   # ~125 ms
OUT=/dev/stdout
[ "${1:-}" = "--dev" ] && [ -n "${2:-}" ] && OUT="$2"

emit() { printf '%b' "$1" >> "$OUT" 2>/dev/null; }
beat() { emit "$1"; sleep 0.125; }

emit '\033[2J\033[H'

# ── phase 1: wake — hex lattice fades in, a spark appears (frames 00-07) ────
for fg in 90 36 96; do
  beat "\033[H\033[${fg}m  NEXUS-OS · live stage · ignition sequence\033[0m\n"
done
hex_lattice "$C_SDIM" > "$OUT" 2>/dev/null || true

# ── phase 2: ignite — seven dies light in sequence (frames 08-17) ───────────
DIE_OFF='\033[90m█\033[0m'; DIE_ON='\033[96m█\033[0m'; TICK='\033[93m▸\033[0m'
line7=""
for n in 1 2 3 4 5 6 7; do
  line7="$line7$DIE_ON "
  dies=""
  for m in $(seq 1 7); do
    [ "$m" -le "$n" ] && dies="$dies$DIE_ON " || dies="$dies$DIE_OFF "
  done
  beat "\033[3;4H\033[K   FW lineage 7.00 ─▸ 13.60:  $dies  $TICK die $n"
done

# ── phase 3: spin-up — relay ring arcs counter-rotate (frames 18-29) ────────
for r in 1 2 3 4; do
  a=$(( r % 4 )); case $a in 0) ch='|';; 1) ch='/';; 2) ch='-';; 3) ch='\';; esac
  beat "\033[6;10H\033[K      relay ring  \033[95m($ch)  ((  o  ))  ($ch)\033[0m"
done

# ── phase 4: glitch — RGB-split snap (frames 30-33) ─────────────────────────
beat "\033[8;1H\033[91m N E X U S \033[0m"
beat "\033[9;3H\033[94mN E X U S\033[0m"
beat "\033[8;1H\033[93m▓\033[96mN E X U S\033[93m▓\033[0m"

# ── phase 5: identity — wordmark + tagline + three orbit nodes (34-47) ──────
emit '\033[H\033[2J'
nexus_wordmark > "$OUT" 2>/dev/null || true
emit "\033[93m      ONE CONSOLE. EVERY OS.\033[0m\n"
emit "\033[90m     ───────────────────────────────────────\033[0m\n"
emit "     \033[37m●\033[0m \033[97mmacOS\033[0m   \033[94m●\033[0m \033[97mWindows\033[0m   \033[92m●\033[0m \033[97mLinux\033[0m\n"
sleep 0.4
emit '\033[2J\033[H'
[ -t 0 ] || true
exit 0
