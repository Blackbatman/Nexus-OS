# DIC — DualSense Integrated Command Interface (voice for NEXUS-OS)

Voice control that never leaves the room: **whisper.cpp runs locally**, no cloud
speech. The DualSense's built-in microphone (recognized by the mainline
`hid-playstation` driver as a USB audio device) or any ALSA mic feeds it.

## Design

```
DualSense mic (hid-playstation, USB audio)
   → arecord (16 kHz mono wav, 4 s VAD-ish windows)
   → whisper.cpp (NEXUS_WHISPER + NEXUS_WHISPER_MODEL, ggml "small" is enough)
   → voice_cmd.py intent parser (deterministic, fuzz-tested)
   → action JSON  →  hub / gate-daemon / nexus-bootd
```

## Intent grammar (v1)

| Utterance | Action |
| --- | --- |
| "Nexus, boot Arch" / "Nexus boot linux mint" | `{"intent":"boot","target":"linux","flavor":"arch\|mint"}` |
| "Nexus, boot macOS" / "boot Windows" | chain M / chain W dispatch |
| "Nexus, power rest" | suspend (honest status: RESEARCH) |
| "Nexus, gate approve id 12" | permission-gate approval from the couch |
| "Nexus, status" | current staged target + last boot-log lines |

## Setup

```bash
# 1. whisper.cpp (offline)
git clone https://github.com/ggml-org/whisper.cpp && cd whisper.cpp
make whisper-cli && sh models/download-ggml-model.sh small.en
# 2. wire it
export NEXUS_WHISPER=$PWD/whisper-cli
export NEXUS_WHISPER_MODEL=$PWD/models/ggml-small.en.bin
# 3. prove the parser without any mic
python3 tools/voice/voice_cmd.py --selftest
```

## Safety properties

- The parser is **deterministic** — the beta team fuzzes it (empty input, 10 KB
  input, injection-shaped text like `boot arch; rm -rf /`); its output is a JSON
  action consumed by the hub, never a shell string.
- `power` intents always carry the honest note that clean power features are
  RESEARCH on this hardware.
- Wake word required ("Nexus …"); ambient chatter parses to `none`.

## On the PS5 (Linux stage)

DualSense audio is a UAC1 device on USB; the Linux stage's ALSA/PipeWire stack
picks it up like any headset mic. BT mic (NXP IW620) is blocked by the upstream
WiFi/BT driver gap — see `docs/04-hardware-support.md`.
