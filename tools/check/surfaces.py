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
import re
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
    # A fold frame is paper too, and for a whole cycle nothing looked at it: this check read
    # paper/, shell/ and objects/ and the one sequence the material row is judged on sat in a
    # directory one level deeper, where a single-level glob never reached. 94 of its 240 frames
    # were under the paper floor, and the unfolding clip was a flat cream rectangle.
    "folds": 1.2,
}
PATCH = 200

# The shading field: what the light does across a whole surface, as opposed to what the material
# does inside a patch. These two are different measurements and the report used to carry only the
# first, which is how "none flat, lowest patch_std 2.29" stood over a library of paper whose
# delivered surface swings 1.2 grey levels from one side of a sheet to the other. Worse, on a ruled
# stock every 200 px patch contains three or four printed rules, so patch_std there is a
# measurement of the ruling and the margin line rather than of the tooth.
#
#   tooth        median std inside ink-free 32 px blocks after a box high-pass: the paper itself
#   field_swing  p5-p95 of those blocks' means: the gradient the key light lays across the sheet
#   lit_across   for a cut-out object, the left third's mean minus the right third's
#
# Only the first two are floors. `lit_across` is reported and not gated, because it is a curvature
# meter rather than a light meter: it is near zero for any surface with a single normal however
# hard the key hits it, so a flat-lying ticket, a coffee ring or the flat top disc that is 68 per
# cent of the candle reads ~0 and always will. Ranking the object library by it ranks it by how
# much the normal turns across the frame. A floor on it would fail eight objects for being flat
# things, which is what they are, and would have to be silenced — which is how a check stops
# meaning anything.
SHADING_FLOORS = {
    "paper": {"tooth": 0.60, "field_swing": 3.5},
    "folds": {"tooth": 0.60},
}
BLOCK = 32


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


def _boxblur(a, r=3):
    """Mean over a (2r+1) square, by summed-area table. NaNs are treated as absent."""
    m = ~np.isnan(a)
    v = np.where(m, a, 0.0)
    def integral(x):
        c = np.cumsum(np.cumsum(x, axis=0), axis=1)
        return np.pad(c, ((1, 0), (1, 0)), mode="constant")
    iv, im_ = integral(v), integral(m.astype(np.float64))
    h, w = a.shape
    ys = np.arange(h)[:, None]
    xs = np.arange(w)[None, :]
    y0 = np.clip(ys - r, 0, h); y1 = np.clip(ys + r + 1, 0, h)
    x0 = np.clip(xs - r, 0, w); x1 = np.clip(xs + r + 1, 0, w)
    def win(t):
        return t[y1, x1] - t[y0, x1] - t[y1, x0] + t[y0, x0]
    n = win(im_)
    with np.errstate(invalid="ignore", divide="ignore"):
        return np.where(n > 0, win(iv) / np.maximum(n, 1), np.nan)


def shading(a, family):
    """The light across a surface, and the material inside it, as two separate numbers."""
    out = {}
    lo = _boxblur(a, 3)
    hp = a - lo
    h, w = a.shape
    # Every block of the surface, and print taken out of each one from the inside rather than by
    # throwing the block away. Requiring a block to be free of print measured nothing at all on
    # graph paper — no 32-pixel square of a grid is ever clean — and nothing at all on any dark
    # stock while the threshold was absolute. A block of ruled paper is mostly paper: its median is
    # the paper's tone, and the pixels near that median are the paper.
    # Two passes. The first reads every whole block's paper tone; the second keeps the blocks that
    # are actually on the surface. A packed sheet carries the ground it was photographed against
    # around its edge — lined_01's border sits at 147 against an interior of 233 — and a first
    # attempt that measured every block reported an 88 grey level "shading field", which is the
    # edge of the sheet, not the light on it. The cut is relative to the surface's own tone, so it
    # works on a dusk stock as well as a daylight one, which an absolute floor of 200 did not: it
    # rejected every block of every dark sheet and let twenty-four surfaces pass unmeasured.
    tones = []
    for y in range(0, h - BLOCK + 1, BLOCK):
        for x in range(0, w - BLOCK + 1, BLOCK):
            t = a[y:y + BLOCK, x:x + BLOCK]
            if np.isnan(t).any():
                continue
            # the 75th percentile, not the median: on a ruled stock a block whose median lands on a
            # rule reports the rule. The paper is the bright end of the block, on a dark stock too.
            tones.append((y, x, float(np.percentile(t, 75))))
    if len(tones) < 10:
        out["unmeasurable"] = f"only {len(tones)} whole blocks of this surface"
        return out
    body = float(np.median([v for _, _, v in tones]))
    means, hps = [], []
    for y, x, tone in tones:
        if tone < body - 20.0:
            continue                      # the ground around the sheet, not the sheet
        t = a[y:y + BLOCK, x:x + BLOCK]
        near = np.abs(t - tone) <= 6.0
        if near.sum() < 200:
            continue
        # the mean of the paper in this block, not the percentile that found it: a percentile of
        # 8-bit data lands on a data point, so the swing came out quantised to whole grey levels
        means.append(float(t[near].mean()))
        hps.append(float(np.std(hp[y:y + BLOCK, x:x + BLOCK][near])))
    if len(means) >= 10:
        m = np.array(means)
        out["blocks"] = len(means)
        out["field_swing"] = round(float(np.percentile(m, 95) - np.percentile(m, 5)), 3)
        if hps:
            out["tooth"] = round(float(np.median(hps)), 3)
            out["tooth_from_blocks"] = len(hps)
    else:
        out["unmeasurable"] = f"only {len(means)} blocks of this surface are on the surface"
    if family == "objects":
        cols = np.nanmean(a, axis=0)
        k = max(1, len(cols) // 3)
        left, right = np.nanmean(cols[:k]), np.nanmean(cols[-k:])
        if np.isfinite(left) and np.isfinite(right):
            out["lit_across"] = round(float(abs(left - right)), 3)
    return out


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


def object_coverage(surfaces):
    """Every object a feeling names, split by whether there is a rendered surface to measure."""
    lib = os.path.join(ROOT, "app", "lib", "feelings")
    named = set()
    try:
        with open(os.path.join(lib, "builtins.dart"), encoding="utf-8") as f:
            named = set(re.findall(r"object:\s*'([a-z0-9_]+)'", f.read()))
    except OSError:
        return {"why": "app/lib/feelings/builtins.dart is not readable from here"}
    drawn = set()
    try:
        with open(os.path.join(lib, "drawn.dart"), encoding="utf-8") as f:
            drawn = set(re.findall(r"'(obj_[a-z0-9_]+)'\s*:", f.read()))
    except OSError:
        pass
    measured = {k.split("/", 1)[1].rsplit(".", 1)[0] for k in surfaces if k.startswith("objects/")}
    return {
        "named": len(named),
        "measured": sorted(named & measured),
        "drawn_in_the_app": sorted(named & drawn),
        "named_but_neither": sorted(named - measured - drawn),
        "note": "a drawn feeling is a mark the app makes with a pen, not a render, so it has no "
                "surface to measure; anything under 'named_but_neither' is a hole",
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--floor", type=float, default=0.0, help="override every floor")
    args = ap.parse_args()

    report = {
        "floors": FLOORS,
        "shading_floors": SHADING_FLOORS,
        "what_lit_across_is": "the left third's mean luminance minus the right third's, over a "
                              "cut-out object. Reported, never gated: it measures how much the "
                              "surface normal turns across the frame, not how well the object is "
                              "lit, so a flat-lying sheet reads near zero under any light.",
        "what_patch_std_is": "the largest standard deviation among nine 200 px patches of the "
                             "whole file. On a ruled stock every such patch contains three or four "
                             "printed rules, so this number is dominated by the ruling and the "
                             "margin line and is not a measurement of the paper's tooth. Read "
                             "`tooth` and `field_swing` for the material and for the light.",
        "surfaces": {},
        "flat": [],
        "unlit": [],
        "too_small_to_measure": [],
    }
    for family, floor in FLOORS.items():
        if args.floor:
            floor = args.floor
        # folds/<sequence>/NNNN.webp is one level deeper than the flat families
        found = sorted(glob.glob(os.path.join(ASSETS, family, "*.webp"))
                       + glob.glob(os.path.join(ASSETS, family, "*", "*.webp")))
        for path in found:
            name = os.path.relpath(path, os.path.join(ASSETS, family))
            if "_shadow" in name or "_mask" in name:
                continue      # a shadow is meant to be smooth; that is what a shadow is
            a = read(path)
            if a is None:
                # Too little opaque material to measure — and until now that was a silent skip,
                # which is how three objects a feeling names went unmeasured for three cycles
                # while the report said "none of them flat".
                report["too_small_to_measure"].append(f"{family}/{name}")
                continue
            best = 0.0
            for p in patches(a):
                p = p[~np.isnan(p)]
                if p.size < 250:
                    continue
                best = max(best, float(p.std()))
            entry = {"family": family, "patch_std": round(best, 3), "floor": floor}
            entry.update(shading(a, family))
            report["surfaces"][f"{family}/{name}"] = entry
            if best < floor:
                report["flat"].append(f"{family}/{name}: {best:.3f} < {floor}")
            wants = SHADING_FLOORS.get(family, {})
            for key, want in wants.items():
                got = entry.get(key)
                if got is not None and got < want:
                    report["unlit"].append(f"{family}/{name}: {key} {got} < {want}")
            # A surface in a family that carries a floor and that cannot be measured has not
            # passed — it has not been looked at, which is the thing this file exists to stop.
            if wants and "unmeasurable" in entry:
                report["unlit"].append(f"{family}/{name}: {entry['unmeasurable']}")

    # a sequence is two hundred and forty files; what a reader wants is the worst of them and the
    # middle of them, per sequence, beside the per-frame rows
    sequences = {}
    for key, entry in report["surfaces"].items():
        family, _, rest = key.partition("/")
        if family != "folds" or "/" not in rest:
            continue
        seq = rest.split("/")[0]
        sequences.setdefault(seq, []).append(entry["patch_std"])
    report["fold_sequences"] = {
        seq: {"frames": len(v), "worst": round(min(v), 3), "median": round(sorted(v)[len(v) // 2], 3),
              "below_floor": sum(1 for x in v if x < FLOORS["folds"]), "floor": FLOORS["folds"]}
        for seq, v in sorted(sequences.items())
    }
    # Which feelings' objects were actually measured, and which were not and why. The report used
    # to be an inventory of the files that happen to exist, which a reader takes for an inventory
    # of the feelings: a completeness pass found eight objects named by feelings with no entry
    # here, including two that other critics were arguing about, and had no way to tell whether
    # they were missing or simply not rendered. Some feelings are marks the app draws rather than
    # things it renders, and a mark has no surface to measure. That is now said rather than left
    # as a gap.
    report["objects_named_by_feelings"] = object_coverage(report["surfaces"])
    report["read"] = len(report["surfaces"])
    report["ok"] = not report["flat"] and not report["unlit"]
    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)
    # Both gates fail the run. The shading floors were added and then not wired to the exit, so a
    # surface with no light on it at all was reported and returned 0 — a check that says the right
    # thing and answers "fine" is worse than no check, because capture.sh believes the answer.
    if report["flat"] or report["unlit"]:
        if report["flat"]:
            print(f"{len(report['flat'])} surface(s) with nothing in them:", file=sys.stderr)
            for line in report["flat"][:12]:
                print("  " + line, file=sys.stderr)
        if report["unlit"]:
            print(f"{len(report['unlit'])} surface(s) with no light across them:", file=sys.stderr)
            for line in report["unlit"][:12]:
                print("  " + line, file=sys.stderr)
        return 1
    unmeasured = [k for k, v in report["surfaces"].items() if "unmeasurable" in v]
    print(f"{report['read']} surfaces read, none of them flat, none of them unlit"
          + (f", {len(unmeasured)} too printed-on to measure" if unmeasured else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
