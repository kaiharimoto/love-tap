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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACKED = os.path.join(ROOT, "app", "assets")     # derived, gitignored, what the app ships
SOURCE = os.path.join(ROOT, "assets")            # the renders themselves, committed

# grey levels of variation inside one patch, at 8 bits. These are floors, not targets: paper is
# meant to be quiet and wood is not, so they differ by what the material is.
FLOORS = {
    "paper": 1.2,      # tooth and fibre: quiet, but never nothing
    "shell": 4.0,      # a desk is wood, and wood has figure in it
    "objects": 2.0,    # a rendered thing has form; a flat one has not been lit
    # NOTE: `folds` is deliberately NOT in this table any more. It carried 1.2 here -- paper's
    # floor, on the reasoning that a fold is paper -- and a blank sheet clears 1.2 without
    # difficulty: `unfold_thirds` read patch_std 1.918 to 2.075 across all 240 frames and passed,
    # while ruled stock in the same artifact read 36.9. So the gate was satisfied by procedural
    # tooth alone and could not tell a sheet of ruled stock from a flat rectangle with noise on
    # it, which is how the object five of seven critics named sat unexplained for three cycles.
    # docs/COLOR.md §5a replaces it with the class floor of the stock the sequence is folded
    # from -- 8.0 / 60 for `unfold_thirds`, a written stock -- measured by tools/check/
    # stock_class.py over a window placed from the sheet's own bounds. See fold_report() below.
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


def fold_report(assets, sequences=None):
    """Every fold sequence, read against its stock's §5a class floor rather than paper's 1.2.

    A frame is read at whatever size the library under `--root` holds it at, exactly like every
    other family here: `--root assets` reads the 1440 px source render, the default `app/assets`
    reads the frame packed down to `SIZES['folds']`. Neither is the size the app finally draws,
    and the difference is worth knowing before quoting a number from this file -- frame 0000 of
    `unfold_thirds` reads **6.824** at source, **6.322** packed, and **5.686** once the packed
    frame is drawn at the 1045 px the card actually occupies in `13_messenger_states.png`. So the
    shipped figure is the worst of the three, this file reports one of the other two, and the
    shipped reading is the one `tools/check/stock_class_selftest.py` takes. All three fail 8.0,
    which is why reporting the source figure here is safe today and would not be if the render
    were repaired to just over the floor: a pass here is not yet a pass on the screen.

    The statistic is the MEDIAN over tiled placements, not the maximum. `patch_std` above takes
    `max()`, which passes a flat sheet on the strength of its one textured corner; that leniency is
    most of why this family read green for three cycles.
    """
    import stock_class

    out = {}
    root = os.path.join(assets, "folds")
    if not os.path.isdir(root):
        return out
    for seq in sorted(os.listdir(root)):
        if sequences and seq not in sequences:
            continue
        cls, floor_std = stock_class.floor_for_fold(seq)
        if cls is None:
            # Refusing to guess is the point: a sequence with no declared stock gets no floor and
            # is reported as unmeasured, rather than silently taking someone else's number.
            out[seq] = {"error": "no stock declared in stock_class.FOLDED_FROM", "ok": False}
            continue
        frames = sorted(glob.glob(os.path.join(root, seq, "*.png"))
                        + glob.glob(os.path.join(root, seq, "*.webp")))
        if not frames:
            out[seq] = {"error": "no frames", "ok": False}
            continue
        # The first frame is the one that ships as the FOLDED state of a note and freezes into the
        # stills, so it is read whatever else is; the rest are sampled evenly so 240 frames do not
        # cost 240 decodes on every run.
        picks = [frames[0]] + [frames[i] for i in range(0, len(frames), max(1, len(frames) // 8))
                               if i]
        readings = []
        for path in picks:
            with Image.open(path) as im:
                got = stock_class.measure(np.asarray(im.convert("RGBA")), floor_std)
            if got is not None:
                got["frame"] = os.path.basename(path)
                readings.append(got)
        if not readings:
            out[seq] = {"error": "no frame read as a sheet", "ok": False}
            continue
        first = readings[0]
        out[seq] = {
            "stock": stock_class.FOLDED_FROM.get(seq),
            "class": cls,
            "floor": floor_std,
            "frames_read": len(readings),
            "frame_0000": {k: first[k] for k in
                           ("frame", "bounds", "window", "placements", "median_std",
                            "median_levels", "pass_fraction", "ok")},
            "median_std_over_frames": round(float(np.median([r["median_std"] for r in readings])), 3),
            # `median_levels` is reported and gates nothing. The 60-level clause was struck from
            # §5a at firing 36: it is missed by the REPAIRED written stocks themselves (57-58) as
            # well as by the defect (42), so it separated nothing. See stock_class.py's docstring.
            "ok": all(r["median_std"] >= floor_std for r in readings),
        }
    return out


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

    # The folds family, on its own floor. docs/COLOR.md §5a.
    report["folds"] = fold_report(assets)
    for seq, got in report["folds"].items():
        if got.get("ok"):
            continue
        if "error" in got:
            report["flat"].append(f"folds/{seq}: {got['error']}")
        else:
            f = got["frame_0000"]
            report["flat"].append(
                f"folds/{seq}: median L_std {got['median_std_over_frames']} over "
                f"{got['frames_read']} frames < {got['floor']} ({got['class']} stock "
                f"{got['stock']!r}); frame 0000 reads {f['median_std']} over {f['placements']} "
                f"placements of a {f['window'][0]}x{f['window'][1]} window, "
                f"pass fraction {f['pass_fraction']}")

    report["read"] = len(report["surfaces"]) + len(report["folds"])
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
