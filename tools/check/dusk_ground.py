#!/usr/bin/env python3
"""The darkest ground a word can land on, measured from the stocks that actually ship.

    python3 tools/check/dusk_ground.py
    python3 tools/check/dusk_ground.py --out evidence/dusk_ground.json

WHY THIS EXISTS. `docs/COLOR.md` §2 derives the ink ceiling of the whole palette from one number:

    "The darkest ground a word can legitimately land on is aged stock rendered at dusk, which
     measures Y p50 0.5528 in crops/dusk_pulse.png."

Two things were wrong with that sentence, both measured at firing 36 and both confirmed
independently at firing 38 from the committed library.

  * THERE IS NO `aged` RENDER. `assets/paper` holds graph, index, legal, lined, looseleaf,
    receipt, spiral and three stickies, in day and dusk, and no `aged_*.webp` in any light.
    `Paper.aged` does exist -- as a flat swatch in `app/lib/material/palette.dart` -- which is
    how the name survived four cycles: the law cites a colour the app declares and never draws.

  * 0.5528 IS NOT THE DARKEST STOCK, IT IS A MIDDLING ONE. It is `index_02_dusk`, which this tool
    measures at 0.5530. The written stocks sit at 0.5450-0.5627 and that is the band the number
    came out of. The darkest dusk render that ships is `sticky_pink_02_dusk` at 0.4506, a tenth
    of a unit of luminance below the premise -- and the app treats a sticky as a valid ground for
    a word, which `app/test/legible_on_what_it_is_on_test.dart` has always asserted by sweeping
    every ink against `Paper.stickyPink`.

So the derivation was taking its "darkest ground" from a stock that is neither the darkest nor on
disk, and the ink it produced cleared the dusk body floor against the premise and missed it
against the library: `#464648` is 5.406:1 on 0.5528 and 4.490:1 on 0.4506, under a floor of 5.0.

WHAT THIS TOOL IS FOR. It puts the number in one place, measured rather than quoted, so the law
and the test cannot drift apart. `app/test/legible_on_what_it_is_on_test.dart` reads its output
and asserts the achromatic inks against the darkest dusk ground it names. The p50 is the median
over every pixel of the render -- the same statistic §2 quotes, so the two are comparable.

IT MEASURES THE LIBRARY, NOT A CAPTURE. §2's number came from `crops/dusk_pulse.png`, a capture
artifact, which is why nobody could check it against a file. These are the stocks themselves, read
by asset path, and the reading needs no capture and no rig.
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PAPER = os.path.join(ROOT, "assets", "paper")

# The figure §2 quotes, and the stock this tool says it really came from. Held here so that a
# re-render which moves that stock is visible as a change to the law's own premise rather than as
# a number quietly ceasing to match anything.
LAW_PREMISE = 0.5528
LAW_PREMISE_IS = "index_02_dusk"

# docs/COLOR.md §6. Held here because every number this tool derives is against it.
DUSK_BODY_FLOOR = 5.0


def luminance(arr):
    """Relative luminance, WCAG's definition, which is what every floor in this build is in."""
    import numpy as np

    a = arr / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def measure(path):
    import numpy as np
    from PIL import Image

    arr = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64)
    y = luminance(arr)
    return {
        "p2": round(float(np.percentile(y, 2)), 4),
        "p50": round(float(np.percentile(y, 50)), 4),
        "p98": round(float(np.percentile(y, 98)), 4),
    }


# ---------------------------------------------------------------------------
# THE PART THE p50 CANNOT SEE, ADDED AT FIRING 47.
#
# A p50 is the median pixel of a sheet, and a word does not land on the median pixel of a sheet.
# Every written stock in this library is PRINTED: a horizontal ruling a line of writing sits on,
# and, on legal, lined and spiral, a red vertical margin rule. Both are darker than the paper
# either side of them, and `tools/check/legibility.py` takes a run's ground over the band hugging
# its letters -- which on these stocks is as tall as the rule pitch, so the rule is in it.
#
# Measured at firing 47 on the committed dusk renders: the horizontal rules sit at Y 0.396-0.441
# and the red margin rules at Y 0.224-0.266, against the premise's 0.4506. The law has now been
# derived twice from a statistic that is lighter than the line the words are written on.
#
# Two separate numbers come out of this and they are not interchangeable:
#
#   * THE HORIZONTAL RULE is a ground a word LEGITIMATELY lands on -- that is what ruled paper is
#     for -- so it is what the ink ceiling has to be derived against. `written_ground` below.
#   * THE RED MARGIN RULE is not. At Y 0.2240 the dusk body floor of 5.0:1 would need an ink at
#     Y <= 0.0048, which is very nearly black and outside anything DIRECTION.md's stationery
#     would permit. A word laid ACROSS the margin rule cannot be rescued by any ink; it is a
#     placement defect and it is filed as its own queue item. `margin_rule` below is its number.

# How far below the sheet's own running median a row or column has to sit before it is printed
# rather than paper. The rules are 0.10-0.15 below their surround at dusk; the tooth is ~0.02.
RULE_ROW_DEV = -0.04
RULE_COL_DEV = -0.05
# The red margin rule is red: sRGB (182,121,84) on legal_01_dusk, R - B = 0.38. The spiral binding
# (0.12) and graph's grid (0.12-0.15) are not, and this is what keeps them out of the margin count.
MARGIN_MIN_WARMTH = 0.30
# A printed line is a few pixels thick. Anything thicker is a shadow, a crop edge or a band.
MAX_RULE_PX = 14
MAX_MARGIN_PX = 20
# Below this many lines it is not a ruling, it is a feature.
MIN_RULES = 4


def _erode(mask, k):
    import numpy as np

    m = mask
    for _ in range(k):
        m = (m & np.roll(m, 1, 0) & np.roll(m, -1, 0)
             & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    return m


def _groups(idx, gap, longest):
    out = []
    for i in idx:
        if out and i - out[-1][-1] <= gap:
            out[-1].append(i)
        else:
            out.append([i])
    return [g for g in out if len(g) <= longest]


def _detrend(prof, half):
    import numpy as np

    n = len(prof)
    base = np.full(n, np.nan)
    for i in range(n):
        w = prof[max(0, i - half):i + half]
        w = w[~np.isnan(w)]
        if w.size > 40:
            base[i] = np.median(w)
    return prof - base


def printed_rules(path):
    """The printed rules of one stock: the horizontal ruling and the red margin, in luminance.

    Read down the middle of the sheet, which is what keeps the spiral binding, the punch holes and
    the torn edges out of it -- they are features of the sheet that a word does not land on, and
    a statistic that includes them would derive an ink against a hole.
    """
    import numpy as np
    from PIL import Image

    im = Image.open(path).convert("RGBA")
    a = np.asarray(im, dtype=np.float64) / 255.0
    rgb = a[..., :3]
    y = luminance(np.asarray(im.convert("RGB"), dtype=np.float64))
    opaque = _erode(a[..., 3] > 0.99, 10)
    h, w = y.shape

    out = {}

    x0, x1 = int(w * 0.35), int(w * 0.65)
    rows = np.array([np.median(y[r, x0:x1][opaque[r, x0:x1]])
                     if opaque[r, x0:x1].sum() > 30 else np.nan for r in range(h)])
    dev = _detrend(rows, 90)
    idx = np.where(~np.isnan(dev) & (dev < RULE_ROW_DEV))[0]
    gs = _groups(idx, 2, MAX_RULE_PX)
    if len(gs) >= MIN_RULES:
        cores = np.array([np.nanmin(rows[g]) for g in gs])
        starts = [g[0] for g in gs]
        out["horizontal"] = {
            "n": len(gs),
            "pitch": int(round(float(np.median(np.diff(starts))))) if len(starts) > 1 else None,
            # The median rule's darkest row. The median over rules rather than the darkest rule,
            # because one rule can be crossed by a shadow or a crop edge; the median cannot.
            "y": round(float(np.median(cores)), 4),
            "darkest": round(float(cores.min()), 4),
        }

    y0, y1 = int(h * 0.3), int(h * 0.7)
    cols = np.array([np.median(y[y0:y1, c][opaque[y0:y1, c]])
                     if opaque[y0:y1, c].sum() > 30 else np.nan for c in range(w)])
    dev = _detrend(cols, 90)
    idx = np.where(~np.isnan(dev) & (dev < RULE_COL_DEV))[0]
    best = None
    for g in _groups(idx, 3, MAX_MARGIN_PX):
        c = g[int(np.nanargmin(cols[g]))]
        px = rgb[y0:y1, c][opaque[y0:y1, c]]
        if px.size < 30:
            continue
        warmth = float(px[:, 0].mean() - px[:, 2].mean())
        if warmth < MARGIN_MIN_WARMTH:
            continue
        val = float(np.nanmin(cols[g]))
        if best is None or val < best["y"]:
            best = {"at": [int(g[0]), int(g[-1])], "y": round(val, 4),
                    "warmth": round(warmth, 3)}
    if best is not None:
        out["margin"] = best
    return out


def ink_for(ground, floor):
    """The luminance an ink must be at or below to clear `floor` against `ground`."""
    return round((ground + 0.05) / floor - 0.05, 4)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="write the report here as JSON")
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(PAPER, "*.webp")))
    if not files:
        print(f"no paper stocks under {PAPER}", file=sys.stderr)
        return 2

    stocks = {}
    printed = {}
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        stocks[name] = measure(f)
        r = printed_rules(f)
        if r:
            printed[name] = r

    dusk = {k: v for k, v in stocks.items() if k.endswith("_dusk")}
    day = {k: v for k, v in stocks.items() if not k.endswith("_dusk")}
    if not dusk:
        print("no dusk renders found", file=sys.stderr)
        return 2

    darkest = min(dusk, key=lambda k: dusk[k]["p50"])

    # THE NUMBER THE INK IS DERIVED FROM. The darkest horizontal rule on any dusk stock: the line
    # a word is written on, on the stock where that line is darkest. Read off the renders, so it
    # needs no capture and cannot be quoted out of a screenshot the way the premise it replaces
    # was.
    ruled = {k: v["horizontal"] for k, v in printed.items()
             if k.endswith("_dusk") and "horizontal" in v}
    if not ruled:
        print("no printed rules found on any dusk render", file=sys.stderr)
        return 2
    worst = min(ruled, key=lambda k: ruled[k]["y"])
    written = {
        "what": "the printed horizontal rule of a written stock at dusk -- the line a word is "
                "written ON, which is the ground the band hugging its letters is taken over",
        "stock": worst,
        "y": ruled[worst]["y"],
        "counted": len(ruled),
        "ink_at_or_below": ink_for(ruled[worst]["y"], DUSK_BODY_FLOOR),
        "lighter_than_law_premise_by": round(LAW_PREMISE - ruled[worst]["y"], 4),
        "rules": {k: ruled[k]["y"] for k in sorted(ruled, key=lambda k: ruled[k]["y"])},
    }

    # THE NUMBER NO INK CAN ANSWER. The red vertical margin rule, which a word is written BESIDE
    # and not across. Reported so that the placement defect has a figure of its own rather than
    # being averaged into the one above.
    margins = {k: v["margin"] for k, v in printed.items()
               if k.endswith("_dusk") and "margin" in v}
    margin = None
    if margins:
        mworst = min(margins, key=lambda k: margins[k]["y"])
        margin = {
            "what": "the red vertical margin rule, which a word is written BESIDE. A run laid "
                    "across it is a placement defect and no ink in the ladder answers it",
            "stock": mworst,
            "y": margins[mworst]["y"],
            "counted": len(margins),
            "ink_at_or_below": ink_for(margins[mworst]["y"], DUSK_BODY_FLOOR),
            "rules": {k: margins[k]["y"] for k in sorted(margins, key=lambda k: margins[k]["y"])},
        }
    report = {
        "of": "assets/paper",
        "counted": {"day": len(day), "dusk": len(dusk)},
        "darkest_dusk": {"stock": darkest, "p50": dusk[darkest]["p50"]},
        "darkest_day": {
            "stock": min(day, key=lambda k: day[k]["p50"]),
            "p50": day[min(day, key=lambda k: day[k]["p50"])]["p50"],
        } if day else None,
        # What §2 says, beside what this tool finds at that number, so the correction is legible
        # from the file rather than only from the commit that made it.
        "law_premise": {
            "quoted_in": "docs/COLOR.md §2",
            "p50": LAW_PREMISE,
            "attributed_to": "aged stock rendered at dusk",
            "no_such_render": not any(k.startswith("aged") for k in stocks),
            "actually_matches": LAW_PREMISE_IS,
            "actually_matches_p50": dusk.get(LAW_PREMISE_IS, {}).get("p50"),
            "darker_stocks_shipping": sorted(
                k for k, v in dusk.items() if v["p50"] < LAW_PREMISE),
        },
        "written_ground": written,
        "margin_rule": margin,
        "printed": printed,
        "stocks": stocks,
    }

    order = sorted(dusk, key=lambda k: dusk[k]["p50"])
    print(f"{'Y p50':>8}  dusk stock ({len(dusk)} renders)")
    for k in order:
        mark = "  <- darkest" if k == darkest else ""
        print(f"{dusk[k]['p50']:8.4f}  {k}{mark}")
    print()
    print(f"§2 quotes {LAW_PREMISE} as 'aged stock rendered at dusk'.")
    print(f"  no aged render exists: {report['law_premise']['no_such_render']}")
    print(f"  the number is {LAW_PREMISE_IS} at {dusk.get(LAW_PREMISE_IS, {}).get('p50')}")
    print(f"  stocks darker than the premise: {len(report['law_premise']['darker_stocks_shipping'])}")
    print()
    print(f"the darkest LINE A WORD IS WRITTEN ON, over {written['counted']} ruled dusk stocks:")
    print(f"  {written['stock']} at Y {written['y']}, which is {written['lighter_than_law_premise_by']} "
          f"below the premise")
    print(f"  the dusk body floor of {DUSK_BODY_FLOOR}:1 against it needs an ink at Y <= "
          f"{written['ink_at_or_below']}")
    if margin:
        print(f"the darkest RED MARGIN RULE, over {margin['counted']} dusk stocks that carry one:")
        print(f"  {margin['stock']} at Y {margin['y']}; the same floor across it would need an ink "
              f"at Y <= {margin['ink_at_or_below']}, which is very nearly black")

    if args.out:
        out = args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=1)
            f.write("\n")
        print(f"\nwrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
