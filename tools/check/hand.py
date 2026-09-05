#!/usr/bin/env python3
"""Are the letters on the page actually different from each other?

    python3 tools/check/hand.py evidence/02_chat.png --out evidence/logs/hand.json

The handwriting fonts carry several variants of every glyph and a calt feature that cycles them,
and for two cycles that was true of the font file and false of the page: the variants differed by
less than a device pixel, so a critic laying one 'e' over the next found them identical (IoU
0.998). This reads the same 300 percent crop the critics are handed and does what they did — finds
every mark of ink, normalises each to the same box, and lays every pair of similar-sized marks over
each other. Two glyphs of the same letter from a hand that varies should not fit each other; two
from a font that does not will.

What is reported is the distribution of the best fit each mark has among the others, and how many
marks have a near-twin (IoU above 0.85). The pass condition is that no more than a small share of
marks have one: a real hand repeats itself a little, a font repeats itself exactly.
"""
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image

TWIN = 0.85
BOX = 24


def ink_mask(im):
    """Ink: dark pixels on paper. The desk is dark too, so first the paper is found — the bright
    pixels, grown a little so a letter's own pixels count as inside it — and only what is dark
    inside the paper is ink. On the 300 percent crop half the frame was desk, and every pixel of
    it was read as one enormous mark."""
    grey = np.asarray(im.convert("L")).astype(float)
    paper = grey > 170
    # grow the paper region over the letters written on it: a letter is at most ~70 px tall at
    # 3x, so a box of that order closes the gaps
    from PIL import ImageFilter
    grown = Image.fromarray((paper * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(31))
    grown = np.asarray(grown) > 127
    # and shrink back so the paper's own edge (the torn fibres against the desk) is not inside
    shrunk = Image.fromarray((grown * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(15))
    inside = np.asarray(shrunk) > 127
    return inside & (grey < 120)


def components(mask, min_px=30, max_frac=0.2):
    """Connected marks of ink, four-connected, with their bounding boxes."""
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    marks = []
    n = 0
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if labels[y0, x0]:
            continue
        n += 1
        stack = [(y0, x0)]
        labels[y0, x0] = n
        pts = []
        while stack:
            y, x = stack.pop()
            pts.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not labels[yy, xx]:
                    labels[yy, xx] = n
                    stack.append((yy, xx))
        if len(pts) < min_px:
            continue
        arr = np.array(pts)
        top, left = arr.min(axis=0)
        bottom, right = arr.max(axis=0)
        if (bottom - top) > h * max_frac or (right - left) > w * max_frac:
            continue      # a rule line or a tear edge, not a letter
        box = np.zeros((bottom - top + 1, right - left + 1), dtype=bool)
        box[arr[:, 0] - top, arr[:, 1] - left] = True
        for piece, offset in split_joined(box):
            if piece.sum() >= min_px:
                marks.append({"top": int(top), "left": int(left + offset), "h": int(piece.shape[0]),
                              "w": int(piece.shape[1]), "box": piece})
    return marks


def split_joined(box):
    """A word in a joined hand is one component. Letters join through thin strokes, so the
    component is cut wherever a column carries almost no ink, and each run between cuts is a mark.
    A thin-column cut does not separate letters that overlap in x — nothing short of a reading
    would — and what is left joined is compared as the shape it is."""
    cols = box.sum(axis=0)
    if box.shape[1] < 2 * box.shape[0] * 0.8:
        return [(box, 0)]      # about as wide as tall: one letter
    typical = np.median(cols[cols > 0]) if (cols > 0).any() else 0
    thin = cols <= max(1, typical * 0.22)
    pieces = []
    start = None
    for x in range(box.shape[1] + 1):
        inside = x < box.shape[1] and not thin[x]
        if inside and start is None:
            start = x
        elif not inside and start is not None:
            if x - start >= 3:
                sub = box[:, start:x]
                rows = np.nonzero(sub.any(axis=1))[0]
                sub = sub[rows.min():rows.max() + 1]
                pieces.append((sub, start))
            start = None
    return pieces or [(box, 0)]


def normalised(box):
    im = Image.fromarray((box * 255).astype(np.uint8)).resize((BOX, BOX), Image.BILINEAR)
    return np.asarray(im) > 127


def iou(a, b):
    inter = np.logical_and(a, b).sum()
    union = np.logical_or(a, b).sum()
    return float(inter / union) if union else 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("crop")
    ap.add_argument("--out", default="")
    ap.add_argument("--twin", type=float, default=TWIN)
    ap.add_argument("--max-twin-share", type=float, default=0.25,
                    help="the share of marks allowed a near-twin before the hand is a font")
    args = ap.parse_args()

    path = pathlib.Path(args.crop)
    if not path.exists():
        report = {"crop": str(path), "missing": "no crop to read", "ok": False}
    else:
        with Image.open(path) as im:
            mask = ink_mask(im)
        marks = components(mask)
        norms = [normalised(m["box"]) for m in marks]
        best = []
        pairs_over = 0
        for i, a in enumerate(norms):
            bi = 0.0
            for j, b in enumerate(norms):
                if i == j:
                    continue
                # only marks of about the same shape can be the same letter
                ra, rb = marks[i]["h"] / max(marks[i]["w"], 1), marks[j]["h"] / max(marks[j]["w"], 1)
                if abs(marks[i]["h"] - marks[j]["h"]) > 0.35 * max(marks[i]["h"], marks[j]["h"]):
                    continue
                if abs(ra - rb) > 0.5 * max(ra, rb):
                    continue
                v = iou(a, b)
                if v > bi:
                    bi = v
                if j > i and v >= args.twin:
                    pairs_over += 1
            best.append(round(bi, 3))
        twins = sum(1 for b in best if b >= args.twin)
        share = twins / len(best) if best else 0.0
        srt = sorted(best)
        report = {
            "crop": str(path),
            "marks": len(marks),
            "best_fit_iou": {
                "median": srt[len(srt) // 2] if srt else None,
                "p90": srt[int((len(srt) - 1) * 0.9)] if srt else None,
                "max": srt[-1] if srt else None,
            },
            "marks_with_a_twin": twins,
            "twin_share": round(share, 3),
            "pairs_over_twin": pairs_over,
            "twin_iou": args.twin,
            "note": "marks are connected components of ink, normalised to one box; a font repeats "
                    "itself exactly, a hand a little",
            "ok": len(marks) >= 12 and share <= args.max_twin_share,
        }
    text = json.dumps(report, indent=1)
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(text)
    print(text if not args.out else
          f"{report.get('marks', 0)} marks, {report.get('marks_with_a_twin', 0)} with a near-twin "
          f"(share {report.get('twin_share')}), best-fit median {report.get('best_fit_iou', {}).get('median')}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
