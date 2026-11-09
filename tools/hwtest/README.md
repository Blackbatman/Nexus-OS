# hwtest — F18 operator harness (hardware validation)

Operator-facing tools for `docs/12-hardware-validation.md`. All three tools
run offline, ship **no exploit code** (NOTICE.md §2), and only handle logs
you already captured.

| Tool | Runs where | Purpose |
| --- | --- | --- |
| `capture-ktty.sh` | PS5 Linux stage (or any Linux host) | package one attempt into `sessions/<HW-id>/` (ktty.log, boot-log.txt, meta.json, sha256sums) |
| `validate-logs.py` | anywhere with python3 | match the attempt against the docs/12 §5 checkpoint tables → PASS / PARTIAL / FAIL + docs/04 evidence line |
| `delta-report.py` | anywhere with python3 | fill/validate the hardware delta form → markdown rows for `docs/04-hardware-support.md` |

## One session, end to end

```bash
# on the console's Linux stage, after the boot attempt:
tools/hwtest/capture-ktty.sh --chain L --flavor mint --firmware 13.60 \
    --entry relapse --console "CFI-1015A launch model" --operator you

# anywhere:
python3 tools/hwtest/validate-logs.py --chain L \
    --ktty  sessions/<id>/ktty.log \
    --bootlog sessions/<id>/boot-log.txt \
    --meta  sessions/<id>/meta.json --out sessions/<id>/verdict.json

python3 tools/hwtest/delta-report.py --template sessions/<id>/delta.json
# …fill the form…
python3 tools/hwtest/delta-report.py --form sessions/<id>/delta.json --append-check
```

Every tool has a self-test that needs no hardware:

```bash
bash -n tools/hwtest/capture-ktty.sh
python3 tools/hwtest/validate-logs.py --selftest
python3 tools/hwtest/delta-report.py --selftest
```

Verdicts never edit `docs/04` themselves — the beta QA owner reviews the
raw session, then lands the row (docs/12 §6, docs/06 L6).
