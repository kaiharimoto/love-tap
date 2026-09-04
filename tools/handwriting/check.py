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
"""
import argparse
import json
import os
import statistics
import string
import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont

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


def check(path):
    font = TTFont(path)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    order = font.getGlyphOrder()
    findings = []
    variants = 0
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
    return {
        "font": os.path.relpath(path, ROOT),
        "glyphs": len(order),
        "variants_checked": variants,
        "findings": findings,
        "ok": not findings,
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
            print(f"{r['font']}: {r['variants_checked']} variants, {len(r['findings'])} broken")
            for f in r["findings"][:10]:
                print(f"   {f['glyph']}: {f['why']}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
