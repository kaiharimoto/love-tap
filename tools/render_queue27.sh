#!/usr/bin/env bash
# tools/render_queue27.sh — the dusk twin of tools/render_queue26.sh.
#
#   setsid bash tools/render_queue27.sh > /path/queue27.log 2>&1 < /dev/null &
#
# Why: firing 26 added `albedo_tooth` and a per-stock `albedo` to STOCK_LOOK, then re-rendered
# ONLY `--condition day`. The albedo applies to both conditions, so the 23 dusk sheets still carry
# the tooth the library shipped with. That is the-dusk-paper-still-carries-the-old-tooth, filed by
# firing 26 as the half of its own work it did not do. This script is that half.
#
# It is deliberately a copy of render_queue26.sh with one word changed rather than a parameterised
# rewrite of it: render_queue26.sh is the script that produced the committed day library, editing
# it would make that provenance unreadable, and bash reads a running script incrementally so an
# edit to a file a later firing is mid-run on corrupts the run.
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
# graph is not in this queue for the same reason it was not in queue26's: it ships at albedo 1.0
# because it already clears the floor untouched, so its renders would be byte-identical to what is
# committed and the bundle would pay for nothing.
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
    f=$(printf "assets/paper/%s_%02d_dusk.webp" "$s" "$v")
    if ! git diff --quiet -- "$f" 2>/dev/null; then
      say "skip $f (already re-rendered in this working tree)"
      continue
    fi
    say "render $f"
    bash blender/run.sh blender/paper/stocks.py -- --stock "$s" --variant "$v" \
        --res 1800 --samples 48 --condition dusk --format WEBP 2>&1 \
        | grep -E "^paper:|rendered|Error|Traceback" || true
  done
  say "STOCK DONE $s"
done
say "QUEUE27 DONE"
