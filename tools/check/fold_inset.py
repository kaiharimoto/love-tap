#!/usr/bin/env python3
"""Where the writing goes on the opened sheet, measured off the last frame of a fold sequence.

    python3 tools/check/fold_inset.py app/assets/folds/unfold_thirds

The app draws a note's text into the fold frame as it settles, and where that text may sit is a
property of the render, not a number anybody should be typing: the sheet moved in the frame the
moment the camera was tilted, and four hand-tuned fractions went on pointing at where it used to
be. This finds the paper — bright and opaque, as against its own shadow, which is neither — and
prints the four fractions with a margin, in the order FoldedNote.inset wants them.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

MARGIN_X = 0.04
MARGIN_Y = 0.05


def paper_box(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)
    h, w = a.shape[:2]
    alpha = a[..., 3]
    lum = a[..., :3].mean(axis=2)
    paper = (alpha > 160) & (lum > 150)
    if not paper.any():
        return None
    rows = np.where(paper.any(axis=1))[0]
    cols = np.where(paper.any(axis=0))[0]
    return (float(cols.min()) / w, float(rows.min()) / h,
            1.0 - float(cols.max() + 1) / w, 1.0 - float(rows.max() + 1) / h)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sequence", help="a directory of packed or rendered fold frames")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    files = sorted(f for f in os.listdir(args.sequence) if f.endswith((".png", ".webp")))
    if not files:
        print(f"no frames in {args.sequence}", file=sys.stderr)
        return 2
    last = os.path.join(args.sequence, files[-1])
    box = paper_box(last)
    if box is None:
        print(f"no paper found in {last}", file=sys.stderr)
        return 2
    l, t, r, b = box
    inset = [round(l + MARGIN_X, 3), round(t + MARGIN_Y, 3),
             round(r + MARGIN_X, 3), round(b + MARGIN_Y, 3)]
    report = {
        "sequence": os.path.basename(args.sequence.rstrip("/")),
        "measured_on": os.path.relpath(last),
        "paper_box": [round(v, 4) for v in box],
        "margin": [MARGIN_X, MARGIN_Y],
        "inset": inset,
        "writing_area": round((1 - inset[0] - inset[2]) * (1 - inset[1] - inset[3]), 4),
    }
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=1)
    print(f"{report['sequence']}: paper {box[0]:.3f}/{box[1]:.3f}/{box[2]:.3f}/{box[3]:.3f} "
          f"→ FoldedNote.inset = {inset} ({report['writing_area']:.0%} of the frame)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
