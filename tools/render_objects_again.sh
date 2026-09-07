#!/usr/bin/env bash
# The six feeling objects whose geometry changed after the queue had already started rendering with
# the old script. Run after tools/render_cycle6.sh's object stage.
#
#   setsid bash tools/render_objects_again.sh > /path/again.log 2>&1 < /dev/null &
set -uo pipefail
cd "$(dirname "$0")/.."
echo "[$(date -u +%H:%M:%S)] the six that changed shape — day and dusk, beauty and shadow"
bash blender/run.sh blender/objects/objects.py -- \
    --only obj_plane obj_boat obj_candle obj_pinch obj_bookmark obj_dog_ear \
    --res 1200 --samples 48 2>&1 | grep -E "^object:|Error|Traceback" || true
echo "[$(date -u +%H:%M:%S)] packing"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -1
echo "[$(date -u +%H:%M:%S)] done"
