#!/usr/bin/env bash
# Installs the APK on the running emulator, launches it, and checks that it
# boots to the main menu and does not crash. Then taps around randomly with
# monkey and checks again.
# Usage: emulator_smoke.sh <apk> [output dir]
set -euo pipefail

APK="$1"
OUT="${2:-emulator-results}"
PKG="${PACKAGE:-com.dionysisath.loom}"
BOOT_MARKER="LOOM_BOOT_OK"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-120}"
mkdir -p "$OUT"

dump_logs() {
  adb logcat -d > "$OUT/logcat.txt" 2>/dev/null || true
  adb logcat -d -b crash > "$OUT/crash-buffer.txt" 2>/dev/null || true
}

# Fails if our app crashed (Java or native), froze, or hit a GDScript error.
crash_check() {
  dump_logs
  local found=0
  if grep -q "$PKG" "$OUT/crash-buffer.txt"; then
    echo "::error::$PKG crashed during $1"
    cat "$OUT/crash-buffer.txt"
    found=1
  fi
  if grep -qE "ANR in $PKG" "$OUT/logcat.txt"; then
    echo "::error::$PKG stopped responding during $1"
    grep -A 10 "ANR in $PKG" "$OUT/logcat.txt" | head -40
    found=1
  fi
  if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$OUT/logcat.txt"; then
    echo "::error::Godot script error during $1"
    grep -A 6 -E "SCRIPT ERROR|Parse Error|Failed to load script" "$OUT/logcat.txt" | head -60
    found=1
  fi
  return "$found"
}

alive_check() {
  if ! adb shell pidof "$PKG" > /dev/null 2>&1; then
    echo "::error::$PKG is not running after $1"
    dump_logs
    tail -100 "$OUT/logcat.txt"
    return 1
  fi
  echo "$PKG is running after $1 (pid $(adb shell pidof "$PKG" | tr -d '\r'))"
}

screenshot() {
  adb exec-out screencap -p > "$OUT/$1.png" 2>/dev/null || true
}

adb wait-for-device
echo "Android API $(adb shell getprop ro.build.version.sdk | tr -d '\r'), ABI $(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
adb install -r -g "$APK"
adb logcat -c
adb logcat -c -b crash || true

# Start the launcher activity directly. (`monkey -p PKG 1` also sends one
# random event, which can be Back and close the app before it boots.)
ACTIVITY="$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" | tr -d '\r' | tail -1)"
case "$ACTIVITY" in
  "$PKG"/*) ;;
  *) echo "::error::Could not find the launcher activity of $PKG (got: $ACTIVITY)"; exit 1 ;;
esac
echo "Launching $ACTIVITY"
START=$(date +%s)
adb shell am start -W -n "$ACTIVITY" -a android.intent.action.MAIN -c android.intent.category.LAUNCHER

booted=0
for _ in $(seq 1 "$BOOT_TIMEOUT"); do
  dump_logs
  if grep -q "$BOOT_MARKER" "$OUT/logcat.txt"; then
    booted=1
    break
  fi
  if grep -q "$PKG" "$OUT/crash-buffer.txt"; then
    break
  fi
  sleep 1
done
grep -E "Godot Engine|OpenGL API|$BOOT_MARKER" "$OUT/logcat.txt" || true
if [ "$booted" -ne 1 ]; then
  screenshot startup-failed
  echo "::error::App did not reach the main menu within ${BOOT_TIMEOUT}s"
  crash_check "startup" || true
  tail -150 "$OUT/logcat.txt"
  exit 1
fi
echo "Main menu up after $(( $(date +%s) - START ))s"

# Stay on screen a while: crashes right after startup show up here.
sleep 15
alive_check "startup"
crash_check "startup"
adb shell dumpsys window > "$OUT/window.txt" 2>/dev/null || true
if ! grep -E "mCurrentFocus|mFocusedApp" "$OUT/window.txt" | grep -q "$PKG"; then
  echo "::error::$PKG is not in the foreground"
  grep -E "mCurrentFocus|mFocusedApp" "$OUT/window.txt" || true
  exit 1
fi
screenshot startup

# Random taps and swipes through menus and levels. No system keys, app
# switching or "major nav" keys: those include Back, and Back on the main menu
# quits the app on purpose, which would look like a crash.
echo "Running monkey"
adb shell monkey -p "$PKG" --pct-syskeys 0 --pct-appswitch 0 --pct-anyevent 0 --pct-majornav 0 \
  --throttle 120 -s 42 -v 600 > "$OUT/monkey.txt" 2>&1 || true
tail -5 "$OUT/monkey.txt"
if grep -qE "// CRASH|// NOT RESPONDING|Monkey aborted" "$OUT/monkey.txt"; then
  echo "::error::monkey found a crash"
  grep -A 30 -E "// CRASH|// NOT RESPONDING" "$OUT/monkey.txt" | head -60 || true
  exit 1
fi
sleep 3
screenshot after-monkey
crash_check "monkey"
alive_check "monkey"
echo "Emulator smoke test passed"
