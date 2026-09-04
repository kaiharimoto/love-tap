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
ON="web"
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
    --on=*) ON="${a#*=}" ;;
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

case "$ON" in
  web)
    if [ "$BUILD" = "yes" ]; then
      echo "· building the PWA"
      # --no-web-resources-cdn: every byte the page loads comes out of this repo
      (cd app && flutter build web --release --no-web-resources-cdn "${DEFINES[@]}")
    fi
    if [ "$SERVE" = "yes" ]; then
      echo "· serving on http://127.0.0.1:$SERVE_PORT/"
      cd app/build/web && exec python3 -m http.server "$SERVE_PORT" --bind 127.0.0.1
    fi
    ;;
  android)
    if [ "$BUILD" = "yes" ]; then
      echo "· building the APK"
      (cd app && flutter build apk --debug "${DEFINES[@]}")
    fi
    if [ "$SERVE" = "yes" ]; then
      adb wait-for-device
      adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
      adb shell am start -n io.lovetap.desk/.MainActivity
      echo "· running on the emulator; adb forward tcp:$PORT tcp:$PORT to reach its host"
    fi
    ;;
  *) echo "run.sh: --on must be web or android" >&2; exit 2 ;;
esac
