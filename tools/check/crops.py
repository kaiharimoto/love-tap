#!/usr/bin/env python3
"""Three 300 percent crops of the hero, at the places the paper has to survive being stared at.

The crops are nearest-neighbour so that what is on screen is what is judged: a smooth upscale
would hide exactly the thing the crop exists to show.
"""
import argparse
import json
import pathlib
import sys

from PIL import Image

# fractions of the frame: a torn edge, a written line, and a place where two notes overlap
PLACES = [
    ("edge", 0.06, 0.30, 0.42, 0.14),
    ("hand", 0.18, 0.52, 0.56, 0.10),
    ("shadow", 0.30, 0.68, 0.52, 0.13),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--out-dir", default="evidence/crops")
    ap.add_argument("--scale", type=int, default=3)
    args = ap.parse_args()

    im = Image.open(args.image)
    out = pathlib.Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    made = []
    stem = pathlib.Path(args.image).stem
    for name, x, y, w, h in PLACES:
        box = (round(im.width * x), round(im.height * y),
               round(im.width * (x + w)), round(im.height * (y + h)))
        piece = im.crop(box)
        piece = piece.resize((piece.width * args.scale, piece.height * args.scale), Image.NEAREST)
        path = out / f"{stem}_{args.scale}00_{name}.png"
        piece.save(path)
        made.append({"name": name, "file": str(path), "box": box, "size": piece.size})
    print(json.dumps({"source": args.image, "scale": args.scale, "crops": made}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
