#!/usr/bin/env bash
# ./capture.sh — regenerate the evidence set from the running app.
#
#   ./capture.sh                 # everything this session can reach
#   ./capture.sh --only=02_chat  # one scene
#   ./capture.sh --no-build      # against the builds already on disk
#
# Nothing here composes, retouches, or upscales. Every still is a screenshot of the app running in
# Playwright WebKit (the engine on the iPhone) or of the app running on the emulator, taken through
# adb; every clip is a directory of single frames taken with the app's own clock stepped between
# them, then assembled by ffmpeg without re-encoding the pixels. What cannot be captured this
# session is written down as missing, with the reason, rather than faked or skipped quietly.
set -uo pipefail
cd "$(dirname "$0")"
. ./toolchain/env.sh

BROWSER="webkit"
BUILD="yes"
ONLY=""
SEEDED_PORT=8799
FRESH_PORT=8798
DUSK_PORT=8797
FROZEN_NOW="2026-09-03T19:40:00Z"
SCRATCH="${TMPDIR:-/tmp}/lovetap-capture"
LOG="evidence/logs"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

for a in "$@"; do
  case "$a" in
    --only=*) ONLY="${a#*=}" ;;
    --browser=*) BROWSER="${a#*=}" ;;
    --no-build) BUILD="no" ;;
    --frozen-now=*) FROZEN_NOW="${a#*=}" ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "capture.sh: don't know $a" >&2; exit 2 ;;
  esac
done

mkdir -p evidence/crops evidence/frames "$LOG" "$SCRATCH"
MISSING="$SCRATCH/missing.txt"
: > "$MISSING"
note_missing() { echo "$1|$2" >> "$MISSING"; echo "  ✗ $1 — $2"; }

wants() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

# ---- what has to be true before a screenshot is worth taking -------------------------------------
# Three of the four anti-goals are things only a reader catches, and a broken glyph or a widened
# push payload would be visible in the artifacts. Checking first means a failure reads as a
# sentence here rather than as something odd in a picture.
echo "· reading every displayed string against docs/VOICE.md"
python3 tools/lint/strings.py --out "$LOG/strings.json" || note_missing "voice" "a displayed string is against docs/VOICE.md"
echo "· checking both hands still have all their ink"
python3 tools/handwriting/check.py --out "$LOG/fonts.json" || note_missing "handwriting" "a glyph variant has lost a stroke"
echo "· checking every file in assets/ names what made it"
python3 tools/check/manifest.py --out "$LOG/manifest.json" >/dev/null \
  || note_missing "assets" "a file in assets/ has no manifest entry naming its generator"
echo "· checking the push payload carries only kind and sender"
python3 tools/push/webpush.py --self-test > "$LOG/webpush.txt" 2>&1 || note_missing "push" "the web push sender failed its own vectors"

# ---- the two builds ----------------------------------------------------------------------------
# One carries the seeded year; the other is a genuinely fresh install. 10_first_run, 16_setup_android
# and 17_setup_pwa may only come from the fresh one.
if [ "$BUILD" = "yes" ]; then
  echo "· building the seeded PWA"
  python3 tools/pack_assets.py --seed=year >/dev/null || exit 1
  (cd app && flutter build web --release --no-web-resources-cdn \
      --dart-define=SEED=year --dart-define=TRANSPORT=local --dart-define=CAPTURE=true \
      --dart-define=ROLE=client --dart-define=PERSON=teo \
      --dart-define=FROZEN_NOW="$FROZEN_NOW") >"$SCRATCH/build_seeded.log" 2>&1 \
    || { tail -20 "$SCRATCH/build_seeded.log"; exit 1; }
  rm -rf "$SCRATCH/web_seeded" && cp -r app/build/web "$SCRATCH/web_seeded"

  echo "· building the fresh PWA (no seed compiled in)"
  python3 tools/pack_assets.py >/dev/null || exit 1
  (cd app && flutter build web --release --no-web-resources-cdn \
      --dart-define=TRANSPORT=local --dart-define=CAPTURE=true \
      --dart-define=ROLE=client --dart-define=PERSON=teo \
      --dart-define=PROFILE=fresh) >"$SCRATCH/build_fresh.log" 2>&1 \
    || { tail -20 "$SCRATCH/build_fresh.log"; exit 1; }
  rm -rf "$SCRATCH/web_fresh" && cp -r app/build/web "$SCRATCH/web_fresh"

  # and one more, lit by the dusk condition, for the crop the critics are handed alongside the
  # hero: the same desk, the same paper, the same shadows, one light later in the day
  echo "· building the PWA at dusk"
  python3 tools/pack_assets.py --seed=year >/dev/null || exit 1
  (cd app && flutter build web --release --no-web-resources-cdn \
      --dart-define=SEED=year --dart-define=TRANSPORT=local --dart-define=CAPTURE=true \
      --dart-define=ROLE=client --dart-define=PERSON=teo --dart-define=LIGHT=dusk \
      --dart-define=FROZEN_NOW="$FROZEN_NOW") >"$SCRATCH/build_dusk.log" 2>&1 \
    || { tail -20 "$SCRATCH/build_dusk.log"; exit 1; }
  rm -rf "$SCRATCH/web_dusk" && cp -r app/build/web "$SCRATCH/web_dusk"
  # The seed must not be reachable from the fresh build. pack_assets.py leaves the directories
  # behind because pubspec declares them, so what is checked is content, not the folder.
  if find "$SCRATCH/web_fresh/assets/assets/seed" \
       \( -name '*.jsonl' -o -name 'people.json' -o -name '*.jpg' -o -name '*.ogg' -o -name '*.mp4' \) \
       -print -quit 2>/dev/null | grep -q .; then
    echo "capture.sh: the fresh build carries the seed; that is a failure condition" >&2
    exit 4
  fi
  # and the seeded one must actually have it
  if ! find "$SCRATCH/web_seeded/assets/assets/seed" -name '*.jsonl' -print -quit 2>/dev/null | grep -q .; then
    echo "capture.sh: the seeded build has no seeded year in it" >&2
    exit 4
  fi
fi

# Sets SERVED to the server's pid. It does not echo it: a background job started inside $(...)
# keeps the substitution's pipe open for as long as it runs, so reading the pid that way blocks
# until the server exits, which is to say for ever.
SERVED=""
serve() { # dir port
  SERVED=""
  [ -d "$1" ] || return 1
  if (exec 3<>"/dev/tcp/127.0.0.1/$2") 2>/dev/null; then
    echo "capture.sh: something is already serving on port $2; stop it first" >&2
    return 1
  fi
  ( cd "$1" && exec python3 -m http.server "$2" --bind 127.0.0.1 ) >/dev/null 2>&1 &
  SERVED=$!
  return 0
}
stop() { [ -n "$1" ] && kill "$1" 2>/dev/null; wait "$1" 2>/dev/null; return 0; }

serve "$SCRATCH/web_seeded" "$SEEDED_PORT" || { echo "no seeded build to serve"; exit 1; }
SEEDED_PID="$SERVED"
serve "$SCRATCH/web_fresh" "$FRESH_PORT" || { echo "no fresh build to serve"; exit 1; }
FRESH_PID="$SERVED"
serve "$SCRATCH/web_dusk" "$DUSK_PORT" || true
DUSK_PID="$SERVED"
trap 'stop "$SEEDED_PID"; stop "$FRESH_PID"; [ -n "$DUSK_PID" ] && stop "$DUSK_PID"' EXIT
sleep 2

run_scene() { # name url
  local name="$1" url="$2"
  wants "$name" || return 0
  echo "· $name"
  if node tools/capture/scene.js "evidence/scenes/$name.json" --url "$url" --browser "$BROWSER" \
        >"$SCRATCH/$name.out" 2>"$SCRATCH/$name.err"; then
    echo "  ✓ $name"
  else
    # the first line of the error is the sentence; the rest is a stack trace nobody reads
    note_missing "$name" "$(head -1 "$SCRATCH/$name.err" | sed 's/^Error: //' | cut -c1-180)"
    return 1
  fi
}

SEEDED_URL="http://127.0.0.1:$SEEDED_PORT/"
FRESH_URL="http://127.0.0.1:$FRESH_PORT/"

# ---- stills against the seeded year -------------------------------------------------------------
for s in 01_pulse 02_chat 03_us 04_moments 05_settings 12_search 13_messenger_states 14_media_viewer; do
  [ -f "evidence/scenes/$s.json" ] && run_scene "$s" "$SEEDED_URL"
done

# ---- stills against a fresh install --------------------------------------------------------------
for s in 10_first_run 17_setup_pwa; do
  [ -f "evidence/scenes/$s.json" ] && run_scene "$s" "$FRESH_URL"
done

# ---- the dusk crop: not an artifact, but what the material critic is handed beside the hero ------
if [ -n "$DUSK_PID" ] && [ -f evidence/scenes/dusk_pulse.json ]; then
  run_scene dusk_pulse "http://127.0.0.1:$DUSK_PORT/"
fi

# ---- clips ---------------------------------------------------------------------------------------
# ffmpeg is handed the frames the app produced, one per output frame, at the rate the clock was
# stepped at: no interpolation, no dropped frames, nothing invented between them.
make_clip() { # name fps min_seconds
  local name="$1" fps="${2:-60}" min="${3:-4}"
  wants "$name" || return 0
  local dir="evidence/frames/$name"
  [ -d "$dir" ] || { note_missing "$name.mp4" "no frames were captured"; return 1; }
  local staged="$SCRATCH/$name"
  rm -rf "$staged" && mkdir -p "$staged"
  local i=0
  # a clip is taken in runs — before a thing happens, and after it — and they play in order
  local parts=("$dir")
  for suffix in _b _c _d; do
    [ -d "evidence/frames/${name}${suffix}" ] && parts+=("evidence/frames/${name}${suffix}")
  done
  for f in $(for d in "${parts[@]}"; do ls "$d"/*.png 2>/dev/null; done); do
    [ -f "$f" ] || continue
    ln -sf "$(realpath "$f")" "$(printf '%s/%06d.png' "$staged" "$i")"
    i=$((i + 1))
  done
  ffmpeg -y -loglevel error -framerate "$fps" -i "$staged/%06d.png" \
    -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -movflags +faststart \
    "evidence/$name.mp4" </dev/null || { note_missing "$name.mp4" "ffmpeg refused the frames"; return 1; }
  python3 tools/check/frames.py "$dir" --fps "$fps" --min-seconds "$min" \
    --strip "evidence/crops/${name}_strip.png" --out "$LOG/${name}.frames.json" >/dev/null \
    || note_missing "$name.mp4" "the frame check failed; see $LOG/${name}.frames.json"
  echo "  ✓ $name.mp4 ($i frames at ${fps}fps)"
}

for s in 06_unfolding 07_feeling_landing 11_chat_scroll 15_authored_feeling; do
  [ -f "evidence/scenes/$s.json" ] && run_scene "$s" "$SEEDED_URL"
done
make_clip 06_unfolding 60 4
make_clip 07_feeling_landing 60 6
make_clip 11_chat_scroll 60 4
make_clip 15_authored_feeling 60 4

# ---- the two artifacts that need the Android phone -----------------------------------------------
# 08 and 09 need both phones at once, and 16 needs the Android one. When the emulator is not up
# they are recorded as missing with the reason, never faked from the PWA.
if adb shell true >/dev/null 2>&1; then
  if [ "$BUILD" = "yes" ]; then
    echo "· building the two APKs"
    python3 tools/pack_assets.py --seed=year >/dev/null
    (cd app && flutter build apk --debug --dart-define=SEED=year --dart-define=TRANSPORT=local \
        --dart-define=CAPTURE=true --dart-define=FROZEN_NOW="$FROZEN_NOW") >"$SCRATCH/build_apk_seeded.log" 2>&1 \
      && cp app/build/app/outputs/flutter-apk/app-debug.apk "$SCRATCH/app-seeded.apk"
    python3 tools/pack_assets.py >/dev/null
    (cd app && flutter build apk --debug --dart-define=TRANSPORT=local \
        --dart-define=CAPTURE=true --dart-define=PROFILE=fresh) >"$SCRATCH/build_apk_fresh.log" 2>&1 \
      && cp app/build/app/outputs/flutter-apk/app-debug.apk "$SCRATCH/app-fresh.apk"
  fi
  bash tools/capture/android.sh "$SEEDED_URL" "$FRESH_URL" || true
else
  for s in 08_state_propagating.mp4 09_two_devices.png 16_setup_android.png; do
    wants "${s%.*}" && note_missing "$s" "no Android device was up in this session"
  done
fi

# ---- derived: crops, strips, diffs, the capture log ------------------------------------------------
if [ -f evidence/02_chat.png ]; then
  python3 tools/check/crops.py evidence/02_chat.png --out-dir evidence/crops --scale 3 >"$LOG/crops.json"
  python3 tools/check/tears.py "$LOG/02_chat.report.json" --out "$LOG/tears.json" >/dev/null \
    || note_missing "02_chat.png" "$(python3 -c "import json;print(json.load(open('$LOG/tears.json')).get('why',''))" 2>/dev/null)"
fi

python3 tools/capture/collect.py --stamp "$STAMP" --missing "$MISSING" --browser "$BROWSER"

echo
if [ -s "$MISSING" ]; then
  echo "captured with $(wc -l < "$MISSING") artifact(s) missing; evidence/frames.json names each one and why."
else
  echo "the whole evidence set was captured."
fi
