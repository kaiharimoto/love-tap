#!/usr/bin/env bash
# tools/render_queue3.sh — the photographs again, with every builder able to be told where to
# stand, and then the rest.
#
# The last run stopped ten minutes in: kit.wall never learned to take `at`, still.py hands the
# whole spec to the builder, and eight of a hundred and fifteen photographs were exposed before
# the TypeError. tools/check/recipes.py now says that in a second without opening Blender.
set -uo pipefail
cd "$(dirname "$0")/.."
. ./toolchain/env.sh

say() { echo "[$(date +%H:%M:%S)] $*"; }

say "checking every recipe can be built before spending four hours finding out"
python3 tools/check/recipes.py || { say "the recipes do not build; stopping"; exit 1; }

say "1/4 the photographs — 115, at a thousand pixels"
bash blender/run.sh blender/photos/still.py -- --all --res 1000 --samples 28 --skip-existing \
    2>&1 | grep -E "^still:|Error|Traceback" || true
say "developing the negatives"
python3 blender/photos/develop.py --all 2>&1 | tail -8
say "photographs on disk: $(ls seed/photos/*.jpg 2>/dev/null | wc -l)"

say "2/4 the videos — 14, five seconds each"
bash blender/run.sh blender/videos/clip.py -- --all --res 420 --samples 16 --fps 12 \
    --seconds 5 --skip-existing 2>&1 | grep -E "^clip:|Error|Traceback" || true
python3 blender/videos/cut.py --all 2>&1 | tail -16

say "3/4 paper stocks, dusk — the half the library has never had"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 3 2>&1 | grep -E "^paper:|Error|Traceback" || true

say "4/4 packing the display-resolution set"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -2
say "the queue is finished"
