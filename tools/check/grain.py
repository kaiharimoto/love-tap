#!/usr/bin/env python3
"""Wood has to happen in both directions.

    python3 tools/check/grain.py --out evidence/logs/grain.json

A flat-sawn board has rings running across it and, along those rings, vessels and rays that break
them up. Draw only the rings and you get a comb: a set of stripes, which is what four cycles of
this desk were. It is measurable and it was measured — 128 px tiles of the exposed wood on
10_first_run.png gave a mean absolute gradient of 3.005 across the grain and 0.662 along it, a
ratio of 4.54, while the paper in the same picture reads 4.13 and 4.37 and a ratio near 1. An
anti-goal critic found the same thing from the other end: the horizontal power spectrum of that
region has a dominant band at a 20.3 px period with a peak-to-median ratio of 6701 to 1.

So this reads the desk texture itself — not a still, which has paper all over it — and reports the
two gradients and their ratio. It fails when the ratio goes above `--max-ratio`, which is set at
what the asset measures now plus a little, so the next change cannot quietly put the stripes back.
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def gradients(path, tile=128):
    import numpy as np
    from PIL import Image
    with Image.open(path) as im:
        a = np.asarray(im.convert("L"), dtype=np.float32)
    h, w = a.shape
    across, along = [], []
    for y in range(0, h - tile, tile):
        for x in range(0, w - tile, tile):
            t = a[y:y + tile, x:x + tile]
            # the grain runs down the board, so "across" is column to column
            across.append(float(np.abs(np.diff(t, axis=1)).mean()))
            along.append(float(np.abs(np.diff(t, axis=0)).mean()))
    return float(np.median(across)), float(np.median(along)), len(across)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--max-ratio", type=float, default=3.6)
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    files = a.files or [os.path.join(ROOT, "assets", "shell", n)
                        for n in ("desk.png", "desk_dusk.png")]
    files = [f for f in files if os.path.exists(f)] or [
        os.path.join(ROOT, "app", "assets", "shell", n) for n in ("desk.webp", "desk_dusk.webp")]
    report = {
        "tile": 128,
        "how": "mean absolute first difference inside 128 px tiles, column to column (across the "
               "grain) and row to row (along it), median over the tiles",
        "max_ratio": a.max_ratio,
        "why": "a board with only rings on it is a comb. Vessels and rays are what happens along "
               "the grain, and without them the surface reads as stripes rather than as a cut "
               "through fibre.",
        "surfaces": {},
    }
    worst = 0.0
    for f in files:
        if not os.path.exists(f):
            continue
        across, along, n = gradients(f, a.tile if hasattr(a, "tile") else 128)
        ratio = across / along if along else 999.0
        report["surfaces"][os.path.basename(f)] = {
            "across_the_grain": round(across, 3),
            "along_the_grain": round(along, 3),
            "ratio": round(ratio, 2),
            "tiles": n,
        }
        worst = max(worst, ratio)
    report["worst_ratio"] = round(worst, 2)
    report["ok"] = bool(report["surfaces"]) and worst <= a.max_ratio
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
