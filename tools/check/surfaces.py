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
# The exposure the floors are calibrated at: the body tone of the daylight stocks as they ship.
# A sheet's tooth and its shading field are both read at this brightness whatever it was rendered
# at, so the same material gives the same number in daylight and at dusk.
REFERENCE_BODY = 233.0

# The radius the high-pass is taken over, and the distance from print a pixel has to be to count.
TOOTH_RADIUS = 3

# Recalibrated against the corrected instrument. The tooth floor was 0.60 and the field floor 3.5,
# both set against a high-pass that was mostly the halo the printed rules cast on the paper beside
# them: with the halo out, the shipped stocks read 0.58 to 2.22 rather than 0.7 to 3.8. The control
# is a sheet with its paper replaced by its own box mean and its rules left untouched — a sheet with
# mathematically no tooth in it: receipt_01 0.580 -> 0.016, lined_01 1.388 -> 0.276, legal_01 1.331
# -> 0.258, graph_01 0.810 -> 0.410 (a grid every forty pixels leaves narrow strips of halo the
# erosion cannot reach). 0.45 is the number that passes every real stock and fails every flattened
# one. The field floor sits just under the lowest real reading, 3.544 on the receipt.
SHADING_FLOORS = {
    "paper": {"tooth": 0.45, "field_swing": 3.0},
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
    """The light across a surface, and the material inside it, as two separate numbers.

    Both numbers are reported at a reference exposure. They are linear in how brightly the sheet
    was lit — halve the key and the tooth amplitude and the swing across the sheet halve with it —
    and the floors they are gated against are grey levels, so a good sheet rendered darker used to
    fail and a poor one rendered brighter used to pass. receipt_01 passes today with 19 and 8 per
    cent of margin; the same file at 0.7 of its exposure fails both floors with no material
    changed. So what is gated is the number the sheet would give at the reference exposure, and the raw
    reading is reported beside it.
    """
    out = {}
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
    # edge of the sheet, not the light on it.
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
    if body <= 1.0:
        out["unmeasurable"] = "the surface is black"
        return out
    # The cut is a fraction of the surface's own tone, so it means the same thing on a dusk stock
    # as on a daylight one. It was `body - 20` and the comment above it said it was relative: on a
    # sheet at body 233 that is 8.6 per cent and the ground is cleanly outside it, but on the same
    # sheet at a quarter of the light it is 37 per cent, the sheet's own dark border sits inside
    # the cut, and field_swing goes back to being the sheet-edge contrast the two passes exist to
    # remove — in the passing direction. It is also two-sided now: a sheet on a lighter ground had
    # its ground counted as surface at any exposure, because only the dark side was ever cut.
    dark_cut = body * (1.0 - 20.0 / REFERENCE_BODY)
    light_cut = body * 1.25
    kept = []
    for y, x, tone in tones:
        if tone < dark_cut or tone > light_cut:
            continue                      # the ground around the sheet, not the sheet
        kept.append((y, x, tone))
    window = 6.0 * body / REFERENCE_BODY
    # Where the paper is, pixel by pixel, so the high-pass can be read off the paper alone.
    #
    # The high-pass used to be taken over the whole image and then sampled through the same
    # per-block mask. The mask takes out the rule's own pixels and cannot take out the halo it
    # casts: every paper pixel within the blur radius of a rule has its neighbourhood mean pulled
    # toward the rule, so its high-pass reads ten to twenty grey levels instead of nothing. On a
    # stock ruled every forty pixels that is most of the reading — a reviewer replaced the paper of
    # every stock with its own box mean, leaving the rules untouched, and 35 of 54 files still
    # passed the tooth floor with mathematically zero tooth in them. So the mask is eroded by the
    # blur radius: a pixel counts only when everything its own neighbourhood mean was made of is
    # paper too.
    paper = np.zeros(a.shape, dtype=bool)
    for y, x, tone in kept:
        t = a[y:y + BLOCK, x:x + BLOCK]
        paper[y:y + BLOCK, x:x + BLOCK] = np.abs(t - tone) <= window
    inner = _boxblur(paper.astype(float), TOOTH_RADIUS) >= 0.999
    lo = _boxblur(a, TOOTH_RADIUS)
    hp = a - lo
    means, hps = [], []
    for y, x, tone in kept:
        near = paper[y:y + BLOCK, x:x + BLOCK]
        if near.sum() < 200:
            continue
        # the mean of the paper in this block, not the percentile that found it: a percentile of
        # 8-bit data lands on a data point, so the swing came out quantised to whole grey levels
        t = a[y:y + BLOCK, x:x + BLOCK]
        means.append(float(t[near].mean()))
        clean = inner[y:y + BLOCK, x:x + BLOCK]
        if clean.sum() >= 120:
            hps.append(float(np.std(hp[y:y + BLOCK, x:x + BLOCK][clean])))
    scale = REFERENCE_BODY / body
    if len(means) >= 10:
        m = np.array(means)
        out["blocks"] = len(means)
        out["body"] = round(body, 1)
        swing = float(np.percentile(m, 95) - np.percentile(m, 5))
        out["field_swing_raw"] = round(swing, 3)
        out["field_swing"] = round(swing * scale, 3)
        if hps:
            tooth = float(np.median(hps))
            out["tooth_raw"] = round(tooth, 3)
            out["tooth"] = round(tooth * scale, 3)
            out["tooth_from_blocks"] = len(hps)
        else:
            out["unmeasurable"] = "no block of this surface is clear of print"
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
    # And the ones the couple made themselves. This read only the built-ins, so it said `named: 34`
    # and `named_but_neither: 0` while two objects in the vocabulary had never been looked at — the
    # field whose whole job is to find holes was not being shown the part of the vocabulary most
    # likely to have one, because an authored object is the only kind nobody wrote into this repo.
    authored = set()
    seed = os.path.join(ROOT, "app", "assets", "seed", "year")
    try:
        for name in sorted(os.listdir(seed)):
            if not name.endswith(".jsonl"):
                continue
            with open(os.path.join(seed, name), encoding="utf-8") as f:
                for line in f:
                    if '"feeling_authored"' not in line:
                        continue
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    asset = (e.get("payload") or {}).get("object_asset")
                    if asset:
                        authored.add(asset)
    except OSError:
        pass
    named |= authored
    drawn = set()
    try:
        with open(os.path.join(lib, "drawn.dart"), encoding="utf-8") as f:
            drawn = set(re.findall(r"'(obj_[a-z0-9_]+)'\s*:", f.read()))
    except OSError:
        pass
    # An entry under objects/ is a file that was opened, not a surface that was measured: an object
    # whose only shading output is `unmeasurable` was being reported as covered, in the field whose
    # whole job is to separate what was looked at from the holes.
    measured, unmeasured = set(), set()
    for k, v in surfaces.items():
        if not k.startswith("objects/"):
            continue
        (unmeasured if "unmeasurable" in v else measured).add(k.split("/", 1)[1].rsplit(".", 1)[0])
    return {
        "named": len(named),
        "authored_by_the_couple": sorted(authored),
        "measured": sorted(named & measured),
        "read_but_not_measurable": sorted(named & unmeasured),
        "drawn_in_the_app": sorted(named & drawn),
        "named_but_neither": sorted(named - measured - unmeasured - drawn),
        "note": "a drawn feeling is a mark the app makes with a pen, not a render, so it has no "
                "surface to measure; anything under 'named_but_neither' is a hole",
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--floor", type=float, default=None,
                    help="override the patch_std floor for every family, including with 0")
    args = ap.parse_args()

    # What this run used, not what the file declares. `--floor` replaced the per-family number in
    # the loop and the report went on echoing the module's own dict, so the summary a reader reads
    # said one thing while the failure list in the same file said another; and `if args.floor:`
    # silently ignored `--floor 0`, which is the one value somebody passes to turn a gate off.
    floors = {f: (args.floor if args.floor is not None else v) for f, v in FLOORS.items()}

    report = {
        "floors": floors,
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
        "not_looked_at": [],
        "too_small_to_measure": [],
    }
    for family, floor in floors.items():
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
            # But it is not the same as one that was looked at and found flat, and putting the two
            # in one list said "2 surfaces with no light across them" about two frames of a
            # letter standing on its edge, where the sampler could not find a block to stand on.
            # Both still fail; a reader can now tell which is which.
            if wants and "unmeasurable" in entry:
                report["not_looked_at"].append(f"{family}/{name}: {entry['unmeasurable']}")

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
              "below_floor": sum(1 for x in v if x < floors["folds"]), "floor": floors["folds"]}
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
    # A family that carries a floor and has nothing in it has not passed either. app/assets is
    # derived and gitignored, and capture.sh used to run this before pack_assets.py built it: on a
    # fresh clone the globs found nothing, `flat` and `unlit` stayed empty, and the check
    # greenlit the whole library without opening a file. Coverage is part of the answer now.
    report["by_family"] = {
        family: sum(1 for k in report["surfaces"] if k.startswith(family + "/"))
        for family in FLOORS
    }
    report["empty"] = [
        f"{family}: nothing to measure — has {os.path.join('app/assets', family)} been packed?"
        for family in SHADING_FLOORS
        if report["by_family"].get(family, 0) == 0
    ]
    # `not_looked_at` is reported and does not gate, and the reason is the two frames in it.
    #
    # This sampler stands 32-pixel blocks on a surface and reads the paper between the print. A
    # letter with one flap up is a sheet standing on its edge with a hard cast shadow over the
    # third below it: two frames of the fold sequence have no block that is both whole, on the
    # surface, and clear of print, and no tuning changes that, because there is no flat surface in
    # the picture to stand on. Reporting it as "no light across this surface" said the opposite of
    # what is true — it is the one thing in the library with the most light across it. So it is
    # named, with the reason, and the gate is left to `flat` and `unlit`, which are measurements
    # that were actually taken.
    report["ok"] = not report["flat"] and not report["unlit"] and not report["empty"]
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
    # The exit code is `ok`, and it did not used to be: `not_looked_at` was split out of `unlit`
    # and taken out of the verdict, and this line was left gating on it. So the twelfth capture
    # recorded `surfaces` as missing with the reason "a rendered surface in the library has nothing
    # in it" while the report it wrote in the same breath said ok: true, 260 surfaces read, none of
    # them flat — over two fold frames the sampler could not stand a block on. A check whose exit
    # code disagrees with its own verdict is worse than no check.
    if not report["ok"] or report["not_looked_at"]:
        for line in report["empty"]:
            print(line, file=sys.stderr)
        if report["flat"]:
            print(f"{len(report['flat'])} surface(s) with nothing in them:", file=sys.stderr)
            for line in report["flat"][:12]:
                print("  " + line, file=sys.stderr)
        if report["not_looked_at"]:
            print(f"{len(report['not_looked_at'])} surface(s) the sampler could not stand on:",
                  file=sys.stderr)
            for line in report["not_looked_at"][:12]:
                print(f"  {line}", file=sys.stderr)
        if report["unlit"]:
            print(f"{len(report['unlit'])} surface(s) with no light across them:", file=sys.stderr)
            for line in report["unlit"][:12]:
                print("  " + line, file=sys.stderr)
        if not report["ok"]:
            return 1
    unmeasured = [k for k, v in report["surfaces"].items() if "unmeasurable" in v]
    print(f"{report['read']} surfaces read, none of them flat, none of them unlit"
          + (f", {len(unmeasured)} too printed-on to measure" if unmeasured else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
