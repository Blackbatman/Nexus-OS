# Install guide — disc media (the honest one)

You asked for disc burning support. Here is exactly what is true:

## What discs CAN do

- **PC-hosted installs**: `NEXUS-OS.iso` (Linux flavor) and `NEXUS-Windows.iso`
  are standard hybrid ISOs — burn and boot on any PC:
  ```bash
  # Linux
  growisofs -dvd-compat -Z /dev/sr0=NEXUS-OS.iso
  # or: xorriso -as mkisofs is already applied; use brasero/k3b/Xfburn too
  # macOS
  hdiutil burn NEXUS-OS.iso
  ```
- **Archival**: both ISOs verify bit-perfect from disc with
  `cmp <(dd if=/dev/sr0 bs=1M count=$(stat -c%s NEXUS-OS.iso))` style checks.
- **BD-R for the PS5 stage**: a BD-R written from `disc` layout is a convenient
  *transfer medium* — read it on a PC and copy to the PS5 boot USB.

## What discs CANNOT do (hardware truth)

**A PS5 optical drive will not boot burned discs.** The drive authenticates
pressed media against the console's secure boot path; a burned disc — of any
OS — is not a boot medium for the console. Any project claiming otherwise is
selling you something. The PS5 boots NEXUS chains via the jailbreak entry →
`elfldr` (network) → USB stage chain, per `usb.md` and `ftp.md`.

So: discs are first-class for the **macOS/Intel, Windows-PC, and Linux-PC
versions** of the project (live USB + disc), and a transfer convenience for the
PS5 — and this guide says so plainly rather than pretending.
