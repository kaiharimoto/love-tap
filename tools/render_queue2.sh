#!/usr/bin/env bash
# tools/render_queue2.sh — everything still to be baked, in the order it is worth having.
#
#   setsid bash tools/render_queue2.sh >> "$LOG" 2>&1 &
#
# The photographs come first because a hundred and twenty-nine missing renders were taking a
# hundred and twenty-two read markers, reactions and replies down with them: a quarter of a
# percent of the year's lines, and the whole of its media. Then the dusk half of the library,
# which the material check has never had anything to run on. Then the videos.
set -uo pipefail
cd "$(dirname "$0")/.."
. ./toolchain/env.sh

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "1/4 the photographs — 115, at a thousand pixels"
bash blender/run.sh blender/photos/still.py -- --all --res 1000 --samples 28 --skip-existing \
    2>&1 | grep -E "^still:|Error|Traceback" || true
say "developing the negatives"
python3 blender/photos/develop.py --all 2>&1 | tail -6
say "photographs on disk: $(ls seed/photos/*.jpg 2>/dev/null | wc -l)"

say "2/4 paper stocks, dusk — the half the library has never had"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 3 2>&1 | grep -E "^paper:|Error|Traceback" || true

say "3/4 the videos — 14, five seconds each"
bash blender/run.sh blender/videos/clip.py -- --all --res 420 --samples 16 --fps 12 \
    --seconds 5 --skip-existing 2>&1 | grep -E "^clip:|Error|Traceback" || true
python3 blender/videos/cut.py --all 2>&1 | tail -16

say "4/4 packing the display-resolution set"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -2
say "the queue is finished"
