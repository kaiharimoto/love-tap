#!/usr/bin/env python3
"""Which flat-fill floor a paper stock takes, and the window that measures it.

`docs/COLOR.md` §5a is the declaration; this file is the only place it is written in code, so a
floor cannot drift between the three tools that read it. Nothing here is a preference: every
number in `FLOORS` is defended in §5a against a measurement, and this module refuses to invent a
class for a stock it does not recognise rather than guessing one.

Three classes, because one floor was the right number for a writing paper and the wrong number for
a coated stock:

  written   stock carrying printed rules, a grid or a margin    8.0 / 60
  plain     uncoated stock with no printed content              6.0 / 48
  coated    a surface whose correct render is near-featureless  4.0 / 32

And the window, which is the half of the ruler that cycle 3 got wrong three times. A 400x200 window
is placed **from the surface's own declared bounds** and tiled across them at a fixed stride, and
the statistic is the **median** over every placement with the pass fraction beside it. Never a box
at a fixed coordinate -- `loop/WORKER_PROMPT.md` §3d is why, and firing 31's fold sample sliding off
the fold and onto `assets/paper/looseleaf_03` is the case that forced it. Never the maximum over
placements either: `surfaces.py` took `max()` until firing 33, which passes a flat sheet on the
strength of one textured corner.
"""
import os

import numpy as np

# docs/COLOR.md §5a. (L_std floor, distinct-luminance-level floor).
FLOORS = {
    "written": (8.0, 60),
    "plain": (6.0, 48),
    "coated": (4.0, 32),
}

# Which class each stock is in, by the prefix of its name. §5a's table, verbatim.
PREFIXES = (
    ("lined_", "written"),
    ("spiral_", "written"),
    ("legal_", "written"),
    ("looseleaf_", "written"),
    ("index_", "written"),
    ("graph_", "written"),
    ("sticky_", "coated"),
    ("receipt", "coated"),
)

# A fold sequence is governed by the class of the stock it is folded from -- §5a again. The stock
# is named here rather than inferred from the sequence name, because `unfold_thirds` says nothing
# about what it is folded from and a guess is exactly what this module exists to refuse.
# `blender/folds/fold.py`'s RULES_STOCK is the source of truth; this mirrors it, and
# `fold_stock_matches_the_renderer` in tools/check/stock_class_selftest.py asserts they agree.
FOLDED_FROM = {
    "unfold_thirds": "lined",
}

SAMPLE = (400, 200)
STRIDE = 25


def classify(stock):
    """The class of a stock by name, or None if this file does not recognise it.

    Both spellings resolve, because the repository uses both: §5a's table and `assets/paper/`
    name a sheet `lined_03`, while `blender/folds/fold.py`'s `RULES_STOCK` names the family it
    is cut from as `lined`. A family that matched only the suffixed form silently returned None
    for the fold sequence, which is the one surface this floor was written for.
    """
    for prefix, cls in PREFIXES:
        if stock.startswith(prefix) or stock == prefix.rstrip("_"):
            return cls
    return None


def floor_for_fold(sequence):
    """(class, L_std floor, level floor) for a fold sequence, by the stock it is folded from."""
    stock = FOLDED_FROM.get(sequence)
    if stock is None:
        return None, None, None
    cls = classify(stock)
    if cls is None:
        return None, None, None
    std, levels = FLOORS[cls]
    return cls, std, levels


def sheet_bounds(rgba):
    """The paper's own declared bounds inside a rendered frame: the sheet, not its drop shadow.

    A fold frame is a sheet lying on transparency with a rendered drop shadow beside it. The
    shadow is opaque and dark, so a window that straddles it reads the shadow's contrast as if it
    were the paper's tooth -- frame 0000 of `unfold_thirds` measures 19.311 that way and 5.686
    when the shadow is excluded, which is the difference between passing this floor and failing
    it by a third. So the bounds are the bright opaque region, and the rows and columns taken are
    the ones where it is actually present rather than the bounding box of a stray pixel.

    Returns (y0, y1, x0, x1, mask) or None when there is no sheet to measure.
    """
    a = rgba.astype(float)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    sheet = (a[..., 3] > 250) & (lum > 190)
    if sheet.sum() < 4000:
        return None
    rows_present = sheet.sum(axis=1)
    cols_present = sheet.sum(axis=0)
    rows = np.where(rows_present > 0.5 * rows_present.max())[0]
    cols = np.where(cols_present > 0.5 * cols_present.max())[0]
    if rows.size == 0 or cols.size == 0:
        return None
    return int(rows.min()), int(rows.max()) + 1, int(cols.min()), int(cols.max()) + 1, sheet


def tiled(lum, bounds, sample=SAMPLE, stride=STRIDE):
    """Every placement of the window inside [bounds], as (L_std, distinct levels) pairs."""
    y0, y1, x0, x1 = bounds
    ww = min(sample[0], x1 - x0)
    wh = min(sample[1], y1 - y0)
    out = []
    for y in range(y0, y1 - wh + 1, stride):
        for x in range(x0, x1 - ww + 1, stride):
            patch = lum[y:y + wh, x:x + ww]
            vals = patch[~np.isnan(patch)]
            if vals.size < 0.5 * ww * wh:
                continue          # mostly off the sheet: not a placement on this surface
            out.append((float(vals.std()),
                        int(len(np.unique(np.round(vals).astype(int))))))
    return (ww, wh), out


def measure(rgba, floor_std, floor_levels):
    """The §5a reading of one frame: median over tiled placements, with the pass fraction."""
    found = sheet_bounds(rgba)
    if found is None:
        return None
    y0, y1, x0, x1, sheet = found
    a = rgba.astype(float)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    lum = np.where(sheet, lum, np.nan)
    window, placements = tiled(lum, (y0, y1, x0, x1))
    if not placements:
        return None
    stds = np.array([p[0] for p in placements])
    levels = np.array([p[1] for p in placements])
    passed = (stds >= floor_std) & (levels >= floor_levels)
    return {
        "bounds": [x0, y0, x1 - x0, y1 - y0],
        "window": list(window),
        "placements": len(placements),
        "median_std": round(float(np.median(stds)), 3),
        "median_levels": int(np.median(levels)),
        "min_std": round(float(stds.min()), 3),
        "max_std": round(float(stds.max()), 3),
        "pass_fraction": round(float(passed.mean()), 3),
        "floor": [floor_std, floor_levels],
        "ok": bool(np.median(stds) >= floor_std and np.median(levels) >= floor_levels),
    }
