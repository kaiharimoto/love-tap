#!/usr/bin/env python3
"""Whether a sheet of paper is flat because it was magnified, or flat as it was rendered.

    python3 tools/paper_tooth.py                      # the default six stocks
    python3 tools/paper_tooth.py --all                # every stock in assets/paper
    python3 tools/paper_tooth.py --long-side 1800     # what a bigger pack would buy
    python3 tools/paper_tooth.py --out evidence/logs/paper_tooth.json
    python3 tools/paper_tooth.py --all --condition dusk          # one half of the library
    python3 tools/paper_tooth.py --all --source /tmp/old/assets/paper   # a library out of git

This exists to settle one question that two queue items disagreed about, and it is not a gate.

`the-backing-surface-of-three-screens-is-one-rgb-value` asks that every 400x200 sample of a paper
region measure L_std >= 8. Firing 20 fixed the cause it was
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

THE FLOOR IS NO LONGER ONE NUMBER. It was `FLOOR_STD = 8.0`, "quoted from the queue item rather
than defended here", until docs/COLOR.md §5a declared a floor per stock class -- written 8.0,
plain 6.0, coated 4.0 -- and required each to be met SEPARATELY at day and at dusk. Both live in
tools/check/stock_class.py and nowhere else, so this file, flat_fill.py and surfaces.py cannot
drift apart. Each window is counted against its own stock's floor, and the table ends with the
§5a verdict per stock: its class, its floor, its day and dusk medians, and whether both clear.

AND THE DRAW NOW INCLUDES THE MAGNIFICATION THE APP ACTUALLY APPLIES. Every `Slip` -- `RegionPad`
included -- hands `PaperPiece` a `stockScale` of 1.12, and `PaperPiece` wraps the image in
`Transform.scale(stockScale)` on top of `BoxFit.cover`. The pad's own `surfaces.json` entry shows
it: `drawn` 1347x2908, `rect` 1513x3259, which is x1.123 on both axes. Until firing 49 this file
drew into the box at cover alone, which is a draw the app never makes. `--stock-scale 1.0` gives
the old chain back, for comparing against a number measured before.

WHAT THIS DRAW STILL IS NOT, stated so a verdict is not read as more than it is: every stock is
drawn into the PAD's box, and the pad is only ever `lined`, `looseleaf`, `graph`, `legal` or
`spiral` (`RegionPad.stocks`). The committed evidence set draws `receipt` as notes at a median
declared scale of 1.56 and never draws a sticky note at 400x200 or larger at all -- 198x192 is the
biggest -- so the coated verdicts are a verdict on the stock, read at the pad's magnification,
and not on any surface a person has seen.
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
sys.path.insert(0, os.path.join(ROOT, "tools", "check"))
import stock_class  # noqa: E402
SOURCE = os.path.join(ROOT, "assets", "paper")

# what the queue item asks of a 400x200 sample of a paper region
SAMPLE = (400, 200)
# The floor is per class and lives in stock_class.FLOORS -- docs/COLOR.md §5a.
# No level floor: struck from docs/COLOR.md §5a at firing 36 for failing the repaired stocks
# (57-58) as well as the defect (42). The count is still measured and reported per window.

# RegionPad's box on a 1440x3120 capture, as firing 20 measured it off the live build, and what
# every capture since declares as the pad's `drawn`
PAD_BOX = (1347, 2908)
# PaperPiece's Transform.scale around the image, as Slip passes it (app/lib/material/slip.dart)
STOCK_SCALE = 1.12

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


def tiled(img, stride=stock_class.STRIDE):
    """Every placement of the window across the whole drawn box at a fixed stride, as L_std.

    docs/COLOR.md §5a's statistic: the window is tiled across the surface's own bounds and the
    reading is the median over every placement, never a handful of random drops. Firing 49
    measured why on this very file: eight seeded placements per sheet put `receipt` at dusk at
    3.799 and sixty-four put it at 4.494, and `index` at dusk passed on one and failed on the
    other. Computed off an integral image, so four thousand placements a sheet cost nothing.
    """
    a = np.asarray(img.convert("L"), dtype=np.float64)
    w, h = SAMPLE
    if a.shape[0] < h or a.shape[1] < w:
        return np.array([])
    s1 = np.pad(a.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    s2 = np.pad((a * a).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    ys = np.arange(0, a.shape[0] - h + 1, stride)
    xs = np.arange(0, a.shape[1] - w + 1, stride)
    Y, X = np.meshgrid(ys, xs, indexing="ij")

    def box(t):
        return t[Y + h, X + w] - t[Y, X + w] - t[Y + h, X] + t[Y, X]
    n = float(w * h)
    mean = box(s1) / n
    var = np.maximum(box(s2) / n - mean * mean, 0.0)
    return np.sqrt(var).ravel()


def family(stem):
    """`sticky_blue_02_dusk` -> `sticky_blue`. The variant is two digits and a condition
    suffix is one word, and every stock name in rules.STOCKS is what is left."""
    parts = stem.split("_")
    while parts and (parts[-1] == "dusk" or parts[-1].isdigit()):
        parts.pop()
    return "_".join(parts)


def condition(stem):
    return "dusk" if stem.endswith("_dusk") else "day"


def floor_of(stem):
    """The §5a floor for this sheet's stock, or None when the stock has no class."""
    cls = stock_class.classify(family(stem))
    return stock_class.FLOORS[cls] if cls else None


def passes(ss, floor):
    return 0 if floor is None else sum(1 for s in ss if s["std"] >= floor)


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
    ap.add_argument("--source", default=SOURCE,
                    help="the directory of rendered stocks to read. Defaults to assets/paper. "
                         "A before/after against a re-render needs the OLD library too, and the "
                         "old library is in git rather than on disk: `git archive <sha> "
                         "assets/paper | tar -x -C <dir>` and point this at it.")
    ap.add_argument("--only", default="",
                    help="keep only stems containing this substring, so one family can be read "
                         "on its own while the rest of a re-render is still in flight.")
    ap.add_argument("--stock-scale", type=float, default=STOCK_SCALE,
                    help="PaperPiece's Transform.scale on top of cover. 1.12 is what Slip passes; "
                         "1.0 is the chain this file measured until firing 49.")
    ap.add_argument("--condition", choices=["day", "dusk", "both"], default="both",
                    help="which half of the library to read. A stem ending `_dusk` is a dusk "
                         "sheet and every other stem is a day one. Only meaningful with --all.")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    source = args.source
    box = tuple(args.box)

    if args.all:
        stocks = sorted(os.path.basename(p)[:-5] for p in glob.glob(os.path.join(source, "*.webp")))
    else:
        stocks = DEFAULT
    if args.only:
        stocks = [s_ for s_ in stocks if args.only in s_]
    if args.condition == "day":
        stocks = [s_ for s_ in stocks if not s_.endswith("_dusk")]
    elif args.condition == "dusk":
        stocks = [s_ for s_ in stocks if s_.endswith("_dusk")]

    rows = []
    for stem in stocks:
        path = os.path.join(source, stem + ".webp")
        if not os.path.exists(path):
            rows.append({"stock": stem, "why": "not on disk"})
            continue
        src = Image.open(path)
        floor = floor_of(stem)
        row = {"stock": stem, "source": list(src.size), "class": stock_class.classify(family(stem)),
               "floor": floor}

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
            mag = max(box[0] / (whole[0] * pack_scale),
                      box[1] / (whole[1] * pack_scale)) * args.stock_scale
            drawn = packed.resize((max(1, round(packed.width * mag)),
                                   max(1, round(packed.height * mag))), Image.BILINEAR)
            ss = samples(drawn, args.samples)
            row[tag] = {"long_side": ls, "packed": list(packed.size), "bytes": nbytes,
                        "magnification": round(mag, 3),
                        "passes": passes(ss, floor), "of": len(ss), "samples": ss}
            # What the glass shows is the box, not the whole magnified sheet: cover crops the
            # overhang, so a window that lands in it is measuring paper nobody is shown.
            left = max(0, (drawn.width - box[0]) // 2)
            top = max(0, (drawn.height - box[1]) // 2)
            t = tiled(drawn.crop((left, top, left + min(box[0], drawn.width),
                                  top + min(box[1], drawn.height))))
            row[tag]["tiled"] = {
                "placements": int(t.size),
                "median_std": round(float(np.median(t)), 3) if t.size else None,
                "pass_fraction": (round(float((t >= floor).mean()), 3)
                                  if t.size and floor is not None else None),
            }
            if tag == "today":
                row["_tiled"] = t

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
                                "passes": passes(ss, floor), "of": len(ss), "samples": ss}
        rows.append(row)

    def mean(rs, key):
        v = [s["std"] for r in rs if key in r for s in r[key]["samples"]]
        return round(float(np.mean(v)), 3) if v else None

    good = [r for r in rows if "today" in r]
    cols = ["today", "bigger"] + (["probe"] if any("probe" in r for r in rows) else [])
    report = {
        "floor": {"std": dict(stock_class.FLOORS), "by": "docs/COLOR.md 5a, per stock class",
                  "sample": list(SAMPLE)},
        "box": list(box),
        "stock_scale": args.stock_scale,
        "stocks": len(good),
        "mean_std": {k: mean([r for r in good if k in r], k) for k in cols},
        "passes": {k: (sum(r[k]["passes"] for r in good if k in r),
                       sum(r[k]["of"] for r in good if k in r)) for k in cols},
        "bytes": {k: sum(r[k]["bytes"] for r in good) for k in ("today", "bigger")},
        "by_family": {},
        "rows": rows,
    }

    # By family, because the floor is a per-stock question: a writing paper reaches 8.0 and a
    # coated one does not at any amplitude that still reads as paper. The median is the statistic
    # the queue item's own readings are quoted in. The combined figure is reported and gates
    # nothing; the verdict below is taken per condition.
    def median_of(rs):
        v = [sm["std"] for r in rs for sm in r["today"]["samples"]]
        return round(float(np.median(v)), 3) if v else None

    def tiled_median(rs):
        v = np.concatenate([r["_tiled"] for r in rs]) if rs else np.array([])
        return round(float(np.median(v)), 3) if v.size else None

    report["verdicts"] = []
    for fam in sorted({family(r["stock"]) for r in good}):
        fr = [r for r in good if family(r["stock"]) == fam]
        report["by_family"][fam] = {
            "sheets": len(fr),
            "median_std": median_of(fr),
            "mean_std": round(float(np.mean([sm["std"] for r in fr
                                             for sm in r["today"]["samples"]])), 3),
            "passes": sum(r["today"]["passes"] for r in fr),
            "of": sum(r["today"]["of"] for r in fr),
            "by_condition": {},
        }
        readings = {}
        for cond in stock_class.CONDITIONS:
            cr = [r for r in fr if condition(r["stock"]) == cond]
            if cr:
                # The verdict is the tiled median. The eight-window figure beside it is kept so a
                # reading can be compared with one quoted before firing 49, and gates nothing.
                readings[cond] = tiled_median(cr)
                report["by_family"][fam]["by_condition"][cond] = {
                    "sheets": len(cr), "median_std": readings[cond],
                    "median_std_8_windows": median_of(cr),
                    "passes": sum(r["today"]["passes"] for r in cr),
                    "of": sum(r["today"]["of"] for r in cr)}
        report["verdicts"].append(stock_class.verdict(fam, readings))
    report["failing"] = [v["stock"] for v in report["verdicts"] if not v["ok"]]
    for r in rows:
        r.pop("_tiled", None)

    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w") as fh:
            json.dump(report, fh, indent=1)

    w = sys.stdout.write
    w("floor: per docs/COLOR.md 5a -- %s -- on a %dx%d sample of the artifact\n"
      % (", ".join("%s %.1f" % kv for kv in stock_class.FLOORS.items()), SAMPLE[0], SAMPLE[1]))
    w("drawn at cover x %.2f, the Transform.scale PaperPiece puts around the image\n"
      % args.stock_scale)
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
    w("\nthe 5a verdict, packed %d: a stock passes only when day AND dusk clear its class floor,\n"
      "on the median of every %dx%d window tiled across the drawn box at a stride of %d\n"
      % (args.packed_at, SAMPLE[0], SAMPLE[1], stock_class.STRIDE))
    for v in report["verdicts"]:
        c = v["conditions"]
        w("%s %-14s %-8s %4s  day %-8s dusk %-8s %s\n" % (
            "ok" if v["ok"] else "--", v["stock"], v["class"] or "?",
            "%.1f" % v["floor"] if v["floor"] is not None else "-",
            "%.3f" % c["day"]["median_std"] if c.get("day") else "-",
            "%.3f" % c["dusk"]["median_std"] if c.get("dusk") else "-",
            "; ".join(v["why"])))
    w("%d of %d stocks fail\n" % (len(report["failing"]), len(report["verdicts"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
