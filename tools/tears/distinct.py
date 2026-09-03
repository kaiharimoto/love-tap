#!/usr/bin/env python3
"""tools/tears/distinct.py — no mask in the pool may be another mask transformed.

    python3 tools/tears/distinct.py assets/tears --json evidence/tears_distinct.json

A tear mask counted as distinct when it is a flip, rotation, scale or crop of another is a failure
condition of the build, so the pool is guarded by image registration rather than by a summary
statistic that could be fooled.

For a pair of masks the torn boundary is traced (Canny on the binary piece) and reduced to 128x128,
zero-meaned. Then, over both reflections, twenty-four rotations and three scales, the two maps are
correlated at every translation at once (FFT cross-correlation normalised by both norms, so an
identical map scores 1.0). Translation freedom is what makes a *crop* of another mask score high.
The coarse pass runs on a blurred map so a rotation falling between two sweep steps still
registers; the best pose is then refined at two degrees on the sharp map, where a true transform
scores above 0.85 and two independently drawn fractures score around 0.3.

The rejection threshold is 0.72. tear.py calls best_match() before keeping a mask, and redraws with
a new seed on rejection.
"""
import argparse
import json
import os
import sys

import numpy as np

THRESHOLD = 0.72
N = 128
COARSE_STEP = 15
COARSE_BLUR = 1.6
SCALES = (0.85, 1.0, 1.18)
REFINE_SPAN = 10
REFINE_STEP = 2
REFINE_SCALES = (0.92, 1.0, 1.09)


def _edge_map(mask, blur):
    import cv2
    m = (mask > 0.5).astype(np.uint8)
    e = cv2.Canny(m * 255, 50, 150).astype(np.float32) / 255.0
    e = cv2.resize(e, (N, N), interpolation=cv2.INTER_AREA)
    if blur > 0:
        e = cv2.GaussianBlur(e, (0, 0), blur)
    return e - e.mean()


def signature(mask):
    """The blurred and the sharp boundary map of one mask."""
    return {"coarse": _edge_map(mask, COARSE_BLUR), "fine": _edge_map(mask, 0.6)}


def _peak(a, b):
    """Best normalised correlation over every translation (FFT); 1.0 for identical maps."""
    n = a.shape[0] * 2
    fa = np.fft.rfft2(a, (n, n))
    fb = np.fft.rfft2(b, (n, n))
    corr = np.fft.irfft2(fa * np.conj(fb), (n, n))
    return float(corr.max() / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))


def _warp(img, deg, scale, flip):
    import cv2
    base = np.fliplr(img) if flip else img
    if deg % 360 == 0 and abs(scale - 1.0) < 1e-9:
        return base
    m = cv2.getRotationMatrix2D((N / 2, N / 2), deg, scale)
    return cv2.warpAffine(base, m, (N, N), flags=cv2.INTER_LINEAR)


def similarity(sig_a, sig_b, want_pose=False):
    """How much one mask is the other under reflection, rotation, scale and translation."""
    best = (-1.0, 0, 1.0, False)
    for flip in (False, True):
        for deg in range(0, 360, COARSE_STEP):
            for s in SCALES:
                v = _peak(sig_a["coarse"], _warp(sig_b["coarse"], deg, s, flip))
                if v > best[0]:
                    best = (v, deg, s, flip)
    _, deg0, s0, flip0 = best
    fine = -1.0
    pose = (deg0, s0, flip0)
    for d in range(-REFINE_SPAN, REFINE_SPAN + 1, REFINE_STEP):
        for k in REFINE_SCALES:
            v = _peak(sig_a["fine"], _warp(sig_b["fine"], deg0 + d, s0 * k, flip0))
            if v > fine:
                fine = v
                pose = (deg0 + d, round(s0 * k, 3), flip0)
    return (fine, pose) if want_pose else fine


def best_match(sig, others):
    """(highest similarity, index) against a list of signatures; (-1, -1) when empty."""
    best, at = -1.0, -1
    for i, o in enumerate(others):
        v = similarity(sig, o)
        if v > best:
            best, at = v, i
    return best, at


def check_dir(path, verbose=True):
    from PIL import Image
    files = sorted(f for f in os.listdir(path)
                   if f.startswith("tear_") and f.endswith(".png") and "_edge" not in f and "_shadow" not in f)
    sigs, names = [], []
    for f in files:
        arr = np.asarray(Image.open(os.path.join(path, f)).convert("L"), dtype=np.float32) / 255.0
        sigs.append(signature(arr))
        names.append(f[:-4])
    rows = []
    for i in range(len(sigs)):
        for j in range(i + 1, len(sigs)):
            v, pose = similarity(sigs[i], sigs[j], want_pose=True)
            rows.append((v, names[i], names[j], pose))
    rows.sort(reverse=True, key=lambda r: r[0])
    worst = rows[0][0] if rows else 0.0
    if verbose:
        print(f"{len(sigs)} masks, {len(rows)} pairs, threshold {THRESHOLD}")
        for v, a, b, pose in rows[:10]:
            print(f"  {v:.3f}  {a} vs {b}  (best pose {pose[0]}deg x{pose[1]}"
                  f"{' flipped' if pose[2] else ''}){'   REJECT' if v > THRESHOLD else ''}")
        print(f"worst pair at {worst:.3f}")
    return worst, ((rows[0][1], rows[0][2]) if rows else None), rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("dir", nargs="?", default=os.path.join(here, "..", "..", "assets", "tears"))
    ap.add_argument("--json", help="write the pair summary here")
    a = ap.parse_args(argv)
    worst, pair, rows = check_dir(os.path.abspath(a.dir))
    if a.json:
        os.makedirs(os.path.dirname(os.path.abspath(a.json)), exist_ok=True)
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"method": "FFT cross-correlation of boundary maps over both reflections, 24 rotations, "
                                 "3 scales and every translation, refined at 2 degrees on the sharp map",
                       "threshold": THRESHOLD, "pairs": len(rows), "worst": round(worst, 4),
                       "worst_pair": pair,
                       "top": [{"similarity": round(v, 4), "a": x, "b": y,
                                "pose": {"deg": p[0], "scale": p[1], "flipped": p[2]}} for v, x, y, p in rows[:25]]},
                      f, indent=1)
    return 1 if worst > THRESHOLD else 0


if __name__ == "__main__":
    sys.exit(main())
