#!/usr/bin/env python3
"""Every glyph, and every one of its variants, still has all of its ink.

The failure this exists to catch happened: skia refused a union while the outlines were being
built, the builder skipped the stroke, and the font shipped with an 'h' that had lost its ascender
and a 'b' that was a stub. Nothing about the build failed; the letters were simply wrong, and the
only place it showed was a screenshot of a note that read "ecause I have a heavy hand".

So the check is: no variant may be much smaller than its siblings. A variant that is *larger* is
fine — a 1 with a base serif really is twice the width of a bare stem — but one that has lost a
third of its height has lost a stroke.

    python3 tools/handwriting/check.py
    python3 tools/handwriting/check.py --json --out evidence/logs/fonts.json

And the second failure, found a cycle later: every variant of a glyph was pixel-identical to the
others on screen (IoU 0.998 on the 300 percent crop), because they differed by less than a device
pixel at the size a note is written. So the check also asks, for each glyph, how far apart its
variants are — the symmetric Hausdorff distance between their outlines, in font units — and fails
a face whose variants sit closer than the distance its hands.json entry asks for.
"""
import argparse
import json
import os
import statistics
import string
import sys

import numpy as np
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTFont

# How much a hand's stroke has to vary along its length, as a coefficient of variation over the
# medial-axis widths of its lower case at the size it is shown at. Measured on the shipped faces
# before the pressure model was widened: TeoHand 0.168, NoorHand 0.190, which a critic read off a
# captured note as 0.186 and called pressureless. The floor is set under what the widened model
# gives (0.249 and 0.259) and well over what it replaced.
STROKE_CV_FLOOR = 0.22

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONTS = os.path.join(ROOT, "assets", "fonts")

# How much smaller than its siblings a variant may be before it has clearly lost something.
# Height is the strict one, because a lost stroke is nearly always a lost ascender or descender —
# that is what an 'h' without its stem and a 'b' reduced to a stub both look like. Width is loose,
# because two alternates of a letter can legitimately be different shapes: a capital I with serifs
# really is twice the width of a bare stem, and telling them apart is the point of having both.
FLOOR_HEIGHT = 0.68
FLOOR_WIDTH = 0.45
LETTERS = string.ascii_letters + string.digits + ".,;:'\"?()-"


def bounds(glyphs, name):
    pen = BoundsPen(glyphs)
    glyphs[name].draw(pen)
    return pen.bounds


def outline_points(glyphs, name, per_segment=6):
    """The outline as a cloud of points, curves sampled along their length."""
    pen = RecordingPen()
    glyphs[name].draw(pen)
    pts = []
    cur = None
    start = None
    for op, args in pen.value:
        if op == "moveTo":
            cur = start = args[0]
            pts.append(cur)
        elif op == "lineTo":
            nxt = args[0]
            for t in np.linspace(0, 1, per_segment, endpoint=False)[1:]:
                pts.append((cur[0] + (nxt[0] - cur[0]) * t, cur[1] + (nxt[1] - cur[1]) * t))
            cur = nxt
            pts.append(cur)
        elif op == "qCurveTo":
            # TrueType: implied on-curve points between consecutive off-curve ones
            controls = list(args)
            if controls[-1] is None:
                controls = controls[:-1]
                controls.append(((controls[0][0] + controls[-1][0]) / 2, (controls[0][1] + controls[-1][1]) / 2))
            offs, end = controls[:-1], controls[-1]
            p0 = cur
            for i, c in enumerate(offs):
                p2 = end if i == len(offs) - 1 else ((c[0] + offs[i + 1][0]) / 2, (c[1] + offs[i + 1][1]) / 2)
                for t in np.linspace(0, 1, per_segment, endpoint=False)[1:]:
                    x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t ** 2 * p2[0]
                    y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t ** 2 * p2[1]
                    pts.append((x, y))
                p0 = p2
            cur = end
            pts.append(cur)
        elif op == "curveTo":
            c1, c2, end = args[-3], args[-2], args[-1]
            for t in np.linspace(0, 1, per_segment, endpoint=False)[1:]:
                x = (1 - t) ** 3 * cur[0] + 3 * (1 - t) ** 2 * t * c1[0] + 3 * (1 - t) * t ** 2 * c2[0] + t ** 3 * end[0]
                y = (1 - t) ** 3 * cur[1] + 3 * (1 - t) ** 2 * t * c1[1] + 3 * (1 - t) * t ** 2 * c2[1] + t ** 3 * end[1]
                pts.append((x, y))
            cur = end
            pts.append(cur)
        elif op in ("closePath", "endPath"):
            if start is not None and cur is not None and cur != start:
                pts.append(start)
            cur = start = None
    return np.array(pts, dtype=float) if pts else np.zeros((0, 2))


def _contours(glyphs, name):
    """The glyph's closed contours as point lists, and the sign of its net area."""
    pen = RecordingPen()
    glyphs[name].draw(pen)
    out, cur = [], []
    for op, args in pen.value:
        if op == "moveTo":
            cur = [args[0]]
        elif op == "lineTo":
            cur.append(args[0])
        elif op == "qCurveTo":
            cur.extend(a for a in args if a is not None)
        elif op == "curveTo":
            cur.extend(args)
        elif op in ("closePath", "endPath"):
            if len(cur) > 2:
                out.append(cur)
            cur = []
    return out


def stroke_widths(glyphs, name, upm, px_per_em=54.0):
    """The widths a stroke of this glyph actually has, in device pixels at [px_per_em].

    A hand varies its stroke as it presses and lifts; a machine-set face does not. The pressure
    model is authored in tools/handwriting/hands.json and turned into an outline by build.py, and
    nothing until now measured whether any of it reached the outline — a critic measured a
    coefficient of variation of 0.186 on a captured note and called the handwriting pressureless.

    Measured on the built outline rather than on a rendering, so it is the font that is being
    judged: the glyph is filled at the size it is shown at, and the medial axis is taken as the
    ridge of the distance transform. Twice the distance at a ridge point is the width there.
    """
    import cv2
    from PIL import Image, ImageDraw
    cs = _contours(glyphs, name)
    if not cs:
        return np.zeros(0)
    scale = px_per_em / upm
    pts = np.vstack([np.asarray(c, float) for c in cs]) * scale
    x0, y0 = pts.min(axis=0) - 3
    x1, y1 = pts.max(axis=0) + 3
    w, h = int(x1 - x0) + 1, int(y1 - y0) + 1
    if w < 6 or h < 6 or w > 4000 or h > 4000:
        return np.zeros(0)
    areas = []
    for c in cs:
        a = np.asarray(c, float)
        areas.append(0.5 * float(np.dot(a[:, 0], np.roll(a[:, 1], -1)) - np.dot(a[:, 1], np.roll(a[:, 0], -1))))
    net = sum(areas)
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    # outers first, then the holes cut back out: PIL fills by scanline, not by winding
    for c, a in sorted(zip(cs, areas), key=lambda t: -abs(t[1])):
        poly = [((px * scale - x0), (h - (py * scale - y0))) for px, py in c]
        d.polygon(poly, fill=255 if (a < 0) == (net < 0) else 0)
    ink = (np.asarray(im) > 127).astype(np.uint8)
    if ink.sum() < 20:
        return np.zeros(0)
    dt = cv2.distanceTransform(ink, cv2.DIST_L2, 5)
    # the ridge: no neighbour is further from the edge than this pixel is
    mx = cv2.dilate(dt, np.ones((3, 3), np.uint8))
    ridge = (dt >= mx - 1e-6) & (dt > 0.9)
    return 2.0 * dt[ridge]


def ink_area(glyphs, name):
    """The glyph's filled area under the nonzero rule, as font units squared, and whether any
    contour winds the outer way. A stroke whose union failed can keep its bounding box and lose
    its ink: the '9' that read as a faint ring in a timestamp had four contours all wound as
    holes and a fifth of its siblings' area."""
    pen = RecordingPen()
    glyphs[name].draw(pen)
    contours, cur = [], []
    for op, args in pen.value:
        if op == "moveTo":
            cur = [args[0]]
        elif op == "lineTo":
            cur.append(args[0])
        elif op == "qCurveTo":
            cur.extend(a for a in args if a is not None)
        elif op == "curveTo":
            cur.extend(args)
        elif op in ("closePath", "endPath"):
            if len(cur) > 2:
                contours.append(cur)
            cur = []
    areas = []
    for c in contours:
        areas.append(0.5 * sum(c[i][0] * c[(i + 1) % len(c)][1] - c[(i + 1) % len(c)][0] * c[i][1]
                               for i in range(len(c))))
    net = sum(areas)
    outer = sum(1 for a in areas if (a < 0) == (net < 0))
    return abs(net), outer


def hausdorff(a, b):
    """Symmetric Hausdorff distance between two point clouds, in the units they are given in."""
    if len(a) == 0 or len(b) == 0:
        return 0.0
    d = np.sqrt(((a[:, None, :] - b[None, :, :]) ** 2).sum(axis=2))
    return float(max(d.min(axis=1).max(), d.min(axis=0).max()))


def distinct_floor(font_name, hands_path):
    """How far apart a face's variants have to be, from its hands.json entry."""
    try:
        with open(hands_path, encoding="utf-8") as f:
            hands = json.load(f)
    except OSError:
        return 40.0
    entry = hands.get(font_name) or {}
    # The builder is given twenty-four attempts at each variant and keeps the one furthest from
    # its siblings when none reaches the asked distance, so a glyph can ship a little under it.
    # Two thirds of the distance is still a device pixel and a half at the size a note is
    # written; under that the variants are one shape on the page.
    return 0.65 * float(entry.get("distinct_min", 40.0))


def year_texts(limit=4000):
    """What the couple actually wrote, for measuring how often a letter repeats itself. Falls back
    to a pangram when the seed is not packed, so the check runs on a bare clone."""
    import glob
    out = []
    for f in sorted(glob.glob(os.path.join(ROOT, "app", "assets", "seed", "year", "*.jsonl"))):
        for line in open(f, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            body = e.get("body") or e.get("payload") or {}
            if isinstance(body, dict) and isinstance(body.get("text"), str):
                out.append(body["text"])
            if len(out) >= limit:
                return out
    return out or ["the quick brown fox jumps over the lazy dog, and the dog lets it"]


def twin_share(path, hands_path):
    """How often two of the same letter in one piece of writing come out as the same outline.

    Measured against the rules the builder writes, over the year's own messages, rather than
    against a rendering — a rendering measures the renderer as much as the font. The floor is one
    in `variants`: with that many outlines and an index that walks over them, that share of pairs
    coincides however the rules are arranged, so the number to read is how close to the floor it
    sits.
    """
    sys.path.insert(0, os.path.join(ROOT, "tools", "handwriting"))
    try:
        import build as builder
    except ImportError:
        return None
    face = os.path.splitext(os.path.basename(path))[0]
    with open(hands_path, encoding="utf-8") as f:
        hand = json.load(f).get(face)
    if not hand:
        return None
    n = int(hand.get("variants", 1))
    if n < 2:
        return {"variants": n, "share": None, "floor": None}
    letters = set("abcdefghijklmnopqrstuvwxyz")
    texts = year_texts()
    return {
        "variants": n,
        "share": round(builder.twin_rate(texts, letters, n), 4),
        "if_the_step_were_fixed": round(builder.twin_rate(texts, letters, n, fixed_step=True), 4),
        "floor": round(1.0 / n, 4),
        "texts": len(texts),
    }


def check(path, hands_path=os.path.join(ROOT, "tools", "handwriting", "hands.json")):
    font = TTFont(path)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    order = font.getGlyphOrder()
    findings = []
    variants = 0
    apart_floor = distinct_floor(os.path.splitext(os.path.basename(path))[0], hands_path)
    apart = []       # the closest pair of variants, per glyph
    too_close = []
    for ch in LETTERS:
        base = cmap.get(ord(ch))
        if not base:
            findings.append({"glyph": ch, "why": "no glyph for this character at all"})
            continue
        names = [base] + [n for n in order if n.startswith(base + ".v")]
        variants += len(names)
        sizes = []
        for n in names:
            b = bounds(glyphs, n)
            if b is None:
                findings.append({"glyph": n, "why": "no outline"})
                sizes.append((n, 0.0, 0.0))
                continue
            sizes.append((n, b[2] - b[0], b[3] - b[1]))
        # and how far apart the variants sit: the nearest pair, in font units
        clouds = [outline_points(glyphs, n) for n in names]
        nearest = None
        for i in range(len(clouds)):
            for j in range(i + 1, len(clouds)):
                d = hausdorff(clouds[i], clouds[j])
                nearest = d if nearest is None else min(nearest, d)
        if nearest is not None:
            # a full stop cannot move forty units without leaving its place on the line, so the
            # floor for a glyph is never more than a fair fraction of the glyph's own size
            size = max(max(w for _, w, _ in sizes), max(h for _, _, h in sizes), 1.0)
            floor_here = min(apart_floor, 0.3 * size)
            apart.append((ch, round(nearest, 1)))
            # punctuation is reported but not held to the floor: nobody reads a hand off its
            # full stops, and a dot has nowhere to go
            if nearest < floor_here and ch.isalnum():
                too_close.append({"glyph": ch, "nearest_variants_apart": round(nearest, 1), "floor": round(floor_here, 1)})
        # and how much ink each variant carries: a variant with its bounding box intact and a
        # fraction of its siblings' filled area has lost strokes to a failed union
        inks = [ink_area(glyphs, n) for n in names]
        med_ink = statistics.median([a for a, _ in inks]) or 1.0
        for n, (a, outer) in zip(names, inks):
            if a < med_ink * 0.55 or outer == 0:
                findings.append({
                    "glyph": n,
                    "why": "carries a fraction of its siblings' ink: a stroke was lost in the union",
                    "ink": round(a),
                    "siblings": round(med_ink),
                })
        widths = statistics.median([w for _, w, _ in sizes]) or 1.0
        heights = statistics.median([h for _, _, h in sizes]) or 1.0
        for n, w, h in sizes:
            if h < heights * FLOOR_HEIGHT or w < widths * FLOOR_WIDTH:
                findings.append({
                    "glyph": n,
                    "why": "smaller than its siblings, so a stroke went missing in the union",
                    "size": [round(w), round(h)],
                    "siblings": [round(widths), round(heights)],
                })
    # A face with one variant per glyph has nothing to keep apart; one that claims variants has
    # to keep every glyph's variants at least the floor apart, or the variants are decoration in
    # the font file and identical on the page.
    distances = [d for _, d in apart]
    # How much the stroke varies as the hand presses and lifts. A stamp is meant to be even, so
    # only the hands carry a floor.
    upm = font["head"].unitsPerEm
    letters = [n for ch, n in cmap.items()
               if chr(ch).isalpha() and chr(ch).islower() and n in glyphs.keys()]
    widths = np.concatenate([stroke_widths(glyphs, n, upm) for n in sorted(letters)[:40]]) \
        if letters else np.zeros(0)
    if widths.size > 200:
        stroke = {
            "measured_at_px_per_em": 54,
            "samples": int(widths.size),
            "mean_px": round(float(widths.mean()), 3),
            "cv": round(float(widths.std() / widths.mean()), 4),
            "p1_px": round(float(np.percentile(widths, 1)), 3),
            "p99_px": round(float(np.percentile(widths, 99)), 3),
            "floor_cv": STROKE_CV_FLOOR if "Hand" in os.path.basename(path) else None,
        }
        if stroke["floor_cv"] and stroke["cv"] < STROKE_CV_FLOOR:
            findings.append({
                "glyph": "(the face)",
                "why": f"the stroke barely varies: coefficient of variation {stroke['cv']} "
                       f"against a floor of {STROKE_CV_FLOOR}. A hand presses and lifts.",
            })
    else:
        stroke = {"samples": int(widths.size), "why": "too little ink to measure"}
    return {
        "font": os.path.relpath(path, ROOT),
        "stroke": stroke,
        "glyphs": len(order),
        "variants_checked": variants,
        "twins": twin_share(path, hands_path),
        "findings": findings,
        "variants_apart": {
            "floor_units": apart_floor,
            "min": min(distances) if distances else None,
            "median": round(statistics.median(distances), 1) if distances else None,
            "too_close": too_close,
        },
        "ok": not findings and not too_close,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="")
    ap.add_argument("--dir", default=FONTS)
    args = ap.parse_args()

    reports = []
    for name in sorted(os.listdir(args.dir)):
        if name.endswith(".ttf"):
            reports.append(check(os.path.join(args.dir, name)))
    out = {"fonts": reports, "ok": all(r["ok"] for r in reports)}
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=1)
    if args.json:
        print(json.dumps(out, indent=1))
    else:
        for r in reports:
            va = r["variants_apart"]
            print(f"{r['font']}: {r['variants_checked']} variants, {len(r['findings'])} broken, "
                  f"variants apart min {va['min']} / median {va['median']} (floor {va['floor_units']}), "
                  f"{len(va['too_close'])} glyphs too close")
            for f in r["findings"][:10]:
                print(f"   {f['glyph']}: {f['why']}")
            for f in va["too_close"][:10]:
                print(f"   {f['glyph']}: variants only {f['nearest_variants_apart']} units apart")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
