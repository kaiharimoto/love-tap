#!/usr/bin/env python3
"""What one screen holds decoded for its tears, and what packing the lit edges smaller costs it.

    python3 tools/check/edge_residency.py                      # 12_search, the shipped pack
    python3 tools/check/edge_residency.py --artifact 03_us
    python3 tools/check/edge_residency.py --downsample 3       # what a 3x pack would cost
    python3 tools/check/edge_residency.py --out evidence/edge_residency.json

Two numbers, both read off what the app declared rather than off pixels:

  residency   every tear mask and lit edge the still's `<artifact>.surfaces.json` declares, at the
              size `app/assets/INDEX.json` says it is packed at, times four bytes -- a `ui.Image`
              has no single-channel format (firing 51) -- plus the compositions `SlicedMasks`
              keeps, from each mask entry's own `composed`. This is firing 51's arithmetic, kept
              in one place so a second reading cannot drift from the first.

  the band    for every edge the still declares, the edge drawn at the geometry the sidecar
              says (`drawn`, `fixed`, `centre`, `slice`) over paper, once from a 1x edge
              re-packed out of `assets/tears/<id>_edge.png` exactly as `tools/pack_assets.py`
              crops it, and once from a copy downsampled N times and drawn at the same geometry.
              Mean |difference| per channel, out of 255, over the piece's rect and over the band
              itself (where the 1x edge's alpha exceeds 5%). Held to 2/255 on the band, so an
              edge cannot pass by fading out.

The ruler was earned on a known pair before it was cited (WORKER_PROMPT 3d): at `--downsample 1`
it must read zero, and at 3 it reads the band past the 2/255 the item set, so it can refuse.
"""
import argparse
import json
import os
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import pack_assets  # noqa: E402

PAPER = np.array([236, 229, 214], float)  # a mid cream; the band is a light, so darker reads harsher
BAND_ALPHA = 13
BAND_CEILING = 2.0


def _nine(img, dw, dh, fx, cx, fy, cy, e):
    """drawImageNine's lattice, resampled bilinearly: corners at `fixed` device px a source px,
    the middle at `centre`, normalised to exactly the drawn box."""
    H, W = img.shape[:2]
    xs = [0, round(W * e), round(W * (1 - e)), W]
    ys = [0, round(H * e), round(H * (1 - e)), H]
    dxs = np.array([xs[1] * fx, (xs[2] - xs[1]) * cx, (W - xs[2]) * fx])
    dys = np.array([ys[1] * fy, (ys[2] - ys[1]) * cy, (H - ys[2]) * fy])
    dxs = dxs * dw / dxs.sum()
    dys = dys * dh / dys.sum()
    bx = np.round(np.concatenate([[0], np.cumsum(dxs)])).astype(int)
    by = np.round(np.concatenate([[0], np.cumsum(dys)])).astype(int)
    out = np.zeros((dh, dw, 4))
    for j in range(3):
        for i in range(3):
            w_, h_ = bx[i + 1] - bx[i], by[j + 1] - by[j]
            sub = img[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
            if w_ <= 0 or h_ <= 0 or sub.size == 0:
                continue
            ch = [np.asarray(Image.fromarray(sub[..., c].astype(np.float32), "F")
                             .resize((w_, h_), Image.BILINEAR, reducing_gap=2.0)) for c in range(4)]
            out[by[j]:by[j + 1], bx[i]:bx[i + 1]] = np.stack(ch, -1)
    return out


def _premultiplied(im):
    f = np.asarray(im.convert("RGBA")).astype(float)
    f[..., :3] *= f[..., 3:4] / 255.0
    return f


def _edge_at_1x(tear, tmp):
    """The edge as the pack wrote it before firing 54: the mask's crop, at the mask's 1024."""
    src = os.path.join(ROOT, "assets", "tears")
    box = pack_assets.paper_box(os.path.join(src, tear + ".png"))
    dst = os.path.join(tmp, tear + "_edge.webp")
    pack_assets.convert(os.path.join(src, tear + "_edge.png"), dst, pack_assets.SIZES["tears"],
                        pack_assets.QUALITY["tears"], keep_alpha=True, crop=box)
    return Image.open(dst)


def residency(surfaces, index):
    sizes = {r["id"]: (r["w"], r["h"]) for r in index["tears"]}
    # a big sheet is cut by its mask's finer copy (assets/tears/hi/, since firing 54)
    sizes.update({"hi/" + r["id"]: (r["w"], r["h"]) for r in index.get("tears_hi", [])})
    masks, edges, composed = set(), set(), set()
    for s in surfaces:
        a = s["asset"]
        if not a.startswith("assets/tears/"):
            continue
        tid = os.path.splitext(a[len("assets/tears/"):])[0]
        if s.get("fit") == "mask":
            masks.add(tid)
            if s.get("composed"):
                composed.add((tid, tuple(s["composed"])))
    for s in surfaces:
        tid = os.path.splitext(os.path.basename(s["asset"]))[0]
        if s.get("fit") == "nine" and tid.endswith("_edge") and (
                tid[:-5] in masks or "hi/" + tid[:-5] in masks):
            edges.add(tid)
    b = lambda ids: sum(sizes[t][0] * sizes[t][1] * 4 for t in ids)
    return {
        "masks": len(masks), "edges": len(edges),
        "mask_mb": round(b(masks) / 2**20, 2), "edge_mb": round(b(edges) / 2**20, 2),
        "composed_mb": round(sum(w * h * 4 for _, (w, h) in composed) / 2**20, 2),
        "edge_px": sorted({f"{sizes[t][0]}x{sizes[t][1]}" for t in edges})[:4],
    }


def band(surfaces, k):
    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        cache = {}
        for s in surfaces:
            if s.get("fit") != "nine" or not s["asset"].endswith("_edge.webp"):
                continue
            tear = os.path.basename(s["asset"])[: -len("_edge.webp")]
            if tear not in cache:
                cache[tear] = _edge_at_1x(tear, tmp)
            full = cache[tear]
            small = full.resize((max(1, round(full.width / k)), max(1, round(full.height / k))),
                                Image.LANCZOS)
            dw, dh = s["drawn"]
            if dw < 2 or dh < 2:
                continue
            # the sidecar reports magnification per pixel of what was decoded; bring it back to
            # per pixel of the 1x edge, which is what the lattice is laid out in
            d0 = float(s.get("downsample", 1))
            fx, fy = (f / d0 for f in s["fixed"])
            cx, cy = (c / d0 for c in s["centre"])
            # a list since firing 60, when the edge took its mask's bands: [left, top]
            sl = s.get("slice", 0.4)
            e = float(sl[0] if isinstance(sl, list) else sl)
            a = _nine(_premultiplied(full), dw, dh, fx, cx, fy, cy, e)
            b = _nine(_premultiplied(small), dw, dh, fx * k, cx * k, fy * k, cy * k, e)
            ca = a[..., :3] + PAPER * (1 - a[..., 3:4] / 255)
            cb = b[..., :3] + PAPER * (1 - b[..., 3:4] / 255)
            d = np.abs(ca - cb)
            on = a[..., 3] > BAND_ALPHA
            rows.append({"asset": s["asset"], "piece": s.get("piece", ""), "drawn": [dw, dh],
                         "rect_mean": round(float(d.mean()), 3),
                         "band_mean": round(float(d[on].mean()), 3) if on.any() else 0.0,
                         "p999": round(float(np.percentile(d, 99.9)), 1)})
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--artifact", default="12_search")
    ap.add_argument("--downsample", type=float, default=2.0)
    ap.add_argument("--no-band", action="store_true", help="residency only; skips the re-pack")
    ap.add_argument("--out")
    a = ap.parse_args(argv)
    surfaces = json.load(open(os.path.join(ROOT, "evidence", f"{a.artifact}.surfaces.json")))
    index = json.load(open(os.path.join(ROOT, "app", "assets", "INDEX.json")))
    rep = {"artifact": a.artifact, "residency": residency(surfaces, index)}
    r = rep["residency"]
    r["total_mb"] = round(r["mask_mb"] + r["edge_mb"] + r["composed_mb"], 2)
    print(f"{a.artifact}: {r['masks']} masks {r['mask_mb']} MB, {r['edges']} edges {r['edge_mb']} MB "
          f"({', '.join(r['edge_px'])}...), composed {r['composed_mb']} MB, total {r['total_mb']} MB")
    ok = True
    if not a.no_band:
        rows = band(surfaces, a.downsample)
        worst = max(rows, key=lambda x: x["band_mean"])
        rep["band"] = {"downsample": a.downsample, "n": len(rows),
                       "rect_mean_max": max(x["rect_mean"] for x in rows),
                       "band_mean_max": worst["band_mean"],
                       "band_mean_median": float(np.median([x["band_mean"] for x in rows])),
                       "worst": worst, "ceiling": BAND_CEILING, "rows": rows}
        ok = worst["band_mean"] <= BAND_CEILING
        print(f"band at {a.downsample:g}x over {len(rows)} declared edges: rect mean <= "
              f"{rep['band']['rect_mean_max']}/255, band mean <= {worst['band_mean']}/255 "
              f"({worst['asset'].split('/')[-1]} {worst['piece']}), ceiling {BAND_CEILING} -> "
              f"{'PASS' if ok else 'FAIL'}")
    if a.out:
        with open(a.out, "w") as f:
            json.dump(rep, f, indent=1)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
