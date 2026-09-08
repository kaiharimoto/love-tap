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


def note_bands(mask, band=(0.08, 0.80), least=40):
    """Every run of rows that is mostly paper, in the part of the frame the thread has.

    The first version took the single densest band and called it the paper. The densest band on a
    chat screen is the sheet you write on — it is the widest piece on the glass and it is always
    there — so the crop the material row is judged on landed on the composer's own placeholder,
    and a critic had to cut its own. The thread is what these crops are of, so the sheet at the
    bottom and the tab strip under it are out of the search, and what is left is every note.
    """
    h, w = mask.shape
    lo_row, hi_row = int(h * band[0]), int(h * band[1])
    per_row = mask[:, :].sum(axis=1)
    wide = per_row > w * 0.45
    out = []
    y = lo_row
    while y < hi_row:
        if not wide[y]:
            y += 1
            continue
        start = y
        while y < hi_row and wide[y]:
            y += 1
        if y - start >= least:
            cols = np.where(mask[start:y].any(axis=0))[0]
            if len(cols):
                out.append((start, y, int(cols.min()), int(cols.max())))
    return out


def find_places(im, box_w, box_h):
    grey = np.asarray(im.convert("L"), dtype=np.float32) / 255.0
    mask = paper_mask(grey)
    bands = note_bands(mask)
    if not bands:
        return []
    # the tallest note, which is the one with the most writing on it
    top, bottom, left, right = max(bands, key=lambda b: b[1] - b[0])
    places = []

    # A written line, found by sliding the crop's own box over the note and taking the box with
    # the most ink in it. Taking the darkest 24-pixel patch instead put the box on whatever single
    # mark was darkest — a tear's own shadow line, often — and the crop came back "mostly tear and
    # desk with one partial word of script across its top edge".
    # Ink is dark, and paper_mask says paper is light, so `ink & mask` was always empty and the
    # box never moved off the first place it looked. Ink is the dark pixels inside the note's own
    # rectangle, not inside the paper mask.
    ink = np.zeros_like(mask)
    ink[top:bottom, left:right] = grey[top:bottom, left:right] < 0.55
    best, at = -1, None
    step = max(8, box_w // 12)
    for y in range(top, max(top + 1, bottom - box_h), step):
        for x in range(left, max(left + 1, right - box_w), step):
            n = int(ink[y:y + box_h, x:x + box_w].sum())
            if n > best:
                best, at = n, (x, y)
    if at is None:
        at = (left, top)
    places.append(("hand", at[0], at[1]))
    hand_ink = best / float(box_w * box_h)

    # a torn edge: the top boundary of that same note, where the fibres are
    mid = (left + right) // 2
    rows = np.where(mask[top:bottom, mid])[0]
    edge_y = top + (int(rows.min()) if len(rows) else 0)
    places.append(("edge", mid - box_w // 2, edge_y - box_h // 3))

    # the contact shadow: the boundary on the side the light is not coming from
    shadow_y = top + (int(rows.max()) if len(rows) else bottom - top)
    places.append(("shadow", mid - box_w // 2 - LIGHT[0] * box_w // 4, shadow_y - box_h // 2))
    return places, hand_ink


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
    found = find_places(im, box_w, box_h)
    places, hand_ink = found if found else ([], 0.0)
    for name, x, y in places:
        x = int(max(0, min(x, im.width - box_w)))
        y = int(max(0, min(y, im.height - box_h)))
        piece = im.crop((x, y, x + box_w, y + box_h))
        piece = piece.resize((piece.width * args.scale, piece.height * args.scale), Image.NEAREST)
        path = out / f"{stem}_{args.scale}00_{name}.png"
        piece.save(path)
        made.append({"name": name, "file": str(path), "box": [x, y, x + box_w, y + box_h],
                     "size": list(piece.size)})
    print(json.dumps({"source": args.image, "scale": args.scale,
                      "note": "boxes are found from the paper in the frame, not fixed fractions; "
                              "the sheet you write on and the tab strip are out of the search, "
                              "because these are crops of the thread",
                      "ink_in_the_hand_crop": round(hand_ink, 4),
                      "crops": made}, indent=1))
    return 0 if made else 1


if __name__ == "__main__":
    sys.exit(main())
