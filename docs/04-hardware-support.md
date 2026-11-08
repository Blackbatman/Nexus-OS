# 04 — Hardware Support Matrix (honest)

Sources: upstream `rodri0x/ps5-hackintosh` README (macOS chain), PS5 Linux
loader/kernel work, PS5GreenApple backend behavior. The **brief's mandatory
list** (audio, WiFi, power/restart/rest, visuals, Bluetooth, settings) is
answered exactly below — with today's truth, not with marketing.

| Component | PS5 Linux stage (B) | macOS chain M | Windows chain W | Verdict |
| --- | --- | --- | --- | --- |
| **Visuals/display** | Works (upstream GPU maturing; 4K HDMI reported) | 2560×1440 fixed, **no accel** (Cyan Skillfish RDNA1) | framebuffer only | **WORKS** (accel = roadmap) |
| **Audio** | PipeWire stack works; HDMI audio off on chain M | USB DAC/headset **works**; HDMI audio no | untested (RESEARCH) | **PARTIAL — works via USB; HDMI = research** |
| **Wi-Fi** | NXP IW620 no public driver | none | none | **NOT SOLVED** — Ethernet (Salina, ~25 MB/s) is the network path |
| **Bluetooth** | NXP IW620 combo chip — same gap | none | none | **NOT SOLVED** — USB BT dongle is the workaround (upstream roadmap) |
| **Input** | DualSense via `hid-playstation` + USB KB/M **works** | USB KB/M/trackpad works; DualSense HID = research | USB input expected | **WORKS** |
| **Power / restart / rest** | kexec reboots work in Linux; **clean FW return & rest mode unsolved upstream** | manual power-cycle | n/a | **RESEARCH** — honest labels in hub |
| **Storage** | NVMe (internal) + USB | internal SSD locked by upstream; USB SSD APFS works | USB-only | **WORKS** within policy |
| **Settings app** | Plasma settings on stage B | macOS System Preferences | Windows Settings | **WORKS** |
| **Voice (DIC)** | whisper.cpp local; DualSense USB mic | n/a (host) | n/a (host) | **WORKS** on stage B |

## What "mandatory audio/WiFi/BT/power" means in practice

1. **Audio works** today on the Linux stage (PipeWire + SOF/ALSA firmware) and
   on macOS chain M via USB audio. HDMI audio is the open research item.
2. **WiFi/BT do not work** on PS5 radios because the NXP IW612-class combo
   chip has no public driver on any chain. Nobody has solved this upstream.
   The honest product ships: Ethernet (proven), USB BT dongle path (upstream
   roadmap item #6), and keeps `wifi/bt: NOT SOLVED` on the tin until a kext
   or kernel driver lands. Promising otherwise would be the one lie this
   project refuses.
3. **Power/restart/rest**: restart works *within* the Linux stage; returning
   cleanly to the FW / rest-mode suspend is upstream-unsolved. The hub shows
   `RESEARCH` and the roadmap tracks it (upstream roadmap item #5).

## Maintenance rule

Any commit that changes this matrix must cite evidence: an upstream commit, a
ktty log, or a beta-team hardware report (`F18`). No matrix edits from vibes.
