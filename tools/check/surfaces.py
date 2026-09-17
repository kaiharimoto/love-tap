#!/usr/bin/env python3
"""Nothing in the library is a flat fill.

    python3 tools/check/surfaces.py
    python3 tools/check/surfaces.py --out evidence/logs/surfaces.json
    python3 tools/check/surfaces.py --root assets      # the source library, before it is packed

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

Two things about how this file is run, both of which cost a firing.

`app/assets/` is derived and gitignored: `tools/pack_assets.py` writes it, and a fresh container
does not have one. Run with no arguments there and every glob matched nothing, so the report came
back `"read": 0, "ok": true` and exit 0 — a gate that had looked at nothing declaring nothing wrong
with it, which is the same shape of failure as the flat plate this file exists to catch. Reading
nothing is now an error in its own right (exit 2), not a pass, and `--min-read` says how many
surfaces a real run is expected to find.

`--root` picks which library is read. The default is `app/assets`, what the app actually ships and
what a capture measures. `--root assets` reads the source renders instead, which is the only form
that works before a pack and the form to use when checking a re-render — so PNG is matched as well
as WebP.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACKED = os.path.join(ROOT, "app", "assets")     # derived, gitignored, what the app ships
SOURCE = os.path.join(ROOT, "assets")            # the renders themselves, committed

# grey levels of variation inside one patch, at 8 bits. These are floors, not targets: paper is
# meant to be quiet and wood is not, so they differ by what the material is.
FLOORS = {
    "paper": 1.2,      # tooth and fibre: quiet, but never nothing
    "shell": 4.0,      # a desk is wood, and wood has figure in it
    "objects": 2.0,    # a rendered thing has form; a flat one has not been lit
    # The family this file did not read, and the one the material row is judged on. 281 of the
    # 320 frames of 06_unfolding.mp4 were a flat cream rectangle and nothing here objected,
    # because fold frames live one directory deeper than every other family -- folds/<name>/NNNN
    # -- so even naming the family was not enough on its own. Same floor as paper: a fold is
    # paper, and it has to carry the tooth the stocks carry.
    "folds": 1.2,
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
    ap.add_argument("--root", default="app/assets",
                    help="which library to read: app/assets (packed, the default) or assets (source)")
    ap.add_argument("--min-read", type=int, default=1,
                    help="fewer surfaces than this is an error, not a pass")
    args = ap.parse_args()

    assets = args.root if os.path.isabs(args.root) else os.path.join(ROOT, args.root)
    report = {"floors": FLOORS, "root": os.path.relpath(assets, ROOT), "surfaces": {}, "flat": []}
    for family, floor in FLOORS.items():
        if args.floor:
            floor = args.floor
        found = []
        for ext in ("webp", "png"):
            found += sorted(glob.glob(os.path.join(assets, family, f"*.{ext}")))
            found += sorted(glob.glob(os.path.join(assets, family, "*", f"*.{ext}")))
        for path in sorted(found):
            name = os.path.basename(path)
            # folds/<name>/NNNN sits a directory deeper than the rest
            rel = os.path.relpath(path, os.path.join(assets, family))
            name = rel if os.sep in rel else name
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
    report["enough_read"] = report["read"] >= args.min_read
    report["ok"] = report["enough_read"] and not report["flat"]
    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)
    # Read nothing, say so. This is deliberately checked before the flat list: a run that found no
    # surfaces has an empty flat list too, and reporting that as a pass is how this gate spent four
    # cycles being green in a container that had never packed app/assets.
    if report["read"] < args.min_read:
        print(f"read {report['read']} surface(s) under {report['root']}, expected at least "
              f"{args.min_read}: nothing was measured, so nothing is being asserted. "
              f"Pack with tools/pack_assets.py, or read the source library with --root assets.",
              file=sys.stderr)
        return 2
    if report["flat"]:
        print(f"{len(report['flat'])} surface(s) with nothing in them:", file=sys.stderr)
        for line in report["flat"][:12]:
            print("  " + line, file=sys.stderr)
        return 1
    print(f"{report['read']} surfaces read from {report['root']}, none of them flat")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
