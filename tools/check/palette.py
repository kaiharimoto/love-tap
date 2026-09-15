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

Nothing here has a pass/fail floor until `docs/COLOR.md` declares one. Until then this reports and
exits 0: a measurement with no target is still worth having, and inventing a target here rather
than in the design law would put the number in two places.
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
    if len(centres) >= 2:
        gaps = [(centres[i + 1] - centres[i]) for i in range(len(centres) - 1)]
        gaps.append(360 - centres[-1] + centres[0])
        spread = round(float(max(gaps)), 1)
    else:
        spread = 0.0

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
                   "grey_fraction": round(float((C <= CHROMA_MIN).mean()), 4)},
        "chroma_by_band": per_band,
        "hue_families": len(families),
        "hue_centres_deg": centres,
        "widest_hue_gap_deg": spread,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--dir", default=EVIDENCE)
    ap.add_argument("--only", default="")
    args = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(args.dir, "*.png")))
    if args.only:
        paths = [p for p in paths if os.path.basename(p) == args.only]
    if not paths:
        print(f"palette: no PNGs in {args.dir}", file=sys.stderr)
        return 2

    report = {"space": "OKLab", "sampled_long_edge": SAMPLE, "artifacts": {}}
    for p in paths:
        report["artifacts"][os.path.basename(p)] = describe(read(p))

    every = list(report["artifacts"].values())
    report["across_the_set"] = {
        "mean_chroma": round(float(np.mean([a["chroma"]["mean"] for a in every])), 4),
        "mean_lightness_span": round(float(np.mean([a["lightness"]["span"] for a in every])), 4),
        "hue_families_min": int(min(a["hue_families"] for a in every)),
        "hue_families_max": int(max(a["hue_families"] for a in every)),
        "grey_fraction": round(float(np.mean([a["chroma"]["grey_fraction"] for a in every])), 4),
        "lightness_drift": round(
            float(max(a["lightness"]["p50"] for a in every)
                  - min(a["lightness"]["p50"] for a in every)), 4),
    }
    report["read"] = len(paths)

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
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
