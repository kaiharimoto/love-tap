#!/usr/bin/env python3
"""Whether a sheet of paper is flat because it was magnified, or flat as it was rendered.

    python3 tools/paper_tooth.py                      # the default six stocks
    python3 tools/paper_tooth.py --all                # every stock in assets/paper
    python3 tools/paper_tooth.py --long-side 1800     # what a bigger pack would buy
    python3 tools/paper_tooth.py --out evidence/logs/paper_tooth.json

This exists to settle one question that two queue items disagreed about, and it is not a gate.

`the-backing-surface-of-three-screens-is-one-rgb-value` asks that every 400x200 sample of a paper
region measure L_std >= 8 with >= 60 distinct luminance levels. Firing 20 fixed the cause it was
filed on -- a till roll stretched across a whole phone screen, because `hashOf` overflowed a double
on the web and picked a different stock there than on Android -- and left two of four samples still
under that floor. `no-surface-in-this-app-is-drawn-at-its-own-resolution` then read those two as a
resolution fault, on the argument that "magnifying a render of paper resamples its tooth away", and
named the remedy: raise `SIZES['paper']` in `tools/pack_assets.py` from 1500, against sources
`DIRECTION.md` says are 2400x3200 minimum.

Both halves of that are measurable here without a capture, and this file measures them.

  the chain        a stock is rendered into `assets/paper/`, packed to a long side by
                   `tools/pack_assets.py`, and drawn by `RegionPad` at about 1347x2908 device px
                   under `BoxFit.cover`. Each stage is reproduced here with the filter the stage
                   actually uses -- LANCZOS for the packer, bilinear for the draw, because the app
                   asks for `FilterQuality.medium` -- so a number here is a number about the app.

  the control      a sheet rendered at a higher resolution and drawn into the SAME box. `--probe`
                   takes a directory of such renders and puts them in the same table.

THE ONE TRAP IN MEASURING THIS, which cost a reading before it was caught. Do not compare a sample
of the source at 1:1 against a sample of the drawn sheet. The floor is defined on a 400x200 window
of the ARTIFACT, and every chain draws into the same 2908-px-tall box, so a screen window always
covers the same fraction of physical paper -- 0.137 of the sheet's width -- whatever the source
resolution is. A 400x200 window taken from an 1800-px source at 1:1 covers 0.222 of it instead,
1.6x more paper, and so it catches a printed rule far more often. The rules carry nearly all the
variance on a lined sheet, so that comparison reads 21/48 against 6/48 and looks like proof that
magnification is the mechanism. It is not a like-for-like reading and it is not evidence. Every
column in this table draws into `--box`, for that reason.

The floor is quoted from the queue item rather than defended here. Whether 8.0 is the right floor
for the quiet paper between a lined sheet's printed rules is a separate question, and the answer
this file gives is an input to it, not a verdict on it.
"""
import argparse
import glob
import io
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "paper")

# what the queue item asks of a 400x200 sample of a paper region
SAMPLE = (400, 200)
FLOOR_STD = 8.0
FLOOR_LEVELS = 60

# RegionPad's box on a 1440x3120 capture, as firing 20 measured it off the live build
PAD_BOX = (1347, 2908)

# the six the item and its parent name between them, plus the two that bracket the range
DEFAULT = ["lined_02", "lined_01", "looseleaf_01", "legal_01", "graph_01", "index_01"]


def pack(im, long_side, quality=88):
    """tools/pack_assets.py convert(), for a paper stock: RGB, LANCZOS down, lossy WEBP."""
    im = im.convert("RGB")
    if max(im.size) > long_side:
        s = long_side / max(im.size)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=quality, method=5, lossless=False)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB"), len(buf.getvalue())


def draw(packed, box=PAD_BOX):
    """BoxFit.cover into box, at FilterQuality.medium."""
    w, h = packed.size
    s = max(box[0] / w, box[1] / h)
    out = packed.resize((round(w * s), round(h * s)), Image.BILINEAR)
    left = max(0, (out.width - box[0]) // 2)
    top = max(0, (out.height - box[1]) // 2)
    return out.crop((left, top, left + box[0], top + box[1])), s


def samples(img, n=8, seed=7):
    """n windows of the size the item measures, placed the same way for every stock."""
    a = np.asarray(img.convert("L"), dtype=np.float64)
    w, h = SAMPLE
    if a.shape[0] < h or a.shape[1] < w:
        # a border-crop probe is smaller than the window: take the one window it does hold, so a
        # probe reports a reading rather than silently reporting nothing
        if a.shape[0] < h // 2 or a.shape[1] < w // 2:
            return []
        p = a[:h, :w]
        return [{"std": round(float(p.std()), 3),
                 "levels": int(len(np.unique(np.round(p)))), "clipped": list(p.shape)}]
    rng = np.random.default_rng(seed)
    out = []
    for _ in range(n):
        y = int(rng.integers(0, a.shape[0] - h))
        x = int(rng.integers(0, a.shape[1] - w))
        p = a[y:y + h, x:x + w]
        out.append({"std": round(float(p.std()), 3),
                    "levels": int(len(np.unique(np.round(p))))})
    return out


def passes(ss):
    return sum(1 for s in ss if s["std"] >= FLOOR_STD and s["levels"] >= FLOOR_LEVELS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="every stock, not the default six")
    ap.add_argument("--long-side", type=int, default=1800,
                    help="the alternative pack size to compare against the committed 1500")
    ap.add_argument("--packed-at", type=int, default=1500, help="what SIZES['paper'] is today")
    ap.add_argument("--samples", type=int, default=8)
    ap.add_argument("--box", type=int, nargs=2, default=list(PAD_BOX),
                    metavar=("W", "H"), help="the box every chain is drawn into")
    ap.add_argument("--probe", default="",
                    help="a directory of higher-resolution renders of the same stocks")
    ap.add_argument("--probe-res", type=int, default=3000,
                    help="the long side the --probe renders were made at")
    ap.add_argument("--border", type=float, nargs=4, metavar=("X0", "Y0", "X1", "Y1"),
                    help="crop every source to this fraction of the sheet first, so a border-crop "
                         "probe and the committed chain cover the SAME paper. Given in Blender's "
                         "convention, with y measured from the bottom, so the same four numbers "
                         "passed to blender/paper/stocks.py --border go here unchanged.")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    box = tuple(args.box)

    if args.all:
        stocks = sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(SOURCE, "*.webp")))
    else:
        stocks = DEFAULT

    rows = []
    for stem in stocks:
        path = os.path.join(SOURCE, stem + ".webp")
        if not os.path.exists(path):
            rows.append({"stock": stem, "why": "not on disk"})
            continue
        src = Image.open(path)
        row = {"stock": stem, "source": list(src.size)}

        # Both the packer's downscale and the draw's magnification are set by the WHOLE sheet
        # against the box. A crop must be put through those same two factors, not renormalised to
        # them, or cropping flatters the reading.
        whole = src.size
        if args.border:
            x0, y0, x1, y1 = args.border
            W, H = whole
            # blender measures y from the bottom of the frame and PIL from the top
            src = src.crop((round(x0 * W), round((1 - y1) * H), round(x1 * W), round((1 - y0) * H)))
            row["border"] = [x0, y0, x1, y1]
            row["cropped"] = list(src.size)

        for tag, ls in (("today", args.packed_at), ("bigger", args.long_side)):
            pack_scale = min(1.0, ls / max(whole))
            packed, nbytes = pack(src, round(max(src.size) * pack_scale))
            mag = max(box[0] / (whole[0] * pack_scale), box[1] / (whole[1] * pack_scale))
            drawn = packed.resize((max(1, round(packed.width * mag)),
                                   max(1, round(packed.height * mag))), Image.BILINEAR)
            ss = samples(drawn, args.samples)
            row[tag] = {"long_side": ls, "packed": list(packed.size), "bytes": nbytes,
                        "magnification": round(mag, 3),
                        "passes": passes(ss), "of": len(ss), "samples": ss}

        # a render made at a resolution the committed library does not have. It is already at its
        # own scale, so it is only resized by the magnification the box would apply to it.
        if args.probe:
            hit = ""
            for ext in (".png", ".webp"):
                cand = os.path.join(args.probe, stem + ext)
                if os.path.exists(cand):
                    hit = cand
                    break
            if hit:
                pim = Image.open(hit).convert("RGB")
                mag = box[1] / args.probe_res
                pim = pim.resize((max(1, round(pim.width * mag)), max(1, round(pim.height * mag))),
                                 Image.BILINEAR)
                ss = samples(pim, args.samples)
                row["probe"] = {"long_side": args.probe_res, "file": os.path.relpath(hit, ROOT),
                                "magnification": round(mag, 3),
                                "passes": passes(ss), "of": len(ss), "samples": ss}
        rows.append(row)

    def mean(rs, key):
        v = [s["std"] for r in rs if key in r for s in r[key]["samples"]]
        return round(float(np.mean(v)), 3) if v else None

    good = [r for r in rows if "today" in r]
    cols = ["today", "bigger"] + (["probe"] if any("probe" in r for r in rows) else [])
    report = {
        "floor": {"std": FLOOR_STD, "levels": FLOOR_LEVELS, "sample": list(SAMPLE)},
        "box": list(box),
        "stocks": len(good),
        "mean_std": {k: mean([r for r in good if k in r], k) for k in cols},
        "passes": {k: (sum(r[k]["passes"] for r in good if k in r),
                       sum(r[k]["of"] for r in good if k in r)) for k in cols},
        "bytes": {k: sum(r[k]["bytes"] for r in good) for k in ("today", "bigger")},
        "rows": rows,
    }

    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w") as fh:
            json.dump(report, fh, indent=1)

    w = sys.stdout.write
    w("floor: L_std >= %.1f and >= %d levels on a %dx%d sample of the artifact\n"
      % (FLOOR_STD, FLOOR_LEVELS, SAMPLE[0], SAMPLE[1]))
    w("every column below is drawn into the same %dx%d box, so each samples the same paper\n\n"
      % box)
    head = "%-16s %-20s %-20s" % ("stock", "packed %d" % args.packed_at,
                                  "packed %d" % args.long_side)
    if "probe" in cols:
        head += " %-16s" % ("rendered %d" % args.probe_res)
    w(head + "\n")
    for r in rows:
        if "today" not in r:
            w("%-16s %s\n" % (r["stock"], r.get("why", "?")))
            continue
        line = "%-16s %-20s %-20s" % (
            r["stock"],
            "%d/%d %5.1fkB %.2fx" % (r["today"]["passes"], r["today"]["of"],
                                     r["today"]["bytes"] / 1e3, r["today"]["magnification"]),
            "%d/%d %5.1fkB %.2fx" % (r["bigger"]["passes"], r["bigger"]["of"],
                                     r["bigger"]["bytes"] / 1e3, r["bigger"]["magnification"]))
        if "probe" in cols:
            line += (" %-16s" % ("%d/%d %.2fx" % (r["probe"]["passes"], r["probe"]["of"],
                                                  r["probe"]["magnification"]))
                     if "probe" in r else " %-16s" % "-")
        w(line + "\n")
    p, m = report["passes"], report["mean_std"]
    w("\n")
    for k, label in (("today", "packed %d" % args.packed_at),
                     ("bigger", "packed %d" % args.long_side),
                     ("probe", "rendered %d" % args.probe_res)):
        if k in cols and p[k][1]:
            w("%-18s pass %3d/%-3d   mean L_std %.3f\n" % (label, p[k][0], p[k][1], m[k]))
    w("paper bytes  %d: %.1f kB   %d: %.1f kB  (%.2fx)\n" % (
        args.packed_at, report["bytes"]["today"] / 1e3,
        args.long_side, report["bytes"]["bigger"] / 1e3,
        report["bytes"]["bigger"] / max(1, report["bytes"]["today"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
