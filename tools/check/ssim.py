#!/usr/bin/env python3
"""SSIM between this session's artifact and the last one, for evidence/DIFF.json."""
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image


def grey(path, size=None):
    im = Image.open(path).convert("L")
    if size and im.size != size:
        im = im.resize(size, Image.LANCZOS)
    return np.asarray(im, dtype=np.float64) / 255.0


def ssim(a, b, window=8):
    """Mean SSIM over non-overlapping windows: enough to tell a redraw from a nudge."""
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    h = a.shape[0] // window * window
    w = a.shape[1] // window * window
    a = a[:h, :w].reshape(h // window, window, w // window, window).transpose(0, 2, 1, 3)
    b = b[:h, :w].reshape(h // window, window, w // window, window).transpose(0, 2, 1, 3)
    a = a.reshape(-1, window * window)
    b = b.reshape(-1, window * window)
    ma, mb = a.mean(1), b.mean(1)
    va, vb = a.var(1), b.var(1)
    cov = ((a - ma[:, None]) * (b - mb[:, None])).mean(1)
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))
    return float(s.mean())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    args = ap.parse_args()
    if not pathlib.Path(args.b).exists():
        print(json.dumps({"ssim": None, "why": "no previous capture"}))
        return 0
    ga = grey(args.a)
    gb = grey(args.b, size=(ga.shape[1], ga.shape[0]))
    print(json.dumps({"ssim": round(ssim(ga, gb), 4)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
