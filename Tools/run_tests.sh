#!/usr/bin/env bash
# Headless test runner (Linux / macOS / CI). The PowerShell twin is Tools/run_tests.ps1;
# keep the two in step.
#
# Same two hazards it guards against as the PowerShell version:
#
#  1. Godot writes a lot to stderr (every push_error prints a full GDScript backtrace) and
#     the Godot binary does not return a usable exit code for a --script run, so success is
#     decided by the "RESULT:"/"SMOKE CHECK:" line the suite prints, not by $?.
#  2. A suite that fails to COMPILE makes RunTests._initialize() throw before it can call
#     quit(), leaving the headless SceneTree running forever. The parse check runs first so
#     a compile error is a readable failure instead of a hang, and `timeout` bounds the run.
#
# THIS script's exit code is authoritative: 0 pass, 1 fail. CI depends on that.
#
#   ./Tools/run_tests.sh              # full suite
#   ./Tools/run_tests.sh SmokeCheck   # a different entry script
#   ./Tools/run_tests.sh --import     # refresh the class cache, run nothing
#
# Godot is located via $GODOT_BIN, then $GODOT, then godot/godot4 on PATH.

set -uo pipefail

SCRIPT_NAME="${1:-RunTests}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GODOT="${GODOT_BIN:-${GODOT:-}}"
if [ -z "$GODOT" ]; then
  for candidate in godot godot4; do
    if command -v "$candidate" >/dev/null 2>&1; then GODOT="$(command -v "$candidate")"; break; fi
  done
fi
if [ -z "$GODOT" ]; then
  echo "----- GODOT NOT FOUND -----"
  echo "Install Godot 4.7.x, then put it on PATH or set GODOT_BIN."
  exit 1
fi

OUT_DIR="${TMPDIR:-/tmp}/duelarena-tests"
mkdir -p "$OUT_DIR"

echo "Godot:   $GODOT"
echo "Project: $PROJECT"

run_godot() {  # run_godot <tag> <timeout> <extra args...>
  local tag="$1"; shift
  local limit="$1"; shift
  local out="$OUT_DIR/$SCRIPT_NAME.$tag.out.txt"
  local err="$OUT_DIR/$SCRIPT_NAME.$tag.err.txt"
  timeout "$limit" "$GODOT" --headless --path "$PROJECT" "$@" >"$out" 2>"$err"
  local rc=$?
  RUN_OUT="$out"; RUN_ERR="$err"; RUN_RC=$rc
  RUN_TEXT="$(cat "$out" 2>/dev/null)
$(cat "$err" 2>/dev/null)"
  return 0
}

# --- 0. optional import pass ------------------------------------------------
# Godot only registers a new `class_name` after an import pass, and the parse check below
# reads that class cache. Run this as its OWN invocation after adding a new class.
if [ "$SCRIPT_NAME" = "--import" ]; then
  run_godot "import" 300 --import
  echo "IMPORT: done"
  exit 0
fi

# --- 1. parse check ---------------------------------------------------------
run_godot "check" 180 --check-only --script "res://Scripts/tests/$SCRIPT_NAME.gd"
if printf '%s' "$RUN_TEXT" | grep -Eq "Parse Error|Compile Error|Failed to (load|compile)"; then
  echo "----- PARSE CHECK FAILED -----"
  printf '%s' "$RUN_TEXT" | grep -E "Parse Error|Compile Error|Failed to (load|compile)"
  exit 1
fi

# --- 2. the run -------------------------------------------------------------
run_godot "run" "$TIMEOUT_SECONDS" --script "res://Scripts/tests/$SCRIPT_NAME.gd"
RUN_TIMED_OUT=$RUN_RC

echo "----- stdout -----"
cat "$RUN_OUT" 2>/dev/null
if [ -s "$RUN_ERR" ]; then
  echo "----- stderr ($(wc -l < "$RUN_ERR") lines, first 40) -----"
  head -40 "$RUN_ERR"
fi

# `timeout` exits 124 when it had to kill the run. That is a failure even if a PASS line
# was printed before the hang.
if [ "$RUN_TIMED_OUT" -eq 124 ]; then
  echo "RUNNER: FAIL (timeout after ${TIMEOUT_SECONDS}s)"
  exit 1
fi

if printf '%s' "$RUN_TEXT" | grep -Eq "RESULT:[[:space:]]*PASS|SMOKE CHECK:[[:space:]]*PASS"; then
  echo "RUNNER: PASS"
  exit 0
fi
echo "RUNNER: FAIL"
exit 1
