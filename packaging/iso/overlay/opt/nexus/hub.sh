#!/bin/bash
# hub.sh — NEXUS-OS live stage hub (QEMU-safe, dry-run boot actions only).
#
# The hub is the OS: this is the same boot-select contract as the PS5 hub
# (SM-01 Boot Intent Contract) rendered as a NEXUS Metro console UI. Every
# boot action runs through the real chain scripts with --dry-run guards —
# the live stage NEVER writes to real disks or stages real boots.
#
# Menu:
#   1 SYSTEM STATUS   2 BOOT MANAGER   3 HARDWARE PROBES
#   4 PERMISSION GATE 5 IGNITION       6 METRO THEME
#   7 SHELL           0 POWER OFF
set -u
export NEXUS_ISO=1
REPO=/opt/nexus/repo
REL="$(cat /etc/nexus-release 2>/dev/null || echo 'NEXUS-OS live stage')"
FLAVORS="$(grep -hoE 'known: [a-z0-9 ]+' "$REPO/bootchain/kexec/chainload-linux.sh" 2>/dev/null | head -1 | sed 's/^known: //')"
[ -n "$FLAVORS" ] || FLAVORS="arch ubuntu fedora debian cachyos nobara mint omarchy"

. /opt/nexus/lib/metro.sh
nx_init_palette
stty -echo 2>/dev/null || true

header() {
  printf '\033[40m\033[0m'
  printf '\033[4;10H' 2>/dev/null || true
  printf '\033[2J\033[H'
  printf '\033[%sm  %s\033[0m\n' "$C_WHT" "$REL"
  printf '\033[%sm  Mass Effect × Cyberpunk 2077 hybrid · one console, every OS\033[0m\n' "$C_SDIM"
  hex_lattice "$C_DIM"
}

footer() {
  printf '\n\033[%sm' "$C_DIM"
  printf '  ──────────────────────────────────────────────────────────────────\n'
  printf '\033[%sm  SAFE STAGE: boot actions DRY-RUN in QEMU · palette: docs/14\033[0m\n' "$C_SDIM"
  printf '\033[%sm  F18: T1+T2 operator runs APPROVED 2026-11-11 · T3 watch-only\033[0m\n' "$C_YEL"
  printf '\033[%sm  select [1-7] · [0] power off ▸ \033[0m' "$C_CYAN"
}

pause() {
  printf '\n\033[%sm  press any key for the hub ▸\033[0m' "$C_DIM"
  ser "hub: action done, waiting for key"
  read -rsn1
}

banner() {  # "$@" printed as a cyan panel head
  printf '\033[%sm  ┌── \033[%sm%s\033[%sm ' "$C_CYAN" "$C_SYEL" "$1" "$C_CYAN"
  printf '──────────────────────────────────────────\033[0m\n'
}

# ── 1 · SYSTEM STATUS ────────────────────────────────────────────────────────
do_status() {
  banner "SYSTEM STATUS"
  printf '\033[%sm  stage   : \033[%sm%s\033[0m\n' "$C_DIM" "$C_TXT" "$REL"
  printf '\033[%sm  kernel  : \033[%sm%s\033[0m\n' "$C_DIM" "$C_TXT" "$(uname -r)"
  printf '\033[%sm  cpu/mem : \033[%sm%s cpus · %s KiB MemTotal\033[0m\n' "$C_DIM" "$C_TXT" \
    "$(nproc)" "$(awk '/MemTotal/{print $3}' /proc/meminfo)"
  printf '\033[%sm  video   : \033[%sm%s\033[0m\n' "$C_DIM" "$C_TXT" \
    "$([ -c /dev/fb0 ] && echo "framebuffer $(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo '?')" || echo 'serial console only')"
  printf '\033[%sm  kexec   : \033[%sm%s\033[0m\n' "$C_DIM" "$C_TXT" \
    "$([ -e /sys/kernel/kexec_crash_loaded ] && echo 'crash-kexec capable' || echo 'not in this stage (QEMU demo)')"
  printf '\033[%sm  console : \033[%smNEXUS Metro palette (16 registers remapped, docs/14)\033[0m\n' "$C_DIM" "$C_TXT"
  echo ""
  banner "STATE REGISTRY (SM-01..SM-12)"
  if python3 "$REPO/tools/statecheck/statecheck.py" "$REPO/agents/state-machines.json" --repo-root "$REPO" 2>&1 | tail -4; then
    ser "hub: statecheck PASS (12 machines)"
  else
    printf '\033[%sm  statecheck reported problems — see log\033[0m\n' "$C_RED"
    ser "hub: statecheck FAIL"
  fi
  pause
}

# ── 2 · BOOT MANAGER ────────────────────────────────────────────────────────
do_boot() {
  banner "BOOT MANAGER — chains (docs/12 §2)"
  printf '  \033[%smM\033[0m macOS  \033[%smcrash-kexec → UefiPayload → OpenCore → XNU\033[0m   \033[%smPROVEN upstream\033[0m\n' \
    "$C_WHT" "$C_SDIM" "$C_MINT"
  printf '  \033[%smL\033[0m Linux  \033[%smdirect kexec, %s flavors\033[0m                      \033[%smREADY\033[0m\n' \
    "$C_WHT" "$C_SDIM" "$(wc -w <<< "$FLAVORS")" "$C_YEL"
  printf '  \033[%smW\033[0m Windows\033[%smUefiPayload → bootmgfw.efi\033[0m                       \033[%smRESEARCH\033[0m\n' \
    "$C_WHT" "$C_SDIM" "$C_RED"
  printf '\n  \033[%smL flavors: \033[%sm%s\033[0m\n' "$C_DIM" "$C_TXT" "$FLAVORS"
  echo ""
  banner "STAGE A BOOT INTENT (dry-run, SM-01)"
  printf '  \033[%smwrites /tmp/boot-select.json and replays the real\033[0m\n' "$C_SDIM"
  printf '  \033[%smnexus-boot-select.sh --dry-run contract. No disk writes.\033[0m\n' "$C_SDIM"
  echo ""
  printf '  \033[%sm[l]inux:<flavor> · [m]acos · [w]indows · [b]ack ▸ \033[0m' "$C_CYAN"
  read -rsn1 pick
  printf '\n'
  case "$pick" in
    m)
      printf '{"version":1,"target":"macos"}' > /tmp/boot-select.json
      sel="--select /tmp/boot-select.json"
      ;;
    w)
      printf '{"version":1,"target":"windows"}' > /tmp/boot-select.json
      sel="--select /tmp/boot-select.json"
      ;;
    l)
      printf '  \033[%smflavor [%s] ▸ \033[0m' "$C_CYAN" "$(echo "$FLAVORS" | cut -d' ' -f1)"
      read -rsn8 fl
      fl="$(printf '%s' "$fl" | tr -d ' ')"
      printf '\n'
      printf '{"version":1,"target":"linux","flavor":"%s"}' "$fl" > /tmp/boot-select.json
      sel="--select /tmp/boot-select.json"
      ;;
    *) printf '\033[%sm  back\033[0m\n' "$C_DIM"; sleep 1; return ;;
  esac
  echo ""
  if bash "$REPO/bootchain/kexec/nexus-boot-select.sh" --dry-run $sel 2>&1 | sed 's/^/  /'; then
    ser "hub: boot-select dry-run OK ($(cat /tmp/boot-select.json))"
  else
    ser "hub: boot-select dry-run REJECTED (intent contract worked)"
    printf '\033[%sm  intent rejected by the contract — that is the guard working.\033[0m\n' "$C_YEL"
  fi
  pause
}

# ── 3 · HARDWARE PROBES (F22, docs/13) ──────────────────────────────────────
do_probes() {
  banner "PLATFORM PROBES — read-only JSON evidence (F22)"
  bash "$REPO/tools/hwtest/probes/probe-platform.sh" all 2>&1 | sed 's/^/  /' | head -60
  ser "hub: probes all done (pci/framebuffer/interrupts/storage/network)"
  pause
}

# ── 4 · PERMISSION GATE (SM-06) ─────────────────────────────────────────────
do_gate() {
  banner "PERMISSION GATE — nested-OS isolation (default deny)"
  if [ -f /tmp/nexus-gate.up ]; then
    printf '  \033[%sm daemon  : \033[%smUP · 127.0.0.1:7421\033[0m\n' "$C_DIM" "$C_MINT"
    python3 - <<'PY' 2>/dev/null | sed 's/^/  /' | head -30
import json, urllib.request
try:
    pol = json.load(urllib.request.urlopen("http://127.0.0.1:7421/policy", timeout=3))
    print(f"default : {pol.get('default')}")
    for g, v in pol.get("guests", {}).items():
        print(f"guest   : {g:14s} allow={','.join(v.get('allow', []))}")
    log = urllib.request.urlopen("http://127.0.0.1:7421/log", timeout=3).read().decode()
    print(f"decisions logged: {len([l for l in log.splitlines() if l.strip()])}")
except Exception as e:
    print(f"(daemon query failed: {e})")
PY
  else
    printf '  \033[%sm daemon  : \033[%smDOWN (python runtime absent?)\033[0m\n' "$C_DIM" "$C_RED"
  fi
  printf '\n  \033[%smguests share NOTHING with the host unless policy allows —\033[0m\n' "$C_SDIM"
  printf '  \033[%smevery other request queues for explicit human approval.\033[0m\n' "$C_SDIM"
  pause
}

# ── 5 · IGNITION REPLAY ─────────────────────────────────────────────────────
do_ignition() {
  banner "IGNITION — replay (docs/14, 48 frames)"
  if [ -c /dev/fb0 ] && [ -x /usr/local/bin/nexfblit ] && [ -f /opt/nexus/anim/ignition.frb ]; then
    /opt/nexus/ascii-ignition.sh --dev /dev/ttyS0 2>/dev/null
    /usr/local/bin/nexfblit /opt/nexus/anim/ignition.frb --fps 10 --loop 1 >/dev/null 2>&1
    ser "hub: ignition replay (framebuffer) done"
  else
    /opt/nexus/ascii-ignition.sh 2>/dev/null
    ser "hub: ignition replay (ascii) done"
  fi
  pause
}

# ── 6 · NEXUS METRO THEME ───────────────────────────────────────────────────
do_theme() {
  banner "NEXUS METRO — Mass Effect × Cyberpunk 2077 (docs/14)"
  printf '  \033[%sm palette registers (live remap):\033[0m\n\n' "$C_DIM"
  printf '   \033[40m deep-space \033[0m  \033[41m n7-red     \033[0m  \033[42m mint       \033[0m  \033[43m cyber-yell \033[0m\n'
  printf '   \033[44m hub-blue   \033[0m  \033[45m relay-viol \033[0m  \033[46m relay-dim  \033[0m  \033[47m text       \033[0m\n'
  printf '   \033[100m slate-dim  \033[0m  \033[101m n7-bright  \033[0m  \033[102m mint-br    \033[0m  \033[103m yell-br    \033[0m\n'
  printf '   \033[104m blue-br    \033[0m  \033[105m viol-br    \033[0m  \033[106m \033[30mrelay-cyan \033[0m  \033[107m\033[30m white      \033[0m\n'
  echo ""
  printf '  \033[%sm motifs: relay ring · seven dies (FW 7.00→13.60) · glitch ticks\033[0m\n' "$C_SDIM"
  printf '  \033[%sm         hex lattice ≤5%% opacity · Metro zero-animation discipline\033[0m\n' "$C_SDIM"
  echo ""
  hex_lattice "$C_DIM"
  echo ""
  printf '  \033[%sm orbit nodes: \033[37m● macOS\033[0m \033[%sm\033[94m● Windows\033[0m \033[%sm\033[92m● Linux\033[0m\033[0m\n' "$C_DIM" "" ""
  printf '  \033[%sm delivery: Plymouth nexus-ignition · KSplash · SDDM · wallpapers ·\033[0m\n' "$C_SDIM"
  printf '  \033[%sm           Konsole · this console palette · IGNITION on boot\033[0m\n' "$C_SDIM"
  ser "hub: theme showcase shown (16 palette registers + motifs)"
  pause
}

# ── main loop ───────────────────────────────────────────────────────────────
while :; do
  clear
  header
  nexus_wordmark | sed 's/^/ /'
  printf '\033[%sm   %s\033[0m\n\n' "$C_SYEL" "ONE CONSOLE. EVERY OS."
  printf '  \033[%sm[1]\033[0m system status      \033[%sm[2]\033[0m boot manager      \033[%sm[3]\033[0m hw probes\n' "$C_CYAN" "$C_CYAN" "$C_CYAN"
  printf '  \033[%sm[4]\033[0m permission gate    \033[%sm[5]\033[0m ignition replay   \033[%sm[6]\033[0m metro theme\n' "$C_CYAN" "$C_CYAN" "$C_CYAN"
  printf '  \033[%sm[7]\033[0m shell              \033[%sm[0]\033[0m power off\n' "$C_CYAN" "$C_CYAN"
  footer
  read -rsn1 key
  printf '\033[2J\033[H'
  case "$key" in
    1) ser "hub: menu -> status";    do_status ;;
    2) ser "hub: menu -> boot";      do_boot ;;
    3) ser "hub: menu -> probes";    do_probes ;;
    4) ser "hub: menu -> gate";      do_gate ;;
    5) ser "hub: menu -> ignition";  do_ignition ;;
    6) ser "hub: menu -> theme";     do_theme ;;
    7) ser "hub: menu -> shell"
       printf '\033[2J\033[H\033[%sm NEXUS-OS live stage shell — exit to return to the hub\033[0m\n\n' "$C_DIM"
       sh < /dev/console > /dev/console 2>&1
       ser "hub: shell exit -> menu" ;;
    0) ser "hub: power off requested"
       printf '\033[2J\033[H\033[%sm NEXUS-OS stage down. Goodbye.\033[0m\n' "$C_CYAN"
       sleep 0.6
       exit 0 ;;
  esac
done
