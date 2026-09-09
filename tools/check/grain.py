#!/usr/bin/env python3
"""Wood has to happen in both directions.

    python3 tools/check/grain.py --out evidence/logs/grain.json

A flat-sawn board has rings running across it and, along those rings, vessels and rays that break
them up. Draw only the rings and you get a comb: a set of stripes, which is what four cycles of
this desk were. It is measurable and it was measured — 128 px tiles of the exposed wood on
10_first_run.png gave a mean absolute gradient of 3.005 across the grain and 0.662 along it, a
ratio of 4.54, while the paper in the same picture reads 4.13 and 4.37 and a ratio near 1. An
anti-goal critic found the same thing from the other end: the horizontal power spectrum of that
region has a dominant band at a 20.3 px period with a peak-to-median ratio of 6701 to 1.

So this reads the desk texture itself — not a still, which has paper all over it — and reports the
two gradients and their ratio. It fails when the ratio goes above `--max-ratio`, which is set at
what the asset measures now plus a little, so the next change cannot quietly put the stripes back.
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def high_frequency(path, frac=0.35, tile=256):
    """The share of spectral power above a fraction of Nyquist: how much fine detail is there.

    This is the number that matters, and it took three renders to work out that the anisotropy
    below is not. A material critic measured 0.11 to 0.49 per cent of power above 35 per cent of
    Nyquist on the desk against 16 to 32 for the paper in the same frame, and called the desk
    drawn rather than photographed. Anisotropy cannot see that: pores add to the gradient across
    the grain as much as along it, so a board can go from painted stripes to visible oak and the
    ratio will not move — it went 5.76, 5.16, 5.60, 5.11, 5.13 across five renders while the fine
    detail went 1.23 to 1.83 per cent and the picture changed completely.
    """
    import numpy as np
    from PIL import Image
    with Image.open(path) as im:
        a = np.asarray(im.convert("L"), dtype=np.float32)
    h, w = a.shape
    win = np.hanning(tile)[:, None] * np.hanning(tile)[None, :]
    fy = np.fft.fftshift(np.fft.fftfreq(tile))[:, None]
    fx = np.fft.fftshift(np.fft.fftfreq(tile))[None, :]
    r = np.sqrt(fy ** 2 + fx ** 2) / 0.5
    vals = []
    for y in range(0, h - tile, tile):
        for x in range(0, w - tile, tile):
            t = a[y:y + tile, x:x + tile]
            t = t - t.mean()
            F = np.abs(np.fft.fftshift(np.fft.fft2(t * win))) ** 2
            total = F.sum()
            if total > 0:
                vals.append(float(F[r > frac].sum() / total))
    return float(np.median(vals)) * 100.0 if vals else 0.0


def gradients(path, tile=128):
    import numpy as np
    from PIL import Image
    with Image.open(path) as im:
        a = np.asarray(im.convert("L"), dtype=np.float32)
    h, w = a.shape
    across, along = [], []
    for y in range(0, h - tile, tile):
        for x in range(0, w - tile, tile):
            t = a[y:y + tile, x:x + tile]
            # the grain runs down the board, so "across" is column to column
            across.append(float(np.abs(np.diff(t, axis=1)).mean()))
            along.append(float(np.abs(np.diff(t, axis=0)).mean()))
    return float(np.median(across)), float(np.median(along)), len(across)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--max-ratio", type=float, default=3.6,
                    help="reported, not gated: see high_frequency() for why")
    ap.add_argument("--min-fine", type=float, default=1.6,
                    help="the share of spectral power above 35 per cent of Nyquist, as a "
                         "percentage. The desk measures 1.83 with its pores in and 1.23 without "
                         "them; the paper beside it measures 7.4.")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    files = a.files or [os.path.join(ROOT, "assets", "shell", n)
                        for n in ("desk.png", "desk_dusk.png")]
    files = [f for f in files if os.path.exists(f)] or [
        os.path.join(ROOT, "app", "assets", "shell", n) for n in ("desk.webp", "desk_dusk.webp")]
    report = {
        "tile": 128,
        "how": "mean absolute first difference inside 128 px tiles, column to column (across the "
               "grain) and row to row (along it), median over the tiles",
        "max_ratio": a.max_ratio,
        "why": "a board with only rings on it is a comb. Vessels and rays are what happens along "
               "the grain, and without them the surface reads as stripes rather than as a cut "
               "through fibre.",
        "surfaces": {},
    }
    worst = 0.0
    finest = None
    for f in files:
        if not os.path.exists(f):
            continue
        across, along, n = gradients(f, a.tile if hasattr(a, "tile") else 128)
        ratio = across / along if along else 999.0
        fine = high_frequency(f)
        report["surfaces"][os.path.basename(f)] = {
            "fine_detail_share": round(fine, 2),
            "across_the_grain": round(across, 3),
            "along_the_grain": round(along, 3),
            "ratio": round(ratio, 2),
            "tiles": n,
        }
        worst = max(worst, ratio)
        finest = fine if finest is None else min(finest, fine)
    report["worst_ratio"] = round(worst, 2)
    report["least_fine_detail"] = None if finest is None else round(finest, 2)
    report["min_fine"] = a.min_fine
    report["ok"] = bool(report["surfaces"]) and finest is not None and finest >= a.min_fine
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
