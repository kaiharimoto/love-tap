#!/usr/bin/env bash
# tools/render_queue6.sh — the library re-rendered under the corrected day illuminant.
#
#   setsid bash tools/render_queue6.sh > /path/queue6.log 2>&1 < /dev/null &
#
# Why this exists: blender/rig/common.py's day illuminant was a 6125 K sun annotated "~5200 K"
# under an open-sky fill that cancelled it, and everything in assets/ was rendered through it. The
# rig is fixed at a6f46fd; the library has to catch up, and the library is 400-odd files on four
# cores, which is more than one firing of the loop has.
#
# setsid, because three earlier attempts at a backlog this size were killed part way through by a
# stray process-group signal (tools/render_queue.sh records that); and no pgrep or pkill anywhere,
# because a pattern that matches your own command line has ended three sessions in this container.
#
# TO STOP THIS RUN, in this order, and the order is the whole of it:
#
#   kill -9 <pid of this script>     # FIRST, so it cannot advance to the next family
#   kill -9 <pid of blender>         # then the render
#   git ls-files -d -- assets seed/photos | xargs -r git checkout --
#
# Read both pids out of `ps`. Killing blender first lets `run` return normally, the script walks on
# to the next family, prunes it, and only then takes the signal — firing 5 did exactly that and
# deleted every tear in the library on its way out. The last line is not optional tidying; it is
# what puts back anything pruned but not yet rendered.
#
# That last line used to read `git checkout -- assets seed/photos`, and firing 6 lost three finished
# tears to it. `git checkout -- <dir>` restores every MODIFIED file in the directory as well as
# every deleted one, so it does not put back what was pruned — it throws away what was rendered.
# Restore the deleted paths and nothing else, which is what restore_missing below has always done
# and what the header should always have said. Commit finished work before stopping a run anyway:
# a pushed commit is the only thing here that a mistake at this step cannot reach.
#
# ONLY the day condition is re-rendered. The dusk rig is untouched by this change and its assets
# already carry three to five times the chroma of their day twins, which was the clue in the first
# place.
#
# assets/folds is deliberately NOT here, and that is a judgement rather than an oversight. It is
# 240 frames, the largest family in the build, and it feeds 06_unfolding.mp4 alone —
# tools/check/palette.py reads stills, so not one of the chroma floors this change exists to reach
# can see a single frame of it. It is owed a pass and it is owed it after everything a still can
# see. Whoever picks this up: add it as a step, or run it on its own.
#     bash blender/run.sh blender/folds/fold.py -- --all --res 540 --samples 16 --condition day
set -uo pipefail
cd "$(dirname "$0")/.."
STAMP() { date -u +%H:%M:%S; }
say() { echo "[$(STAMP)] $*"; }
# bits.py prints "bits:", not "bit:", so this filter swallowed every line that family wrote and
# firing 7 watched the step pass in one second with nothing in the log at all.
run() { bash blender/run.sh "$@" 2>&1 | grep -E "^(paper|object|bits?|still|fold|tear|desk):|Error|Traceback" || true; }

# The commit that corrected the day illuminant. A file touched at or after this is already relit.
RIG_COMMIT=a6f46fd

# ---- resuming, and why it is done through git rather than through mtime --------------------
#
# Firing 5 lost forty minutes of tear renders learning this. The generators all take
# --skip-existing, but skip-existing skips a file because it EXISTS, and every file in this library
# exists — they are all wrong, not all missing. And mtime cannot tell warm from cool either: a
# firing runs in a fresh container that cloned the repo, so every file carries its checkout time
# and they are all identical. The only durable record of which assets have been relit is git.
#
# So: a file is already relit if the working tree has it modified, or if it changed in some commit
# between RIG_COMMIT and HEAD. Everything else in the family is stale, is deleted, and is then the
# only thing --skip-existing will render. That makes a family resumable at file granularity, which
# is what matters when one family is four hours and one firing is not.
#
# The deletion is the part to understand before running this. Between the delete and the render a
# family's stale files are absent from the working tree. They are all committed and nothing here
# ever commits, so nothing is ever lost — but a file can be deleted and then NOT come back, and
# that case was real rather than theoretical: assets/objects/obj_heart_fold.png was in the library
# and was not in blender/objects/objects.py's list of twenty-five objects, so pruning it and
# running the generator would have removed an asset permanently from the working tree. Firing 6
# retired heart_fold — obj_pinch had replaced it in the app and only two documents still named it —
# and taught tools/check/manifest.py to fail on an entry whose generator cannot build it, so the
# library no longer holds a file with no maker. restore_missing stays, because the next one of
# those is found by this script and not by the gate: after every generator run, and on the way out
# of a killed run, anything still deleted was not regenerated and is put straight back. If this script is ever killed between
# the two, the recovery is one command:
#
#     git checkout -- assets/ seed/photos
#
restore_missing() {
  local n=0
  while IFS= read -r f; do git checkout -- "$f" && n=$((n+1)); done < <(git ls-files -d -- assets seed/photos)
  [ "$n" -gt 0 ] && say "  restored $n file(s) the generator did not rebuild"
  return 0
}
trap restore_missing EXIT INT TERM

prune_stale() {   # prune_stale <dir> <find-expression...>
  local dir="$1"; shift
  local relit
  relit="$(mktemp)"
  { git diff --name-only "$RIG_COMMIT"..HEAD -- "$dir"
    git diff --name-only -- "$dir"; } | sort -u > "$relit"
  local kept=0 dropped=0
  while IFS= read -r f; do
    if grep -qxF "$f" "$relit"; then kept=$((kept+1)); else rm -f "$f"; dropped=$((dropped+1)); fi
  done < <(find "$dir" "$@" -type f | sort)
  rm -f "$relit"
  say "  $dir: $kept already relit, $dropped to render"
}

say "== render_queue6: the library under the 5200 K room =="
python3 tools/check/illuminant.py || { echo "the rig does not pass its own gate; not rendering"; exit 2; }

# Ordered by how much of a screen the family actually covers, which is NOT the same as how many
# files it has. Firing 5 got this wrong the first time and put tears third: tears are a two
# millimetre band along a torn edge, while the photographs ARE the whole of 04_moments and
# 14_media_viewer — the two stills that fail the ground chroma floor hardest. Photographs first.

# The photographs are TWO phases and the second one is not optional. still.py renders a .exr per
# shot and develop.py is what turns the negatives into the .jpg the app actually loads. Firing 5
# left develop.py out, so a run that had rendered fourteen negatives had produced zero usable
# photographs. Budget for it: about 45 seconds a negative on four cores, so 115 of them is ninety
# minutes before a single jpg exists, and the .exr files are gitignored and die with the container.
# This family is therefore all-or-nothing WITHIN a firing. Do not start it with under two hours.
say "1/3 photographs — 115, and they are the content of the two worst stills in the set"
prune_stale seed/photos -name '*.jpg'
run blender/photos/still.py -- --all --res 1100 --samples 36 --skip-existing
say "developing the negatives"
python3 blender/photos/develop.py --all 2>&1 | tail -3
restore_missing
say "photographs done"

# Measured at firing 5: about four minutes a tear, 57 of them, so the better part of four hours.
# Resumable at file granularity through prune_stale, so it is the right family to leave running in
# whatever a firing has left over.
# --conditions day is load-bearing and was missing until firing 6. tear_relief.py defaults to
# "day,dusk", and --skip-existing tests only tear_NNN_edge.png, so pruning a day edge made the
# generator render that tear's dusk shadow too: a third of the wall clock on this family, spent on
# the condition this backlog exists to leave alone. It also explains a stray in the library —
# assets/tears holds four *_shadow_dusk.png, for tears 001-004 and no others, which is exactly the
# four firing 5 rendered before it ran out of lease. Nothing reads them; they are the side effect,
# not the asset. Measured here: 6.5 minutes a tear with dusk, and the header's four without it.
say "2/3 tears — the lit torn edge of every note, day only. About four minutes apiece."
prune_stale assets/tears -name 'tear_*_edge.png' -o -name 'tear_*_shadow.png' ! -name '*dusk*'
run blender/paper/tear_relief.py -- --all --res 1400 --conditions day --skip-existing
restore_missing
say "tears done"

say "3/3 a sweep for anything the earlier families missed"
prune_stale assets/objects -name 'obj_*.png' ! -name '*dusk*'
run blender/objects/objects.py -- --all --res 1200 --samples 64 --conditions day --skip-existing
prune_stale assets/bits -name '*.png' ! -name '*dusk*'
run blender/bits/bits.py -- --all --res 600 --samples 18 --conditions day --skip-existing
restore_missing
say "sweep done"

say "== render_queue6 complete =="
