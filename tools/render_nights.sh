#!/usr/bin/env bash
# tools/render_nights.sh — the eighteen night photographs, re-exposed with the lamp in the room.
set -uo pipefail
cd "$(dirname "$0")/.."
. ./toolchain/env.sh
say() { echo "[$(date +%H:%M:%S)] $*"; }
say "the eighteen night photographs"
bash blender/run.sh blender/photos/still.py -- --all --res 1000 --samples 28 --skip-existing \
    2>&1 | grep -E "^still:|Error|Traceback" || true
say "developing them"
python3 blender/photos/develop.py --all 2>&1 | tail -8
say "photographs on disk: $(ls seed/photos/*.jpg 2>/dev/null | wc -l)"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -2
python3 tools/check/manifest.py --fill 2>&1 | tail -1
say "the nights are done"
