#!/usr/bin/env bash
# tools/render_queue6.sh — the library re-rendered under the corrected day illuminant.
#
#   setsid bash tools/render_queue6.sh > /path/queue6.log 2>&1 < /dev/null &
#
# Why this exists: blender/rig/common.py's day illuminant was a 6125 K sun annotated "~5200 K"
# under an open-sky fill that cancelled it, and everything in assets/ was rendered through it. The
# rig is fixed; the library has to catch up, and the library is 400-odd files on four cores, which
# is more than one firing of the loop has. So the backlog is a script rather than a list of
# commands in a journal, ordered by how much of a screen each family actually covers, and every
# family is idempotent: a firing that dies part way is resumed by running this again.
#
# setsid, because three earlier attempts at a backlog this size were killed part way through by a
# stray process-group signal (tools/render_queue.sh records that); and no pgrep or pkill anywhere,
# because a pattern that matches your own command line has ended three sessions in this container.
#
# ONLY the day condition is re-rendered. The dusk rig is untouched by this change and its assets
# already carry three to five times the chroma of their day twins, which was the clue in the first
# place.
#
# assets/folds is deliberately NOT here, and that is a judgement rather than an oversight. It is
# 240 frames, the largest family in the build, and it feeds 06_unfolding.mp4 alone —
# tools/check/palette.py reads stills, so not one of the chroma floors this change exists to reach
# can see a single frame of it. It is owed a pass and it is owed it after everything a still can
# see. Whoever picks this up: add it as step 5, or run it on its own.
#     bash blender/run.sh blender/folds/fold.py -- --all --res 540 --samples 16 --condition day
set -uo pipefail
cd "$(dirname "$0")/.."
STAMP() { date -u +%H:%M:%S; }
say() { echo "[$(STAMP)] $*"; }
run() { bash blender/run.sh "$@" 2>&1 | grep -E "^(paper|object|bit|still|fold|tear|desk):|Error|Traceback" || true; }

say "== render_queue6: the library under the 5200 K room =="
python3 tools/check/illuminant.py || { echo "the rig does not pass its own gate; not rendering"; exit 2; }

say "1/4 objects — the accent carriers, 26 of them, day only"
run blender/objects/objects.py -- --all --res 1200 --samples 64 --conditions day
say "objects done"

say "2/4 bits — clips, staples, tape, day only"
run blender/bits/bits.py -- --all --res 600 --samples 18
say "bits done"

say "3/4 tears — the lit torn edge of every note, day only"
run blender/paper/tear_relief.py -- --all --res 1400
say "tears done"

say "4/4 photographs — 115, and the largest single family after folds"
run blender/photos/still.py -- --all --res 1100 --samples 36
say "photos done"

say "== render_queue6 complete =="
