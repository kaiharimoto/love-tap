#!/usr/bin/env python3
"""Does the printed-rule ruler tell a known darker ground from a known lighter one?

    python3 tools/check/dusk_ground_selftest.py

`loop/WORKER_PROMPT.md` §3e: *"Every new ruler earns its place by being run against a defect that
is known to be present and a repair that is known to have landed, and printing them in the right
order."* `printed_rules` in `tools/check/dusk_ground.py` is a new ruler -- it claims to find the
line a word is written on and to say how dark it is -- so it answers that question here, before
`docs/COLOR.md` §2 or `app/lib/material/palette.dart` cites a number it produced.

There is no before-and-after repair to point at, because nothing has been repaired: what this
ruler measures is a property of renders that have not moved. So the known pair is a physical one
of the same shape, and it is stronger than a one-off because the library supplies twenty of it.

  lighter  every stock's rules as rendered BY DAY
  darker   the same stock's rules rendered AT DUSK, under a lamp at -3 stops

A ruler that reports a dusk rule at or above its own day twin has not found the rule; it has found
the sheet, or a crop edge, or its own detrending. Twenty-one pairs, and one inversion fails this.

Three further assertions, and the second is the one the whole firing rests on:

  2. THE DARKEST RULE IS DARKER THAN THE LAW'S PREMISE. `docs/COLOR.md` §2 derives the ink ceiling
     from `sticky_pink_02_dusk`'s Y p50 of 0.4506. If the darkest printed rule were lighter than
     that, this measurement would be redundant and the law would already cover it. It is not: the
     rule is the darker ground and the premise does not reach it.
  3. THE RULE IS DARKER THAN ITS OWN SHEET, on every stock, by a margin wider than the tooth.
     This is what separates "found a printed line" from "found a dark patch of paper".
  4. THE RED MARGIN RULE IS DARKER STILL, and is found only on stocks that have one -- legal,
     lined and spiral carry it; looseleaf, graph and the stickies do not. A ruler that reports a
     margin on looseleaf is reading grain, and the capture says so independently: of the 24 runs
     below floor in `crops/dusk_pulse.png`, the six worst all cross a margin rule and every one of
     them is on legal, while the nine on looseleaf sit at the horizontal rule and no lower.

Exits 0 when the ruler discriminates, 1 when it does not.
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dusk_ground import (  # noqa: E402
    LAW_PREMISE_IS, PAPER, measure, printed_rules)

# The premise `docs/COLOR.md` §2 currently derives the ink ceiling from: the darkest stock's
# median pixel. Named rather than recomputed so that assertion 2 is against the law as written.
PREMISE_STOCK = "sticky_pink_02_dusk"
# Stocks whose rendered stock carries a red vertical margin rule, and stocks that do not. From
# `blender/paper/stocks.py` and visible in `evidence/crops/dusk_pulse.png`.
HAS_MARGIN = ("legal", "lined", "spiral")
NO_MARGIN = ("looseleaf", "graph", "sticky", "index", "receipt")
# The tooth's own swing, measured at firing 47 over text-band windows: a rule has to be further
# below its sheet than this or it is paper.
TOOTH = 0.05


def main():
    failures = []

    rules = {}
    sheets = {}
    for f in sorted(glob.glob(os.path.join(PAPER, "*.webp"))):
        name = os.path.splitext(os.path.basename(f))[0]
        r = printed_rules(f)
        if "horizontal" in r or "margin" in r:
            rules[name] = r
            sheets[name] = measure(f)["p50"]

    if not rules:
        print("the ruler found no printed rule on any stock at all", file=sys.stderr)
        return 1

    # 1 -- day above dusk, on every pair the library supplies.
    pairs = 0
    print(f"{'stock':22}{'day rule':>10}{'dusk rule':>11}   day above dusk?")
    for name in sorted(rules):
        if name.endswith("_dusk"):
            continue
        twin = f"{name}_dusk"
        if twin not in rules:
            continue
        d = rules[name].get("horizontal")
        n = rules[twin].get("horizontal")
        if d is None or n is None:
            failures.append(f"{name}: a horizontal ruling on one of the pair and not the other")
            continue
        pairs += 1
        ok = d["y"] > n["y"]
        print(f"{name:22}{d['y']:10.4f}{n['y']:11.4f}   {'yes' if ok else 'NO'}")
        if not ok:
            failures.append(
                f"{name}: the dusk rule reads {n['y']} against a day rule of {d['y']}. A lamp at "
                f"-3 stops cannot make a printed line lighter, so this is not a rule")
    if pairs < 10:
        failures.append(f"only {pairs} day/dusk pairs carried a ruling; the ruler is not reading "
                        "the library it claims to")
    print(f"\n{pairs} day/dusk pairs, all in the right order" if not failures else "")

    # 2 -- the darkest rule is darker than the law's premise.
    ruled_dusk = {k: v["horizontal"]["y"] for k, v in rules.items()
                  if k.endswith("_dusk") and "horizontal" in v}
    worst = min(ruled_dusk, key=lambda k: ruled_dusk[k])
    premise = sheets.get(PREMISE_STOCK) or measure(
        os.path.join(PAPER, f"{PREMISE_STOCK}.webp"))["p50"]
    print(f"darkest printed rule at dusk: {worst} at {ruled_dusk[worst]:.4f}")
    print(f"the law's premise:            {PREMISE_STOCK} p50 {premise:.4f} "
          f"(and {LAW_PREMISE_IS} is what §2's older number really was)")
    if ruled_dusk[worst] >= premise:
        failures.append(
            f"the darkest printed rule ({ruled_dusk[worst]}) is not darker than the premise "
            f"({premise}), so this measurement adds nothing to the law and the ink ceiling it "
            "supports should be withdrawn rather than rewritten")

    # 3 -- a rule is darker than its own sheet by more than the tooth.
    for name, y in sorted(ruled_dusk.items()):
        gap = sheets[name] - y
        if gap <= TOOTH:
            failures.append(f"{name}: its rule is only {gap:.4f} below its own sheet median, "
                            f"which is inside the tooth -- that is paper, not a printed line")

    # 4 -- the margin rule is found where the stock has one and nowhere else.
    for name, r in sorted(rules.items()):
        if not name.endswith("_dusk"):
            continue
        has = "margin" in r
        should = name.startswith(HAS_MARGIN)
        if should and not has:
            failures.append(f"{name} carries a red margin rule and the ruler did not find it")
        if not should and has and name.startswith(NO_MARGIN):
            failures.append(f"{name} has no margin rule and the ruler reported one at "
                            f"{r['margin']['y']} -- it is reading grain")
        if has and "horizontal" in r and r["margin"]["y"] >= r["horizontal"]["y"]:
            failures.append(f"{name}: the margin rule reads {r['margin']['y']} against a "
                            f"horizontal rule of {r['horizontal']['y']}; the margin is the darker "
                            "of the two on every stock that has both")

    print()
    if failures:
        print(f"{len(failures)} failure(s):", file=sys.stderr)
        for line in failures:
            print("  " + line, file=sys.stderr)
        return 1
    margins = {k: v["margin"]["y"] for k, v in rules.items()
               if k.endswith("_dusk") and "margin" in v}
    mworst = min(margins, key=lambda k: margins[k])
    print(f"the ruler discriminates: margin {margins[mworst]:.4f} ({mworst}) "
          f"< rule {ruled_dusk[worst]:.4f} ({worst}) < premise {premise:.4f} ({PREMISE_STOCK})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
