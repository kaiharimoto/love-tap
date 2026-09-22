#!/usr/bin/env python3
"""No day render is pinned at 255 in a channel: the lamp's headroom, which illuminant.py never read.

    python3 tools/check/headroom.py                  # every day render under assets/
    python3 tools/check/headroom.py --condition dusk # the twins, which carry the rig's aperture
    python3 tools/check/headroom.py --out evidence/logs/headroom.json

`the-corrected-lamp-pins-the-red-channel`. tools/check/illuminant.py holds the corrected day lamp to
its declared temperature AND to the luminous irradiance the rig always delivered -- and luminance is
0.2126R + 0.7152G + 0.0722B, almost all green, so warming the spectrum at constant luminance can
only push red up. Nothing checked whether red had room to go. Firing 10 measured the answer against
the pre-relight blobs: graph_01 0.0000 -> 0.5123 of its pixels at R=255, receipt_01 0.0025 ->
0.7735, obj_plaster 0.2272 -> 0.8274. A channel pinned at 255 is tooth and relief the render made
and the file threw away, and the rig already names that failure for dusk -- `DUSK_STOPS`, an
aperture in blender/rig/common.py -- with no day equivalent.

The clause, as the item states it: no day asset with more than 1% of its OPAQUE pixels at 255 in
any single channel. Opaque is alpha >= 250 where a file has alpha, so an object's transparent
surround cannot dilute its own clipping; a paper stock has no alpha and every pixel counts.

What it reads: the render families a still is made of -- paper, objects, bits, shell -- and not
shadows, which are dark by construction, nor tears, which are masks and lit edges, nor the fold
frames, whose 240-frame re-render is fenced and which `--family folds` reads when anyone wants the
number. A stem ending `_dusk` (or `_dusk_shadow`) is dusk; every other stem is day.

Exits 0 when every file read passes, 2 when any fails, and 2 when it read nothing at all -- an
empty read is not a pass (cc078d7).
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CEILING = 0.01          # of opaque pixels, per channel -- the item's number
FAMILIES = ("paper", "objects", "bits", "shell")


def condition(stem):
    return "dusk" if "_dusk" in stem else "day"


def wanted(path, cond):
    stem = os.path.splitext(os.path.basename(path))[0]
    if stem.endswith("_shadow") or stem.endswith("_shadow_dusk") or stem.endswith("_dusk_shadow"):
        return False
    return condition(stem) == cond


def read(path):
    im = Image.open(path)
    has_alpha = "A" in im.getbands()
    a = np.asarray(im.convert("RGBA"))
    opaque = a[..., 3] >= 250 if has_alpha else np.ones(a.shape[:2], bool)
    n = int(opaque.sum())
    if n == 0:
        return {"file": os.path.relpath(path, ROOT), "opaque": 0, "ok": False,
                "why": "no opaque pixels to read"}
    at = {ch: round(float((a[..., i][opaque] == 255).mean()), 4) for i, ch in enumerate("RGB")}
    worst = max(at, key=at.get)
    return {"file": os.path.relpath(path, ROOT), "opaque": n, "at_255": at,
            "worst": worst, "ok": at[worst] <= CEILING}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--condition", choices=["day", "dusk"], default="day")
    ap.add_argument("--family", action="append", default=[],
                    help="read only these families under assets/ (repeatable); default: %s"
                         % ", ".join(FAMILIES))
    ap.add_argument("--source", default=os.path.join(ROOT, "assets"),
                    help="the assets directory to read, for a library out of git")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    fams = a.family or list(FAMILIES)
    paths = []
    for fam in fams:
        for ext in ("webp", "png"):
            paths += glob.glob(os.path.join(a.source, fam, "**", "*." + ext), recursive=True)
    paths = sorted(p for p in paths if wanted(p, a.condition))
    if not paths:
        print("headroom: nothing to read", file=sys.stderr)
        return 2
    rows = [read(p) for p in paths]
    bad = [r for r in rows if not r["ok"]]
    by_family = {}
    for r in rows:
        fam = r["file"].split(os.sep)[1] if r["file"].startswith("assets") else "?"
        f = by_family.setdefault(fam, {"read": 0, "failing": 0})
        f["read"] += 1
        f["failing"] += 0 if r["ok"] else 1
    report = {"ceiling": CEILING, "condition": a.condition, "read": len(rows),
              "failing": len(bad), "by_family": by_family, "files": rows, "ok": not bad}
    if a.out:
        os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
        with open(a.out, "w") as fh:
            json.dump(report, fh, indent=1)
    for r in sorted(bad, key=lambda r: -r.get("at_255", {}).get(r.get("worst", "R"), 0)):
        if "at_255" in r:
            print("-- %-44s %s=255 on %.4f of %d opaque px"
                  % (r["file"], r["worst"], r["at_255"][r["worst"]], r["opaque"]))
        else:
            print("-- %-44s %s" % (r["file"], r["why"]))
    for fam, f in by_family.items():
        print("%-8s %3d of %3d %s renders over %.0f%% at 255 in a channel"
              % (fam, f["failing"], f["read"], a.condition, CEILING * 100))
    print("%d of %d fail" % (len(bad), len(rows)))
    return 0 if report["ok"] else 2


if __name__ == "__main__":
    sys.exit(main())
