#!/usr/bin/env python3
"""tools/handwriting/build.py — builds NoorHand.ttf, TeoHand.ttf and DeskStamp.ttf from
skeletons.json + hands.json. See SPEC.md.

    python3 tools/handwriting/build.py --out assets/fonts --preview assets/fonts/previews --seed 20260903

Pipeline per glyph variant:
  skeleton strokes -> alt choice -> hand styling (scale, slant, t-cross lateness, exits, overshoot)
  -> seeded jitter (smooth field + point noise + per-stroke rotation, pressure jitter)
  -> centripetal Catmull-Rom sampling (>= 64 samples per stroke, corners at pen reversals)
  -> pressure profile through the pen model -> variable-width polygon pieces
  -> union with skia-pathops -> RDP + Schneider cubic fit -> cu2qu -> TrueType quadratic outline.
Nothing is downloaded; the RNG is seeded per (face, glyph, variant, attempt).
"""
import argparse
import hashlib
import json
import math
import os
import sys
import time

import numpy as np
import pathops
from fontTools.cu2qu import curve_to_quadratic
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.misc.timeTools import timestampFromString
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from scipy.spatial.distance import directed_hausdorff

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "blender", "rig"))
from manifest import record  # noqa: E402

GENERATOR = "tools/handwriting/build.py"
DEFAULT_SEED = 20260903
FACES = ["NoorHand", "TeoHand", "DeskStamp"]
UPM = 1000
HAUSDORFF_MIN = 12.0
PUA_BASE = 0xE000  # variant glyphs also get private-use codepoints so plain renderers can reach them


# ============================================================================ small helpers
def norm(v):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-9)


def signed_area(poly):
    x, y = poly[:, 0], poly[:, 1]
    return 0.5 * np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y)


def turning_angles_deg(pts):
    """Turning angle at each interior point of an open polyline (degrees, 0 = straight)."""
    d1 = norm(pts[1:-1] - pts[:-2])
    d2 = norm(pts[2:] - pts[1:-1])
    c = np.clip(np.sum(d1 * d2, axis=1), -1, 1)
    return np.degrees(np.arccos(c))


def smoothstep(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def point_in_polygon(p, poly):
    x, y = p
    xs, ys = poly[:, 0], poly[:, 1]
    xn, yn = np.roll(xs, -1), np.roll(ys, -1)
    cond = (ys > y) != (yn > y)
    with np.errstate(divide="ignore", invalid="ignore"):
        xint = xs + (y - ys) * (xn - xs) / (yn - ys)
    return bool(np.sum(cond & (x < xint)) % 2)


# ============================================================================ splines
def catmull_rom(pts, alpha, step):
    """Centripetal (alpha) Catmull-Rom through pts (N,3: x,y,pressure). Returns (M,3) samples."""
    P = np.asarray(pts, float)
    if len(P) == 1:
        return np.vstack([P, P + [1.0, 0.0, 0.0]])
    if len(P) == 2:
        n = max(8, int(np.linalg.norm(P[1, :2] - P[0, :2]) / step))
        return np.linspace(P[0], P[1], n + 1)
    Q = np.vstack([2 * P[0] - P[1], P, 2 * P[-1] - P[-2]])
    xy = Q[:, :2]
    d = np.linalg.norm(np.diff(xy, axis=0), axis=1)
    t = np.concatenate([[0.0], np.cumsum(np.maximum(d, 1e-3) ** alpha)])
    out = []
    for i in range(1, len(Q) - 2):
        p0, p1, p2, p3 = xy[i - 1], xy[i], xy[i + 1], xy[i + 2]
        t0, t1, t2, t3 = t[i - 1], t[i], t[i + 1], t[i + 2]
        seg = np.linalg.norm(p2 - p1)
        n = max(6, int(seg / step))
        ts = np.linspace(t1, t2, n, endpoint=False)[:, None]
        A1 = (t1 - ts) / (t1 - t0) * p0 + (ts - t0) / (t1 - t0) * p1
        A2 = (t2 - ts) / (t2 - t1) * p1 + (ts - t1) / (t2 - t1) * p2
        A3 = (t3 - ts) / (t3 - t2) * p2 + (ts - t2) / (t3 - t2) * p3
        B1 = (t2 - ts) / (t2 - t0) * A1 + (ts - t0) / (t2 - t0) * A2
        B2 = (t3 - ts) / (t3 - t1) * A2 + (ts - t1) / (t3 - t1) * A3
        C = (t2 - ts) / (t2 - t1) * B1 + (ts - t1) / (t2 - t1) * B2
        u = (ts - t1) / (t2 - t1)
        pr = Q[i, 2] * (1 - u) + Q[i + 1, 2] * u
        out.append(np.hstack([C, pr]))
    out.append(P[-1:])
    return np.vstack(out)


def sample_stroke(pts, alpha, step, corner_deg, rounding):
    """Split a stroke at pen reversals (corners), round the rest, sample each piece."""
    P = np.asarray(pts, float)
    if len(P) < 3:
        return catmull_rom(P, alpha, step), np.zeros(0, int)
    ang = turning_angles_deg(P[:, :2])
    corners = [i + 1 for i, a in enumerate(ang) if a > corner_deg]
    if rounding > 0:
        R = P.copy()
        for i in range(1, len(P) - 1):
            if i in corners:
                continue
            mid = (P[i - 1, :2] + P[i + 1, :2]) / 2
            R[i, :2] = P[i, :2] + rounding * 0.3 * (mid - P[i, :2])
        P = R
    bounds = [0] + corners + [len(P) - 1]
    pieces, corner_idx = [], []
    total = 0
    for a, b in zip(bounds[:-1], bounds[1:]):
        s = catmull_rom(P[a:b + 1], alpha, step)
        if pieces:
            s = s[1:]
        pieces.append(s)
        total += len(s)
        corner_idx.append(total - 1)
    samples = np.vstack(pieces)
    corner_idx = np.array(corner_idx[:-1], int)
    return samples, corner_idx


# ============================================================================ hand styling
def stroke_length(pts):
    return float(np.sum(np.linalg.norm(np.diff(np.asarray(pts)[:, :2], axis=0), axis=1)))


def apply_roles(strokes, roles, hand):
    late = hand.get("t_cross_late", 0.0)
    out = []
    for s, role in zip(strokes, roles):
        s = np.array(s, float)
        if role == "cross" and late > 0:
            s[:, 0] += late * 70
            s[:, 1] += late * 22
            s[-1, 0] += late * 60          # the bar flies on past the stem
            s[-1, 1] += late * 12
            s[:, 2] *= 1 - 0.3 * late      # and lands lighter
        if role == "dot" and late > 0:     # fast hands drop the dot a little late and high
            s[:, 0] += late * 40
            s[:, 1] += late * 25
        out.append(s)
    return out


def stretch_exit(strokes, factor):
    """The trailing light run of the last stroke is the exit; a fast hand throws it further."""
    if not strokes or abs(factor - 1) < 1e-6:
        return strokes
    s = strokes[-1]
    if len(s) < 4:
        return strokes
    k = len(s) - 1
    while k > 0 and s[k, 2] < 0.43 and s[k, 0] >= s[k - 1, 0] - 5:
        k -= 1
    if k >= len(s) - 1 or k == 0:
        return strokes
    anchor = s[k, :2].copy()
    s = s.copy()
    s[k + 1:, :2] = anchor + (s[k + 1:, :2] - anchor) * factor
    strokes = strokes[:-1] + [s]
    return strokes


def overshoot_start(strokes, amount, roles):
    if amount <= 0:
        return strokes
    out = []
    for s, role in zip(strokes, roles):
        if role == "dot" or len(s) < 2 or stroke_length(s) < 90:
            out.append(s)
            continue
        d = norm(s[1, :2] - s[0, :2])
        p0 = s[0].copy()
        p0[:2] -= d * amount
        p0[2] = max(0.15, s[0, 2] - 0.25)
        out.append(np.vstack([p0, s]))
    return out


class JitterField:
    """A smooth random displacement field: a few random plane waves, amplitude capped."""

    def __init__(self, rng, amp, wavelengths):
        self.waves = []
        for _ in range(3):
            lam = rng.uniform(*wavelengths)
            th = rng.uniform(0, 2 * math.pi)
            k = 2 * math.pi / lam * np.array([math.cos(th), math.sin(th)])
            ph = rng.uniform(0, 2 * math.pi, size=2)
            a = rng.uniform(0.5, 1.0, size=2) * amp / 3.0
            self.waves.append((k, ph, a))
        self.amp = amp

    def __call__(self, xy):
        d = np.zeros_like(xy)
        for k, ph, a in self.waves:
            arg = xy @ k
            d[:, 0] += a[0] * np.cos(arg + ph[0])
            d[:, 1] += a[1] * np.sin(arg + ph[1])
        m = np.linalg.norm(d, axis=1, keepdims=True)
        return d * np.minimum(1.0, self.amp / np.maximum(m, 1e-9))


def jitter_strokes(strokes, hand, rng):
    J = hand["jitter"]
    field = JitterField(rng, J["point"], J["field_wavelength"])
    pj = hand["pressure"]["jitter"]
    out = []
    for s in strokes:
        s = s.copy()
        s[:, :2] += field(s[:, :2])
        s[:, :2] += rng.uniform(-J["point_noise"], J["point_noise"], size=(len(s), 2))
        th = math.radians(rng.uniform(-J["rotation_deg"], J["rotation_deg"]))
        c = s[:, :2].mean(axis=0)
        R = np.array([[math.cos(th), -math.sin(th)], [math.sin(th), math.cos(th)]])
        s[:, :2] = (s[:, :2] - c) @ R.T + c
        if pj > 0:
            g = rng.normal(0, pj, size=len(s))
            if len(g) >= 3:
                # smooth without changing the length (np.convolve 'same' returns max(M, N))
                g = np.convolve(np.pad(g, 1, mode="edge"), [0.25, 0.5, 0.25], mode="valid")
            s[:, 2] = np.clip(s[:, 2] * (1 + g), 0.05, 1.2)
        out.append(s)
    return out


def plan_alts(glyph, hand, rng):
    """Alt index per variant (-1 = base skeleton). Variant 0 is always the base; variants 1 and 3
    always take an alternate (different ones when the glyph has two or more); 2 and 4 pick by the
    hand's taste, where loop openness weights the 'open' alternates."""
    n = hand["variants"]
    alts = glyph.get("alts") or []
    plan = [-1] * n
    if not alts:
        return plan
    openness = hand.get("loop_openness", 0.5)
    weights = []
    for a in alts:
        tags = a.get("tags", [])
        w = 1.0
        if "open" in tags:
            w *= 0.4 + 1.2 * openness
        if "closed" in tags:
            w *= 0.4 + 1.2 * (1 - openness)
        weights.append(w)
    weights = np.array(weights)

    def pick(exclude=None):
        w = weights.copy()
        if exclude is not None and len(alts) > 1:
            w[exclude] = 0
        return int(rng.choice(len(alts), p=w / w.sum()))

    first = pick()
    for v in range(1, n):
        if v == 1:
            plan[v] = first
        elif v == 3:
            plan[v] = pick(exclude=first)
        elif rng.random() < hand["jitter"]["alt_prob"]:
            plan[v] = pick()
    return plan


def pick_alt(glyph, variant, hand, plan):
    i = plan[variant] if plan else -1
    if i < 0:
        return glyph["strokes"], glyph.get("roles"), "base"
    alt = glyph["alts"][i]
    return alt["strokes"], alt.get("roles"), alt["name"]


def style_strokes(glyph, variant, hand, rng, plan=None):
    """Skeleton -> hand-styled control strokes for one variant (before sampling)."""
    strokes, roles, alt = pick_alt(glyph, variant, hand, plan)
    strokes = [np.array(s, float) for s in strokes]
    roles = list(roles or [None] * len(strokes))
    roles += [None] * (len(strokes) - len(roles))
    if hand.get("uppercase_only") and glyph.get("_lower_scale"):
        k = glyph["_lower_scale"]
        strokes = [s * np.array([k, k, 1.0]) for s in strokes]
    strokes = apply_roles(strokes, roles, hand)
    strokes = stretch_exit(strokes, hand.get("exit_stretch", 1.0))
    sx, sy = hand["width_scale"], hand["xheight_scale"]
    strokes = [s * np.array([sx, sy, 1.0]) for s in strokes]
    if variant > 0:
        strokes = jitter_strokes(strokes, hand, rng)
        wob = hand["baseline_wobble"]
        dy = rng.uniform(-wob, wob)
        strokes = [s + np.array([0, dy, 0]) for s in strokes]
    strokes = overshoot_start(strokes, hand["start_overshoot"], roles)
    sl = math.tan(math.radians(hand["slant_deg"]))
    if sl:
        strokes = [s + np.column_stack([s[:, 1] * sl, np.zeros(len(s)), np.zeros(len(s))]) for s in strokes]
    return strokes, roles, alt


# ============================================================================ pressure and pens
def pressure_profile(samples, corner_idx, hand, rng):
    """Authored pressure + the hand's habits -> effective pressure per sample (0..1+)."""
    pr = hand["pressure"]
    xy = samples[:, :2]
    p = samples[:, 2]
    if len(xy) < 3:
        return np.full(len(xy), pr["base"] + pr["scale"] * (p.mean() - 0.5) + 0.3)
    v = np.gradient(xy, axis=0)
    speed = np.linalg.norm(v, axis=1)
    d = v / np.maximum(speed, 1e-9)[:, None]
    down = np.clip(-d[:, 1], 0, 1)
    seg = np.linalg.norm(np.diff(xy, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    L = max(s[-1], 1e-6)
    u = s / L
    stop = pr["stop_weight"] * smoothstep((u - 0.80) / 0.20) ** 1.5
    start = pr["start_weight"] * (1 - smoothstep(u / 0.07))
    base_line = pr["baseline_weight"] * np.exp(-(xy[:, 1] / 55.0) ** 2)
    # sharpness: direction change across a ~14 unit window
    k = max(1, min(len(d) - 1, int(round(14 / max(np.median(seg), 1e-3)))))
    d_prev = np.vstack([d[:1].repeat(k, 0), d[:-k]])
    d_next = np.vstack([d[k:], d[-1:].repeat(k, 0)])
    turn = np.degrees(np.arccos(np.clip(np.sum(d_prev * d_next, axis=1), -1, 1)))
    turn_w = pr["turn_weight"] * np.clip(turn / 110.0, 0, 1)
    eff = pr["base"] + pr["scale"] * (p - 0.5) * 2 + pr["down_weight"] * down + base_line + stop + start + turn_w
    if pr["jitter"] > 0:
        n = rng.normal(0, pr["jitter"] * 0.5, size=len(eff))
        n = np.convolve(n, np.ones(9) / 9, mode="same")
        eff = eff + n
    return np.clip(eff, 0.05, 1.15), turn


def width_curve(eff, pen):
    w0 = pen["width_em"] * UPM
    lo, hi, g = pen.get("width_min", 1.0), pen.get("width_max", 1.0), pen.get("gamma", 1.0)
    return w0 * (lo + (hi - lo) * np.clip(eff, 0, 1.15) ** g)


def circle(c, r, n=12):
    a = np.linspace(0, 2 * math.pi, n, endpoint=False)
    return np.column_stack([c[0] + r * np.cos(a), c[1] + r * np.sin(a)])


def ribbon_pieces(xy, left, right, caps="round", squares=False):
    """Triangles between successive offsets, plus round discs (or oriented squares) at samples."""
    v = np.gradient(xy, axis=0)
    d = norm(v)
    nrm = np.column_stack([-d[:, 1], d[:, 0]])
    L = xy + nrm * left[:, None]
    R = xy - nrm * right[:, None]
    pieces = []
    for i in range(len(xy) - 1):
        pieces.append(np.array([L[i], L[i + 1], R[i + 1]]))
        pieces.append(np.array([L[i], R[i + 1], R[i]]))
    if squares:
        for i in range(len(xy)):
            h = min(left[i], right[i])
            t = d[i] * h
            n_ = nrm[i] * h
            pieces.append(np.array([xy[i] - t + n_, xy[i] + t + n_, xy[i] + t - n_, xy[i] - t - n_]))
    elif caps == "round":
        for i in range(len(xy)):
            pieces.append(circle(xy[i], max(0.8, min(left[i], right[i]))))
    return pieces


def smooth_noise(rng, n, spacing_samples, amp):
    """Piecewise-linear noise with a random value every `spacing_samples` samples."""
    k = max(2, int(n / max(spacing_samples, 1)) + 2)
    knots = np.clip(rng.normal(0, amp * 0.55, size=k), -amp, amp)
    xk = np.linspace(0, n - 1, k)
    return np.interp(np.arange(n), xk, knots)


def pen_pieces(samples, corner_idx, hand, rng, role):
    """One sampled stroke -> list of convex polygons (font units) for the union."""
    pen = hand["pen"]
    model = pen["model"]
    xy = samples[:, :2]
    if model == "stamp":
        w = np.full(len(xy), pen["width_em"] * UPM + pen.get("ink_spread_em", 0) * UPM)
        half = w / 2
        pieces = ribbon_pieces(xy, half, half, squares=True)
        # slab serifs on near-vertical stroke ends
        if role != "dot" and stroke_length(samples) > 120:
            for end, other in ((0, 1), (-1, -2)):
                d = norm(xy[end] - xy[other])
                if abs(d[1]) > math.cos(math.radians(38)):
                    hw = w[end] * pen["serif_length"] / 2
                    ht = w[end] * pen["serif_thickness"] / 2
                    c = xy[end]                     # the serif sits square on the end of the stem
                    pieces.append(np.array([[c[0] - hw, c[1] - ht], [c[0] + hw, c[1] - ht],
                                            [c[0] + hw, c[1] + ht], [c[0] - hw, c[1] + ht]]))
        return pieces

    eff, turn = pressure_profile(samples, corner_idx, hand, rng)
    w = width_curve(eff, pen)
    if model == "ballpoint":
        pieces = []
        # occasional skip: the ball misses for a short span in the middle of a long stroke
        skip = np.ones(len(xy))
        if role != "dot" and stroke_length(samples) > 220 and rng.random() < pen["skip_prob"]:
            seg = np.linalg.norm(np.diff(xy, axis=0), axis=1)
            s = np.concatenate([[0], np.cumsum(seg)])
            a = rng.uniform(0.25, 0.7) * s[-1]
            b = a + rng.uniform(*pen["skip_len"])
            skip[(s > a) & (s < b)] = 0.3
        w = w * skip
        half = w / 2
        pieces += ribbon_pieces(xy, half, half, caps="round")
        # ink pooling at the start and at sharp turns
        if role != "dot" and rng.random() < pen["pool_prob"]:
            pieces.append(circle(xy[0], half[0] * pen["pool_radius"], 14))
        sharp = np.where(turn > pen["pool_turn_deg"])[0]
        last = -100
        for i in sharp:
            if i - last > 10 and skip[i] > 0.5:
                pieces.append(circle(xy[i], half[i] * pen["pool_radius"] * 0.9, 14))
                last = i
        return pieces

    if model == "pencil":
        half = w / 2
        amp = pen.get("edge_noise_em", 0) * UPM
        if amp > 0:
            seg = np.median(np.linalg.norm(np.diff(xy, axis=0), axis=1))
            spacing = (UPM / pen.get("edge_samples_per_em", 40)) / max(seg, 1e-3)
            left = np.maximum(half + smooth_noise(rng, len(xy), spacing, amp), 2.0)
            right = np.maximum(half + smooth_noise(rng, len(xy), spacing, amp), 2.0)
        else:
            left = right = half
        return ribbon_pieces(xy, left, right, caps="round")

    raise ValueError(model)


# ============================================================================ union and contours
def _clean_poly(poly, snap=0.0):
    """Consistently wound, duplicate-free polygon, optionally snapped to a grid."""
    if len(poly) < 3:
        return None
    poly = np.asarray(poly, float)
    if snap > 0:
        poly = np.round(poly / snap) * snap
        keep = np.ones(len(poly), bool)
        keep[1:] = np.any(np.abs(np.diff(poly, axis=0)) > 1e-9, axis=1)
        poly = poly[keep]
        if len(poly) > 2 and np.allclose(poly[0], poly[-1]):
            poly = poly[:-1]
    if len(poly) < 3 or abs(signed_area(poly)) < 1e-3:
        return None
    return poly if signed_area(poly) > 0 else poly[::-1]


def _path_of(polys, snap=0.0):
    path = pathops.Path()
    for poly in polys:
        poly = _clean_poly(poly, snap)
        if poly is None:
            continue
        path.moveTo(float(poly[0, 0]), float(poly[0, 1]))
        for q in poly[1:]:
            path.lineTo(float(q[0]), float(q[1]))
        path.close()
    path.fillType = pathops.FillType.WINDING
    return path


def _simplified(pieces):
    """Skia occasionally refuses a pile of near-degenerate ribbon quads. Try it clean, then
    snapped to a grid, then piece by piece, dropping only the pieces that will not union."""
    for snap in (0.0, 0.5, 1.0):
        try:
            return pathops.simplify(_path_of(pieces, snap), fix_winding=True, keep_starting_points=False)
        except pathops.PathOpsError:
            continue
    acc = pathops.Path()
    acc.fillType = pathops.FillType.WINDING
    for poly in pieces:
        one = _path_of([poly], 0.5)
        if not list(one.contours):
            continue
        try:
            out = pathops.Path()
            pathops.union([acc, one], out.getPen())
            acc = out
        except pathops.PathOpsError:
            continue
    return acc


def union_pieces(pieces):
    """Union of consistently-wound polygons with skia-pathops -> list of (N,2) polylines."""
    result = _simplified(pieces)
    contours = []
    for c in result.contours:
        pts = []
        for verb, args in c.segments:
            if verb == "moveTo":
                pts.append(args[0])
            elif verb == "lineTo":
                pts.append(args[0])
            elif verb == "qCurveTo":
                pts.extend(args[:-1] if args[-1] is None else args)
            elif verb == "curveTo":
                pts.extend(args)
        pts = np.array(pts, float)
        if len(pts) >= 3 and abs(signed_area(pts)) > 40:
            if np.allclose(pts[0], pts[-1]):
                pts = pts[:-1]
            contours.append(pts)
    return contours


def orient_contours(contours):
    """TrueType: outer contours clockwise (negative area, y up), holes counter-clockwise.
    Returns (contours, depth flags)."""
    out = []
    for i, c in enumerate(contours):
        depth = 0
        probe = c[0]
        for j, o in enumerate(contours):
            if i != j and abs(signed_area(o)) > abs(signed_area(c)) and point_in_polygon(probe, o):
                depth += 1
        want_cw = depth % 2 == 0
        is_cw = signed_area(c) < 0
        if want_cw != is_cw:
            c = c[::-1]
        out.append((c, depth))
    return out


def resample_closed(poly, spacing):
    seg = np.linalg.norm(np.diff(np.vstack([poly, poly[:1]]), axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    L = s[-1]
    n = max(8, int(L / spacing))
    t = np.linspace(0, L, n, endpoint=False)
    closed = np.vstack([poly, poly[:1]])
    x = np.interp(t, s, closed[:, 0])
    y = np.interp(t, s, closed[:, 1])
    return np.column_stack([x, y])


def erode_contour(poly, rng, amp, spacing):
    """Irregular inward bites along an oriented contour (fill is to the right of travel)."""
    poly = resample_closed(poly, spacing)
    d = norm(np.roll(poly, -1, axis=0) - np.roll(poly, 1, axis=0))
    inward = np.column_stack([d[:, 1], -d[:, 0]])
    bite = rng.uniform(0, amp, size=len(poly)) * (rng.random(len(poly)) < 0.7)
    bite = np.convolve(np.concatenate([bite[-1:], bite, bite[:1]]), [0.3, 0.4, 0.3], mode="valid")
    return poly + inward * bite[:, None]


# ============================================================================ curve fitting
def rdp(points, eps):
    """Ramer-Douglas-Peucker on an open polyline."""
    if len(points) < 3:
        return points
    stack = [(0, len(points) - 1)]
    keep = np.zeros(len(points), bool)
    keep[0] = keep[-1] = True
    while stack:
        a, b = stack.pop()
        if b - a < 2:
            continue
        p, q = points[a], points[b]
        seg = q - p
        L = np.linalg.norm(seg)
        mid = points[a + 1:b]
        if L < 1e-9:
            dist = np.linalg.norm(mid - p, axis=1)
        else:
            dist = np.abs((mid - p) @ np.array([-seg[1], seg[0]])) / L
        i = int(np.argmax(dist))
        if dist[i] > eps:
            keep[a + 1 + i] = True
            stack.append((a, a + 1 + i))
            stack.append((a + 1 + i, b))
    return points[keep]


def rdp_closed(poly, eps):
    far = int(np.argmax(np.linalg.norm(poly - poly[0], axis=1)))
    if far == 0:
        return poly
    a = rdp(poly[:far + 1], eps)
    b = rdp(np.vstack([poly[far:], poly[:1]]), eps)
    return np.vstack([a[:-1], b[:-1]])


def bezier_eval(bez, u):
    u = u[:, None]
    return ((1 - u) ** 3) * bez[0] + 3 * u * (1 - u) ** 2 * bez[1] + 3 * u ** 2 * (1 - u) * bez[2] + u ** 3 * bez[3]


def generate_bezier(pts, u, t1, t2):
    p0, p3 = pts[0], pts[-1]
    B0, B1, B2, B3 = (1 - u) ** 3, 3 * u * (1 - u) ** 2, 3 * u ** 2 * (1 - u), u ** 3
    A0 = t1[None, :] * B1[:, None]
    A1 = t2[None, :] * B2[:, None]
    C00 = np.sum(A0 * A0)
    C01 = np.sum(A0 * A1)
    C11 = np.sum(A1 * A1)
    tmp = pts - (p0[None, :] * (B0 + B1)[:, None] + p3[None, :] * (B2 + B3)[:, None])
    X0 = np.sum(A0 * tmp)
    X1 = np.sum(A1 * tmp)
    det = C00 * C11 - C01 * C01
    seg = np.linalg.norm(p3 - p0)
    if abs(det) > 1e-12:
        al = (C11 * X0 - C01 * X1) / det
        ar = (C00 * X1 - C01 * X0) / det
    else:
        al = ar = -1
    eps = 1e-6 * seg
    if al < eps or ar < eps or al > 1.2 * seg or ar > 1.2 * seg:
        al = ar = seg / 3
    return np.array([p0, p0 + t1 * al, p3 + t2 * ar, p3])


def reparameterize(pts, u, bez):
    q = bezier_eval(bez, u)
    q1 = 3 * ((1 - u)[:, None] ** 2 * (bez[1] - bez[0]) + 2 * (1 - u)[:, None] * u[:, None] * (bez[2] - bez[1])
              + u[:, None] ** 2 * (bez[3] - bez[2]))
    q2 = 6 * ((1 - u)[:, None] * (bez[2] - 2 * bez[1] + bez[0]) + u[:, None] * (bez[3] - 2 * bez[2] + bez[1]))
    num = np.sum((q - pts) * q1, axis=1)
    den = np.sum(q1 * q1, axis=1) + np.sum((q - pts) * q2, axis=1)
    with np.errstate(divide="ignore", invalid="ignore"):
        un = np.where(np.abs(den) > 1e-12, u - num / den, u)
    un = np.clip(un, 0, 1)
    un[0], un[-1] = 0.0, 1.0
    return np.maximum.accumulate(un)


def fit_cubic(pts, t1, t2, err, depth=0):
    if len(pts) == 2:
        d = np.linalg.norm(pts[1] - pts[0]) / 3
        return [np.array([pts[0], pts[0] + t1 * d, pts[1] + t2 * d, pts[1]])]
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    u = np.concatenate([[0], np.cumsum(seg)])
    u = u / max(u[-1], 1e-9)
    bez = generate_bezier(pts, u, t1, t2)
    dist = np.linalg.norm(bezier_eval(bez, u) - pts, axis=1)
    split = int(np.argmax(dist))
    if dist[split] < err:
        return [bez]
    if dist[split] < err * 4:
        for _ in range(4):
            u = reparameterize(pts, u, bez)
            bez = generate_bezier(pts, u, t1, t2)
            dist = np.linalg.norm(bezier_eval(bez, u) - pts, axis=1)
            split = int(np.argmax(dist))
            if dist[split] < err:
                return [bez]
    split = min(max(split, 1), len(pts) - 2)
    if depth > 40:
        return [bez]
    tc = norm(pts[split - 1] - pts[split + 1])
    if np.linalg.norm(pts[split - 1] - pts[split + 1]) < 1e-9:
        tc = norm(pts[split - 1] - pts[split])
    return (fit_cubic(pts[:split + 1], t1, tc, err, depth + 1)
            + fit_cubic(pts[split:], -tc, t2, err, depth + 1))


def contour_to_cubics(poly, err, corner_deg=55, rdp_eps=0.7):
    poly = rdp_closed(poly, rdp_eps)
    n = len(poly)
    if n < 3:
        return []
    d1 = norm(poly - np.roll(poly, 1, axis=0))
    d2 = norm(np.roll(poly, -1, axis=0) - poly)
    ang = np.degrees(np.arccos(np.clip(np.sum(d1 * d2, axis=1), -1, 1)))
    corners = [i for i in range(n) if ang[i] > corner_deg]
    smooth_loop = not corners
    if smooth_loop:
        corners = [int(np.argmax(ang))]
    cubics = []
    for k, a in enumerate(corners):
        b = corners[(k + 1) % len(corners)]
        if b > a:
            seg = poly[a:b + 1]
        else:
            seg = np.vstack([poly[a:], poly[:b + 1]])
        if len(seg) < 2:
            continue
        if smooth_loop:
            t1 = norm(seg[1] - poly[(a - 1) % n])
            t2 = -t1
        else:
            t1 = norm(seg[1] - seg[0])
            t2 = norm(seg[-2] - seg[-1])
        cubics += fit_cubic(seg, t1, t2, err)
    return cubics


def cubics_to_glyph(contour_cubics, max_err=1.0):
    pen = TTGlyphPen(None)
    for cubics in contour_cubics:
        if not cubics:
            continue
        start = tuple(int(round(v)) for v in cubics[0][0])
        pen.moveTo(start)
        for cb in cubics:
            spline = curve_to_quadratic([tuple(map(float, p)) for p in cb], max_err)
            pts = [tuple(int(round(v)) for v in p) for p in spline[1:]]
            if len(pts) == 1:
                pen.lineTo(pts[0])
            else:
                pen.qCurveTo(*pts)
        pen.closePath()
    return pen.glyph()


# ============================================================================ glyph variants
def build_variant(glyph, variant, hand, rng, plan=None):
    """One glyph variant -> (oriented contours (list of (N,2)), alt name)."""
    strokes, roles, alt = style_strokes(glyph, variant, hand, rng, plan)
    pieces = []
    for s, role in zip(strokes, roles):
        L = stroke_length(s)
        step = min(6.0, max(1.0, L / 64.0))
        samples, corner_idx = sample_stroke(s, hand["tension"], step, hand["corner_deg"], hand["rounding"])
        pieces += pen_pieces(samples, corner_idx, hand, rng, role)
    if not pieces:
        return [], alt
    contours = union_pieces(pieces)
    oriented = orient_contours(contours)
    pen = hand["pen"]
    if pen["model"] == "stamp":
        amp = pen.get("erode_em", 0) * UPM
        spacing = UPM / pen.get("erode_samples_per_em", 40)
        eroded = []
        for c, depth in oriented:
            c = erode_contour(c, rng, amp, spacing)
            eroded.append(c)
        # erosion can pinch slivers; re-union to clean up
        contours = union_pieces([c if signed_area(c) > 0 else c[::-1] for c in eroded]) if eroded else []
        # holes were reversed above, re-orient with proper nesting
        oriented = orient_contours(contours)
        if variant > 0:
            mx, my = pen["misregister"]
            dx = rng.choice([-1, 1]) * rng.uniform(0.5, 1.0) * mx
            dy = rng.choice([-1, 1]) * rng.uniform(0.5, 1.0) * my
            oriented = [(c + [dx, dy], d) for c, d in oriented]
        tilt = math.radians(rng.uniform(-pen["tilt_deg"], pen["tilt_deg"])) if variant > 0 else 0.0
        if tilt:
            R = np.array([[math.cos(tilt), -math.sin(tilt)], [math.sin(tilt), math.cos(tilt)]])
            allpts = np.vstack([c for c, _ in oriented])
            cx = allpts[:, 0].mean()
            oriented = [((c - [cx, 0]) @ R.T + [cx, 0], d) for c, d in oriented]
    return [c for c, _ in oriented], alt


def hausdorff(a, b):
    if len(a) == 0 or len(b) == 0:
        return 0.0 if len(a) == len(b) else 1e9
    return max(directed_hausdorff(a, b)[0], directed_hausdorff(b, a)[0])


def contour_points(contours):
    if not contours:
        return np.zeros((0, 2))
    return np.vstack([resample_closed(c, 4.0) for c in contours])


def build_glyph_variants(glyph, hand, face_index, glyph_index, seed):
    """All variants of a glyph, re-rolled until every pair is distinct (Hausdorff > 12)."""
    n = hand["variants"]
    results = []
    plan = plan_alts(glyph, hand, np.random.default_rng([seed, face_index, glyph_index, 7]))
    for v in range(n):
        for attempt in range(24):
            rng = np.random.default_rng([seed, face_index, glyph_index, v, attempt])
            contours, alt = build_variant(glyph, v, hand, rng, plan)
            if not contours and glyph["strokes"]:
                continue
            pts = contour_points(contours)
            if v == 0 or not glyph["strokes"]:
                break
            if all(hausdorff(pts, r["pts"]) > HAUSDORFF_MIN for r in results):
                break
        results.append({"contours": contours, "pts": pts, "alt": alt, "attempts": attempt + 1})
    return results


# ============================================================================ faces
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def load_inputs():
    with open(os.path.join(HERE, "skeletons.json"), encoding="utf-8") as f:
        skel = json.load(f)
    with open(os.path.join(HERE, "hands.json"), encoding="utf-8") as f:
        hands = json.load(f)
    return skel, hands


def is_lower_letter(name, glyph):
    cp = glyph.get("cp")
    if cp is None:
        return False
    ch = chr(cp)
    return ch.isalpha() and ch.islower()


def face_glyphs(skel, hand):
    """The glyph set for a face: name -> skeleton entry (DeskStamp maps lower case to caps at 0.8)."""
    glyphs = {}
    for name, g in skel["glyphs"].items():
        g = dict(g)
        if hand.get("uppercase_only") and is_lower_letter(name, g):
            upper = name.upper() if len(name) == 1 else name[0].upper() + name[1:]
            if upper in skel["glyphs"]:
                src = skel["glyphs"][upper]
                g = dict(src)
                g["cp"] = skel["glyphs"][name]["cp"]
                g["_lower_scale"] = hand.get("lowercase_scale", 0.8)
                g["alts"] = []  # stamps do not vary structure
        if hand.get("uppercase_only"):
            g["alts"] = []
        glyphs[name] = g
    return glyphs


def glyph_order_for(glyphs):
    names = [n for n in glyphs if n != ".notdef"]
    names.sort(key=lambda n: (glyphs[n]["cp"] if glyphs[n]["cp"] is not None else 1 << 30, n))
    return [".notdef"] + names


def variant_name(name, v):
    return name if v == 0 else f"{name}.v{v}"


def feature_text(base_names, n):
    names = [b for b in base_names if b != ".notdef"]
    lines = ["languagesystem DFLT dflt;", "languagesystem latn dflt;", ""]
    for k in range(n):
        lines.append(f"@v{k} = [" + " ".join(variant_name(b, k) for b in names) + "];")
    lines.append("")
    for k in range(1, n):
        lines.append(f"lookup CYC{k} {{ sub @v0 by @v{k}; }} CYC{k};")
    lines.append("")
    lines.append("feature calt {")
    for k in range(n - 1):
        lines.append(f"  sub @v{k} @v0' lookup CYC{k + 1};")
    lines.append("} calt;")
    lines.append("")
    for j in range(1, 6):
        target = (j - 1) % n
        lines.append(f"feature ss0{j} {{")
        for k in range(n):
            if k != target:
                lines.append(f"  sub @v{k} by @v{target};")
        lines.append(f"}} ss0{j};")
        lines.append("")
    lines.append("feature rand {")
    for b in names:
        alts = " ".join(variant_name(b, k) for k in range(1, n))
        lines.append(f"  sub {b} from [{alts}];")
    lines.append("} rand;")
    return "\n".join(lines) + "\n"


def build_face(face, face_index, skel, hands, seed, out_dir, log):
    hand = hands[face]
    glyphs = face_glyphs(skel, hand)
    order = glyph_order_for(glyphs)
    n = hand["variants"]
    t0 = time.time()
    built = {}
    alt_usage = {}
    for gi, name in enumerate(order):
        g = glyphs[name]
        variants = build_glyph_variants(g, hand, face_index, gi, seed)
        built[name] = variants
        alt_usage[name] = [v["alt"] for v in variants]
        if gi % 25 == 0:
            log(f"  {face}: {gi + 1}/{len(order)} glyphs ({time.time() - t0:.1f}s)")

    # metrics and TrueType glyphs
    glyf = {}
    metrics = {}
    cmap = {}
    full_order = []
    space_adv = int(round(hand["space_em"] * UPM))
    gap = hand["gap"]
    for v in range(n):
        for gi, name in enumerate(order):
            gname = variant_name(name, v)
            full_order.append(gname)
            var = built[name][v]
            contours = var["contours"]
            rng = np.random.default_rng([seed, face_index, gi, v, 99])
            if not contours:
                glyf[gname] = TTGlyphPen(None).glyph()
                metrics[gname] = (space_adv if name == "space" else 500, 0)
            else:
                allpts = np.vstack(contours)
                xmin, xmax = allpts[:, 0].min(), allpts[:, 0].max()
                jl = rng.uniform(-hand["spacing_jitter"], hand["spacing_jitter"]) if v > 0 else 0
                jr = rng.uniform(-hand["spacing_jitter"], hand["spacing_jitter"]) if v > 0 else 0
                lsb = int(round(gap + jl))
                rsb = int(round(gap + jr))
                shift = lsb - xmin
                shifted = [c + [shift, 0] for c in contours]
                cubics = [contour_to_cubics(c, 1.5) for c in shifted]
                glyf[gname] = cubics_to_glyph(cubics, 1.0)
                adv = int(round(lsb + (xmax - xmin) + rsb))
                metrics[gname] = (adv, lsb)
            cp = glyphs[name].get("cp")
            if cp is not None:
                if v == 0:
                    cmap[cp] = gname
                else:
                    cmap[PUA_BASE + (v - 1) * 256 + (gi % 256) + (gi // 256) * 1280] = gname

    fb = FontBuilder(UPM, isTTF=True)
    stamp = timestampFromString("Thu Sep  3 12:00:00 2026")
    fb.setupHead(unitsPerEm=UPM, created=stamp, modified=stamp, fontRevision=1.0, lowestRecPPEM=8)
    fb.setupGlyphOrder(full_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(metrics)
    asc, desc, lgap = 950, -300, 100   # 1.35 em line height
    fb.setupHorizontalHeader(ascent=asc, descent=desc, lineGap=lgap)
    family, style = hand["family"], hand["style"]
    ps = f"{family}-{style}"
    fb.setupNameTable({
        "copyright": "love-tap. Authored stroke skeletons; built by tools/handwriting/build.py.",
        "familyName": family,
        "styleName": style,
        "uniqueFontIdentifier": f"1.000;LTAP;{ps}",
        "fullName": family if style == "Regular" else f"{family} {style}",
        "version": "Version 1.000",
        "psName": ps,
        "manufacturer": "love-tap",
        "designer": hand.get("person") or "desk furniture",
        "description": hand.get("description", ""),
    }, windows=True, mac=True)
    xh = int(round(skel["metrics"]["xheight"] * hand["xheight_scale"]))
    cap = int(round(skel["metrics"]["cap"] * hand["xheight_scale"]))
    fb.setupOS2(
        version=4,
        usWeightClass=400, usWidthClass=5, fsType=0,
        sTypoAscender=asc, sTypoDescender=desc, sTypoLineGap=lgap,
        usWinAscent=1000, usWinDescent=350,
        sxHeight=xh, sCapHeight=cap,
        achVendID="LTAP",
        fsSelection=(1 << 6) | (1 << 7),
        usDefaultChar=0, usBreakChar=32, usMaxContext=2,
        panose=dict(bFamilyType=3, bSerifStyle=0, bWeight=5, bProportion=0, bContrast=0, bStrokeVariation=0,
                    bArmStyle=0, bLetterForm=0, bMidline=0, bXHeight=0),
    )
    fb.setupPost(isFixedPitch=0, underlinePosition=-120, underlineThickness=60)
    gasp = newTable("gasp")
    gasp.version = 1
    gasp.gaspRange = {0xFFFF: 15}
    fb.font["gasp"] = gasp
    addOpenTypeFeaturesFromString(fb.font, feature_text(order, n))
    os2 = fb.font["OS/2"]
    os2.recalcUnicodeRanges(fb.font)
    os2.recalcAvgCharWidth(fb.font)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{face}.ttf")
    fb.save(path)
    log(f"  {face}: wrote {path} ({len(full_order)} glyphs, {time.time() - t0:.1f}s)")
    return path, {"glyphs": len(order), "variants": n, "alt_usage": alt_usage,
                  "attempts_max": max(v["attempts"] for vs in built.values() for v in vs)}


# ============================================================================ previews
PANGRAM = "The quick brown fox jumps over the lazy dog. Sphinx of black quartz, judge my vow."
DIGITS = "0123456789 £4.50 €12 ½ 20° 3×4 – — ‘quotes’ “here” … café"
PARAGRAPHS = {
    "NoorHand": ("back by six. the pigeon is still on the cupboard, year nine have named it. "
                 "left your good pen on my desk, which is not the same as lending it. "
                 "soup tonight? eight out of ten if there's bread from the bridge. "
                 "the boiler is sulking again, so is the boiler."),
    "TeoHand": ("off at eight, asleep by nine, don't ring. bins are thursday here, I put them out already. "
                "soup is on the hob with the lid on, don't rate it before it's done. "
                "turned the corner down where I stopped reading. "
                "your sock is still with the sock. the lift can keep the rest."),
    "DeskStamp": ("PULSE • CHAT • US • MOMENTS • SETTINGS\n"
                  "WRITTEN EARLIER • TOOK THIS BACK • FROM NOOR • FOR TEO\n"
                  "TUESDAY 3 SEPT 2026 • HALF TERM • BINS WEDNESDAY"),
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def wrap_text(draw, text, font, max_w, features):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        cur = ""
        for w in words:
            trial = (cur + " " + w).strip()
            if draw.textlength(trial, font=font, features=features) <= max_w or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
    return lines


def render_preview(face, font_path, hand, out_path, scale=2):
    from PIL import Image, ImageDraw, ImageFont
    W = 1100 * scale
    margin = 60 * scale
    paper = hex_rgb(hand.get("paper", "#f1ecdf"))
    ink = hex_rgb(hand.get("ink", "#1f2a44"))
    try:
        engine = ImageFont.Layout.RAQM
        ImageFont.truetype(font_path, 20, layout_engine=engine)
        features = ["calt"]
    except Exception:
        engine = ImageFont.Layout.BASIC
        features = None
    sizes = {"pangram": 40 * scale, "para": 34 * scale, "digits": 36 * scale}
    fonts = {k: ImageFont.truetype(font_path, s, layout_engine=engine) for k, s in sizes.items()}
    scratch = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    text = PANGRAM if face != "DeskStamp" else PANGRAM.upper()
    digits = DIGITS if face != "DeskStamp" else DIGITS.upper()
    blocks = [("pangram", wrap_text(scratch, text, fonts["pangram"], W - 2 * margin, features)),
              ("para", wrap_text(scratch, PARAGRAPHS[face], fonts["para"], W - 2 * margin, features)),
              ("digits", wrap_text(scratch, digits, fonts["digits"], W - 2 * margin, features))]
    y = margin
    layout = []
    for key, lines in blocks:
        lh = int(sizes[key] * 1.35)
        for ln in lines:
            layout.append((key, ln, y))
            y += lh
        y += int(sizes[key] * 0.6)
    H = y + margin // 2
    img = Image.new("RGB", (W, H), paper)
    draw = ImageDraw.Draw(img)
    for key, ln, yy in layout:
        draw.text((margin, yy), ln, font=fonts[key], fill=ink, features=features)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, optimize=True)
    return {"width": W, "height": H, "scale": scale, "layout_engine": "raqm" if features else "basic",
            "features": features or []}


def render_sheet(face, font_path, hand, out_path, order, n, scale=2):
    """Debug sheet: every glyph with all its variants side by side (via the PUA cmap)."""
    from PIL import Image, ImageDraw, ImageFont
    from fontTools.ttLib import TTFont
    tt = TTFont(font_path)
    rev = {g: cp for cp, g in tt["cmap"].getBestCmap().items()}
    size = 30 * scale
    cols = 6
    cell_w, cell_h = int(size * 1.0 * (n + 0.6)), int(size * 1.7)
    rows = math.ceil(len(order) / cols)
    img = Image.new("RGB", (cols * cell_w + 20, rows * cell_h + 20), hex_rgb(hand.get("paper", "#f1ecdf")))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(font_path, size, layout_engine=ImageFont.Layout.BASIC)
    ink = hex_rgb(hand.get("ink", "#1f2a44"))
    for i, name in enumerate(order):
        x = 10 + (i % cols) * cell_w
        y = 10 + (i // cols) * cell_h
        s = "".join(chr(rev[variant_name(name, v)]) for v in range(n) if variant_name(name, v) in rev)
        d.text((x, y), s, font=font, fill=ink)
    img.save(out_path)


# ============================================================================ main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "fonts"))
    ap.add_argument("--preview", default=None, help="preview directory (default <out>/previews)")
    ap.add_argument("--seed", type=int, default=DEFAULT_SEED)
    ap.add_argument("--faces", default=",".join(FACES))
    ap.add_argument("--sheet", default=None, help="also write a debug glyph sheet per face into this dir")
    ap.add_argument("--no-manifest", action="store_true", help="do not touch assets/MANIFEST.json")
    args = ap.parse_args(argv)
    out_dir = os.path.abspath(args.out)
    prev_dir = os.path.abspath(args.preview or os.path.join(out_dir, "previews"))
    faces = [f.strip() for f in args.faces.split(",") if f.strip()]
    skel, hands = load_inputs()
    inputs = {"tools/handwriting/skeletons.json": sha256(os.path.join(HERE, "skeletons.json")),
              "tools/handwriting/hands.json": sha256(os.path.join(HERE, "hands.json"))}
    log = lambda m: print(m, flush=True)  # noqa: E731
    fonts_manifest = {"generator": GENERATOR, "seed": args.seed, "inputs": inputs, "faces": {}, "outputs": []}
    for face in faces:
        face_index = FACES.index(face)
        log(f"building {face} (seed {args.seed})")
        path, info = build_face(face, face_index, skel, hands, args.seed, out_dir, log)
        hand = hands[face]
        settings = {"seed": args.seed, "face": face, "inputs": inputs, "hand": hand,
                    "glyphs": info["glyphs"], "variants": info["variants"],
                    "union": "skia-pathops", "outline": "RDP + Schneider cubic fit + cu2qu"}
        if not args.no_manifest:
            record(path, GENERATOR, settings, kind="font")
        prev = os.path.join(prev_dir, f"{face}.png")
        pinfo = render_preview(face, path, hand, prev)
        if not args.no_manifest:
            record(prev, GENERATOR, {"seed": args.seed, "face": face, "font": os.path.relpath(path, ROOT),
                                     **pinfo}, kind="preview")
        if args.sheet:
            os.makedirs(args.sheet, exist_ok=True)
            render_sheet(face, path, hand, os.path.join(args.sheet, f"{face}_sheet.png"),
                         glyph_order_for(face_glyphs(skel, hand)), hand["variants"])
        fonts_manifest["faces"][face] = {"font": os.path.relpath(path, ROOT), "preview": os.path.relpath(prev, ROOT),
                                         "glyphs": info["glyphs"], "variants": info["variants"],
                                         "max_variant_attempts": info["attempts_max"],
                                         "alt_usage": {k: v for k, v in info["alt_usage"].items()
                                                       if any(a != "base" for a in v)},
                                         "parameters": hand}
        fonts_manifest["outputs"] += [os.path.relpath(path, ROOT), os.path.relpath(prev, ROOT)]
    mpath = os.path.join(out_dir, "MANIFEST.fonts.json")
    with open(mpath, "w", encoding="utf-8") as f:
        json.dump(fonts_manifest, f, indent=1, sort_keys=True)
    if not args.no_manifest:
        record(mpath, GENERATOR, {"seed": args.seed, "inputs": inputs, "faces": faces}, kind="manifest")
    log(f"wrote {mpath}")


if __name__ == "__main__":
    main()
