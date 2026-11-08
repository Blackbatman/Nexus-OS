# Henge bridge — macOS guests beyond the desktop (RESEARCH)

`Leviidev/Henge` runs macOS on iOS/iPadOS devices (A14/M1, iOS/iPadOS 17+). The
NEXUS-OS idea: treat a Henge guest as **just another gate client** — the same
default-deny broker, the same approval UX as terminal-mac and the Windows guest.

## Proposed shape (not implemented yet — RESEARCH)

```
iOS/iPadOS device running Henge (macOS guest)
        │  HTTP over LAN (mTLS planned)
        ▼
gate-daemon (host)  ── policy.json gains a "henge-guest" entry
```

1. Add to `policy.json`:
   ```json
   "henge-guest": { "label": "Henge macOS (iOS/iPadOS)", "allow": ["~/nexus-workspace/henge/**"] }
   ```
2. Henge guest reaches the gate over the network; `gate-daemon.py` must gain a
   `--listen 0.0.0.0 --tls-cert …` mode before any LAN exposure (current build is
   localhost-only by design).
3. Voice/DIC commands from the PS5 side could approve gate requests from the couch
   (`gate approve` intent — already parsed by `tools/voice/voice_cmd.py`).

## Why it matters for the mission

The user's brief asks for terminal-launched OS environments that never step on
each other's work. Henge extends that boundary to handheld Apple hardware: your
macOS guest can live on an iPhone-class device while the PS5 runs the hub —
still behind the same gate.

## Status

RESEARCH. Blockers: Henge network-stack maturity, TLS mode for the daemon,
iOS background-execution limits. Owner: integration-builder.
