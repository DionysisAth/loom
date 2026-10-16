#!/usr/bin/env bash
# Runs headless Godot with a timeout and fails on script errors, which Godot
# otherwise only prints (a script error in a --script run can also hang it).
set -uo pipefail

LOG="$(mktemp)"
timeout "${GODOT_TIMEOUT:-600}" godot --headless --path . "$@" 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
if [ "$STATUS" -eq 124 ]; then
  echo "::error::Godot timed out"
fi
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script" "$LOG"; then
  echo "::error::Godot reported script errors"
  STATUS=1
fi
rm -f "$LOG"
exit "$STATUS"
