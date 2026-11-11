#!/usr/bin/env bash
# build.sh — NEXUS-OS artifact builds with honest degradation.
#   ./build.sh ps5          # PS5 .elf (requires ps5-payload-sdk)
#   ./build.sh syntax       # host syntax gate (always available)
#   ./build.sh iso          # Linux live ISO (requires archiso on an Arch host)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '\033[1;35m[nexus-build]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[nexus-build] FAIL\033[0m %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  ps5)
    if [ -z "${PS5_PAYLOAD_SDK:-}" ] || [ ! -x "${PS5_PAYLOAD_SDK}/bin/clang" ]; then
      say "ps5-payload-sdk not found — installing is a network fetch (APPROVAL GATE):"
      say "  git clone https://github.com/ps5-payload-dev/sdk && cd sdk && make install"
      say "  export PS5_PAYLOAD_SDK=\$PWD/ps5-payload-sdk"
      exit 2
    fi
    make -C "$HERE/ps5-elf" ps5
    say "built: $HERE/ps5-elf/build/nexus_boot.elf"
    say "deploy: see packaging/install-guides/ftp.md (elfldr :9021 · ftpsrv :2121)"
    ;;
  syntax)
    make -C "$HERE/ps5-elf" host-syntax
    ;;
  iso)
    command -v mkarchiso >/dev/null 2>&1 || die "mkarchiso not found — build the ISO on an Arch host with archiso installed"
    bash "$HERE/linux-iso/build-iso.sh"
    ;;
  iso-qemu)
    # F24 QEMU live stage — unprivileged build, QEMU-verified (docs/16)
    bash "$HERE/iso/build-iso.sh" --smoke
    ;;
  iso-deps)
    # forward everything after the subcommand ("$@" leaked "iso-deps" itself)
    bash "$HERE/iso/fetch-deps.sh" "${@:2}"
    ;;
  *) die "usage: build.sh ps5|syntax|iso|iso-qemu|iso-deps [--qemu]" ;;
esac
