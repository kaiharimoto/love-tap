#!/usr/bin/env bash
# Re-render the paper stocks big enough for the pieces the app actually draws.
#
# A full-width piece in the capture viewport is 1,356 device pixels across (452 logical points at
# three device pixels a point) and the A5 stocks were 1,288 wide, so every full-width sheet was
# enlarged — measured at 1.17x on the Settings console sheet, which took its tooth from 2.52 grey
# levels to 1.26. The short side has to clear 1,356 x 1.12 (the stockScale overscan) = 1,519.
#
#   A5 (148x210):   long side 2200 -> 1550 x 2200
#   index (127x76): long side 2560 -> 2560 x 1531
#   receipt (80x180): long side 3420 -> 1520 x 3420
#   stickies are 1800 x 1800 already
set -u
cd "$(dirname "$0")/.."
run() { BLENDER_THREADS=${BLENDER_THREADS:-4} bash blender/run.sh blender/paper/stocks.py -- "$@"; }
for s in lined graph spiral looseleaf; do
  for v in 1 2 3 4; do
    run --stock "$s" --variant "$v" --condition both --res 2200 || exit 1
  done
done
for v in 1 2; do run --stock legal --variant "$v" --condition both --res 2200 || exit 1; done
for v in 1 2; do run --stock index --variant "$v" --condition both --res 2560 || exit 1; done
run --stock receipt --variant 1 --condition both --res 3420 || exit 1
echo "STOCKS DONE"
