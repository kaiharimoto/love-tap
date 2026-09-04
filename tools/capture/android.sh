#!/usr/bin/env bash
# tools/capture/android.sh — the artifacts that can only come off the Android phone.
#
# Called by capture.sh when a device answers adb. Everything here is a screenshot or a screen
# recording taken off the device itself; nothing is composed from the PWA captures.
#
#   16_setup_android.png   the first-run checklist on a fresh install
#   frames.json scroll      real scroll frame timings, read out of the framework's own gfxinfo
#   09_two_devices.png      the AVD window and the WebKit window in one frame off one display
#   08_state_propagating    one phone changing state and the other one showing it
set -uo pipefail
cd "$(dirname "$0")/../.."
. ./toolchain/env.sh

SEEDED_URL="${1:-http://127.0.0.1:8799/}"
FRESH_URL="${2:-http://127.0.0.1:8798/}"
PKG="io.lovetap.desk"
LOGS="evidence/logs"
SCRATCH="${TMPDIR:-/tmp}/lovetap-capture"
mkdir -p "$LOGS" "$SCRATCH"
missing() { echo "$1|$2" >> "$SCRATCH/missing.txt"; echo "  ✗ $1 — $2"; }

adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 5; done

# ---- 16_setup_android.png: the fresh install, first run -------------------------------------------
if [ -f "$SCRATCH/app-fresh.apk" ]; then
  adb uninstall "$PKG" >/dev/null 2>&1
  adb install -r "$SCRATCH/app-fresh.apk" >/dev/null || missing "16_setup_android.png" "the fresh APK would not install"
  adb shell am start -n "$PKG/.MainActivity" >/dev/null
  sleep 12
  adb exec-out screencap -p > evidence/16_setup_android.png 2>/dev/null
  [ -s evidence/16_setup_android.png ] || missing "16_setup_android.png" "screencap came back empty"
else
  missing "16_setup_android.png" "no fresh APK was built this session"
fi

# ---- scroll frame timings, off the device ---------------------------------------------------------
if [ -f "$SCRATCH/app-seeded.apk" ]; then
  adb uninstall "$PKG" >/dev/null 2>&1
  adb install -r "$SCRATCH/app-seeded.apk" >/dev/null
  adb shell am start -n "$PKG/.MainActivity" >/dev/null
  sleep 20
  adb shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1
  # a thumb dragging the thread, four times
  for _ in 1 2 3 4; do
    adb shell input swipe 540 2400 540 700 320
    sleep 1
  done
  adb shell dumpsys gfxinfo "$PKG" framestats > "$SCRATCH/gfxinfo.txt" 2>/dev/null
  python3 tools/capture/gfxinfo.py "$SCRATCH/gfxinfo.txt" --out "$LOGS/scroll_emulator.json" >/dev/null \
    || missing "frames.json" "gfxinfo held no frame statistics"
else
  missing "frames.json" "no seeded APK was built this session"
fi

# ---- 09 and 08 need both phones side by side on one display ----------------------------------------
missing "09_two_devices.png" "the emulator ran headless in this session; the two-window frame needs both windows on one X display"
missing "08_state_propagating.mp4" "needs both phones running at once; the emulator ran headless in this session"
