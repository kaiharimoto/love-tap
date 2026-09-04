#!/usr/bin/env python3
"""Nothing in the library is a flat fill.

    python3 tools/check/surfaces.py
    python3 tools/check/surfaces.py --out evidence/logs/surfaces.json

The whole visual concept is that a surface is a photograph of a real material, and the way that
fails is not dramatic: a render comes out of Blender with a map that did not reach the shader, or a
plate is left behind from before a fix, and it is a smooth field of one colour with a bit of shading
on it. Nobody notices, because it looks approximately like the thing.

Two of those went a long way in this build. A blank patch of paper carried 0.44 grey levels of
high-frequency variation — less than the desk under it — because the tooth was modelled as a bump
too fine for the renderer to resolve. And the desk itself carried 0.57 levels over a two hundred
pixel patch, four unique values in the whole square, because the plate on disk had been rendered
before the wood was finished and nothing ever re-rendered it: every artifact in the evidence set
had a flat brown field behind it for the entire build.

So each surface is read the way a person reads it — a patch at a time, at the size it is shown at —
and asked whether it has anything in it.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(ROOT, "app", "assets")

# grey levels of variation inside one patch, at 8 bits. These are floors, not targets: paper is
# meant to be quiet and wood is not, so they differ by what the material is.
FLOORS = {
    "paper": 1.2,      # tooth and fibre: quiet, but never nothing
    "shell": 4.0,      # a desk is wood, and wood has figure in it
    "objects": 2.0,    # a rendered thing has form; a flat one has not been lit
}
PATCH = 200


def patches(a):
    """A few squares spread over the image, avoiding the edges where a render falls off."""
    h, w = a.shape
    side = min(PATCH, h // 2, w // 2)
    if side < 40:
        yield a
        return
    ys = np.linspace(h * 0.12, h * 0.88 - side, 3).astype(int)
    xs = np.linspace(w * 0.12, w * 0.88 - side, 3).astype(int)
    for y in ys:
        for x in xs:
            yield a[y:y + side, x:x + side]


def read(path):
    """The image as grey, with anything transparent removed and the rest cropped to itself.

    A rendered object is a small thing in the middle of a big transparent frame, so reading the
    frame would be reading mostly nothing. What is measured is the material: the bounding box of
    what is actually opaque, with the transparent pixels inside it left out of the arithmetic.
    """
    with Image.open(path) as im:
        if im.mode not in ("RGBA", "LA"):
            return np.asarray(im.convert("L")).astype(float)
        alpha = np.asarray(im.convert("RGBA"))[..., 3]
        grey = np.asarray(im.convert("L")).astype(float)
    solid = alpha > 200
    if solid.sum() < 4000:
        return None
    rows = np.where(solid.any(axis=1))[0]
    cols = np.where(solid.any(axis=0))[0]
    grey = np.where(solid, grey, np.nan)
    return grey[rows.min():rows.max() + 1, cols.min():cols.max() + 1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--floor", type=float, default=0.0, help="override every floor")
    args = ap.parse_args()

    report = {"floors": FLOORS, "surfaces": {}, "flat": []}
    for family, floor in FLOORS.items():
        if args.floor:
            floor = args.floor
        for path in sorted(glob.glob(os.path.join(ASSETS, family, "*.webp"))):
            name = os.path.basename(path)
            if "_shadow" in name or "_mask" in name:
                continue      # a shadow is meant to be smooth; that is what a shadow is
            a = read(path)
            if a is None:
                continue
            best = 0.0
            for p in patches(a):
                p = p[~np.isnan(p)]
                if p.size < 250:
                    continue
                best = max(best, float(p.std()))
            entry = {"family": family, "patch_std": round(best, 3), "floor": floor}
            report["surfaces"][f"{family}/{name}"] = entry
            if best < floor:
                report["flat"].append(f"{family}/{name}: {best:.3f} < {floor}")

    report["read"] = len(report["surfaces"])
    report["ok"] = not report["flat"]
    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)
    if report["flat"]:
        print(f"{len(report['flat'])} surface(s) with nothing in them:", file=sys.stderr)
        for line in report["flat"][:12]:
            print("  " + line, file=sys.stderr)
        return 1
    print(f"{report['read']} surfaces read, none of them flat")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
