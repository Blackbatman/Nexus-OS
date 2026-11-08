#!/usr/bin/env bash
# symbol-diff.sh — compare two builds of the same boot stage with radiff2.
# Catches silent drift: added/removed symbols, changed entry, size jumps.
# Usage: symbol-diff.sh <old.elf> <new.elf>
set -euo pipefail

OLD="${1:?usage: symbol-diff.sh <old> <new>}"
NEW="${2:?usage: symbol-diff.sh <old> <new>}"
[ -f "$OLD" ] || { echo "not found: $OLD" >&2; exit 1; }
[ -f "$NEW" ] || { echo "not found: $NEW" >&2; exit 1; }
command -v radiff2 >/dev/null 2>&1 || { echo "radiff2 (radare2) not installed" >&2; exit 1; }

echo "# symbol/build diff: $(basename "$OLD") vs $(basename "$NEW")"
echo "- sha old: $(sha256sum "$OLD" | cut -d' ' -f1)"
echo "- sha new: $(sha256sum "$NEW" | cut -d' ' -f1)"
echo "- size   : $(stat -c%s "$OLD") -> $(stat -c%s "$NEW")"
echo
echo "## radiff2 -A (function-level symmetry)"
radiff2 -A "$OLD" "$NEW" 2>/dev/null | awk '
  /diffs:/ {print "SUMMARY " $0}
  /^+|added/ {added++} /^-|removed/ {removed++}
  {print}
  END {print "added-lines:", added+0, "removed-lines:", removed+0}'
echo
echo "verdict guidance: identical size + empty diff = identical build; any
unexpected symbol addition in a boot stage -> reverse-engineer agent, immediately."
