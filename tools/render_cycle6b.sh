#!/usr/bin/env bash
# What is left of the cycle-6 library after the first queue died on its last stage.
#
#   setsid bash tools/render_cycle6b.sh > /path/queue.log 2>&1 < /dev/null &
#
# The dusk stocks (the first queue reached them and was killed with two of twenty-seven written),
# the two objects that stopped reading as emoji, and the bookmark that had to be curled to have any
# light on it at all. The dusk tear shadows are not here: one costs five minutes, fifty-four are
# left, and nothing in the seventeen artifacts is lit at dusk — they run after the capture.
set -uo pipefail
cd "$(dirname "$0")/.."
say() { echo "[$(date -u +%H:%M:%S)] $*"; }

say "1/3 paper stocks, dusk"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 4 --skip-existing 2>&1 | grep -E "^paper:|Error|Traceback" || true
say "paper dusk: $(ls assets/paper/*_dusk.webp 2>/dev/null | wc -l) of 27"

say "2/3 the wrapper, the confetti and the bookmark"
bash blender/run.sh blender/objects/objects.py -- \
    --only obj_wrapper obj_confetti obj_bookmark --res 1200 --samples 48 \
    2>&1 | grep -E "^object:|Error|Traceback" || true

say "3/3 packing"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -1
say "the queue is finished"
