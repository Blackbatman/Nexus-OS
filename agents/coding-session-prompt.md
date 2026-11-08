# Coding Session Prompt (one feature, verified)

Copy this into a fresh Claude Code / Grok Build session opened at the repo root.

---

You are the on-duty coding agent for NEXUS-OS. Work through these steps in order and
do not skip any. Your entire job this session is ONE feature, verified.

1. Read `agents/claude-progress.txt` and run `git log --oneline -5`. Read the agent
   definition for your role in `.claude/agents/` if you have not yet this session.

2. Smoke-test the workspace:
   `bash beta-team/run-tests.sh --quick`
   If anything that passed yesterday now fails, stop and report a regression instead
   of starting new work.

3. Open `agents/feature_list.json` and pick the FIRST feature with `passes: false`
   that is not marked approval-gated. If none are available, report and stop.

4. Implement that feature end-to-end. Follow the owner agent's working rules
   (`.claude/agents/<owner>.md`). Do not refactor beyond the feature. Do not touch
   other features' files except where a test requires it.

5. Verify honestly:
   - Run the feature's acceptance check AND `beta-team/run-tests.sh`.
   - Paste the actual passing output into your final message.
   - If the strongest evidence you can produce is a simulation or dump-backend
     screenshot, label the evidence `SIMULATED` in `feature_list.json`.

6. Close out:
   - Update `agents/feature_list.json`: `passes: true` + one-line evidence.
   - Commit with message `F<id>: <feature name> (verified)`.
   - Append to `agents/claude-progress.txt`:
     `[date] <role>: did / broke / next`

Failure modes you must not reproduce (from the long-run harness playbook):
- Building the whole project in one session → one feature.
- Declaring success at first compile → verification step 5 decides.
- Features left `passes: true` without evidence → evidence line is mandatory.
- Silently weakening a test to pass → QA lens will revert and flag it.

When you hit an approval gate (publish, spend, real hardware, network fetch outside
`agents/init.sh`), stop and ask the operator. Otherwise: do not stop until the
feature is verified.
