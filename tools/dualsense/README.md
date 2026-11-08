# DualSense input map — NEXUS-OS

The DualSense is the primary NEXUS input (mouse + keyboard remain first-class).
Three surfaces consume it:

## 1. PS5GreenApple v2 hub (FW userland · SDL2)

Already upstream: full DualSense mapping, D-pad focus cursor with animated
selection ring, on-screen keyboard (OSK). NEXUS v2 adds:

| Input | Action |
| --- | --- |
| Cross | confirm staged boot (writes boot-select.json) |
| Circle | back / cancel staging |
| L1+R1 | open power menu (honest: restart/rest = RESEARCH) |
| Share | push-to-talk → DIC voice (`tools/voice/`) |
| Options | open Boot Camp volumes |

## 2. NEXUS Linux stage (Plasma session)

- Mainline `hid-playstation` (kernel ≥ 5.12): touchpad = pointer, rumble works.
- Controller-first Plasma navigation: dock icons-only task manager gives one
  press = one app; `plasma-navigator`-style D-pad navigation via accessibility
  settings (documented, not scripted — Plasma upgrades change the UI paths).

## 3. Nested guests

- terminal-mac guest: keyboard/mouse bridged by Apple Virtualization; DualSense
  is host-side only (gamepad HID passthrough is not provided by the framework —
  noted honestly, not faked).
- Windows guest: DualSense works as a standard USB HID gamepad inside QEMU when
  passed through with `-device usb-host`; audio via the ich9-hda device already
  in `run-windows-guest.sh`.

## Voice

Share button → push-to-talk → DIC grammar (`tools/voice/nexus-voice.md`).
