#!/usr/bin/env bash
# tools/render_cycle6.sh — the light touching things.
#
#   setsid bash tools/render_cycle6.sh > /path/queue.log 2>&1 < /dev/null &
#
# Two rig changes, both about a surface that was not there: paper stocks now cockle by a fraction
# of their own width instead of by a fixed sixth of a millimetre, and objects and bits are rendered
# with the desk under them (invisible to the camera, present to the light) so the key can reach the
# camera-facing side by bounce. Everything either change touches is re-rendered here.
set -uo pipefail
cd "$(dirname "$0")/.."
STAMP() { date -u +%H:%M:%S; }
say() { echo "[$(STAMP)] $*"; }

say "1/4 paper stocks, daylight — 23 sheets, the ground of every screen"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition day --threads 4 2>&1 | grep -E "^paper:|Error|Traceback" || true

say "2/4 the feeling objects — 34, day and dusk, beauty and shadow"
bash blender/run.sh blender/objects/objects.py -- --all --res 1200 --samples 48 \
    2>&1 | grep -E "^object:|Error|Traceback" || true

say "3/4 the bits — tape, staples, clips, pins, glue"
bash blender/run.sh blender/bits/bits.py -- --all --res 900 --samples 48 \
    2>&1 | grep -E "^bit:|Error|Traceback" || true

say "4/4 paper stocks, dusk"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 4 2>&1 | grep -E "^paper:|Error|Traceback" || true

say "packing the display-resolution set"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -2
say "the queue is finished"
