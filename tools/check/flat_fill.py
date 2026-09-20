#!/usr/bin/env python3
"""Whether a still has a flat fill in it: one exact RGB value standing in for a surface.

    python3 tools/check/flat_fill.py                            # every still in evidence/
    python3 tools/check/flat_fill.py evidence/10_first_run.png  # one
    python3 tools/check/flat_fill.py --out evidence/logs/flat_fill.json

`the-backing-surface-of-three-screens-is-one-rgb-value` names two clauses and asks for a gate to
hold them: **no single RGB value occupies more than 8% of a frame**, and **every 400x200 window of
a paper region measures L_std >= 8 with >= 60 distinct luminance levels**. Until firing 28 both
were measured by hand, once per firing, by whoever happened to be looking -- which is how
`10_first_run.png` sat at 59.56% one exact colour for five firings while three separate diagnoses
of it were written down and two of them were wrong.

The first clause is the one that catches the failure this was written for, and it is cheap and
exact: a *render* of paper cannot put 59% of a frame on one value to the bit, because a render of
paper has tooth in it. A flat fill can, and the value it lands on is a constant somebody typed.
So the report names the constant when it recognises one, out of `app/lib/material/palette.dart`.

The second clause is the tooth, sampled the way `tools/paper_tooth.py` samples it -- the same
window size, the same floors, the same fixed seed -- so a number here and a number there are the
same kind of number.

The box for the second clause is the region pad's, which is where the flat fills were. It is
derived from the frame rather than written down, so it holds for any still of this app at any
size: the pad is inset by RegionPad._margin (12 logical px) and sits under the partner strip.

Exits 0 if every still passes both clauses, 2 if any fails, so capture.sh can gate on it.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# the ceiling the queue item names, as a fraction of the frame
DOMINANT_CEILING = 0.08
# the tooth floors, quoted from the same item and shared with tools/paper_tooth.py
SAMPLE = (400, 200)
FLOOR_STD = 8.0
FLOOR_LEVELS = 60

# app/lib/material/palette.dart. A dominant value that is one of these to the bit is a fallback
# colour showing through, not a render -- which is the whole diagnosis, stated once.
CONSTANTS = {
    0xF1ECDF: "Paper.lined", 0xECE0C2: "Paper.aged", 0xE9ECEC: "Paper.graph",
    0xF3E6A8: "Paper.legal", 0xF6F1E6: "Paper.index", 0xF2EDE2: "Paper.looseleaf",
    0xEFEADC: "Paper.spiral", 0xF3E08A: "Paper.stickyYellow", 0xF2C1C1: "Paper.stickyPink",
    0xE7E0CE: "Paper.underside", 0x4C3E32: "DeskColour.day", 0x2A241F: "DeskColour.dusk",
}


def dominant(rgb):
    """The most common exact RGB value in the frame, and what share of it that value is."""
    flat = rgb.reshape(-1, 3).astype(np.int32)
    key = (flat[:, 0] << 16) | (flat[:, 1] << 8) | flat[:, 2]
    values, counts = np.unique(key, return_counts=True)
    i = int(counts.argmax())
    return int(values[i]), float(counts[i]) / key.size


def pad_box(w, h):
    """RegionPad's box in device pixels, derived from the frame.

    The pad is `Positioned.fill` inside the region, inset by `_margin` = 12 logical px, under a
    `PartnerStrip` 86 logical px tall in a 6-point padding; the nav row is 68 at the bottom. At
    dpr 3 on a 1440x3120 capture that is x 36..1404 and y 318..2898, which is the box firing 27
    measured the 59.56% fill's own bounding box at to the pixel.
    """
    dpr = w / 480.0
    return (round(36 * dpr / 3), round(318 * dpr / 3),
            round(1368 * dpr / 3), round(2580 * (h / 3120.0)))


def samples(lum, n=8, seed=7):
    """n windows of the size the item measures. Identical to tools/paper_tooth.py's sampler --
    same size, same seed, same placement rule -- so the two tables can be read together."""
    sw, sh = SAMPLE
    if lum.shape[0] < sh or lum.shape[1] < sw:
        return []
    rng = np.random.default_rng(seed)
    out = []
    for _ in range(n):
        y = int(rng.integers(0, lum.shape[0] - sh))
        x = int(rng.integers(0, lum.shape[1] - sw))
        p = lum[y:y + sh, x:x + sw]
        out.append({"at": [x, y],
                    "std": round(float(p.std()), 3),
                    "levels": int(len(np.unique(np.round(p))))})
    return out


def read(path):
    im = Image.open(path)
    rgb = np.asarray(im.convert("RGB"))
    h, w = rgb.shape[0], rgb.shape[1]
    value, share = dominant(rgb)
    x, y, bw, bh = pad_box(w, h)
    lum = np.asarray(im.convert("L"), dtype=np.float64)[y:y + bh, x:x + bw]
    ss = samples(lum)
    passing = sum(1 for s in ss if s["std"] >= FLOOR_STD and s["levels"] >= FLOOR_LEVELS)
    stds = sorted(s["std"] for s in ss)
    problems = []
    if share > DOMINANT_CEILING:
        named = CONSTANTS.get(value)
        problems.append(
            "%.2f%% of the frame is the one value #%06X%s, against a ceiling of %.0f%%"
            % (share * 100, value, " -- which is %s, a constant, so no render made it" % named
               if named else "", DOMINANT_CEILING * 100))
    if ss and passing < len(ss):
        problems.append(
            "%d of %d %dx%d windows of the pad box are under L_std %.1f with %d levels"
            % (len(ss) - passing, len(ss), SAMPLE[0], SAMPLE[1], FLOOR_STD, FLOOR_LEVELS))
    return {
        "of": os.path.basename(path),
        "size": [w, h],
        "dominant": {"rgb": "#%06X" % value, "share": round(share, 5),
                     "constant": CONSTANTS.get(value)},
        "pad_box": [x, y, bw, bh],
        "windows": {"declared": len(ss), "passing": passing,
                    "median_std": stds[len(stds) // 2] if stds else None,
                    "each": ss},
        "problems": problems,
        "ok": not problems,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stills", nargs="*", help="default: every PNG in evidence/")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    paths = a.stills or sorted(glob.glob(os.path.join(ROOT, "evidence", "*.png")))
    if not paths:
        # reading nothing is an error, not a pass: cc078d7 made that the rule for every gate here
        print("flat_fill: no stills to read", file=sys.stderr)
        return 2
    results = [read(p) for p in paths]
    report = {
        "ceiling": {"dominant_share": DOMINANT_CEILING, "sample": list(SAMPLE),
                    "std": FLOOR_STD, "levels": FLOOR_LEVELS},
        "stills": results,
        "ok": all(r["ok"] for r in results),
    }
    if a.out:
        os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
        with open(a.out, "w") as fh:
            json.dump(report, fh, indent=1)
    for r in results:
        mark = "ok" if r["ok"] else "--"
        print("%s %-28s dominant %6.2f%% %s%s  windows %d/%d  median L_std %s"
              % (mark, r["of"], r["dominant"]["share"] * 100, r["dominant"]["rgb"],
                 " (%s)" % r["dominant"]["constant"] if r["dominant"]["constant"] else "",
                 r["windows"]["passing"], r["windows"]["declared"],
                 r["windows"]["median_std"]))
        for p in r["problems"]:
            print("     %s" % p)
    return 0 if report["ok"] else 2


if __name__ == "__main__":
    sys.exit(main())
