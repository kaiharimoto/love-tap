#!/usr/bin/env bash
# What the hands' contextual alternates cost the scroll, measured rather than guessed.
#
# Three cycles have named a cause for the scroll's build spikes. The tear mask baked per note:
# disproved by a counter that read twelve masks across a fling through 8,075 rows. The scope
# subscription rebuilding every row on every sync round: real, fixed, and the row count over the
# same fling fell from 5,028 to 167. What is left is a frame that builds nothing costing 4 ms
# against one that builds two and a half rows costing 688 — about 276 ms a row — and the test that
# was supposed to rule the fonts out runs under `flutter test`, which passes --use-test-fonts
# --disable-asset-fonts and therefore laid every one of its paragraphs out in a font with no
# alternates in it.
#
# Both arms are built here, from whatever commit is checked out, so the only difference between
# them is the flag. Reading a previous capture's scroll_webkit.json as the control would compare
# builds that differ by more than the fonts.
#
#   bash tools/plain_fonts_experiment.sh
#
# Writes evidence/logs/what_the_alternates_cost.json.
set -uo pipefail
cd "$(dirname "$0")/.."
. ./toolchain/env.sh

SCRATCH="${TMPDIR:-/tmp}/lovetap-plain"
FROZEN_NOW="2026-09-03T19:40:00Z"
mkdir -p "$SCRATCH"
OUT="evidence/logs/what_the_alternates_cost.json"

run_arm() { # name  extra-dart-defines
  local name="$1" extra="${2:-}"
  echo "· building the seeded PWA: $name"
  (cd app && flutter build web --release --no-web-resources-cdn \
      --dart-define=SEED=year --dart-define=TRANSPORT=local --dart-define=CAPTURE=true \
      --dart-define=ROLE=client --dart-define=PERSON=teo $extra \
      --dart-define=FROZEN_NOW="$FROZEN_NOW") >"$SCRATCH/build_$name.log" 2>&1 \
    || { tail -20 "$SCRATCH/build_$name.log"; return 1; }
  rm -rf "$SCRATCH/web_$name" && cp -r app/build/web "$SCRATCH/web_$name"

  local pair="$SCRATCH/pair_$name.json"
  rm -f "$pair" "$pair.do"
  ( cd app && dart run tool/host_daemon.dart --out "$pair" \
      --transport local --address "" --proxy "" \
      --pwa "$SCRATCH/web_$name" --seed year --now "$FROZEN_NOW" --seconds 3600 \
    ) >"$SCRATCH/daemon_$name.log" 2>&1 &
  local daemon=$!
  local i
  for i in $(seq 1 240); do [ -f "$pair" ] && break; sleep 0.5; done
  if [ ! -f "$pair" ]; then
    echo "the far phone would not start for $name"; tail -5 "$SCRATCH/daemon_$name.log"
    kill $daemon 2>/dev/null; return 1
  fi
  local base
  base="$(python3 -c "import json;print(json.load(open('$pair'))['base'])")"

  python3 tools/experiment/scene_for.py "$SCRATCH/scene_$name.json" "$name"
  echo "· the same fling, against $name"
  node tools/capture/scene.js "$SCRATCH/scene_$name.json" --url "$base/" --browser webkit \
    --pair "$pair" --profile "$SCRATCH/profile_$name" >"$SCRATCH/scene_$name.log" 2>&1
  local ok=$?
  kill $daemon 2>/dev/null
  rm -rf "evidence/frames/11_$name"
  [ $ok -eq 0 ] || { tail -20 "$SCRATCH/scene_$name.log"; return 1; }
}

run_arm alternates "" || exit 1
run_arm plain "--dart-define=PLAIN_FONTS=true" || exit 1
python3 tools/experiment/read_arms.py "$OUT"
echo "PLAIN FONTS DONE"
