#!/usr/bin/env bash
# tools/render_dusk.sh — the dusk half of the paper library, and then the packing.
set -uo pipefail
cd "$(dirname "$0")/.."
. ./toolchain/env.sh
say() { echo "[$(date +%H:%M:%S)] $*"; }
say "paper stocks, dusk — 27 sheets at three stops down"
bash blender/run.sh blender/paper/stocks.py -- --all --res 1800 --samples 48 \
    --condition dusk --threads 3 2>&1 | grep -E "^paper:|Error|Traceback" || true
say "dusk sheets on disk: $(ls assets/paper/*_dusk.webp 2>/dev/null | wc -l)"
say "packing the display-resolution set"
python3 tools/pack_assets.py --seed=year 2>&1 | tail -3
python3 tools/check/manifest.py --fill 2>&1 | tail -2
say "the queue is finished"
