#!/usr/bin/env python3
"""How rough a torn edge actually is on the glass, against the render it came from.

    python3 tools/check/deckle.py --out evidence/logs/deckle.json
    python3 tools/check/deckle.py evidence/02_chat.png

A material critic traced every paper/wood boundary run of 300 columns or more in the stills, high-
passed it over 31 columns and found rms 0.20 to 2.71 px, median 0.71, with 13 of 22 edges under one
pixel — "the torn edges are very nearly straight". That is a measurement of the fibres, not of the
overall wander: a tear's identity is in the fine scale, and a high-pass over 31 columns is where it
lives.

The mechanism it is measuring is the nine-patch. A piece's tear is drawn as four corners at their
rendered size with the middle band *stretched* across whatever is left, so on a piece much wider
than the band the fibres in the middle are smeared out to a quarter of their frequency and a
high-pass stops seeing them. The corners keep theirs. So this reports the roughness of each edge
*and* of its own middle third against its own outer thirds, which is the signature of a stretched
centre slice rather than of a smooth tear.

The control is the masks themselves: the same measurement on the alpha boundary of every packed
tear render, at the scale the render was made. That is the roughness the material actually has, and
anything on the glass is being compared against it rather than against a number somebody chose.
"""
import argparse
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVIDENCE = os.path.join(ROOT, "evidence")
TEARS = os.path.join(ROOT, "app", "assets", "tears")


def _highpass(y, window=31):
    """The edge with everything slower than [window] columns taken out of it."""
    if len(y) < window * 2:
        return np.zeros(0)
    k = np.ones(window) / window
    smooth = np.convolve(y, k, mode="same")
    edge = window // 2
    return (y - smooth)[edge:-edge]


def _runs(mask, min_len=300):
    """Boundary runs: for each column, the first row where [mask] is true, in unbroken stretches."""
    h, w = mask.shape
    first = np.full(w, -1)
    for x in range(w):
        col = np.flatnonzero(mask[:, x])
        if len(col):
            first[x] = col[0]
    out, run = [], []
    for x in range(w):
        if first[x] < 0 or (run and abs(first[x] - first[run[-1]]) > 24):
            if len(run) >= min_len:
                out.append(np.array([first[i] for i in run], dtype=float))
            run = []
            if first[x] >= 0:
                run = [x]
            continue
        run.append(x)
    if len(run) >= min_len:
        out.append(np.array([first[i] for i in run], dtype=float))
    return out


def _thirds(y, window=31):
    """rms of the middle third against the outer thirds — a stretched centre slice shows here."""
    n = len(y)
    if n < window * 4:
        return None
    a, b = n // 3, 2 * n // 3
    mid = _highpass(y[a:b], window)
    out = np.concatenate([_highpass(y[:a], window), _highpass(y[b:], window)])
    if not len(mid) or not len(out):
        return None
    return {"middle_third": round(float(np.sqrt((mid ** 2).mean())), 3),
            "outer_thirds": round(float(np.sqrt((out ** 2).mean())), 3)}


def _sheets(paper, min_len):
    """Every connected patch of paper wide enough to have an edge worth measuring, top and bottom.

    Taking the first pale row of each column over the whole frame finds one edge — the topmost
    sheet — and every other piece on the desk goes unmeasured. Each sheet is its own component.
    """
    try:
        from scipy import ndimage
    except Exception:
        return []
    lab, n = ndimage.label(paper)
    out = []
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(xs) < min_len * 4:
            continue
        x0, x1 = xs.min(), xs.max()
        if x1 - x0 + 1 < min_len:
            continue
        sub = lab[:, x0:x1 + 1] == i
        top = np.full(x1 - x0 + 1, -1.0)
        bottom = np.full(x1 - x0 + 1, -1.0)
        for k in range(sub.shape[1]):
            col = np.flatnonzero(sub[:, k])
            if len(col):
                top[k], bottom[k] = col[0], col[-1]
        for edge in (top, bottom):
            good = edge >= 0
            if good.sum() >= min_len:
                out.append(edge[good])
    return out


def edges_in(path, window=31, min_len=300):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    paper = lum > 150.0          # paper is pale, the desk is not
    rows = []
    for y in _sheets(paper, min_len) or _runs(paper, min_len):
        hp = _highpass(y, window)
        if not len(hp):
            continue
        rows.append({
            "columns": int(len(y)),
            "rms_px": round(float(np.sqrt((hp ** 2).mean())), 3),
            "wander_px": round(float(y.max() - y.min()), 1),
            "thirds": _thirds(y, window),
        })
    rows.sort(key=lambda r: r["rms_px"])
    return rows


def the_material(window=31, min_len=300, limit=24):
    """The same measurement on the renders, which is the roughness the material has."""
    rows = []
    for f in sorted(glob.glob(os.path.join(TEARS, "tear_*.webp")))[:limit * 4]:
        b = os.path.basename(f)
        if "_edge" in b or "_shadow" in b or "_dusk" in b:
            continue
        im = Image.open(f).convert("RGBA")
        alpha = np.asarray(im)[..., 3].astype(np.float32)
        for y in _runs(alpha > 128, min_len):
            hp = _highpass(y, window)
            if len(hp):
                rows.append(float(np.sqrt((hp ** 2).mean())))
        if len(rows) >= limit:
            break
    if not rows:
        return None
    rows.sort()
    return {
        "edges_measured": len(rows),
        "median_rms_px": round(float(np.median(rows)), 3),
        "smoothest": round(rows[0], 3),
        "roughest": round(rows[-1], 3),
        "note": "the alpha boundary of the packed tear renders, at the scale they were rendered. "
                "This is what a torn edge in this material measures; anything on the glass is "
                "compared against it.",
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--window", type=int, default=31)
    ap.add_argument("--min-len", type=int, default=300)
    ap.add_argument("--floor", type=float, default=0.0,
                    help="0 means take it from the material: half its median")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    material = the_material(a.window, a.min_len)
    floor = a.floor if a.floor > 0 else (round(material["median_rms_px"] / 2, 3) if material else 1.0)

    files = a.files or sorted(glob.glob(os.path.join(EVIDENCE, "*.png")))
    report = {
        "window_columns": a.window,
        "shortest_edge_measured": a.min_len,
        "floor_rms_px": floor,
        "floor_is": "half the median of the material's own edges" if a.floor <= 0 else "given",
        "the_material": material,
        "why_a_high_pass": "a tear's identity is in the fine scale. The overall wander of an edge "
                           "can be large while the fibres are gone — which is what a nine-patch "
                           "with a stretched centre band does to it, and why each edge below "
                           "reports its middle third against its outer thirds.",
        "stills": {},
    }
    smooth = 0
    for f in files:
        if not os.path.exists(f):
            continue
        rows = edges_in(f, a.window, a.min_len)
        under = [r for r in rows if r["rms_px"] < floor]
        report["stills"][os.path.basename(f)] = {
            "edges": len(rows),
            "median_rms_px": round(float(np.median([r["rms_px"] for r in rows])), 3) if rows else None,
            "smoothest": rows[0] if rows else None,
            "under_the_floor": len(under),
            "the_smoothest_few": rows[:4],
        }
        if under:
            smooth += 1
    report["ok"] = smooth == 0
    report["files_with_an_edge_smoother_than_the_material"] = smooth
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(json.dumps({k: report[k] for k in ("floor_rms_px", "ok",
                                             "files_with_an_edge_smoother_than_the_material")}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
