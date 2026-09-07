#!/usr/bin/env bash
# What a critic may see, and what it may not.
#
#   bash tools/critics.sh hide 6     # before the critics run
#   bash tools/critics.sh show 6     # after they have written their reports
#
# BRIEFING.md tells every critic that `evidence/SCORE.json` and `evidence/critics/<n>/` are another
# reader's conclusions and not evidence. Telling is not enough — a fresh context asked to look at
# everything under evidence/ will open them — so they are moved out of the tree while the critics
# work and put back afterwards. The cycle's own directory has to stay (they write into it), so what
# moves out of it is the builder's own sheet, which is the most contaminating document of all: it
# says what was fixed and what it measured.
set -euo pipefail
cd "$(dirname "$0")/.."
action="${1:-}"
cycle="${2:-}"
hold=".critics-hold"
[ -n "$action" ] && [ -n "$cycle" ] || { echo "usage: critics.sh hide|show <cycle>" >&2; exit 2; }

case "$action" in
  hide)
    mkdir -p "$hold"
    [ -f evidence/SCORE.json ] && mv evidence/SCORE.json "$hold/"
    for n in $(seq 1 $((cycle - 1))); do
      [ -d "evidence/critics/$n" ] && mv "evidence/critics/$n" "$hold/critics_$n"
    done
    [ -f "evidence/critics/$cycle/measurements.md" ] && \
      mv "evidence/critics/$cycle/measurements.md" "$hold/measurements.md"
    mkdir -p "evidence/critics/$cycle"
    echo "held: $(ls -A "$hold" | tr '\n' ' ')"
    ;;
  show)
    [ -d "$hold" ] || { echo "nothing was held"; exit 0; }
    [ -f "$hold/SCORE.json" ] && mv "$hold/SCORE.json" evidence/
    for d in "$hold"/critics_*; do
      [ -d "$d" ] || continue
      mv "$d" "evidence/critics/$(basename "$d" | sed 's/^critics_//')"
    done
    [ -f "$hold/measurements.md" ] && mv "$hold/measurements.md" "evidence/critics/$cycle/"
    rmdir "$hold" 2>/dev/null || true
    echo "restored"
    ;;
  *) echo "usage: critics.sh hide|show <cycle>" >&2; exit 2 ;;
esac
