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
# A check that ran on an artifact that is there, and failed. Not a missing artifact: it lands in
# MANIFEST.json under `failed_checks`, and the still stays in `artifacts` to be looked at.
FAILED="$SCRATCH/failed.txt"
: > "$FAILED"
note_failed() { echo "$1|$2" >> "$FAILED"; echo "  ✗ $1 (check failed) — $2"; }

wants() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

# ---- what has to be true before a screenshot is worth taking -------------------------------------
# Three of the four anti-goals are things only a reader catches, and a broken glyph or a widened
# push payload would be visible in the artifacts. Checking first means a failure reads as a
# sentence here rather than as something odd in a picture.
# A clip is three hundred full-resolution frames and there are five of them. A run that starts
# with less than this free does not fail where it runs out — ffmpeg says "refused the frames",
# the scenes say ENOSPC in a stack trace, and four artifacts come back missing for a reason that
# has nothing to do with the app. Ask first.
NEED_MB=6000
FREE_MB="$(df -Pm . | awk 'NR==2 {print $4}')"
if [ "${FREE_MB:-0}" -lt "$NEED_MB" ]; then
  echo "capture.sh: ${FREE_MB}MB free and a full run needs about ${NEED_MB}MB." >&2
  echo "  The frames are the bulk of it: five clips at three hundred 1080x2340 PNGs each." >&2
  echo "  evidence/frames/ and the web builds under \$TMPDIR are safe to delete." >&2
  exit 3
fi

echo "· reading every displayed string against docs/VOICE.md"
python3 tools/lint/strings.py --out "$LOG/strings.json" || note_missing "voice" "a displayed string is against docs/VOICE.md"
echo "· checking both hands still have all their ink"
python3 tools/handwriting/check.py --out "$LOG/fonts.json" || note_missing "handwriting" "a glyph variant has lost a stroke"
echo "· checking every file in assets/ names what made it, and every entry has a file"
# The ruler before the reading, for the same reason as diff.py: this gate reported ok true beside
# twenty entries with no file for three cycles, because `ok` was computed from two of the four
# things it measures, and a hundred and fifteen of the entries it called missing were present files
# it had looked for in the wrong directory. The selftest breaks the library one fault at a time and
# fails if any of them leaves the gate green.
python3 tools/check/manifest_selftest.py >"$LOG/manifest_selftest.json" 2>&1 \
  || note_missing "assets" "tools/check/manifest_selftest.py failed: the manifest gate cannot be trusted to go red; see evidence/logs/manifest_selftest.json"
# And the ruler for the record of the run itself, before the run writes one. MANIFEST.json has
# now twice said something false about an artifact -- that a file written fourteen minutes into
# the capture belonged to an earlier session, and that a scene which refused an artifact had
# produced it -- and both went unnoticed because nothing could drive collect.py and scene.js
# against a throwaway directory and watch them lie.
python3 tools/capture/capture_selftest.py >"$LOG/capture_selftest.txt" 2>&1 \
  || note_missing "capture" "tools/capture/capture_selftest.py failed: the manifest cannot be trusted to say whose an artifact is or why it is missing; see evidence/logs/capture_selftest.txt"
python3 tools/check/manifest.py --out "$LOG/manifest.json" >/dev/null \
  || note_missing "assets" "assets/MANIFEST.json does not match what is on disk: see entries_without_a_file and entries_for_files_outside_the_library in evidence/logs/manifest.json"
echo "· checking every recipe can actually be built"
python3 tools/check/recipes.py --out "$LOG/recipes.json" >/dev/null \
  || note_missing "recipes" "a recipe names something the kit cannot build, or tells it something it cannot be told"
echo "· checking the lamp is the colour DIRECTION.md says it is"
python3 tools/check/illuminant.py --out "$LOG/illuminant.json" >/dev/null \
  || note_missing "illuminant" "the day rig's net colour temperature is not the one DIRECTION.md declares, so every render in assets/ is lit wrong; see $LOG/illuminant.json"
echo "· checking the library holds everything the app asks it for at dusk"
python3 tools/check/dusk_shadows.py --out "$LOG/dusk_shadows.json" >/dev/null \
  || note_missing "dusk" "the app names an asset under _dusk that the library does not hold, and loads it behind an errorBuilder, so it draws nothing and says nothing; see $LOG/dusk_shadows.json"
echo "· measuring how far apart the thirty-four haptics are"
# The selftest first, for the same reason the manifest's runs first: a floor that has stopped
# measuring anything passes quietly. It re-breaks the distance on five cases, including the pair
# the old string-equality check could not see.
python3 tools/check/haptics.py --selftest >"$LOG/haptics_selftest.txt" 2>&1 \
  || note_missing "haptics" "tools/check/haptics.py --selftest failed: the discrimination floor cannot be trusted to go red; see evidence/logs/haptics_selftest.txt"
python3 tools/check/haptics.py --out evidence/haptics.json >"$LOG/haptics.txt" 2>&1 \
  || note_missing "haptics" "two feelings are closer than the 2.0 JND floor, or share an object; see problems and discrimination.under_floor in evidence/haptics.json"

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

# The surfaces gate reads `app/assets`, which is derived and gitignored, so it has to be asked
# after something has packed it. It used to sit sixteen lines above the first `pack_assets.py`,
# with the other library checks, and in a fresh container it therefore globbed an empty directory,
# read zero surfaces and exited 2 — correctly, because firing 10 made reading nothing an error on
# purpose (cc078d7) so that a gate could not pass by looking at nothing. What reached
# evidence/frames.json was `surfaces — a rendered surface in the library has nothing in it`, which
# is a false statement about the library and had been made on every fresh-container capture.
# Re-run after the packing, the same gate reads 318 surfaces and none of them is flat.
#
# It stays on the packed library rather than moving to `--root assets`: app/assets is what the app
# ships and what the rest of this capture measures, and a gate that reads a different library from
# the one under the camera is a gate that can be green about the wrong thing.
echo "· checking no surface in the library is a flat fill"
python3 tools/check/surfaces.py --out "$LOG/surfaces.json" \
  || note_missing "surfaces" "a rendered surface in the library has nothing in it; see $LOG/surfaces.json"

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
# A dusk build whose library has no dusk paper in it renders exactly like the day build, and the
# crop taken from it came back byte-identical to 01_pulse.png — which is worse than not having one,
# because it looks like evidence. The app says in its own report whether the dusk half is baked.
if [ -n "$DUSK_PID" ] && [ -f evidence/scenes/dusk_pulse.json ]; then
  if run_scene dusk_pulse "http://127.0.0.1:$DUSK_PORT/"; then
    if ! python3 -c "
import json,sys
r=json.load(open('$LOG/dusk_pulse.report.json'))
sys.exit(0 if r.get('has_dusk_paper') else 1)" 2>/dev/null; then
      rm -f evidence/crops/dusk_pulse.png
      note_missing "dusk_pulse" "the library has no dusk paper baked, so a dusk build renders as the day one"
    fi
  fi
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
  # the check reads the frames the clip was actually assembled from, not just its first run:
  # judging 06 on its opening still is how four static clips came back marked as passing
  python3 tools/check/frames.py "$staged" --fps "$fps" --min-seconds "$min" \
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

# ---- the clip that needs a second device ---------------------------------------------------------
# There is no Android phone in a container: no /dev/kvm, so the emulator will not boot, and no GTK,
# so there is no desktop build either. But 08 does not need the far phone to be *visible* — it needs
# a gesture on one device to become a sensation on the other. app/tool/host_daemon.dart is that far
# device: a real spine, the real transport in its host role, the real six-word pairing, headless.
# It is the tailnet host when the two nodes are up and a loopback host when they are not, and the
# report says which. 09_two_devices does need both screens, so it stays missing.
PAIR="$SCRATCH/pair.json"
if wants 08_state_propagating && [ -f evidence/scenes/08_state_propagating.json ]; then
  rm -f "$PAIR" "$PAIR.do"
  FAR_TRANSPORT="local"; FAR_ADDR=""; FAR_PROXY=""
  # The address files say a tailnet node was once brought up here. They do not say one is running:
  # after a container restart both files are still on disk and both daemons are gone, and the scene
  # then fails with `Could not connect to proxy server` — which reads as the app's fault and is not.
  # So the proxy is asked. A dead tailnet falls back to the local transport rather than failing,
  # and the report says which one carried it.
  if [ -f toolchain/ts/a/address ] && [ -f toolchain/ts/b/address ] \
     && (exec 3<>/dev/tcp/127.0.0.1/1155) 2>/dev/null; then
    FAR_TRANSPORT="tailscale"; FAR_ADDR="$(cat toolchain/ts/a/address)"; FAR_PROXY="127.0.0.1:1155"
  elif [ -f toolchain/ts/a/address ]; then
    echo "  · the tailnet nodes are not running; the far phone will use the local transport." >&2
    echo "    tools/tailscale/up.sh brings them back — their state survives, so no new key is needed." >&2
  fi
  # The far phone serves the page the near one loads, which is how the two of them actually work:
  # the host serves the conversation and the page that reads it, from one origin. It is also the
  # only arrangement a browser will accept — a page served off the loopback file server is a
  # different origin from the host, and nothing in this transport sends an
  # Access-Control-Allow-Origin header, because on the phones there is nothing to allow.
  # $PAIR is absolute, so it must not be joined to anything: "../$PAIR" made "..//tmp/..." and
  # the far phone died on its first write, which capture.sh then reported as "would not start"
  ( cd app && dart run tool/host_daemon.dart --out "$PAIR" \
      --transport "$FAR_TRANSPORT" --address "$FAR_ADDR" --proxy "$FAR_PROXY" \
      --pwa "$SCRATCH/web_fresh" --seconds 900 \
    ) >"$SCRATCH/host_daemon.log" 2>&1 &
  DAEMON_PID=$!
  for _ in $(seq 1 60); do [ -f "$PAIR" ] && break; sleep 0.5; done
  if [ -f "$PAIR" ]; then
    FAR_BASE="$(python3 -c "import json;print(json.load(open('$PAIR'))['base'])")"
    echo "· 08_state_propagating (the far phone is headless and serving, over $FAR_TRANSPORT)"
    if node tools/capture/scene.js evidence/scenes/08_state_propagating.json \
          --url "$FAR_BASE/" --browser "$BROWSER" --pair "$PAIR" \
          ${FAR_PROXY:+--proxy "http://$FAR_PROXY"} \
          >"$SCRATCH/08.out" 2>"$SCRATCH/08.err"; then
      echo "  ✓ 08_state_propagating"
      make_clip 08_state_propagating 60 8
    else
      note_missing "08_state_propagating.mp4" "$(head -1 "$SCRATCH/08.err" | cut -c1-160)"
    fi
    echo "stop" >> "$PAIR.do"
  else
    note_missing "08_state_propagating.mp4" "the far phone would not start; see $SCRATCH/host_daemon.log"
  fi
  wait "$DAEMON_PID" 2>/dev/null || true
fi

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
  for s in 09_two_devices.png 16_setup_android.png; do
    wants "${s%.*}" && note_missing "$s" "no Android device was up in this session. Measured, not assumed: with no /dev/kvm the x86_64 image runs under QEMU's own instruction emulation, and it does start — adbd answered after 113 minutes — but the framework never came up with it, so there was no package service to install an APK into. There is no GTK either, so no desktop build can stand in for a second screen. Neither of these was faked from the PWA"
  done
fi

# ---- derived: crops, strips, diffs, the capture log ------------------------------------------------
if [ -f evidence/02_chat.png ]; then
  python3 tools/check/crops.py evidence/02_chat.png --out-dir evidence/crops --scale 3 >"$LOG/crops.json"
  python3 tools/check/tears.py "$LOG/02_chat.report.json" --out "$LOG/tears.json" >/dev/null \
    || note_missing "02_chat.png" "$(python3 -c "import json;print(json.load(open('$LOG/tears.json')).get('why',''))" 2>/dev/null)"
  # The frame-wide answer, said out loud for every still rather than only for the notes of one.
  #
  # tears.py read the scene report's `tears` map, which is keyed by event id, so it saw the notes
  # and nothing else -- and eight of the eleven stills in firing 39's capture repeat a mask in
  # their CHROME while that map reports no repeat at all. 12_search drew one mask fourteen times.
  # The gate was narrower than the clause it enforces (docs/BRIEF.md 09, rubric row 02: no visible
  # repeat on a single screen), which is how it survived four captures.
  #
  # `--frame-fatal` is ON since firing 52. It was held off because a failed `ok` used to become
  # note_missing, and booking a still as MISSING because its chrome repeats a mask throws the
  # artifact away instead of measuring it. A failure here is now note_failed: the still stays in
  # MANIFEST.json's `artifacts` and the reason goes under `failed_checks`, where a reader expects
  # a failed measurement and not an absent screenshot. Firing 51's capture read frame_repeats
  # empty on all eleven stills, so this is on because it passes, not so that it can.
  for R in "$LOG"/*.report.json; do
    [ -f "$R" ] || continue
    T="${R%.report.json}.tears.json"
    A="$(basename "${R%.report.json}")"
    # Only a still has a surfaces sidecar, so only a still has a frame to read. The four clips and
    # the dusk crop are read for their notes alone, as before, and are not failed for having no
    # frame: that would be booking "not looked at" as "looked at and wrong".
    if [ -f "evidence/$A.surfaces.json" ]; then
      if ! python3 tools/check/tears.py "$R" --frame-fatal --min-notes 0 --out "$T" >/dev/null 2>&1; then
        note_failed "$A.png" "tears.py --frame-fatal: $(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('why','it wrote no verdict'))" "$T" 2>/dev/null || echo 'it wrote no verdict')"
      fi
    else
      python3 tools/check/tears.py "$R" --out "$T" >/dev/null 2>&1 || true
    fi
    python3 tools/check/tears_line.py "$R" "${R%.report.json}.tears.json" || true
  done
fi

# ---- the two rulers the capture describes and never used to write ---------------------------
#
# For four cycles `evidence/legibility.json` and `evidence/palette.json` were the only files under
# evidence/ that no capture produced. Every other number here comes out of this script; those two
# came out of somebody typing the command, which is how firing 24 committed a legibility file
# saying 16 while the shipped ruler read 25 on the same stills. A ruler that is not re-read by the
# run it describes drifts silently, and it drifts in the direction of whoever last ran it.
#
# Both tools exit non-zero when a FLOOR IS BREACHED, which is the normal state of this build and
# not a failure of the tool -- so neither may be treated as a missing artifact on its exit code.
# What would be a real failure is the JSON not being written at all, and that is what is checked.
echo "· writing the legibility and palette rulers"
python3 tools/check/legibility.py --out evidence/legibility.json >"$LOG/legibility.txt" 2>&1 || true
[ -s evidence/legibility.json ] \
  || note_missing "legibility.json" "tools/check/legibility.py wrote no ruler; see $LOG/legibility.txt"
python3 tools/check/palette.py --out evidence/palette.json --floors \
    --classes docs/screen_classes.json >"$LOG/palette.txt" 2>&1 || true
[ -s evidence/palette.json ] \
  || note_missing "palette.json" "tools/check/palette.py wrote no ruler; see $LOG/palette.txt"

# The third ruler, and the one the flat-fill cluster is closed on: whether any still has a single
# RGB value standing in for a surface, and whether the pad box has tooth in it. Read here for the
# same reason as the two above -- for five firings it was measured by hand, once per firing, and
# 10_first_run sat at 59.56% one exact colour through three separate diagnoses of it.
#
# Like them, it exits non-zero on a breached floor, which is the normal state of this build while
# the tooth question in docs/COLOR.md is open, so its exit code is not read as a missing artifact.
python3 tools/check/flat_fill.py --out evidence/flat_fill.json >"$LOG/flat_fill.txt" 2>&1 || true
[ -s evidence/flat_fill.json ] \
  || note_missing "flat_fill.json" "tools/check/flat_fill.py wrote no ruler; see $LOG/flat_fill.txt"

# The fourth and fifth, read here for the reason the three above are: a ruler the run does not
# re-read drifts, and it drifts towards whoever last ran it by hand. Both were written at firing 48
# and both exit non-zero on a breached floor, which is today's state, so neither exit code is read
# as a missing artifact.
#
#   hands.py       does a letter that comes round again get a different outline, measured over the
#                  runs the app DECLARES rather than over `eeeeeeee`, which the app never draws.
#   composited.py  is a feeling object lit by the same lamp as the paper it is lying on, measured
#                  over the object's own opaque pixels between the day still and the dusk one.
#
# `composited.py` needs both stills, so it is skipped rather than booked missing when the dusk
# crop is not in this run.
for T in evidence/*.text.json; do
  [ -f "$T" ] || continue
  python3 tools/check/hands.py "$T" --out "$LOG/$(basename "${T%.text.json}").hands.json" \
    >/dev/null 2>&1 || true
done
if [ -f evidence/01_pulse.png ] && [ -f evidence/crops/dusk_pulse.png ]; then
  python3 tools/check/composited.py evidence/01_pulse.png evidence/crops/dusk_pulse.png \
    --out "$LOG/composited.json" >/dev/null 2>&1 || true
fi

# What moved since the last capture, measured against evidence/.previous, and then this capture
# becomes the baseline for the next one. The rotation has to happen here rather than by hand:
# nothing rotated it for a long time, so every SSIM in DIFF.json was unreproducible from the
# baseline that shipped beside it.
#
# The ruler is checked before it is read. For three cycles the step below wrote a correct DIFF.json
# and tools/capture/collect.py then overwrote it with SSIM measured against the baseline this same
# step had just rotated -- every still compared with itself, every label "unchanged", and a 2.5
# point regression between cycle 2 and cycle 3 that nothing was in a position to see. The selftest
# runs two captures against a throwaway tree with one still altered between them and fails if the
# altered one does not read `changed`, so a second writer cannot come back unnoticed.
python3 tools/check/diff_selftest.py >"$LOG/diff_selftest.json" 2>&1 \
  || note_missing "DIFF.json" "tools/check/diff_selftest.py failed: the comparison against the previous capture is not trustworthy; see evidence/logs/diff_selftest.json"
python3 tools/check/diff.py --rotate || true

# the frames are the negative of a clip and run to hundreds of megabytes a run; the mp4 and the
# strip in evidence/crops are what anybody looks at, so the frames go once they are folded in
[ "${KEEP_FRAMES:-no}" = "yes" ] || rm -rf evidence/frames

python3 tools/capture/collect.py --stamp "$STAMP" --missing "$MISSING" --failed "$FAILED" --browser "$BROWSER"

echo
if [ -s "$MISSING" ]; then
  echo "captured with $(wc -l < "$MISSING") artifact(s) missing; evidence/frames.json names each one and why."
else
  echo "the whole evidence set was captured."
fi
