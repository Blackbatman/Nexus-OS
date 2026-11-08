#!/usr/bin/env bash
# run-tests.sh — NEXUS-OS beta-team test harness (L0-L4 of docs/06-testing-plan.md).
#   --quick   L0+L1 only (syntax + selftests) — used by agents/init.sh smoke
# Full run adds behavior (dry-runs), data validation, demo checks, placeholder sweep.
# Exit code: 0 = all pass, 1 = failures (see printed table; beta QA writes the report).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

PASS=0 FAIL=0 SKIP=0
declare -a ROWS=()
row() { ROWS+=("$1"); if [[ "$1" == PASS* ]]; then PASS=$((PASS+1)); elif [[ "$1" == FAIL* ]]; then FAIL=$((FAIL+1)); else SKIP=$((SKIP+1)); fi; }

chk() { # chk <name> <command...>
  local name="$1"; shift
  if "$@" >/tmp/nexus-test-out.txt 2>&1; then
    row "PASS  $name"
  else
    row "FAIL  $name  — $(tail -2 /tmp/nexus-test-out.txt | tr '\n' ' ' | cut -c1-160)"
  fi
}
skip() { row "SKIP  $1  — $2"; }

# ---------------------------------------------------------------- L0 syntax
for sh in $(git ls-files 2>/dev/null | grep '\.sh$' || rg --files -g '*.sh' | sort); do
  chk "bash -n ${sh#$ROOT/}" bash -n "$sh"
done

for py in $(rg --files -g '*.py' 2>/dev/null | sort); do
  chk "py_compile ${py#$ROOT/}" python3 -m py_compile "$py"
done

# ---------------------------------------------------------------- L1 selftest
chk "madt_fake.py --selftest" python3 bootchain/acpi/madt_fake.py --selftest
chk "gate-daemon.py --selftest" python3 nested-os/permission-gate/gate-daemon.py --selftest
chk "voice_cmd.py --selftest" python3 tools/voice/voice_cmd.py --selftest
chk "statecheck.py --selftest" python3 tools/statecheck/statecheck.py --selftest
chk "state-machine registry valid" python3 tools/statecheck/statecheck.py agents/state-machines.json --repo-root .

if [ "$QUICK" = "1" ]; then
  printf '%s\n' "${ROWS[@]}"
  echo "────────────────────────────────────────────"
  echo "QUICK: $PASS passed, $FAIL failed, $SKIP skipped"
  [ "$FAIL" -eq 0 ]
  exit $?
fi

# ---------------------------------------------------------------- L2 behavior
TD="$(mktemp -d)"
printf '{"version":1,"target":"linux","flavor":"arch"}' > "$TD/select-linux.json"
printf '{"version":1,"target":"macos"}' > "$TD/select-macos.json"
printf '{"version":1,"target":"jailbreak-ps6"}' > "$TD/select-bad.json"
printf 'not json' > "$TD/select-corrupt.json"

chk "chain L dry-run (arch)"          bash bootchain/kexec/chainload-linux.sh --flavor arch --dry-run
chk "chain L dry-run (unknown flavor rejected)" bash -c '! bash bootchain/kexec/chainload-linux.sh --flavor windows95 --dry-run 2>/dev/null'
chk "chain M dry-run (safe, no confirm needed)" bash bootchain/kexec/chainload-macos.sh --dry-run
chk "chain M real-run guard (refuses without confirm)" bash -c '! bash bootchain/kexec/chainload-macos.sh 2>/dev/null'
chk "chain W dry-run"                 bash bootchain/kexec/chainload-windows.sh --dry-run
chk "selector dry-run (linux:arch)"   bash bootchain/kexec/nexus-boot-select.sh --dry-run --select "$TD/select-linux.json"
chk "selector dry-run (macos)"        bash bootchain/kexec/nexus-boot-select.sh --dry-run --select "$TD/select-macos.json"
chk "selector rejects unknown target" bash -c '! bash bootchain/kexec/nexus-boot-select.sh --dry-run --select "'"$TD"'/select-bad.json" 2>/dev/null'
chk "selector rejects corrupt JSON"   bash -c '! bash bootchain/kexec/nexus-boot-select.sh --dry-run --select "'"$TD"'/select-corrupt.json" 2>/dev/null'
chk "MADT generation + checksum reparse" python3 bootchain/acpi/madt_fake.py --cores 8 --threads 2 --out "$TD/madt.bin" && python3 -c "
import sys; sys.path.insert(0,'bootchain/acpi')
from madt_fake import parse_and_verify
info = parse_and_verify(open('$TD/madt.bin','rb').read())
assert info['entry_counts'][0] == 16 and info['checksum']=='OK', info
print('madt ok', info['entry_counts'])"
chk "voice intent: boot linux mint"   python3 tools/voice/voice_cmd.py --text "nexus boot linux mint"
rm -rf "$TD"

# ---------------------------------------------------------------- L3 data
for j in $(rg --files -g '*.json' 2>/dev/null | sort); do
  chk "json valid ${j#$ROOT/}" python3 -c "import json,sys; json.load(open('$j'))"
done
chk "colorscheme sanity" python3 -c "
import configparser
cp = configparser.ConfigParser(); cp.read('nexus-hub/plasma/NEXUSMetro.colors')
assert cp['General']['Name'] == 'NEXUS Metro'
assert '53,224,255' in cp['Colors:Selection']['BackgroundNormal']
print('colorscheme ok')"
chk "gate policy default-deny enforced" python3 -c "
import json
p = json.load(open('nested-os/permission-gate/policy.json'))
assert p['default'] == 'deny' and 'terminal-mac' in p['guests']
print('policy ok')"

# ------------------------------------------------------------- L4 demo checks
DEMO="nexus-hub/web-demo/index.html"
if [ -f "$DEMO" ]; then
  chk "demo HTML parses" python3 -c "
from html.parser import HTMLParser
p = HTMLParser(); p.feed(open('$DEMO').read()); print('demo parse ok')"
  [ "$(stat -c%s "$DEMO")" -gt 15000 ] && row "PASS  demo size > 15KB ($(stat -c%s "$DEMO") bytes)" || row "FAIL  demo size > 15KB"
  chk "demo JS extracted parses (node --check)" bash -c "
    node -e '
      const html = require(\"fs\").readFileSync(\"$DEMO\", \"utf8\");
      const scripts = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
      const body = scripts.join(\";\n\");
      if (!body.trim()) { console.log(\"no inline js\"); process.exit(0); }
      require(\"fs\").writeFileSync(\"/tmp/nexus-demo.js\", body);
    ' && node --check /tmp/nexus-demo.js && echo 'demo js ok'"
else
  skip "demo checks" "web-demo/index.html missing"
fi

# ------------------------------------------------------------- placeholder sweep
SWEEP=$(rg -n --no-heading -g '!third_party/**' -g '!*.png' -g '!backstop_data/**' \
  -e 'TODO[:)]' -e 'lorem' -e '【' -e '\bTBD\b' . 2>/dev/null | rg -v 'run-tests.sh' || true)
if [ -z "$SWEEP" ]; then
  row "PASS  placeholder sweep (no TODO:/TBD/lorem/【】 markers)"
else
  row "FAIL  placeholder sweep found: $(echo "$SWEEP" | head -3 | tr '\n' ' ' | cut -c1-140)"
fi

# ---------------------------------------------------------------- C syntax
if command -v gcc >/dev/null 2>&1; then
  chk "nexus_boot.c host syntax" gcc -fsyntax-only -DNEXUS_NO_SDL -Wall -Wextra packaging/ps5-elf/nexus_boot.c
else
  skip "nexus_boot.c host syntax" "gcc absent"
fi

# --------------------------------------------- F17 greapple-v2 (third_party)
# Real code patches to third_party/PS5GreenApple (nexus-hub/greapple-v2 spec).
# All clone-dependent checks SKIP cleanly when agents/init.sh has not run.
chk "greapple patch file present" test -s patches/PS5GreenApple/greapple-v2.1.patch
GA="$ROOT/third_party/PS5GreenApple"
if [ -d "$GA/.git" ]; then
  chk "greapple: patch applies to fresh clone" bash -c "
    set -e; T=\$(mktemp -d)
    git clone --quiet --depth 1 '$GA' \"\$T/ga\" 2>/dev/null
    git -C \"\$T/ga\" apply --check '$ROOT/patches/PS5GreenApple/greapple-v2.1.patch'
    rm -rf \"\$T\""
  chk "greapple: host build (make host)" make -C "$GA" host
  chk "greapple: nexus_boot unit tests (F17 definition of done)" make -C "$GA" nexus-unit
  chk "greapple: shots pipeline + 3 new PNGs" bash -c "
    set -e; make -C '$GA' shots >/dev/null 2>&1
    for p in nexus-stage-ok nexus-stage-fail bootcamp-volumes; do
      [ -f '$GA/shots/'\"\$p\"'.png' ] || { echo \"missing \$p.png\"; exit 1; }
    done
    echo '3 new PNGs present'"
  chk "greapple: hub-written intent accepted by the NEXUS reader" \
      bash bootchain/kexec/nexus-boot-select.sh --dry-run --select "$GA/data/NEXUS/boot-select.json"
else
  skip "F17 greapple checks (build/unit/shots/reader)" "third_party/PS5GreenApple not cloned (run agents/init.sh)"
fi

# ---------------------------------------------------------------- summary
printf '%s\n' "${ROWS[@]}"
echo "────────────────────────────────────────────"
echo "TOTAL: $PASS passed, $FAIL failed, $SKIP skipped"
[ "$FAIL" -eq 0 ]
