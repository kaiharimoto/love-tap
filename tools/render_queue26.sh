#!/usr/bin/env bash
# tools/render_queue26.sh — assets/paper re-rendered with the per-stock albedo tooth.
#
#   setsid bash tools/render_queue26.sh > /path/queue26.log 2>&1 < /dev/null &
#
# Why: firing 26 measured that `tooth` cannot be raised (it scales the bump too, and past ~1.2 the
# bump darkens the sheet faster than the mottle textures it) and added `albedo_tooth`, which scales
# the mottle alone. STOCK_LOOK now carries a per-stock `albedo`. The library has to catch up.
# tools/paper_tooth_sweep.md is the evidence; blender/paper/stocks.py is the table.
#
# setsid, and no pgrep or pkill anywhere — a pattern that matches your own command line has ended
# three sessions in this container. To stop a run, in this order and the order is the whole of it:
#
#   kill -9 <pid of this script>     # FIRST, so it cannot advance to the next stock
#   kill -9 <pid of blender>         # then the render
#   git ls-files -d -- assets/paper | xargs -r git checkout --
#
# Killing blender first lets the render return normally and the script walks on. The last line
# restores DELETED paths only; `git checkout -- assets/paper` would throw away what was rendered.
#
# ONLY the day condition, and only the stocks whose albedo actually changed.
#   - graph ships at albedo 1.0 because it already passes the floor at 8.755 untouched, so its
#     renders are byte-identical to what is committed and it is not in this queue.
#   - dusk is owed the same pass and is NOT here. A screen is either a day screen or a dusk screen,
#     never both, so a day-only pass is self-consistent on every surface a person looks at, which
#     is the same judgement tools/render_queue6.sh made for the illuminant. It is owed and it is
#     recorded as owed.
#
# Resumable at file granularity, through git rather than mtime: every file in this library exists
# and they are all wrong rather than all missing, and a fresh container gives every file the same
# checkout time. A file is done if the working tree has it modified. Nothing here ever commits;
# commit finished stocks as they land, because a pushed commit is the only durable unit here.
set -uo pipefail
cd "$(dirname "$0")/.."
STAMP() { date -u +%H:%M:%S; }
say() { echo "[$(STAMP)] $*"; }

# writing papers first: they are the app's dominant surface and the stocks the 8.0 floor is about.
STOCKS="lined spiral looseleaf legal index sticky_yellow sticky_pink sticky_blue receipt"
declare -A NVAR=( [lined]=4 [spiral]=4 [looseleaf]=4 [legal]=2 [index]=2 \
                  [sticky_yellow]=2 [sticky_pink]=2 [sticky_blue]=2 [receipt]=1 )

for s in $STOCKS; do
  for ((v=1; v<=${NVAR[$s]}; v++)); do
    f=$(printf "assets/paper/%s_%02d.webp" "$s" "$v")
    if ! git diff --quiet -- "$f" 2>/dev/null; then
      say "skip $f (already re-rendered in this working tree)"
      continue
    fi
    say "render $f"
    bash blender/run.sh blender/paper/stocks.py -- --stock "$s" --variant "$v" \
        --res 1800 --samples 48 --condition day --format WEBP 2>&1 \
        | grep -E "^paper:|rendered|Error|Traceback" || true
  done
  say "STOCK DONE $s"
done
say "QUEUE26 DONE"
