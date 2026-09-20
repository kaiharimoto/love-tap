#!/usr/bin/env python3
"""HF_std: how much high-frequency detail a sheet of paper carries, as one number.

    python3 tools/check/hf_std.py                                  # every strip in evidence/crops
    python3 tools/check/hf_std.py evidence/crops/06_unfolding_strip.png
    python3 tools/check/hf_std.py evidence/13_messenger_states.png --box 200,1350,300,120
    python3 tools/check/hf_std.py --out evidence/logs/hf_std.json

`the-unfolding-clip-shows-a-flat-rectangle-for-two-thirds-of-its-frames` — rank 1, the highest
value item in the build — has been quoting HF_std since firing 18, in four of its five clauses and
in three separate remeasurements. **No committed tool has ever defined it.** Firing 28 read the
strip clause for the first time, got 14.4 to 15.1 against a floor of 4, and wrote the definition
out in prose beside the number because there was nothing to point at. A measurement that only
exists in prose is a claim: nobody can re-run it, nobody can re-break it, and the next firing that
quotes the number is quoting a firing rather than a ruler. This file is that definition, committed,
so the number becomes a measurement.

THE DEFINITION, which is firing 28's, unchanged, and is stated here once so it stops moving:

    L        the frame as 8-bit luminance, PIL's `convert("L")` — the same L that
             `flat_fill.py` and `paper_tooth.py` read, so the three tables are commensurable
    HF       L minus a 2-px Gaussian blur of L: everything the blur throws away, which is
             the tooth, the fibre, the printed rules and the ink edges
    the mask the brightest 45% of L, "which on every artifact in this set is the sheet"
    HF_std   the standard deviation of HF over that mask

IT IS COMMITTED UNCHANGED AND IT DOES NOT WORK ON A STRIP, AND THAT IS THE POINT OF THIS FILE.
The definition is faithful and the number reproduces — this file returns 14.317 to 15.088 on
`06_unfolding_strip.png`, which is firing 28's "14.4 to 15.1" to the tenth. Making it re-runnable
is what showed what it is:

  * `git show 92d7b5a:evidence/crops/06_unfolding_strip.png` is the strip from the era when the
    fold sheet WAS the blank, unruled, square-cornered rectangle this whole item was filed on.
    It reads **14.609 to 15.635 — HIGHER than today's fixed sheet.** The clause scores the defect
    above the repair.
  * A synthetic flat beige rectangle on a dark ground, with not one pixel of tooth anywhere in it,
    reads **14.372**. `hf_std_selftest.py` keeps that standing.
  * Erode the mask by 2 px and 06_unfolding's frames collapse from 14.3-15.1 to 3.7-4.8, on 1,173
    surviving pixels of 22,665. Almost the whole number is the mask's own boundary.

THE REASON IS THE LINE IN QUOTES ABOVE, and it is a premise rather than a bug. "The brightest 45%
of the frame, which is the sheet" holds for a frame that is a sheet of paper on a dark desk. A
`frames.py` strip frame is not that: it is a whole 1440-px phone screen reduced to 148 px, pale
almost edge to edge, with notes, printed rules, handwriting, a search bar and a nav row in it. The
brightest 45% of THAT is a scattered brightness slice through a busy interface, and HF over a
scattered mask is mostly the scatter. The number rises with ink and chrome and falls with neither
flatness nor tooth.

So it measures what it says on a box that is all sheet, and not on a strip frame. The same
`git show 92d7b5a` still, read with `--box 200,1350,300,120` — rank 1's own sample, wholly inside
the note — reads **0.506** against today's **8.454**, a sixteen-fold move on the real defect and
the real repair. That reading discriminates. The strip reading does not.

WHAT THIS FILE IS THEREFORE FOR, and what it is not. It is the definition, committed, so that a
number quoted from it can be re-run and re-broken. **It is deliberately NOT wired into
`capture.sh`**, because a gate that passes a flat beige rectangle is the `surfaces.py` failure
this repository has already filed once (`the-folds-floor-passes-a-blank-sheet`, a floor of 1.2 that
a blank unruled sheet cleared for four firings) and adding a second one is not progress. Re-specify
the mask and it can be a gate; that is a measurement definition, so it is ADDRESS's to set and not
IMPLEMENT's to choose, and it is filed as `hf-std-on-a-strip-frame-does-not-measure-the-sheet`.

WHAT IT ALSO CANNOT TELL YOU, on any input. HF_std is not resolution-invariant: reducing an image
moves energy across the band the 2-px blur cuts at. A reading is comparable with another taken at
the SAME size and not across sizes, which is why every reading records the size it was taken at.
Firing 19's `0.446` and firing 28's `14.4` were never the same measurement twice.

Exits 0 if every frame read clears the floor and 2 if any does not, so it can be used as a gate
once its mask is fixed. Until then a pass on a strip means nothing; read the `--box` rows.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# the definition, in three constants
BLUR_RADIUS = 2.0
# "the brightest 45% of the frame, which is the sheet"
SHEET_SHARE = 0.45
# the floor rank 1's strip clause names
FLOOR = 4.0

# tools/check/frames.py strip(): frames are pasted `height` tall with a 4-px gutter between them,
# on a sheet pre-filled with the desk colour. Read from there rather than guessed, and verified
# against the image, so a change to one is caught here rather than silently mis-splitting.
GUTTER = 4
GUTTER_RGB = (28, 24, 20)


def hf_std(im):
    """The definition above, over one image. Returns the number and what it was taken over."""
    grey = im.convert("L")
    L = np.asarray(grey, dtype=np.float64)
    hf = L - np.asarray(grey.filter(ImageFilter.GaussianBlur(BLUR_RADIUS)), dtype=np.float64)
    threshold = float(np.percentile(L, 100.0 * (1.0 - SHEET_SHARE)))
    sheet = L >= threshold
    return {
        "size": [im.width, im.height],
        "hf_std": round(float(hf[sheet].std()), 3),
        "sheet_threshold": round(threshold, 1),
        "sheet_px": int(sheet.sum()),
        "whole_frame_hf_std": round(float(hf.std()), 3),
    }


def gutters(rgb):
    """The x of every full-height column that is exactly the gutter colour.

    Derived rather than assumed: `strip()` writes six frames today and a successor that writes a
    different number, or pads differently, should not silently be read as six.
    """
    exact = np.all(rgb == np.array(GUTTER_RGB, dtype=rgb.dtype), axis=2).all(axis=0)
    return [int(x) for x in np.where(exact)[0]]


def split(im):
    """A strip into its frames, on the gutters. Returns [] when the image is not a strip."""
    rgb = np.asarray(im.convert("RGB"))
    cols = gutters(rgb)
    if not cols:
        return []
    runs, start = [], cols[0]
    for a, b in zip(cols, cols[1:] + [-99]):
        if b != a + 1:
            runs.append((start, a))
            start = b
    # a run that is not GUTTER wide is not a gutter between two frames; refuse rather than guess
    if not runs or any(hi - lo + 1 != GUTTER for lo, hi in runs):
        return []
    starts = [0] + [hi + 1 for _, hi in runs]
    ends = [lo for lo, _ in runs] + [im.width]
    return [im.crop((a, 0, b, im.height)) for a, b in zip(starts, ends) if b > a]


def read(path, box=None, floor=FLOOR):
    im = Image.open(path)
    if box is not None:
        x, y, w, h = box
        frames = [im.crop((x, y, x + w, y + h))]
        kind = "box"
    else:
        frames = split(im)
        kind = "strip"
        if not frames:
            frames, kind = [im], "whole"
    each = [hf_std(f) for f in frames]
    under = [i for i, e in enumerate(each) if e["hf_std"] < floor]
    problems = []
    if under:
        problems.append(
            "%d of %d frames read under HF_std %.1f: %s"
            % (len(under), len(each), floor,
               ", ".join("frame %d at %.3f" % (i, each[i]["hf_std"]) for i in under)))
    stds = sorted(e["hf_std"] for e in each)
    return {
        "of": os.path.relpath(path, ROOT),
        "read_as": kind,
        "box": list(box) if box else None,
        "frames": len(each),
        "min_hf_std": stds[0],
        "max_hf_std": stds[-1],
        "median_hf_std": stds[len(stds) // 2],
        "each": each,
        "problems": problems,
        "ok": not problems,
    }


def parse_box(s):
    parts = [int(v) for v in s.replace(" ", "").split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("--box wants x,y,w,h")
    return tuple(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="*", help="default: every *_strip.png in evidence/crops")
    ap.add_argument("--box", type=parse_box, default=None,
                    help="x,y,w,h — read one region of one still instead of splitting a strip")
    ap.add_argument("--floor", type=float, default=FLOOR)
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    paths = a.images or sorted(glob.glob(os.path.join(ROOT, "evidence", "crops", "*_strip.png")))
    if not paths:
        # reading nothing is an error, not a pass: cc078d7 made that the rule for every gate here
        print("hf_std: no images to read", file=sys.stderr)
        return 2
    if a.box is not None and len(paths) != 1:
        print("hf_std: --box reads one still, not %d" % len(paths), file=sys.stderr)
        return 2
    results = [read(p, a.box, a.floor) for p in paths]
    report = {
        "definition": {"blur_radius": BLUR_RADIUS, "sheet_share": SHEET_SHARE, "floor": a.floor,
                       "of": "std of (L - gaussian(L, r)) over the brightest `sheet_share` of L"},
        "images": results,
        "ok": all(r["ok"] for r in results),
    }
    if a.out:
        os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
        with open(a.out, "w") as fh:
            json.dump(report, fh, indent=1)
    for r in results:
        print("%s %-34s %s %d frame(s) at %dx%d  HF_std %.3f..%.3f  median %.3f"
              % ("ok" if r["ok"] else "--", os.path.basename(r["of"]), r["read_as"],
                 r["frames"], r["each"][0]["size"][0], r["each"][0]["size"][1],
                 r["min_hf_std"], r["max_hf_std"], r["median_hf_std"]))
        for p in r["problems"]:
            print("     %s" % p)
    return 0 if report["ok"] else 2


if __name__ == "__main__":
    sys.exit(main())
