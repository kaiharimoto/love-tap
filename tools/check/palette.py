#!/usr/bin/env python3
"""What colour this build actually is, as numbers rather than as an opinion.

    python3 tools/check/palette.py
    python3 tools/check/palette.py --out evidence/palette.json

`DIRECTION.md` writes the palette down in prose and `app/lib/material/palette.dart` writes it down
in constants, and neither of them is evidence: the app is a composite of renders, alpha overlays
and photographs, and what reaches the glass is not the swatch that was declared. A sticky note at
40% over aged stock is a colour nobody wrote down. So this reads the captured artifacts and reports
the palette that is really there.

It reports in OKLab, not in RGB or HSV. Both of those lie about lightness — #F3E08A and #3A3A3C
differ by far more perceived lightness than their HSV values suggest, and a palette judged in HSV
drifts dark without anyone noticing. OKLab's L is close to what the eye calls lightness and its
chroma is close to what the eye calls colourfulness, which makes "is there a value structure" and
"has this gone grey" answerable.

The four things it measures, and why each one is here:

  value structure   the spread of L, and whether the image separates into ground, mid and figure
                    at all. A build where everything sits in one L band is a build where nothing
                    reads, which is the legibility failure seen from the other side.
  hue families      how many distinct hues carry any real area, and how far apart they sit. The
                    stationery palette is one warm cluster by construction, so the number is
                    expected to be small; what matters is that it is stated rather than assumed.
  chroma            mean and ceiling. This is the charm axis with a number on it: a build that has
                    drifted to brown and grey has a low mean chroma and says so, and a build that
                    has gone neon has a ceiling that breaks the cap. `DIRECTION.md`'s "nothing
                    emits light" survives as a chroma ceiling instead of as a rule about gradients.
  drift             the same semantic surface, artifact to artifact. If the desk is one colour in
                    01 and another in 04, something is rendering against a stale plate.

`docs/COLOR.md` now declares the floors this file spent a cycle waiting for, so `--floors` reads
them and exits non-zero on a breach. Without `--floors` the tool reports and exits 0, which is the
right default for something that runs inside `capture.sh`: a capture should record what the build
is, not refuse to finish because the build is not finished.

Every number `--floors` enforces is quoted from `docs/COLOR.md` with its section beside it, in
`FLOORS` below. None of them is invented here. If a floor and the law disagree, the law is right and
this file has a bug.
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

SAMPLE = 700          # the long edge everything is read at; the palette does not need full res
HUE_BINS = 36         # ten degrees apiece
HUE_FLOOR = 0.012     # a hue carrying less area than this is a speck, not a family
CHROMA_MIN = 0.004    # below this it is grey and its hue is meaningless
ACCENT_C = 0.09       # docs/COLOR.md section 7: at or above this a pixel is genuinely coloured

CLASSES = os.path.join(ROOT, "docs", "screen_classes.json")

# docs/COLOR.md section 4, the four families and the bands they own. B wraps through zero, which is
# why these are pairs to be tested rather than a range to be compared.
HUE_FAMILIES = {
    "A_paper": (55.0, 105.0),
    "B_rose": (345.0, 35.0),
    "C_cool": (215.0, 275.0),
    "D_green": (120.0, 165.0),
}


def to_oklab(rgb):
    """sRGB 0..255 -> OKLab. Bjorn Ottosson's matrices, written out rather than imported."""
    c = rgb.astype(np.float64) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    ], axis=-1)


def read(path):
    with Image.open(path) as im:
        im = im.convert("RGB")
        w, h = im.size
        k = SAMPLE / float(max(w, h))
        if k < 1:
            im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.BILINEAR)
        return np.asarray(im)


def widest_gap(centres):
    """The largest arc of the wheel carrying no family, for a sorted list of centres."""
    if len(centres) < 2:
        return 0.0
    gaps = [centres[i + 1] - centres[i] for i in range(len(centres) - 1)]
    gaps.append(360 - centres[-1] + centres[0])
    return round(float(max(gaps)), 1)


def in_band(Hdeg, lo, hi):
    """Boolean mask for a hue band, handling the one that wraps through zero."""
    return (Hdeg >= lo) | (Hdeg < hi) if lo > hi else (Hdeg >= lo) & (Hdeg < hi)


def degree_in_band(deg, lo, hi):
    return (deg >= lo or deg < hi) if lo > hi else (lo <= deg < hi)


def named_families(centres):
    """Which of the four families in docs/COLOR.md section 4 carry area.

    This is not `len(centres)`. A "family" in the histogram above is a ten-degree bin, so a build
    living entirely inside family A reports six of them and would satisfy a four-family floor while
    being exactly the monochrome the floor exists to catch — measured: the union of the committed
    set is bins 55 through 105, all six inside family A, at a gap of 310 degrees. The floor is over
    the four named families, and the bin count stays reported beside it.
    """
    return [n for n, (lo, hi) in HUE_FAMILIES.items()
            if any(degree_in_band(c, lo, hi) for c in centres)]


def describe(rgb):
    lab = to_oklab(rgb)
    L = lab[..., 0].ravel()
    a, b = lab[..., 1].ravel(), lab[..., 2].ravel()
    C = np.hypot(a, b)
    Hdeg = (np.degrees(np.arctan2(b, a)) + 360.0) % 360.0

    # value structure: how much of the image sits in each third of the L range in use
    lo, hi = float(np.percentile(L, 2)), float(np.percentile(L, 98))
    span = max(hi - lo, 1e-6)
    t = (L - lo) / span
    bands = {
        "ground": round(float((t < 0.334).mean()), 4),
        "mid": round(float(((t >= 0.334) & (t < 0.667)).mean()), 4),
        "figure": round(float((t >= 0.667).mean()), 4),
    }

    coloured = C > CHROMA_MIN
    hist = np.zeros(HUE_BINS)
    if coloured.any():
        idx = (Hdeg[coloured] / (360.0 / HUE_BINS)).astype(int) % HUE_BINS
        w = C[coloured]
        np.add.at(hist, idx, w)
        hist = hist / max(hist.sum(), 1e-9)
    families = [i for i in range(HUE_BINS) if hist[i] >= HUE_FLOOR]
    centres = [round(i * (360.0 / HUE_BINS) + (360.0 / HUE_BINS) / 2, 1) for i in families]
    spread = widest_gap(centres)

    # section 7 item 5: presence rather than average. A wash warms the mean and moves nothing here.
    accent = C >= ACCENT_C
    by_family = {}
    claimed = np.zeros_like(accent)
    for name, (lo, hi) in HUE_FAMILIES.items():
        sel = accent & in_band(Hdeg, lo, hi)
        claimed |= sel
        by_family[name] = round(float(sel.mean()), 5)
    by_family["outside_any_family"] = round(float((accent & ~claimed).mean()), 5)

    # chroma per value band, because a cap that ignores lightness bans a pale wash and permits
    # a dark one, and the eye does the opposite
    per_band = {}
    for name, sel in (("ground", t < 0.334), ("mid", (t >= 0.334) & (t < 0.667)),
                      ("figure", t >= 0.667)):
        if sel.sum() > 50:
            per_band[name] = {"mean_chroma": round(float(C[sel].mean()), 4),
                              "p99_chroma": round(float(np.percentile(C[sel], 99)), 4)}
    return {
        "lightness": {"p2": round(lo, 4), "p50": round(float(np.median(L)), 4),
                      "p98": round(hi, 4), "span": round(span, 4)},
        "value_bands": bands,
        "chroma": {"mean": round(float(C.mean()), 4),
                   "p99": round(float(np.percentile(C, 99)), 4),
                   "grey_fraction": round(float((C <= CHROMA_MIN).mean()), 4),
                   "accent_fraction": round(float(accent.mean()), 5),
                   "accent_fraction_by_family": by_family},
        "chroma_by_band": per_band,
        "hue_families": len(families),
        "hue_centres_deg": centres,
        "widest_hue_gap_deg": spread,
    }


# --------------------------------------------------------------------------------------------
# The floors. Every one of these is quoted from docs/COLOR.md; the section is carried beside it so
# that a breach names the law it breaches rather than a number in a Python file. `scope` is which
# screens it applies to: "every" is every artifact read, "room" skips the viewer class.

PER_STILL = [
    # (scope, dotted path, comparison, floor, section)
    ("room",  "lightness.p50",                      ">=", 0.78,  "3"),
    ("room",  "lightness.p50",                      "<=", 0.95,  "3"),
    ("room",  "value_bands.ground",                 "<=", 0.50,  "2"),
    ("room",  "value_bands.mid",                    ">=", 0.04,  "2"),
    ("room",  "value_bands.mid",                    "<=", 0.25,  "2"),
    ("every", "hue_families",                       ">=", 3,     "4"),
    ("every", "widest_hue_gap_deg",                 "<=", 200.0, "4"),
    ("every", "chroma_by_band.figure.p99_chroma",   "<=", 0.16,  "5 ceiling"),
    ("every", "chroma_by_band.mid.p99_chroma",      "<=", 0.13,  "5 ceiling"),
    ("every", "chroma_by_band.ground.p99_chroma",   "<=", 0.09,  "5 ceiling"),
    ("every", "chroma_by_band.ground.mean_chroma",  ">=", 0.030, "5 floor"),
    ("every", "chroma_by_band.mid.mean_chroma",     ">=", 0.030, "5 floor"),
    ("every", "chroma_by_band.figure.mean_chroma",  ">=", 0.035, "5 floor"),
    ("every", "chroma_by_band.figure.p99_chroma",   ">=", 0.10,  "5 floor / 7 item 2"),
    ("every", "chroma.grey_fraction",               "<=", 0.08,  "5 floor"),
    ("room",  "chroma.accent_fraction",             ">=", 0.010, "7 item 5"),
]

ACROSS = [
    ("across_the_set.mean_chroma",          ">=", 0.045, "5 floor / 7 item 1"),
    ("across_the_set.lightness_drift_room", "<=", 0.20,  "3"),
    ("across_the_set.widest_hue_gap_deg",   "<=", 150.0, "4 / 7 item 4"),
    ("across_the_set.named_families",       ">=", 4,     "4 / 7 item 4"),
    ("across_the_set.viewers",              "<=", 1,     "3"),
]

FLOORS = {"per_still": PER_STILL, "across_the_set": ACROSS}


def dig(d, path):
    """Follow a dotted path, returning None where the report does not carry the quantity."""
    for key in path.split("."):
        if not isinstance(d, dict) or key not in d:
            return None
        d = d[key]
    return d


def holds(actual, op, floor):
    return actual >= floor if op == ">=" else actual <= floor


def check_floors(report, classes):
    """Every breach of docs/COLOR.md that the numbers in `report` can see."""
    breaches = []
    for name in sorted(report["artifacts"]):
        art = report["artifacts"][name]
        klass = classes.get(name, "room")
        for scope, path, op, floor, section in PER_STILL:
            if scope == "room" and klass != "room":
                continue
            actual = dig(art, path)
            if actual is None:
                breaches.append({"artifact": name, "class": klass, "quantity": path,
                                 "requires": f"{op} {floor}", "actual": None,
                                 "section": section,
                                 "why": "the report does not carry this quantity; the band is "
                                        "empty or the artifact is unreadable"})
            elif not holds(actual, op, floor):
                breaches.append({"artifact": name, "class": klass, "quantity": path,
                                 "requires": f"{op} {floor}", "actual": actual,
                                 "section": section})
    for path, op, floor, section in ACROSS:
        actual = dig(report, path)
        if actual is None or not holds(actual, op, floor):
            breaches.append({"artifact": "<the set>", "class": "-", "quantity": path,
                             "requires": f"{op} {floor}", "actual": actual, "section": section})
    return breaches


def load_classes(path):
    """The room/viewer map from docs/COLOR.md section 3. Anything unlisted is a room, because room
    is the strict class and a screen should have to argue for the exemption."""
    if not path:
        return {}
    if not os.path.exists(path):
        print(f"palette: no class map at {path}; every screen scored as a room", file=sys.stderr)
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f).get("classes", {})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--dir", default=EVIDENCE)
    ap.add_argument("--only", default="")
    ap.add_argument("--classes", default=CLASSES,
                    help="room/viewer map (docs/screen_classes.json); pass '' to score every "
                         "screen as a room")
    ap.add_argument("--floors", action="store_true",
                    help="enforce the floors in docs/COLOR.md and exit non-zero on a breach")
    args = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(args.dir, "*.png")))
    if args.only:
        paths = [p for p in paths if os.path.basename(p) == args.only]
    if not paths:
        print(f"palette: no PNGs in {args.dir}", file=sys.stderr)
        return 2

    classes = load_classes(args.classes)
    report = {"space": "OKLab", "sampled_long_edge": SAMPLE, "artifacts": {}}
    for p in paths:
        report["artifacts"][os.path.basename(p)] = describe(read(p))

    every = list(report["artifacts"].values())
    rooms = [a for n, a in report["artifacts"].items() if classes.get(n, "room") == "room"]
    viewers = [n for n in report["artifacts"] if classes.get(n, "room") == "viewer"]

    # The families are unioned before the gap is taken. Per artifact the gap answers "is this
    # screen monochrome"; over the union it answers "is the palette monochrome", and a build can
    # pass the first nine times and fail the tenth by putting the same wedge on every screen.
    union = sorted({c for a in every for c in a["hue_centres_deg"]})

    report["across_the_set"] = {
        "mean_chroma": round(float(np.mean([a["chroma"]["mean"] for a in every])), 4),
        "mean_lightness_span": round(float(np.mean([a["lightness"]["span"] for a in every])), 4),
        "hue_families_min": int(min(a["hue_families"] for a in every)),
        "hue_families_max": int(max(a["hue_families"] for a in every)),
        "hue_families": len(union),
        "hue_centres_deg": union,
        "widest_hue_gap_deg": widest_gap(union),
        "named_families": len(named_families(union)),
        "named_families_present": named_families(union),
        "grey_fraction": round(float(np.mean([a["chroma"]["grey_fraction"] for a in every])), 4),
        "accent_fraction": round(float(np.mean([a["chroma"]["accent_fraction"] for a in every])), 5),
        "lightness_drift": round(
            float(max(a["lightness"]["p50"] for a in every)
                  - min(a["lightness"]["p50"] for a in every)), 4),
        "lightness_drift_room": round(
            float(max(a["lightness"]["p50"] for a in rooms)
                  - min(a["lightness"]["p50"] for a in rooms)), 4) if rooms else None,
        "rooms": len(rooms),
        "viewers": len(viewers),
    }
    report["read"] = len(paths)

    breaches = check_floors(report, classes) if args.floors else None
    if breaches is not None:
        report["floors"] = {
            "law": "docs/COLOR.md",
            "classes_from": args.classes or "(none; every screen scored as a room)",
            "breaches": len(breaches),
            "breached": breaches,
        }

    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        s = report["across_the_set"]
        print(f"{report['read']} artifacts read -> {args.out}")
        print(f"  mean chroma {s['mean_chroma']}  ·  grey {s['grey_fraction']:.0%}  ·  "
              f"hue families {s['hue_families_min']}-{s['hue_families_max']}  ·  "
              f"lightness drift {s['lightness_drift']}")
    elif not args.floors:
        print(text)

    if breaches is None:
        return 0

    if not breaches:
        print(f"palette: {report['read']} artifacts, every floor in docs/COLOR.md met")
        return 0
    print(f"palette: {len(breaches)} breaches of docs/COLOR.md across "
          f"{report['read']} artifacts", file=sys.stderr)
    for b in breaches:
        print(f"  §{b['section']:<18} {b['artifact']:<24} {b['quantity']} "
              f"= {b['actual']}, requires {b['requires']}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
