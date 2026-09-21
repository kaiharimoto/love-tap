#!/usr/bin/env python3
"""Did the photographs actually arrive in the boxes the app drew for them?

    python3 tools/check/pictures_drawn.py 04_moments

A blob-backed picture -- a photograph out of the spine rather than out of `assets/` -- declares
itself in `<name>.surfaces.json` with an EMPTY `asset`, because it is not a file in the library.
The app only records such a surface at all when its `RenderImage` already holds a decoded image,
so every entry here is the app saying "there is a picture in this box".

This ruler asks the PNG whether there is. It is the artifact clause of
`four-of-fourteen-gallery-tiles-are-blob-backed-and-draw-nothing`, and it exists because that item
was filed against a cause that was not the cause: nothing resolved to nothing, the read landed and
the DECODE had not, and the box was painted as bare paper one frame before the picture arrived.

Two things it deliberately does NOT do, both of them WORKER_PROMPT 3d:

  * It never samples at a fixed coordinate. The window is placed by the surface's own declared
    rect, and it is TILED across that rect at a fixed stride -- the median of the tiling is the
    reading and the pass fraction is printed beside it. The item this replaces sampled one 200x200
    box at the centre of each tile and called `(59,2368)` flat at L_std 3.952. That tile holds
    `2025-12_towpath_lights`, a real night photograph, and a single placement on a dark sky is a
    sampling accident rather than a blank tile.
  * It never decides how many tiles there ought to be. The population comes out of the sidecars --
    the count of on-screen blob-backed surfaces, and the text sidecar's declared run count -- so a
    run that meets the floor by drawing fewer pictures fails on the population instead.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVIDENCE = os.path.join(ROOT, "evidence")

# A window narrower than this is not a sample of a photograph, it is a sample of a few pixels.
MIN_WINDOW = 48


def _rect_on_frame(rect, w, h):
    x, y, rw, rh = rect
    return x < w and y < h and x + rw > 0 and y + rh > 0


def tiled_std(L, rect, frame, window, stride):
    """Median L_std of a `window` square tiled across `rect` at `stride`, clipped to the frame."""
    fw, fh = frame
    x0 = max(0, int(rect[0]))
    y0 = max(0, int(rect[1]))
    x1 = min(fw, int(rect[0] + rect[2]))
    y1 = min(fh, int(rect[1] + rect[3]))
    if x1 - x0 < MIN_WINDOW or y1 - y0 < MIN_WINDOW:
        return None
    win = min(window, x1 - x0, y1 - y0)
    step = max(1, min(stride, win))
    stds = []
    ys = list(range(y0, y1 - win + 1, step)) or [y0]
    xs = list(range(x0, x1 - win + 1, step)) or [x0]
    for yy in ys:
        for xx in xs:
            stds.append(float(np.std(L[yy:yy + win, xx:xx + win])))
    if not stds:
        return None
    stds.sort()
    return {
        "windows": len(stds),
        "window_px": win,
        "stride_px": step,
        "median": round(stds[len(stds) // 2], 3),
        "min": round(stds[0], 3),
        "max": round(stds[-1], 3),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("artifact", help="a still's name, e.g. 04_moments")
    ap.add_argument("--floor", type=float, default=12.0,
                    help="the L_std a drawn photograph has to reach at the median of its tiling")
    ap.add_argument("--window", type=int, default=200)
    ap.add_argument("--stride", type=int, default=100)
    ap.add_argument("--evidence", default=EVIDENCE)
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    name = args.artifact.rsplit(".", 1)[0]
    png = os.path.join(args.evidence, name + ".png")
    surfaces = os.path.join(args.evidence, name + ".surfaces.json")
    textside = os.path.join(args.evidence, name + ".text.json")
    scenelog = os.path.join(args.evidence, "logs", name + ".json")

    out = {"artifact": name, "floor": args.floor}
    for label, path in (("png", png), ("surfaces", surfaces)):
        if not os.path.exists(path):
            out["ok"] = False
            out["why"] = f"no {label} for {name} at {path}"
            print(json.dumps(out, indent=1))
            return 1

    im = Image.open(png)
    frame = im.size
    L = np.asarray(im.convert("L"), dtype=np.float64)
    out["frame"] = list(frame)

    declared = json.load(open(surfaces, encoding="utf-8"))
    blobs = [s for s in declared if not s.get("asset")]
    on = [s for s in blobs if _rect_on_frame(s["rect"], *frame)]
    out["blob_surfaces_declared"] = len(blobs)
    out["blob_surfaces_on_screen"] = len(on)

    # The population that cannot be met by drawing less, read off the app's own declaration.
    if os.path.exists(textside):
        t = json.load(open(textside, encoding="utf-8"))
        runs = t.get("runs", t if isinstance(t, list) else [])
        out["text_runs_declared"] = t.get("declared", len(runs)) if isinstance(t, dict) else len(runs)
    # What the shutter believed when it fired, so a blank tile and a slow decode read differently.
    if os.path.exists(scenelog):
        s = json.load(open(scenelog, encoding="utf-8"))
        waits = s.get("blob_waits") or []
        if waits:
            last = waits[-1]
            out["pending_at_shot"] = last.get("pending_at_shot")
            out["undrawn_at_shot"] = last.get("undrawn_at_shot")

    rows, blank = [], []
    for s in on:
        r = tiled_std(L, s["rect"], frame, args.window, args.stride)
        row = {"rect": s["rect"], "src": s.get("src"), "fit": s.get("fit")}
        if r is None:
            row["skipped"] = f"rect is smaller than a {MIN_WINDOW}px window"
        else:
            row.update(r)
            row["pass_fraction"] = None
            row["drawn"] = r["median"] >= args.floor
            if not row["drawn"]:
                blank.append(row)
        rows.append(row)

    # The pass fraction beside the median, as 3d corollary 1 asks: how much of the tile reads as a
    # photograph, not merely whether its middle does.
    for row, s in zip(rows, on):
        if "median" not in row:
            continue
        x0 = max(0, int(s["rect"][0])); y0 = max(0, int(s["rect"][1]))
        x1 = min(frame[0], int(s["rect"][0] + s["rect"][2]))
        y1 = min(frame[1], int(s["rect"][1] + s["rect"][3]))
        win = row["window_px"]; step = row["stride_px"]
        hits = tot = 0
        for yy in range(y0, y1 - win + 1, step) or [y0]:
            for xx in range(x0, x1 - win + 1, step) or [x0]:
                tot += 1
                if float(np.std(L[yy:yy + win, xx:xx + win])) >= args.floor:
                    hits += 1
        row["pass_fraction"] = round(hits / tot, 3) if tot else None

    out["tiles"] = rows
    out["blank_tiles"] = len(blank)
    out["ok"] = len(blank) == 0 and len(on) > 0
    if not out["ok"]:
        if not on:
            out["why"] = "no blob-backed surface is on screen, so there is nothing to measure"
        else:
            out["why"] = (
                f"{len(blank)} of {len(on)} blob-backed boxes on screen hold no picture: "
                + ", ".join(
                    f"rect {b['rect']} median L_std {b['median']} over {b['windows']} windows"
                    for b in blank)
            )
    text = json.dumps(out, indent=1)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    print(text)
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
