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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="write the report here as JSON")
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(PAPER, "*.webp")))
    if not files:
        print(f"no paper stocks under {PAPER}", file=sys.stderr)
        return 2

    stocks = {}
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        stocks[name] = measure(f)

    dusk = {k: v for k, v in stocks.items() if k.endswith("_dusk")}
    day = {k: v for k, v in stocks.items() if not k.endswith("_dusk")}
    if not dusk:
        print("no dusk renders found", file=sys.stderr)
        return 2

    darkest = min(dusk, key=lambda k: dusk[k]["p50"])
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
