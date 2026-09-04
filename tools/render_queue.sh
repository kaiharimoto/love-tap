#!/usr/bin/env bash
# tools/render_queue.sh — the whole render backlog, in one long-lived job.
#
#   setsid bash tools/render_queue.sh > /path/queue.log 2>&1 < /dev/null &
#
# Launched with setsid so it is in its own session: nothing that signals the shell that started it
# reaches it. Three separate attempts at this backlog were killed part way through by a stray
# process-group signal, which is a silly way to lose two hours of rendering.
#
# In order, most valuable first, because the machine has four cores and everything here wants all
# of them: the paper the whole app is made of, then the photographs the thread is missing, then
# the feeling objects that changed, then the dusk half of the library.
set -uo pipefail
cd "$(dirname "$0")/.."
STAMP() { date -u +%H:%M:%S; }
say() { echo "[$(STAMP)] $*"; }

say "1/4 paper stocks, daylight — 23 sheets"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition day --threads 3 2>&1 | grep -E "^paper:|Error|Traceback" || true
say "paper day done: $(ls assets/paper/*.webp 2>/dev/null | grep -vc dusk) sheets on disk"

say "2/4 the feeling objects that changed"
bash blender/run.sh blender/objects/objects.py -- --only obj_pinch obj_gold_star obj_crown obj_clover \
    --res 1200 --samples 64 2>&1 | grep -E "^object:|Error|Traceback" || true

say "3/4 photographs — 115"
bash blender/run.sh blender/photos/still.py -- --all --res 1100 --samples 36 --skip-existing \
    2>&1 | grep -E "^still:|Error|Traceback" || true
say "developing the negatives"
python3 blender/photos/develop.py --all 2>&1 | tail -3

say "4/4 paper stocks, dusk — the half the library has never had"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 3 2>&1 | grep -E "^paper:|Error|Traceback" || true

say "packing the display-resolution set"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -2
say "the queue is finished"
