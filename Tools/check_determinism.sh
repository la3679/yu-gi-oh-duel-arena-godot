#!/usr/bin/env bash
# Cross-process determinism check (Linux / macOS / CI). The PowerShell twin is
# Tools/check_determinism.ps1; keep the two in step.
#
# Part of the backend acceptance gate (PROJECT_STATE.md §8, unit 3): runs
# Scripts/tests/DumpDuels.gd in two SEPARATE Godot processes and requires the per-duel digests
# to be identical. Same-process determinism is asserted inside ScriptedDuelTests; this proves a
# duel depends on nothing that differs between processes.
#
#   bash ./Tools/check_determinism.sh
#
# This script's exit code is authoritative: 0 = identical, 1 = anything else.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${TMPDIR:-/tmp}/duelarena-determinism"
mkdir -p "$OUT_DIR"

for i in 1 2; do
  if ! bash "$HERE/run_tests.sh" DumpDuels >"$OUT_DIR/run$i.txt" 2>&1; then
    echo "DETERMINISM: FAIL (process $i did not pass)"
    tail -20 "$OUT_DIR/run$i.txt"
    exit 1
  fi
  grep '^DUEL ' "$OUT_DIR/run$i.txt" >"$OUT_DIR/duels$i.txt"
  echo "process $i:"
  sed 's/^/  /' "$OUT_DIR/duels$i.txt"
done

COUNT="$(wc -l <"$OUT_DIR/duels1.txt")"
if [ "$COUNT" -eq 0 ]; then
  echo "DETERMINISM: FAIL (no duel lines were printed)"
  exit 1
fi
if ! diff -u "$OUT_DIR/duels1.txt" "$OUT_DIR/duels2.txt"; then
  echo "DETERMINISM: FAIL (the two processes disagree)"
  exit 1
fi
echo "DETERMINISM: PASS ($COUNT duels identical across two processes)"
exit 0
