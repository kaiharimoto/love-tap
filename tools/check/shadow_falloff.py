#!/usr/bin/env python3
"""The 1-D falloff the contact-shadow renders carry, measured off the renders themselves.

WHAT THIS IS FOR. `the-tear-shadow-is-stretched-six-to-one-and-becomes-a-hard-bar` was settled at
firing 43 onto route (b): stop stretching a photographic falloff to the shape of whatever piece it
lands on, and lay the render's OWN falloff around the outline at the physical scale the piece's
lift asks for. docs/BRIEF.md 05 asks for `contact shadows baked from the render's own lighting
rather than applied as a uniform blur`, so the profile has to be MEASURED rather than invented --
a MaskFilter.blur is the anti-goal, and this is what keeps route (b) on the right side of it.

Firing 43 named the experiment that could refute the whole route before any widget code is
written: read the spill band of the shadow renders and check it carries a monotone 1-D profile
that survives being resampled to the ~11 px of spill a margin strip has room for. This is that
read, and it is also where the profile itself comes from afterwards.

WHAT IT IS NOT. It is not the gate that closes the item. That measurement is the contact band
read off each piece's own declared rect in `evidence/<artifact>.surfaces.json`, and it lives with
the item. This tool reads the library; it never looks at a capture.

HOW IT REGISTERS THE TWO IMAGES, which is the one thing worth getting right. The packed mask is
the piece's box exactly and the packed shadow is `shadow_frame` times it, centred -- and
`shadow_frame` in `app/assets/INDEX.json` is the PACKING margin (1.25), not the `shadow_frame` in
`assets/tears/relief.json`, which is what Blender framed the render at (1.2). tools/pack_assets.py
crops the shadow about the piece's own box and overwrites the number on the way past. Reading the
source file instead puts the outline about 4% out, which reads as a shadow with no spill at all:
alpha 211 under the paper and 4 one pixel outside it. Ask the packed index, which is what the app
asks.
"""
import argparse
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
PACKED = os.path.join(ROOT, "app", "assets")


def profile_of(tear, frame, per_mm):
    import cv2
    import numpy as np
    from PIL import Image

    mask = np.array(Image.open(os.path.join(PACKED, "tears", f"{tear}.webp")).convert("L"))
    shadow = np.array(
        Image.open(os.path.join(PACKED, "tears", f"{tear}_shadow.webp")).convert("RGBA")
    )[..., 3].astype(np.float32)
    h, w = shadow.shape
    pw, ph = int(round(w / frame)), int(round(h / frame))
    ox, oy = (w - pw) // 2, (h - ph) // 2
    paper = np.zeros((h, w), np.uint8)
    paper[oy:oy + ph, ox:ox + pw] = (
        cv2.resize(mask, (pw, ph), interpolation=cv2.INTER_AREA) > 128
    ).astype(np.uint8)
    # distance outward from the paper outline, in packed pixels
    d = cv2.distanceTransform((1 - paper).astype(np.uint8), cv2.DIST_L2, 5)
    ppm = pw / per_mm if per_mm else None
    rings = []
    for k in range(0, 81):
        sel = (d >= k) & (d < k + 1)
        rings.append(round(float(shadow[sel].mean()), 2) if sel.sum() >= 50 else None)
    return {
        "tear": tear,
        "px_per_mm": round(ppm, 3) if ppm else None,
        "under_the_paper": round(float(shadow[paper > 0].mean()), 2),
        "rings": rings,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="where to write the JSON; stdout if absent")
    ap.add_argument("--step-mm", type=float, default=0.05)
    ap.add_argument("--to-mm", type=float, default=4.0)
    args = ap.parse_args()

    import numpy as np

    index = json.load(open(os.path.join(PACKED, "INDEX.json"), encoding="utf-8"))
    frame = float(index["relief"]["shadow_frame"])
    lib = json.load(open(os.path.join(ROOT, "assets", "MANIFEST.json"), encoding="utf-8"))["files"]

    tears = sorted(
        os.path.basename(p)[: -len("_shadow.webp")]
        for p in glob.glob(os.path.join(PACKED, "tears", "*_shadow.webp"))
        if "_dusk" not in p
    )
    rows = []
    for t in tears:
        settings = lib.get(f"assets/tears/{t}.png", {}).get("settings", {})
        w_mm = settings.get("w_mm")
        if not w_mm or not os.path.exists(os.path.join(PACKED, "tears", f"{t}.webp")):
            continue
        rows.append(profile_of(t, frame, w_mm))
    if not rows:
        print("shadow_falloff: no packed shadow renders to read", file=sys.stderr)
        return 2

    # Every render on one millimetre axis, so the profile is a physical thing rather than a
    # per-mask one. This is the whole claim route (b) rests on: that there IS one profile.
    mm = np.arange(0.0, args.to_mm + 1e-9, args.step_mm)
    stack = []
    for r in rows:
        px = np.arange(len(r["rings"]), dtype=float)
        v = np.array([np.nan if x is None else x for x in r["rings"]])
        ok = ~np.isnan(v)
        stack.append(np.interp(mm * r["px_per_mm"], px[ok], v[ok]))
    stack = np.array(stack)
    median = np.nanmedian(stack, axis=0)
    p10 = np.nanpercentile(stack, 10, axis=0)
    p90 = np.nanpercentile(stack, 90, axis=0)
    falling = bool(np.all(np.diff(median) <= 0.01))

    def reaches(frac):
        first = median[1]
        below = np.argmax(median < first * frac)
        return round(float(mm[below]), 3) if below else None

    out = {
        "what": "the alpha of the packed contact-shadow renders as a function of distance outside "
                "the paper outline, in millimetres, over every shadow render in the library",
        "renders": len(rows),
        "shadow_frame": frame,
        "step_mm": args.step_mm,
        "monotone_falling": falling,
        "under_the_paper": round(float(np.median([r["under_the_paper"] for r in rows])), 2),
        "mm": [round(float(x), 3) for x in mm],
        "median": [round(float(x), 2) for x in median],
        "p10": [round(float(x), 2) for x in p10],
        "p90": [round(float(x), 2) for x in p90],
        "reaches": {f"{int(f * 100)}%": reaches(f) for f in (0.5, 0.25, 0.1, 0.05)},
        "per_render": rows,
    }
    text = json.dumps(out, indent=1)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{len(rows)} renders; monotone_falling={falling}; "
              f"5% of its peak by {out['reaches']['5%']} mm -> {args.out}")
    else:
        print(text)
    # A profile that is not monotone has nothing to lay down, which is the refutation firing 43
    # asked for. Say so in the exit code as well as in the JSON.
    return 0 if falling else 1


if __name__ == "__main__":
    sys.exit(main())
