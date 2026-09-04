#!/usr/bin/env python3
"""Three 300 percent crops of the hero, at the places the paper has to survive being stared at.

Fixed fractions of the frame do not work: whatever is at 30 percent down the picture depends on
where the thread was scrolled to, and the first version of this pointed all three crops at a
stretch of bare desk. So the crops are found rather than guessed — the paper is located, and the
three boxes are taken from a torn edge, from a written line, and from the side of a piece where its
contact shadow falls.

The upscale is nearest-neighbour on purpose. A smooth one would hide exactly the thing the crop
exists to show.
"""
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image

# the light comes from the upper left (DIRECTION.md), so a contact shadow falls to the lower right
LIGHT = (-1, -1)


def paper_mask(grey):
    """Paper is much lighter than the desk it lies on, so one threshold separates them."""
    lo, hi = np.percentile(grey, 5), np.percentile(grey, 98)
    return grey > (lo + hi) / 2


def biggest_region(mask, band=(0.10, 0.88)):
    """The largest run of paper, ignoring the strip at the top and the tabs at the bottom."""
    h = mask.shape[0]
    rows = np.zeros(h, dtype=bool)
    rows[int(h * band[0]):int(h * band[1])] = True
    inside = mask & rows[:, None]
    if not inside.any():
        return None
    # column and row extents of the densest horizontal band of paper
    per_row = inside.sum(axis=1)
    best = int(np.argmax(np.convolve(per_row, np.ones(80) / 80, mode="same")))
    lo = best
    while lo > 0 and per_row[lo - 1] > per_row[best] * 0.35:
        lo -= 1
    hi = best
    while hi < h - 1 and per_row[hi + 1] > per_row[best] * 0.35:
        hi += 1
    cols = np.where(inside[lo:hi].any(axis=0))[0]
    if len(cols) == 0:
        return None
    return lo, hi, int(cols.min()), int(cols.max())


def find_places(im, box_w, box_h):
    grey = np.asarray(im.convert("L"), dtype=np.float32) / 255.0
    mask = paper_mask(grey)
    region = biggest_region(mask)
    if region is None:
        return []
    top, bottom, left, right = region
    mid_y = (top + bottom) // 2
    places = []

    # a torn edge: the top boundary of the piece, where the fibres are
    edge_rows = np.where(mask[top:bottom, (left + right) // 2])[0]
    edge_y = top + (int(edge_rows.min()) if len(edge_rows) else 0)
    places.append(("edge", (left + right) // 2 - box_w // 2, edge_y - box_h // 3))

    # a written line: the darkest patch inside the paper is ink
    inside = grey[top:bottom, left:right].copy()
    inside[~mask[top:bottom, left:right]] = 1.0
    k = 24
    if inside.shape[0] > k and inside.shape[1] > k:
        coarse = inside[: inside.shape[0] // k * k, : inside.shape[1] // k * k]
        coarse = coarse.reshape(coarse.shape[0] // k, k, coarse.shape[1] // k, k).mean(axis=(1, 3))
        j, i = np.unravel_index(int(np.argmin(coarse)), coarse.shape)
        places.append(("hand", left + i * k - box_w // 2, top + j * k - box_h // 2))
    else:
        places.append(("hand", left, mid_y))

    # the contact shadow: the boundary on the side the light is not coming from
    shadow_rows = np.where(mask[top:bottom, (left + right) // 2])[0]
    shadow_y = top + (int(shadow_rows.max()) if len(shadow_rows) else bottom - top)
    places.append(("shadow", (left + right) // 2 - box_w // 2 - LIGHT[0] * box_w // 4,
                   shadow_y - box_h // 2))
    return places


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--out-dir", default="evidence/crops")
    ap.add_argument("--scale", type=int, default=3)
    ap.add_argument("--box", type=int, default=420, help="crop width in source pixels")
    args = ap.parse_args()

    im = Image.open(args.image)
    box_w = min(args.box, im.width // 2)
    box_h = round(box_w * 0.62)
    out = pathlib.Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stem = pathlib.Path(args.image).stem
    made = []
    for name, x, y in find_places(im, box_w, box_h):
        x = int(max(0, min(x, im.width - box_w)))
        y = int(max(0, min(y, im.height - box_h)))
        piece = im.crop((x, y, x + box_w, y + box_h))
        piece = piece.resize((piece.width * args.scale, piece.height * args.scale), Image.NEAREST)
        path = out / f"{stem}_{args.scale}00_{name}.png"
        piece.save(path)
        made.append({"name": name, "file": str(path), "box": [x, y, x + box_w, y + box_h],
                     "size": list(piece.size)})
    print(json.dumps({"source": args.image, "scale": args.scale,
                      "note": "boxes are found from the paper in the frame, not fixed fractions",
                      "crops": made}, indent=1))
    return 0 if made else 1


if __name__ == "__main__":
    sys.exit(main())
