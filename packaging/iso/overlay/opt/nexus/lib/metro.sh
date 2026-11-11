# metro.sh — NEXUS Metro console identity for the live stage (docs/14).
# Sourced by init/hub/ascii-ignition. Everything is 16-color ANSI; the 16
# console palette registers are remapped to the exact docs/14 tokens so
# fbcon and any serial terminal that honors OSC "P" render the real palette.
#
#   idx  token          hex        usage
#   0    deep-space     070B18     background (ESC[40m)
#   1    n7-red         FF2A6D     negative/alert
#   2    mint           3DFFA2     positive/OK
#   3    cyber-yellow   FCEE0A     glitch ticks, accents
#   4    hub-blue       4CC2FF     Windows node / info
#   5    relay-violet   B967FF     tertiary accent
#   6    relay-dim      1A6078     secondary strokes
#   7    text           D7E6F2     foreground (ESC[37m)
#   8    slate-dim      46516E     muted text
#   9-15 bright variants; 14 = relay-cyan 35E0FF (focus/glow)

# --- palette registers (fbcon honors ESC]P<n><rr><gg><bb>; serial ignores) --
nx_init_palette() {
  local _c _out=/proc/self/fd/1
  [ -w /dev/tty0 ] && _out=/dev/tty0   # remap the VGA console, not the log
  for _c in \
    "0:070B18" "1:FF2A6D" "2:3DFFA2" "3:FCEE0A" \
    "4:4CC2FF" "5:B967FF" "6:1A6078" "7:D7E6F2" \
    "8:46516E" "9:FF6E9E" "A:7CFFC4" "B:FFF35C" \
    "C:7DD8FF" "D:D39BFF" "E:35E0FF" "F:FFFFFF"
  do
    printf '\033]P%s%s' "${_c%%:*}" "${_c#*:}" >> "$_out" 2>/dev/null || :
  done
  printf '\033[H\033[2J\033[?25l' >> "$_out" 2>/dev/null || :
}

nx_restore_cursor() { printf '\033[?25h'; }

# --- semantic colors --------------------------------------------------------
C_BG=40; C_RED=31; C_MINT=32; C_YEL=33; C_BLUE=34; C_VIO=35; C_DIM=36; C_TXT=37
C_SRED=91; C_SMINT=92; C_SYEL=93; C_SBLU=94; C_SVIO=95; C_SDIM=90; C_CYAN=96; C_WHT=97

# --- helpers ----------------------------------------------------------------
# ser: plain-text mirror to serial console (smoke-test + ttyS0 UX evidence)
ser() { printf '%s\n' "$*" >> /dev/ttyS0 2>/dev/null || :; }

# hex_lattice <fg> — the docs/14 hexagonal lattice motif (cp437-safe glyphs)
hex_lattice() {
  printf '\033[%sm' "$1"
  printf '    /\\  /\\  /\\  /\\  /\\  /\\  /\\  /\\  /\\  /\\    \n'
  printf '   /  \\/  \\/  \\/  \\/  \\/  \\/  \\/  \\/  \\/  \\   \n'
  printf '\033[0m'
}

# hr <fg> — thin rule
hr() { printf '\033[%sm' "$1"; printf -- '─%.0s' $(seq 1 68) 2>/dev/null || printf -- '-%.0s' $(seq 1 68); printf '\033[0m\n'; }

# wordmark — NEXUS block letters (box-drawing glyphs, cp437-safe)
nexus_wordmark() {
  printf '\033[%sm' "$C_CYAN"
  cat <<'WM'
███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗
████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝
██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗
██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║
██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║
╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
WM
  printf '\033[0m'
}

# panel head: cyan corners + title
panel_head() { printf '\033[%sm┌─ \033[%sm%s\033[%sm ─────\n' "$C_CYAN" "$C_SYEL" "$1" "$C_CYAN"; printf '\033[0m'; }
