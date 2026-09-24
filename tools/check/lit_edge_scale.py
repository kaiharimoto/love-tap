#!/usr/bin/env python3
"""Is every lit edge sliced at the scale of the mask it lights?

A torn piece declares two nine-sliced layers in `evidence/<artifact>.surfaces.json`: the mask
(`fit: mask`), which cuts the sheet, and the lit edge (`fit: nine`), a soft band of light along
the same break. They are two renders of one tear and only read as one if they share one lattice.
Until firing 60 they did not: the mask was sliced by its own bands at DEVICE pixels and the edge
at a fixed 0.4 on the LOGICAL canvas, so on 03_us's `us.body.dates` the mask declared `fixed`
[0.842, 1] per pixel of a 2013x1376 render and the edge [3.311, 6] per pixel of a 512x350 one:
1695 against 1695 device px per render width, and 1376 against 2100 per render height. The glow
was drawn where the cut would be on a sheet half as tall again, and a critic saw a second,
blurred copy of the tear 30-60 px inside the real one.

For every piece declaring both layers this checks, per axis:
  * the same fixed bands as fractions of the render (the edge's `slice`/`slice_far` against the
    mask's; a pre-firing-60 edge declares one number, 0.4, for all four);
  * the same device pixels per render width through the fixed bands (`fixed` x `src`), within 5%.
Per render width rather than per pixel because the edge is packed at half the 1024 mask and a big
sheet is cut by the finer copy (assets/tears/hi), so the three renders have three pixel sizes but
one shape.

The POPULATION is printed per still: a piece that stops declaring either layer does not pass, it
leaves the count, and the count is the thing to compare before and after.

    python3 tools/check/lit_edge_scale.py                 # every committed still
    python3 tools/check/lit_edge_scale.py --dir D 03_us   # sidecars lifted out of git into D
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOLERANCE = 0.05


def bands(s):
    sl = s.get("slice", 0.4)
    if not isinstance(sl, list):
        return [float(sl)] * 4
    far = s.get("slice_far", sl)
    return [float(sl[0]), float(sl[1]), float(far[0]), float(far[1])]


def pieces(surfaces):
    by = {}
    for s in surfaces:
        p = s.get("piece")
        if p and s.get("fit") in ("mask", "nine"):
            by.setdefault(p, {})[s["fit"]] = s
    return {p: v for p, v in by.items() if "mask" in v and "nine" in v}


def check(mask, edge):
    out = {"mask": mask["asset"], "edge": edge["asset"], "fails": []}
    mb, eb = bands(mask), bands(edge)
    out["bands"] = [round(x, 3) for x in mb]
    if any(abs(a - b) > 0.005 for a, b in zip(mb, eb)):
        out["fails"].append(f"bands mask {[round(x, 3) for x in mb]} edge {[round(x, 3) for x in eb]}")
    ratio = []
    for axis in (0, 1):
        m = mask["fixed"][axis] * mask["src"][axis]
        e = edge["fixed"][axis] * edge["src"][axis]
        r = e / m if m else float("inf")
        ratio.append(round(r, 3))
        if abs(r - 1) > TOLERANCE:
            out["fails"].append(f"axis {'xy'[axis]}: edge {e:.0f} vs mask {m:.0f} device px per "
                                f"render ({r:.3f}x)")
    out["ratio"] = ratio
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("only", nargs="*", help="artifact names, e.g. 03_us")
    ap.add_argument("--dir", default=os.path.join(ROOT, "evidence"))
    ap.add_argument("--out")
    ap.add_argument("-v", action="store_true", help="print every failing piece")
    a = ap.parse_args(argv)
    paths = sorted(glob.glob(os.path.join(a.dir, "*.surfaces.json")))
    if a.only:
        paths = [p for p in paths if os.path.basename(p).split(".")[0] in a.only]
    rep, total, bad = {}, 0, 0
    for p in paths:
        name = os.path.basename(p).split(".")[0]
        rows = {pc: check(v["mask"], v["nine"]) for pc, v in pieces(json.load(open(p))).items()}
        f = sorted(pc for pc, r in rows.items() if r["fails"])
        total += len(rows)
        bad += len(f)
        rep[name] = {"pieces": len(rows), "failing": len(f), "rows": rows}
        print(f"{name}: {len(rows)} pieces declare both layers, {len(f)} sliced at another scale")
        if a.v:
            for pc in f:
                print(f"   {pc}: {'; '.join(rows[pc]['fails'])}")
    print(f"ALL: {total} pieces, {bad} failing")
    if a.out:
        json.dump({"pieces": total, "failing": bad, "stills": rep}, open(a.out, "w"), indent=1)
    return 0 if bad == 0 and total > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
