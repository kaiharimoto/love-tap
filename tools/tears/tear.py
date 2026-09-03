#!/usr/bin/env python3
"""tools/tears/tear.py — the pool of torn-paper alpha masks.

    python3 tools/tears/tear.py --count 56 --out assets/tears
    python3 tools/tears/tear.py --preview            # composites to look at

A mask is the *piece of paper*: white where paper remains, black where it is gone, with a soft
fibrous boundary. Nothing is drawn as a wavy line: a torn edge is a fracture path with 1/f
roughness, then per-fibre pull-out (short fibres dragged out of the sheet on both sides of the
break), then a feathered fuzz band whose width itself varies along the edge, then a few long
fibres left hanging past the break. Straight edges are the sheet's own guillotined edges and are
imperfect by a few tenths of a millimetre.

Every mask has its own seed, piece kind and tear directions, and every mask is checked against the
whole pool by tools/tears/distinct.py before it is kept: a flip, rotation, scale or crop of another
mask is rejected and redrawn. Sizes are quoted in millimetres at 17.07 px/mm (2048 px = 120 mm).
"""
import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "blender"))
sys.path.insert(0, HERE)

SIZE = 2048
PX_PER_MM = SIZE / 120.0
DEFAULT_OUT = os.path.join(ROOT, "assets", "tears")

# piece kinds: which edges are torn. l/r/t/b, the rest are the sheet's cut edges.
KINDS = {
    "strip":    ["t", "b"],           # a strip torn off across the page
    "half":     ["b"],                # the top half of a sheet, torn along the bottom
    "corner":   ["b", "l"],           # a corner piece
    "rect":     ["t", "b", "l"],      # a ragged rectangle
    "three":    ["t", "b", "r"],
    "diagonal": ["d"],                # a single diagonal tear
    "cut":      ["r"],                # one machine-cut sheet with a single torn edge
    "notepad":  ["t"],                # torn off a pad along the glued top edge
}
# aspect (w:h) ranges per kind, in millimetres
EXTENT_MM = {
    "strip":    ((95, 118), (28, 55)),
    "half":     ((95, 118), (60, 100)),
    "corner":   ((55, 95), (45, 85)),
    "rect":     ((70, 110), (40, 80)),
    "three":    ((70, 110), (40, 80)),
    "diagonal": ((80, 115), (55, 100)),
    "cut":      ((85, 115), (60, 105)),
    "notepad":  ((90, 118), (50, 95)),
}


# ---------------------------------------------------------------- the fracture path
def fracture(n, rng, amp_mm, wander_mm, hurst=None):
    """A 1/f rough break line of n samples, in pixels, mean zero.

    Two ingredients: a low-frequency wander (where the tear drifted across the page) and a
    self-similar roughness (the fibre structure of the break). Real tears are not symmetric —
    the roughness is sharper on one side, so the profile is skewed with a soft power curve."""
    t = np.linspace(0.0, 1.0, n)
    # low-frequency wander: 2-4 slow terms
    wander = np.zeros(n)
    for k in range(1, rng.integers(3, 5) + 1):
        wander += rng.normal(0, 1) / k * np.sin(2 * math.pi * k * t * rng.uniform(0.35, 1.1) + rng.uniform(0, 6.28))
    wander *= wander_mm * PX_PER_MM / (np.abs(wander).max() + 1e-9)
    # 1/f roughness; the exponent is the character of the break — a clean pull is smoother
    # (higher exponent), a slow ragged tear is rougher, and no two sheets tear alike
    h = rng.uniform(0.55, 1.15) if hurst is None else hurst
    rough = np.zeros(n)
    for k in range(3, 320):
        rough += rng.normal(0, 1) / (k ** h) * np.sin(2 * math.pi * k * t + rng.uniform(0, 6.28))
    rough *= amp_mm * PX_PER_MM / (np.abs(rough).max() + 1e-9)
    prof = wander + rough
    # skew: one side of the break has the sharper excursions
    s = rng.uniform(0.7, 1.45)
    prof = np.sign(prof) * (np.abs(prof) ** s) * (np.abs(prof).max() ** (1 - s) + 1e-9)
    return prof - prof.mean()


def cut_edge(n, rng):
    """A guillotined edge: straight to a few tenths of a millimetre, with one or two tiny nicks."""
    prof = rng.normal(0, 0.06, n)
    prof = np.convolve(np.pad(prof, 8, mode="edge"), np.ones(17) / 17, mode="valid")
    prof *= 0.35 * PX_PER_MM / (np.abs(prof).max() + 1e-9)
    for _ in range(rng.integers(0, 3)):
        c = rng.integers(0, n)
        w = int(rng.integers(3, 14))
        d = rng.uniform(0.3, 1.1) * PX_PER_MM
        lo, hi = max(0, c - w), min(n, c + w)
        prof[lo:hi] -= d * np.hanning(max(2, hi - lo))
    return prof


# ---------------------------------------------------------------- fibres
def fibre_pullout(mask, boundary_pts, normals, rng, px_per_mm, density=0.55):
    """Short fibres dragged out of the sheet along the break, both directions.

    A fibre is a capsule from a point on the break, along the local normal, 0.3-2.5 mm long and
    0.06-0.2 mm wide. Fibres pointing outward add paper (a hanging fibre); fibres pointing inward
    remove it (a fibre pulled out of this side). They cluster: paper tears in bundles."""
    h, w = mask.shape
    n = len(boundary_pts)
    if n < 8:
        return mask
    # cluster centres along the break
    n_clusters = max(4, int(n / (px_per_mm * rng.uniform(2.5, 6.0))))
    centres = np.sort(rng.integers(0, n, size=n_clusters))
    ys, xs = np.mgrid[0:h, 0:w]
    for c in centres:
        for _ in range(int(rng.integers(2, 7))):
            i = int(np.clip(c + rng.normal(0, px_per_mm * 1.2), 0, n - 1))
            p = boundary_pts[i]
            nrm = normals[i]
            outward = rng.random() < density
            length = rng.uniform(0.3, 2.5) * px_per_mm * (1.0 if outward else rng.uniform(0.5, 1.0))
            width = rng.uniform(0.06, 0.2) * px_per_mm
            ang = rng.normal(0, 0.42)                    # fibres lean along the break
            d = np.array([nrm[0] * math.cos(ang) - nrm[1] * math.sin(ang),
                          nrm[0] * math.sin(ang) + nrm[1] * math.cos(ang)])
            if not outward:
                d = -d
            q = p + d * length
            # capsule distance field over the bounding box only
            x0, x1 = int(max(0, min(p[0], q[0]) - width - 2)), int(min(w, max(p[0], q[0]) + width + 3))
            y0, y1 = int(max(0, min(p[1], q[1]) - width - 2)), int(min(h, max(p[1], q[1]) + width + 3))
            if x1 <= x0 or y1 <= y0:
                continue
            px = xs[y0:y1, x0:x1] - p[0]
            py = ys[y0:y1, x0:x1] - p[1]
            dx, dy = q[0] - p[0], q[1] - p[1]
            L2 = dx * dx + dy * dy + 1e-9
            tt = np.clip((px * dx + py * dy) / L2, 0.0, 1.0)
            dist = np.hypot(px - tt * dx, py - tt * dy)
            # the fibre tapers to nothing at its tip
            radius = width * (1.0 - 0.75 * tt)
            cov = np.clip((radius - dist) / max(0.8, width * 0.5), 0.0, 1.0)
            sub = mask[y0:y1, x0:x1]
            if outward:
                np.maximum(sub, cov, out=sub)
            else:
                np.minimum(sub, 1.0 - cov, out=sub)
    return mask


def long_fibres(mask, boundary_pts, normals, rng, px_per_mm):
    """A handful of long single fibres still attached, drifting past the break at low alpha."""
    h, w = mask.shape
    n = len(boundary_pts)
    for _ in range(int(rng.integers(3, 9))):
        i = int(rng.integers(0, n))
        p = boundary_pts[i].astype(float)
        d = normals[i].astype(float)
        length = rng.uniform(2.0, 6.5) * px_per_mm
        steps = int(length)
        ang = rng.normal(0, 0.5)
        cur = p.copy()
        alpha = rng.uniform(0.35, 0.8)
        for s in range(steps):
            ang += rng.normal(0, 0.09)
            step = np.array([d[0] * math.cos(ang) - d[1] * math.sin(ang),
                             d[0] * math.sin(ang) + d[1] * math.cos(ang)])
            cur = cur + step
            x, y = int(round(cur[0])), int(round(cur[1]))
            if not (1 <= x < w - 1 and 1 <= y < h - 1):
                break
            a = alpha * (1.0 - s / steps) ** 0.7
            mask[y, x] = max(mask[y, x], a)
            mask[y, x + 1] = max(mask[y, x + 1], a * 0.45)
            mask[y + 1, x] = max(mask[y + 1, x], a * 0.45)
    return mask


# ---------------------------------------------------------------- one mask
def draw_mask(kind, seed, size=SIZE):
    rng = np.random.default_rng(seed)
    px = size / 120.0
    (wlo, whi), (hlo, hhi) = EXTENT_MM[kind]
    w_mm = rng.uniform(wlo, whi)
    h_mm = rng.uniform(hlo, hhi)
    w_px, h_px = w_mm * px, h_mm * px
    cx, cy = size / 2.0, size / 2.0
    left, right = cx - w_px / 2, cx + w_px / 2
    top, bottom = cy - h_px / 2, cy + h_px / 2

    torn = KINDS[kind]
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    inside = np.ones((size, size), np.float32)

    amp = rng.uniform(0.5, 3.0)          # mm of fine roughness
    wander = rng.uniform(1.2, 7.0)       # mm of slow drift
    hurst = rng.uniform(0.55, 1.15)      # the character of this sheet's break

    def edge_profile(n, is_torn):
        # each torn edge of a piece breaks a little differently, around this sheet's character
        return (fracture(n, rng, amp * rng.uniform(0.7, 1.4), wander * rng.uniform(0.6, 1.5),
                         hurst=float(np.clip(hurst + rng.normal(0, 0.07), 0.5, 1.3)))
                if is_torn else cut_edge(n, rng))

    # horizontal edges (top, bottom): profile indexed by x
    prof_t = edge_profile(size, "t" in torn)
    prof_b = edge_profile(size, "b" in torn)
    prof_l = edge_profile(size, "l" in torn)
    prof_r = edge_profile(size, "r" in torn)

    if kind == "diagonal":
        # a single break running corner to corner; the rest are cut edges
        ang = rng.uniform(-0.55, 0.55) + (math.pi / 2 if rng.random() < 0.5 else 0.0)
        nx, ny = math.cos(ang), math.sin(ang)
        s = (xs - cx) * nx + (ys - cy) * ny          # signed distance to the break line
        along = (-(xs - cx) * ny + (ys - cy) * nx)   # position along it
        idx = np.clip(((along / (size * 1.42)) + 0.5) * (size - 1), 0, size - 1).astype(np.int32)
        prof_d = fracture(size, rng, amp, wander)
        inside *= (s < prof_d[idx]).astype(np.float32)
        # keep the sheet's cut edges too
        inside *= ((xs > left + prof_l[np.clip(ys.astype(np.int32), 0, size - 1)]) &
                   (xs < right + prof_r[np.clip(ys.astype(np.int32), 0, size - 1)]) &
                   (ys > top + prof_t[np.clip(xs.astype(np.int32), 0, size - 1)]) &
                   (ys < bottom + prof_b[np.clip(xs.astype(np.int32), 0, size - 1)])).astype(np.float32)
    else:
        xi = np.clip(xs.astype(np.int32), 0, size - 1)
        yi = np.clip(ys.astype(np.int32), 0, size - 1)
        inside *= ((ys > top + prof_t[xi]) & (ys < bottom + prof_b[xi]) &
                   (xs > left + prof_l[yi]) & (xs < right + prof_r[yi])).astype(np.float32)

    mask = inside.astype(np.float32)
    # boundary points and outward normals from the binary mask
    pts, normals = boundary_and_normals(mask)
    mask = fibre_pullout(mask, pts, normals, rng, px)
    mask = long_fibres(mask, pts, normals, rng, px)
    mask = feather(mask, rng, px)
    meta = dict(kind=kind, seed=int(seed), w_mm=round(float(w_mm), 2), h_mm=round(float(h_mm), 2),
                torn_edges=torn, roughness_mm=round(float(amp), 2), wander_mm=round(float(wander), 2),
                hurst=round(float(hurst), 3), px_per_mm=round(float(px), 3))
    return mask, meta


def boundary_and_normals(mask, step=3):
    """Points on the mask boundary and unit normals pointing out of the paper."""
    import cv2
    m = (mask > 0.5).astype(np.uint8)
    contours, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    if not contours:
        return np.zeros((0, 2)), np.zeros((0, 2))
    c = max(contours, key=len).reshape(-1, 2)[::step].astype(np.float64)
    if len(c) < 8:
        return np.zeros((0, 2)), np.zeros((0, 2))
    tang = np.roll(c, -2, axis=0) - np.roll(c, 2, axis=0)
    nrm = np.stack([tang[:, 1], -tang[:, 0]], axis=1)
    nrm /= (np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9)
    # make the normals point outward: sample a step along and check the mask
    probe = np.clip(c + nrm * 4.0, 0, mask.shape[0] - 1).astype(np.int32)
    v = mask[probe[:, 1], probe[:, 0]]
    flip = v > 0.5
    nrm[flip] *= -1
    return c, nrm


def feather(mask, rng, px_per_mm):
    """A soft fibrous boundary: the alpha falls off over a band whose width itself varies, and the
    falloff is bitten into by fine noise so no two millimetres of edge look alike."""
    import cv2
    from scipy.ndimage import distance_transform_edt, gaussian_filter
    m = (mask > 0.5).astype(np.uint8)
    d_in = distance_transform_edt(m)
    d_out = distance_transform_edt(1 - m)
    signed = d_in - d_out                                   # >0 inside
    band = rng.uniform(0.22, 0.5) * px_per_mm
    # the band width varies along the edge
    wobble = gaussian_filter(rng.normal(0, 1, mask.shape).astype(np.float32), sigma=px_per_mm * 1.2)
    wobble /= (np.abs(wobble).max() + 1e-9)
    local = band * (1.0 + 0.55 * wobble)
    soft = np.clip(0.5 + signed / (2.0 * np.maximum(local, 0.6)), 0.0, 1.0)
    # fine fibre noise bites into the falloff only near the edge
    grain = gaussian_filter(rng.normal(0, 1, mask.shape).astype(np.float32), sigma=0.8)
    grain /= (np.abs(grain).max() + 1e-9)
    near = np.clip(1.0 - np.abs(signed) / (band * 3.0), 0.0, 1.0)
    soft = np.clip(soft + 0.35 * grain * near, 0.0, 1.0)
    # keep the fibres drawn earlier (they live outside the binary mask)
    out = np.maximum(soft, np.where(m > 0, 0.0, mask * 0.9)).astype(np.float32)
    out = np.where(d_in > band * 2.5, 1.0, out)
    return cv2.GaussianBlur(out, (0, 0), 0.6)


# ---------------------------------------------------------------- the pool
def build(count, out_dir, seed0, verbose=True, size=SIZE):
    from PIL import Image
    import distinct as distinct_mod
    os.makedirs(out_dir, exist_ok=True)
    kinds = list(KINDS)
    pool = []          # (id, meta, signature)
    metas = []
    attempts = 0
    rejected = 0
    seed = seed0
    while len(pool) < count:
        kind = kinds[len(pool) % len(kinds)]
        seed += 1
        attempts += 1
        if attempts > count * 12:
            raise SystemExit(f"could not draw {count} distinct masks (kept {len(pool)})")
        mask, meta = draw_mask(kind, seed, size)
        sig = distinct_mod.signature(mask)
        worst, against = distinct_mod.best_match(sig, [p[2] for p in pool])
        if worst > distinct_mod.THRESHOLD:
            rejected += 1
            if verbose:
                print(f"  rejected seed {seed} ({kind}): {worst:.3f} vs {pool[against][0]}")
            continue
        idx = len(pool) + 1
        mid = f"tear_{idx:03d}"
        meta["id"] = mid
        meta["max_correlation"] = round(float(worst), 4)
        path = os.path.join(out_dir, mid + ".png")
        Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), "L").save(path, optimize=True)
        pool.append((mid, meta, sig))
        metas.append(meta)
        if verbose:
            print(f"{mid} {kind:9s} {meta['w_mm']:.0f}x{meta['h_mm']:.0f}mm  max corr {worst:.3f}")
    with open(os.path.join(out_dir, "tears.json"), "w", encoding="utf-8") as f:
        json.dump({"count": len(metas), "size": size, "px_per_mm": round(size / 120.0, 3),
                   "threshold": distinct_mod.THRESHOLD, "seed0": seed0,
                   "generator": "tools/tears/tear.py", "masks": metas}, f, indent=1)
    if verbose:
        print(f"{len(pool)} masks, {rejected} rejected as too similar, {attempts} draws")
    return metas


def record_manifest(out_dir, metas):
    from rig import manifest
    for m in metas:
        manifest.record(os.path.join(out_dir, m["id"] + ".png"), "tools/tears/tear.py",
                        {k: v for k, v in m.items() if k != "id"}, kind="tear_mask")
    manifest.record(os.path.join(out_dir, "tears.json"), "tools/tears/tear.py",
                    {"masks": len(metas)}, kind="index")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--count", type=int, default=56)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--seed", type=int, default=20260903)
    ap.add_argument("--size", type=int, default=SIZE)
    ap.add_argument("--no-manifest", action="store_true")
    a = ap.parse_args(argv)
    metas = build(a.count, a.out, a.seed, size=a.size)
    if not a.no_manifest:
        record_manifest(a.out, metas)
    return 0


if __name__ == "__main__":
    sys.exit(main())
