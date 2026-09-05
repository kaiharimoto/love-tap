#!/usr/bin/env bash
# tools/render_queue5.sh — what is left.
#
# A video frame costs twenty-six seconds whether it is 420 pixels at sixteen samples or 320 at
# twelve, because what it costs is not sampling: the wave modifier moves the water, so Cycles
# rebuilds the scene's BVH for every frame. The only lever that works on that is the number of
# frames. Two and a half seconds at ten a second is a phone clip.
set -uo pipefail
cd "$(dirname "$0")/.."
. ./toolchain/env.sh
say() { echo "[$(date +%H:%M:%S)] $*"; }

python3 tools/check/recipes.py || { say "the recipes do not build; stopping"; exit 1; }

say "1/5 the last four photographs, re-lit"
bash blender/run.sh blender/photos/still.py -- --all --res 1000 --samples 28 --skip-existing \
    2>&1 | grep -E "^still:|Error|Traceback" || true
python3 blender/photos/develop.py --all 2>&1 | tail -6
say "photographs on disk: $(ls seed/photos/*.jpg 2>/dev/null | wc -l) of 115"

say "2/5 the last poster"
bash blender/run.sh blender/photos/still.py -- --all --recipes blender/videos/shots \
    --res 900 --samples 24 --skip-existing --out scratch/posters \
    2>&1 | grep -E "^still:|Error|Traceback" || true
python3 blender/photos/develop.py --all --dir scratch/posters 2>&1 | tail -3

say "3/5 the videos — 14, two and a half seconds each"
bash blender/run.sh blender/videos/clip.py -- --all --res 320 --samples 8 --fps 10 \
    --seconds 2.5 --skip-existing 2>&1 | grep -E "^clip:|Error|Traceback" || true
python3 blender/videos/cut.py --all 2>&1 | tail -16

say "4/5 the fold sequence, all two hundred and forty frames of it"
bash blender/run.sh blender/folds/fold.py -- --seq unfold_thirds --frames 240 --res 600 --samples 48 \
    2>&1 | grep -E "^fold:|Error|Traceback" || true

say "5/5 paper stocks, dusk — the half the library has never had"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 3 2>&1 | grep -E "^paper:|Error|Traceback" || true

say "packing the display-resolution set"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -3
python3 tools/check/manifest.py --fill 2>&1 | tail -2
say "the queue is finished"
