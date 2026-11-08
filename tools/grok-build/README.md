# Grok Build as the alternate coding-agent runtime

`xai-org/grok-build` (the `grok` CLI/TUI, Rust, Apache-2.0) is a first-class
alternate runtime for this repo's harness — the whole agent system
(`CLAUDE.md`, `.claude/agents/`, `agents/feature_list.json`) is runtime-agnostic
markdown + JSON on purpose.

## Two ways to run it

1. **Directly** (grok reads `CLAUDE.md` the same way Claude Code does):
   ```bash
   grok            # in repo root
   > Read CLAUDE.md and follow the harness.
   ```

2. **Through craft-anything's ACP bridge** (the inspect→rebuild→compare loop):
   ```bash
   grok login                       # your own credentials; craft-anything never sees them
   craft-anything-cli setup         # select Grok Build as the coding agent
   craft-anything-cli doctor        # verifies the ACP wiring
   craft-anything-cli rebuild       # study→build→check loops against a target UI
   ```

## When to prefer which

| Task | Claude Code | Grok Build |
| --- | --- | --- |
| Harness sessions (feature_list loop) | default | equivalent |
| Long TUI sessions over SSH | fine | strong (full-screen TUI) |
| craft-anything rebuild loops | supported | supported (ACP) |

## Division of labor convention (this repo's default)

- **Claude Code** drives harness sessions by default (architect handoffs).
- **Grok Build** takes the beta team's stress sessions: one session per lens
  (functional / hostile-input / visual), same protocol, same reports — the two
  runtimes cross-check each other's fixes.
