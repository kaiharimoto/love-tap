#!/usr/bin/env bash
# tools/render_cycle6.sh — the light touching things.
#
#   setsid bash tools/render_cycle6.sh > /path/queue.log 2>&1 < /dev/null &
#
# Two rig changes, both about a surface that was not there: paper stocks now cockle by a fraction
# of their own width instead of by a fixed sixth of a millimetre, and objects and bits are rendered
# with the desk under them — two millimetres under their own lowest vertex, invisible to the camera
# and present to the light — so the key can reach the camera-facing side by bounce.
#
# --skip-existing throughout, so a container that goes to sleep costs the sheet it was on and not
# the run: the files that were rendered before the rig changed have been deleted, and everything
# still on disk is either already correct or was made by this queue.
set -uo pipefail
cd "$(dirname "$0")/.."
STAMP() { date -u +%H:%M:%S; }
say() { echo "[$(STAMP)] $*"; }

say "1/4 paper stocks, daylight — the ground of every screen"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition day --threads 4 --skip-existing 2>&1 | grep -E "^paper:|Error|Traceback" || true
say "paper day: $(ls assets/paper/*.webp 2>/dev/null | grep -vc dusk) on disk"

say "2/4 the feeling objects — day and dusk, beauty and shadow"
bash blender/run.sh blender/objects/objects.py -- --all --res 1200 --samples 48 \
    2>&1 | grep -E "^object:|Error|Traceback" || true
say "objects: $(ls assets/objects/*.png 2>/dev/null | wc -l) on disk"

say "3/4 the bits — tape, staples, clips, pins, glue"
bash blender/run.sh blender/bits/bits.py -- --all --res 900 --samples 48 \
    2>&1 | grep -E "^bit:|Error|Traceback" || true

say "4/4 paper stocks, dusk"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 4 --skip-existing 2>&1 | grep -E "^paper:|Error|Traceback" || true
say "paper dusk: $(ls assets/paper/*_dusk.webp 2>/dev/null | wc -l) on disk"

say "packing the display-resolution set"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -2
say "the queue is finished"
