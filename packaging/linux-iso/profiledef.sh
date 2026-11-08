#!/usr/bin/env bash
# profiledef.sh — mkarchiso profile for the NEXUS-OS Linux live flavor.
# Build (on an Arch host): packaging/build.sh iso
iso_name="nexus-os"
iso_label="NEXUSOS_$(date -u +%Y%m)"
iso_publisher="NEXUS-OS <https://github.com/>"
iso_application="NEXUS-OS Live — Plasma (NEXUS Metro) / boot orchestrator"
iso_version="0.2.0"
install_dir="nexus"
bootmodes=('bios.syslinux' 'uefi-x64.systemd-boot.esp' 'uefi-x64.grub.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap="x86_64"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
)
