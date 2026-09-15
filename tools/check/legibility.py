#!/usr/bin/env python3
"""Every word in the evidence is read off the surface it was actually written on.

    python3 tools/check/legibility.py
    python3 tools/check/legibility.py --out evidence/legibility.json
    python3 tools/check/legibility.py --only 02_chat.png --worst 40

There is already a test for this — `app/test/legible_on_what_it_is_on_test.dart` — and it passes,
and the text is still hard to read. It passes because it checks three declared constants against
two declared grounds: `Pen.ballpoint` on `#F1ECDF`, `Pen.margin` on the desk, and the two hands on
the palest stock. That is six numbers out of a build whose grounds are photographs.

What it cannot see is everything that actually happens:

- ink over *rendered* paper, where the ground is not `#F1ECDF` but a fibre field that runs several
  grey levels either side of it, with printed rules and a shadow gradient crossing the letters;
- a stamped label on an index-card tab, which is a different stock at a different exposure;
- anything at dusk, where the whole library is re-rendered against a desk lamp and not one
  declared constant moved;
- a caption over a photograph, where the ground is whatever the photograph is;
- and the antialiasing, which is most of a thin handwritten stroke. A 2px ballpoint line specified
  at 8.9:1 does not put 8.9:1 on the glass; it puts a core of that and a halo of much less.

So this reads the captured artifacts instead of the source, finds the marks that are shaped like
writing, and measures each one against the pixels immediately around it.

Two numbers are reported per run, because they answer two different questions:

  ink_core    the darkest tenth of the stroke against its ground. This is the fair comparison to
              WCAG, which is specified against flat colour, and it is what the floors gate on.
  ink_median  the whole stroke against its ground — what the eye is actually given once the
              antialiasing is counted. Always the lower of the two. Reported, never gated, because
              gating on it would fail every hairline in every hand-drawn face ever made.

A run is not asked to be a paragraph. It is a connected group of glyph-shaped marks sitting on one
line, which is the unit a person reads and the unit a bad ground ruins.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVIDENCE = os.path.join(ROOT, "evidence")

# WCAG 2.1 non-text and large-text is 3:1, body is 4.5:1. The split here is by rendered height
# because that is all an image knows: WCAG's "large" is 18.66px bold or 24px regular at CSS scale,
# and these artifacts are captured at 3x, so the boundary lands at 72 device pixels. Anything
# shorter is asked for 4.5.
# WCAG 2.1 non-text and large-text is 3:1, body is 4.5:1. The split here is by rendered height,
# because a captured image is all this has: WCAG's "large" is 24px regular at CSS scale, and these
# artifacts are captured at about 3x device pixel ratio, so the boundary lands near 72 device
# pixels. Anything shorter is asked for 4.5.
LARGE_PX = 72
FLOOR_BODY = 4.5
FLOOR_LARGE = 3.0

# What counts as a mark shaped like writing. Expressed as a fraction of image height rather than
# in pixels, because the Android stills are 1440x3120 and the PWA stills are 1080x2340 and a
# constant would mean something different in each. At 2340 tall these are 14px and 117px.
GLYPH_MIN_H_FRAC = 0.006
GLYPH_MAX_H_FRAC = 0.050
GLYPH_MIN_AREA = 24
GLYPH_MAX_AREA = 12000

# How far a mark has to sit from the paper before it is a mark at all. This is measured in gamma
# space — the 0..1 sRGB value, not relative luminance — because luminance is so compressed at the
# dark end that one threshold cannot serve both a pencil line on cream paper and a stamped label
# on waxed oak. In luminance, 0.055 is most of the range below mid grey and almost none of the
# range above it, which is how the first version of this file managed to report 1.00:1 on the
# desk: it swallowed the whole dark region as ink and then had no ground left to compare it to.
INK_DELTA = 0.07
GROUND_WINDOW = 81      # the box the ink threshold is taken over, odd, in pixels
RING = 10               # the least distance around a run that the ground is sampled from
GROUND_PCTL = 90        # the ground under dark ink is the light end of what surrounds it
# A pale mark only means writing when the thing under it is dark. On paper, "lighter than the
# local mean" is a highlight, the lit side of a curl, or correction fluid, and reading those as
# letters put a line of ordinary body text at 1.66:1 when its pair is 4.55:1. So the pale pass
# only reports where the ground is genuinely dark — the desk, a photograph, a dusk render.
LIGHT_ON_DARK_MAX_GROUND = 0.30

# The ground is taken over every pixel in the ring box and not only the ones outside the stroke
# mask. That is deliberate and it was wrong the first time: in a dense paragraph the pixels around
# a letter are mostly its own antialiasing, so "everything that is not ink" has a light end that
# is not the paper but the halo, and the ground sinks toward the ink. It read a line of Pen.margin
# on lined stock at 2.83:1 when the pair is 4.55:1. A high percentile over the whole ring finds
# the paper whether or not the halo is in the sample.


def srgb_to_linear(a):
    return np.where(a <= 0.03928, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    """WCAG relative luminance, per pixel, from 8-bit sRGB."""
    lin = srgb_to_linear(rgb.astype(np.float64) / 255.0)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def contrast(a, b):
    hi, lo = (a, b) if a >= b else (b, a)
    return (hi + 0.05) / (lo + 0.05)


def box_mean(a, k):
    """Mean over a k x k window, by summed-area table. Edges repeat rather than darken."""
    pad = k // 2
    p = np.pad(a, pad, mode="edge")
    s = p.cumsum(axis=0).cumsum(axis=1)
    s = np.pad(s, ((1, 0), (1, 0)), mode="constant")
    h, w = a.shape
    tot = s[k:k + h, k:k + w] - s[0:h, k:k + w] - s[k:k + h, 0:w] + s[0:h, 0:w]
    return tot / float(k * k)


def label(ink):
    """Connected components of a boolean mask, by union-find over the set pixels only.

    The first version of this propagated the largest index through the whole array until it
    stopped changing, which is elegant and reads well and took a hundred and four seconds for one
    still. Ink is one or two percent of an image, so there is no reason to do arithmetic on the
    other ninety-eight: this walks the set pixels, unions each with the neighbour above and the
    neighbour to the left, and is done in about a second.
    """
    ys, xs = np.nonzero(ink)
    n = ys.size
    if n == 0:
        return ys, xs, np.empty(0, dtype=np.int64)
    at = -np.ones(ink.shape, dtype=np.int64)
    at[ys, xs] = np.arange(n)

    up = np.where(ys > 0, at[np.maximum(ys - 1, 0), xs], -1)
    left = np.where(xs > 0, at[ys, np.maximum(xs - 1, 0)], -1)

    parent = list(range(n))

    def find(a):
        root = a
        while parent[root] != root:
            root = parent[root]
        while parent[a] != root:       # path compression, iterative: these chains get long
            parent[a], a = root, parent[a]
        return root

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    for nbr in (up, left):
        idx = np.nonzero(nbr >= 0)[0]
        nb = nbr[idx]
        for a, b in zip(idx.tolist(), nb.tolist()):
            union(a, b)

    roots = np.fromiter((find(i) for i in range(n)), dtype=np.int64, count=n)
    return ys, xs, roots


def runs_of(boxes, gap=26):
    """Group glyph boxes that sit on one line into runs, left to right."""
    out = []
    for b in sorted(boxes, key=lambda b: (b[0] // 24, b[2])):
        y0, y1, x0, x1 = b
        placed = False
        for r in out:
            overlap = min(y1, r[1]) - max(y0, r[0])
            if overlap > 0.45 * min(y1 - y0, r[1] - r[0]) and x0 - r[3] < gap and x1 > r[2] - gap:
                r[0], r[1] = min(r[0], y0), max(r[1], y1)
                r[2], r[3] = min(r[2], x0), max(r[3], x1)
                r[4] += 1
                placed = True
                break
        if not placed:
            out.append([y0, y1, x0, x1, 1])
    return out


def marks(gam, ground_gam, polarity):
    """Pixels that sit far enough off the local paper to be a mark, in gamma space."""
    if polarity == "dark":
        return gam < (ground_gam - INK_DELTA)
    return gam > (ground_gam + INK_DELTA)


def measure(path):
    with Image.open(path) as im:
        rgb = np.asarray(im.convert("RGB"))
    H, W = rgb.shape[:2]
    lum = luminance(rgb)                                  # for the arithmetic WCAG specifies
    gam = rgb.astype(np.float64).mean(axis=2) / 255.0     # for deciding what is a mark
    ground_gam = box_mean(gam, GROUND_WINDOW)

    min_h = max(7, int(GLYPH_MIN_H_FRAC * H))
    max_h = int(GLYPH_MAX_H_FRAC * H)

    out = []
    seen = 0
    # Both polarities, because this app writes dark ink on pale paper *and* a pale stamped label
    # straight onto dark waxed oak. A checker that only looked for dark-on-light would have been
    # blind to exactly the pair the build already knows is its worst.
    for polarity in ("dark", "light"):
        mask = marks(gam, ground_gam, polarity)
        if mask.sum() < 60:
            continue
        ys, xs, roots = label(mask)
        if roots.size == 0:
            continue
        order = np.argsort(roots, kind="stable")
        ys, xs, roots = ys[order], xs[order], roots[order]
        starts = np.searchsorted(roots, np.unique(roots))
        bounds = list(starts) + [roots.size]

        boxes = []
        for i in range(len(bounds) - 1):
            a, b = bounds[i], bounds[i + 1]
            area = b - a
            if not (GLYPH_MIN_AREA <= area <= GLYPH_MAX_AREA):
                continue
            yy, xx = ys[a:b], xs[a:b]
            y0, y1 = int(yy.min()), int(yy.max()) + 1
            x0, x1 = int(xx.min()), int(xx.max()) + 1
            h, w = y1 - y0, x1 - x0
            if not (min_h <= h <= max_h):
                continue
            if w > 14 * h or h > 14 * w:      # a printed rule, a tear edge, a stem of nothing
                continue
            boxes.append((y0, y1, x0, x1))
        seen += len(boxes)

        for y0, y1, x0, x1, n in runs_of(boxes):
            ring = max(RING, (y1 - y0) // 2)
            ry0, ry1 = max(0, y0 - ring), min(H, y1 + ring)
            rx0, rx1 = max(0, x0 - ring), min(W, x1 + ring)
            pl = lum[ry0:ry1, rx0:rx1]
            pm = mask[ry0:ry1, rx0:rx1]
            stroke = pl[pm]
            if stroke.size < 40 or pl.size < 400:
                continue
            if polarity == "dark":
                core = float(np.percentile(stroke, 10))         # the darkest of the stroke
                g = float(np.percentile(pl, GROUND_PCTL))       # the lightest of the ring
            else:
                core = float(np.percentile(stroke, 90))         # the lightest of the stroke
                g = float(np.percentile(pl, 100 - GROUND_PCTL)) # the darkest of the ring
            # The test is the median of the surface, not its dark end. A paragraph of dark ink on
            # cream has a very dark tenth percentile — it is full of letters — and reading that as
            # "a dark ground" turns ordinary text inside out and reports the paper as failing ink.
            if polarity == "light" and float(np.median(pl)) > LIGHT_ON_DARK_MAX_GROUND:
                continue
            med = float(np.median(stroke))
            height = y1 - y0
            width = x1 - x0
            # One narrow mark on its own is a pen stroke, a rule end or a piece of a drawn
            # feeling, not writing. Writing is either several glyphs on a line or one wide
            # connected word, which is what a cursive hand produces.
            if n < 2 and width < 2 * height:
                continue
            floor = FLOOR_LARGE if height >= LARGE_PX else FLOOR_BODY
            out.append({
                "box": [x0, y0, x1 - x0, height],
                "glyphs": n,
                "polarity": polarity,
                "role": "large" if height >= LARGE_PX else "body",
                "floor": floor,
                "ink_core": round(contrast(core, g), 2),
                "ink_median": round(contrast(med, g), 2),
                "ground_lum": round(g, 4),
            })
    return {"runs": out, "glyphs": seen, "size": [W, H]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--only", default="", help="one artifact filename")
    ap.add_argument("--worst", type=int, default=12, help="how many failures to print")
    ap.add_argument("--dir", default=EVIDENCE)
    args = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(args.dir, "*.png")))
    if args.only:
        paths = [p for p in paths if os.path.basename(p) == args.only]
    if not paths:
        print(f"legibility: no PNGs in {args.dir}", file=sys.stderr)
        return 2

    report = {
        "mode": "measured-from-pixels",
        "floors": {"body": FLOOR_BODY, "large": FLOOR_LARGE, "large_above_px": LARGE_PX},
        "artifacts": {},
        "failures": [],
    }
    for path in paths:
        name = os.path.basename(path)
        m = measure(path)
        runs = m.get("runs", [])
        bad = [r for r in runs if r["ink_core"] < r["floor"]]
        worst = min((r["ink_core"] for r in runs), default=None)
        report["artifacts"][name] = {
            "runs": len(runs),
            "below_floor": len(bad),
            "worst_ink_core": worst,
            "median_ink_core": round(float(np.median([r["ink_core"] for r in runs])), 2) if runs else None,
            "median_as_rendered": round(float(np.median([r["ink_median"] for r in runs])), 2) if runs else None,
            "detail": sorted(bad, key=lambda r: r["ink_core"])[:60],
        }
        for r in bad:
            report["failures"].append({
                "artifact": name, "box": r["box"], "role": r["role"], "polarity": r["polarity"],
                "ink_core": r["ink_core"], "ink_median": r["ink_median"], "floor": r["floor"],
            })

    report["failures"].sort(key=lambda f: f["ink_core"])
    report["read"] = len(paths)
    report["total_runs"] = sum(a["runs"] for a in report["artifacts"].values())
    report["total_below_floor"] = len(report["failures"])
    report["ok"] = not report["failures"]

    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{report['total_runs']} runs read across {report['read']} artifacts "
              f"-> {args.out}")
    else:
        print(text)

    if report["failures"]:
        print(f"\n{len(report['failures'])} text run(s) below their contrast floor:", file=sys.stderr)
        for f in report["failures"][:args.worst]:
            x, y, w, h = f["box"]
            print(f"  {f['artifact']:<24} {f['ink_core']:>5.2f}:1 (floor {f['floor']}, "
                  f"{f['ink_median']:.2f}:1 as rendered)  {f['role']:<5} {f['polarity']:<5} "
                  f"{w}x{h} at {x},{y}", file=sys.stderr)
        return 1
    print(f"{report['total_runs']} text runs, every one of them above its floor")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
