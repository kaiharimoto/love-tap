#!/usr/bin/env bash
# ./run.sh — build and start the thing, on either phone.
#
#   ./run.sh --seed=year --transport=local              # the PWA, served, with the year in it
#   ./run.sh --seed=year --transport=local --on=android # the APK, installed on the emulator
#   ./run.sh --transport=tailscale --on=android         # an empty history over the tailnet
#
# The seed is a build-time flag, not a runtime switch: a build started without --seed=year has no
# seeded history compiled into it and no way to load one.
set -euo pipefail
cd "$(dirname "$0")"
. ./toolchain/env.sh

SEED=""
TRANSPORT="local"
ON="both"
ROLE=""
PERSON=""
PROFILE="default"
PORT="8480"
SERVE_PORT="8799"
CAPTURE="false"
FROZEN_NOW=""
BUILD="yes"
SERVE="yes"

for a in "$@"; do
  case "$a" in
    --seed=*) SEED="${a#*=}" ;;
    --transport=*) TRANSPORT="${a#*=}" ;;
    --on=*) ON="${a#*=}" ;;   # both (default), web, or android
    --role=*) ROLE="${a#*=}" ;;
    --person=*) PERSON="${a#*=}" ;;
    --profile=*) PROFILE="${a#*=}" ;;
    --port=*) PORT="${a#*=}" ;;
    --serve-port=*) SERVE_PORT="${a#*=}" ;;
    --frozen-now=*) FROZEN_NOW="${a#*=}" ;;
    --capture) CAPTURE="true" ;;
    --no-build) BUILD="no" ;;
    --no-serve) SERVE="no" ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "run.sh: don't know $a" >&2; exit 2 ;;
  esac
done

case "$TRANSPORT" in
  local) ;;
  tailscale)
    if [ ! -f app/lib/transport/tailscale/tailscale_transport.dart ]; then
      echo "run.sh: the tailscale transport is not built yet; use --transport=local" >&2
      exit 3
    fi ;;
  *) echo "run.sh: transport must be local or tailscale" >&2; exit 2 ;;
esac

DEFINES=(
  "--dart-define=SEED=$SEED"
  "--dart-define=TRANSPORT=$TRANSPORT"
  "--dart-define=PROFILE=$PROFILE"
  "--dart-define=PORT=$PORT"
  "--dart-define=CAPTURE=$CAPTURE"
  "--dart-define=FROZEN_NOW=$FROZEN_NOW"
)
[ -n "$ROLE" ] && DEFINES+=("--dart-define=ROLE=$ROLE")
[ -n "$PERSON" ] && DEFINES+=("--dart-define=PERSON=$PERSON")

# ---- the assets the build will carry ----------------------------------------------------------
# app/assets/ is generated: pack_assets.py reads assets/ (the renders) and writes the display-
# resolution set the app ships, copying the seed only when the seed was asked for.
if [ "$BUILD" = "yes" ]; then
  echo "· packing assets${SEED:+ with the $SEED seed}"
  python3 tools/pack_assets.py ${SEED:+--seed="$SEED"} >/dev/null
fi

case "$ON" in both|web|android) ;; *) echo "run.sh: --on must be both, web or android" >&2; exit 2 ;; esac

# ---- the Android phone: the host. It holds the log and serves the PWA's other end. --------------
if [ "$ON" = "both" ] || [ "$ON" = "android" ]; then
  if [ "$BUILD" = "yes" ]; then
    echo "· building the APK"
    (cd app && flutter build apk --debug "${DEFINES[@]}" --dart-define=ROLE=host --dart-define=PERSON=noor) \
      || exit 1
  fi
  if [ "$SERVE" = "yes" ]; then
    if adb shell true >/dev/null 2>&1; then
      echo "· installing into the AVD"
      adb install -r app/build/app/outputs/flutter-apk/app-debug.apk >/dev/null
      adb shell am start -n io.lovetap.desk/.MainActivity >/dev/null
      # the host binds inside the emulator; this is how the PWA in WebKit reaches it from here
      adb forward "tcp:$PORT" "tcp:$PORT" >/dev/null
      echo "· the emulator's host is reachable at http://127.0.0.1:$PORT/"
    else
      echo "· no Android device answered adb; the APK is built but not installed" >&2
      [ "$ON" = "android" ] && exit 5
    fi
  fi
fi

# ---- the iPhone: the client, the PWA the host serves --------------------------------------------
if [ "$ON" = "both" ] || [ "$ON" = "web" ]; then
  if [ "$BUILD" = "yes" ]; then
    echo "· building the PWA"
    # --no-web-resources-cdn: every byte the page loads comes out of this repo
    (cd app && flutter build web --release --no-web-resources-cdn "${DEFINES[@]}" \
       --dart-define=ROLE=client --dart-define=PERSON=teo) || exit 1
  fi
  if [ "$SERVE" = "yes" ]; then
    echo "· serving the PWA on http://127.0.0.1:$SERVE_PORT/"
    if [ "$ON" = "web" ]; then
      cd app/build/web && exec python3 -m http.server "$SERVE_PORT" --bind 127.0.0.1
    fi
    (cd app/build/web && python3 -m http.server "$SERVE_PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
    SERVER=$!
    trap 'kill "$SERVER" 2>/dev/null' EXIT
    sleep 2
    echo "· opening it in Playwright WebKit against the emulator's host"
    node tools/capture/shot.js --url "http://127.0.0.1:$SERVE_PORT/" --browser webkit \
      --out "${TMPDIR:-/tmp}/lovetap-run.png" --width 480 --height 1040 --dpr 3
    echo "· both ends are up. ctrl-c to stop the server."
    wait "$SERVER"
  fi
fi
