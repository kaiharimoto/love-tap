#!/usr/bin/env python3
"""Does the §5a ruler tell a known defect from a known repair, and in the right order?

    python3 tools/check/stock_class_selftest.py

`loop/WORKER_PROMPT.md` §3d: *"a ruler that scores the defect above the repair is disqualified, not
merely suspect... Every new ruler earns its place by being run against a defect that is known to be
present and a repair that is known to have landed, and printing them in the right order."* That is
what `tools/check/hf_std.py` failed -- it read the firing 17 strip, taken when the fold sheet WAS
the blank rectangle, ABOVE today's repaired sheet -- and it is why `HF_std` is struck from rank 1.
So this ruler is made to answer the same question before anything cites it.

The pair, both committed and both measured:

  defect  assets/folds/unfold_thirds/0000.png -- the flat square-cornered card five of seven
          critics named independently for two cycles running. It is a real render with printed
          rules on it and no tooth, which is what makes it a sharper test than a synthetic fill:
          a ruler fooled by procedural noise alone would pass it.
  repair  assets/paper/lined_*.webp -- the written stocks re-rendered at firing 26 with the
          `albedo_tooth` knob, whose measured day median is the 7.977 that §5a's 8.0 floor is set
          from.

Three assertions, and the first is the one that disqualifies a ruler:

  1. the repair scores strictly above the defect;
  2. the defect fails the written floor and the repair clears it, so the floor sits between them;
  3. excluding the drop shadow matters -- the same frame read with the shadow inside the window
     scores ABOVE the floor, which is the sampling accident this module's `sheet_bounds` exists
     to prevent, and a future edit that reintroduces it will trip here rather than in a capture.

And one consistency check that is not about pixels: `FOLDED_FROM` has to name the stock
`blender/folds/fold.py` actually renders the rules from, or the floor is being read off a stock
the sequence is not folded from.

Exits 0 when the ruler discriminates, 1 when it does not.
"""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stock_class  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFECT = os.path.join(ROOT, "assets", "folds", "unfold_thirds", "0000.png")
REPAIR_GLOB = os.path.join(ROOT, "assets", "paper", "lined_*.webp")


def shipped(path, display_width=1045):
    """The frame as the app ships it: packed to SIZES['folds'], then drawn at the card's width.

    §5a measures a fold frame "at the frame's shipped display size", and 540 -> 1045 is what
    `13_messenger_states.png` actually does to frame 0000 -- the card measures 1045 px across
    there. Reading the source render instead would measure a file the app never draws.
    """
    im = Image.open(path).convert("RGBA")
    scale = 540 / max(im.size)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    im = im.resize((display_width, round(im.height * display_width / im.width)), Image.BILINEAR)
    return np.asarray(im)


def whole_frame_reading(rgba, floor_std):
    """The same ruler with the shadow left in: the sampling accident, kept here to be failed."""
    a = rgba.astype(float)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    solid = a[..., 3] > 200
    lum = np.where(solid, lum, np.nan)
    rows = np.where(solid.any(axis=1))[0]
    cols = np.where(solid.any(axis=0))[0]
    _, placements = stock_class.tiled(
        lum, (int(rows.min()), int(rows.max()) + 1, int(cols.min()), int(cols.max()) + 1))
    if not placements:
        return None
    return float(np.median([p[0] for p in placements]))


def main():
    failures = []

    cls, floor_std = stock_class.floor_for_fold("unfold_thirds")
    if cls is None:
        print("unfold_thirds resolves to no stock class at all", file=sys.stderr)
        return 1
    print(f"unfold_thirds is folded from {stock_class.FOLDED_FROM['unfold_thirds']!r}, "
          f"class {cls!r}, floor L_std {floor_std}")

    # --- the consistency check: the stock this claims, against the one the renderer uses --------
    fold_py = os.path.join(ROOT, "blender", "folds", "fold.py")
    if os.path.exists(fold_py):
        with open(fold_py, encoding="utf-8") as f:
            m = re.search(r'^RULES_STOCK\s*=\s*["\'](\w+)["\']', f.read(), re.M)
        if m:
            renderer = m.group(1)
            claimed = stock_class.FOLDED_FROM["unfold_thirds"]
            mark = "ok" if renderer == claimed else "MISMATCH"
            print(f"  fold.py RULES_STOCK = {renderer!r}, FOLDED_FROM says {claimed!r}  [{mark}]")
            if renderer != claimed:
                failures.append(
                    f"FOLDED_FROM['unfold_thirds'] is {claimed!r} but the renderer uses "
                    f"{renderer!r}: the floor is being read off the wrong stock")
        else:
            print("  fold.py has no RULES_STOCK to compare against", file=sys.stderr)

    # --- the defect ------------------------------------------------------------------------------
    if not os.path.exists(DEFECT):
        print(f"the known defect is missing: {DEFECT}", file=sys.stderr)
        return 1
    defect = stock_class.measure(shipped(DEFECT), floor_std)
    if defect is None:
        print("the known defect read as no sheet at all", file=sys.stderr)
        return 1
    print(f"  defect  unfold_thirds/0000 at shipped size: median L_std {defect['median_std']:7.3f}"
          f"  levels {defect['median_levels']:4d}  pass fraction {defect['pass_fraction']:.3f}")

    # --- the repair ------------------------------------------------------------------------------
    repairs = sorted(glob.glob(REPAIR_GLOB))
    repairs = [p for p in repairs if "_dusk" not in os.path.basename(p)]
    if not repairs:
        print(f"no repaired written stock found at {REPAIR_GLOB}", file=sys.stderr)
        return 1
    readings = []
    for path in repairs:
        im = np.asarray(Image.open(path).convert("RGBA"))
        got = stock_class.measure(im, floor_std)
        if got is not None:
            readings.append((os.path.basename(path), got))
    if not readings:
        print("every repaired stock read as no sheet at all", file=sys.stderr)
        return 1
    for name, got in readings:
        print(f"  repair  {name:<22} median L_std {got['median_std']:7.3f}"
              f"  levels {got['median_levels']:4d}  pass fraction {got['pass_fraction']:.3f}")
    repair_median = float(np.median([g["median_std"] for _, g in readings]))

    # --- assertion 1: the order ------------------------------------------------------------------
    if not repair_median > defect["median_std"]:
        failures.append(
            f"the ruler scores the defect ({defect['median_std']}) at or above the repair "
            f"({repair_median}): disqualified under WORKER_PROMPT 3d")

    # --- assertion 2: the floor sits between them ------------------------------------------------
    if defect["ok"]:
        failures.append(
            f"the known defect PASSES the written floor at {defect['median_std']}: a floor that "
            f"the flat card clears is not a floor")
    # The L_std clause is the one §5a derives from a measurement -- "8.0 is the measured median of
    # the re-rendered written stocks: 7.977 by day" -- so it is the clause this ruler is held to.
    missed_std = [n for n, g in readings if g["median_std"] < floor_std]
    if missed_std:
        failures.append(
            f"repaired written stock misses its own L_std floor: {', '.join(missed_std)}. §5a sets "
            f"8.0 from this class's measured median, so this means the floor or the stocks moved")

    # THE LEVEL CLAUSE IS GONE, AND THIS IS THE READING THAT TOOK IT OUT. §5a said only that "the
    # level counts are the existing 60 scaled by the same steps"; measured, 60 separates nothing,
    # because BOTH sides of a known before-and-after sit below it -- the defect at 42 and the
    # repaired stocks at 57-58. Struck at firing 36 from §5a and from all three tools.
    #
    # THE COUNT IS STILL PRINTED, AND THIS CHECK IS WHAT KEEPS THE STRIKE HONEST RATHER THAN
    # CONVENIENT. A floor removed because it was undefended must not quietly become a floor that
    # would now pass: if the repaired stocks ever reach 60 on their own, the reason this clause was
    # struck has evaporated and a successor should know it, because at that point the number could
    # be defended and the argument for striking it could not. This prints; it does not fail.
    levels = sorted(g["median_levels"] for _, g in readings)
    print(f"  levels, reported and gating nothing: defect {defect['median_levels']}, "
          f"repair {levels[0]}-{levels[-1]}")
    if levels[0] >= 60:
        print("  NOTE: every repaired written stock now reaches 60 levels on its own. The reading "
              "that disqualified the 60-level clause -- that it failed the repair as well as the "
              "defect -- no longer holds, so a posterisation guard could be re-derived. That is "
              "ADDRESS's call; file it rather than reinstating a number here.")

    # --- assertion 3: the shadow is the sampling accident ----------------------------------------
    with_shadow = whole_frame_reading(shipped(DEFECT), floor_std)
    if with_shadow is not None:
        print(f"  same frame WITH the drop shadow in the window: median L_std {with_shadow:7.3f}"
              f"  (floor {floor_std})")
        if with_shadow < floor_std:
            failures.append(
                "the shadow-contaminated reading no longer clears the floor, so assertion 3 is "
                "asserting nothing -- re-derive it rather than deleting it")
        elif with_shadow <= defect["median_std"]:
            failures.append(
                "excluding the drop shadow no longer changes the reading; sheet_bounds may have "
                "stopped excluding it")

    # --- assertion 4: the verdict is per class and per condition --------------------------------
    # The readings are firing 49's, off `tools/paper_tooth.py --all` through the app's own chain.
    # Each case is one thing §5a says and one way of getting it wrong: collapse the classes back
    # to one 8.0 and every coated stock goes red together; combine day and dusk into one figure and
    # looseleaf passes on its dusk twin (7.689 and 8.581 average 8.135); let a half-read library
    # through and an unmeasured condition passes by being absent.
    cases = [
        ("sticky_pink", {"day": 4.206, "dusk": 4.378}, True, "a coated stock clears 4.0"),
        ("receipt", {"day": 1.119, "dusk": 4.412}, False, "the flat receipt fails by day"),
        ("looseleaf", {"day": 7.689, "dusk": 8.581}, False, "a written miss by day is a miss"),
        ("lined", {"day": 8.200, "dusk": 8.653}, True, "a written stock clears 8.0 twice"),
        ("lined", {"day": 8.200}, False, "an unmeasured dusk is not a pass"),
        ("vellum", {"day": 9.0, "dusk": 9.0}, False, "no class, no floor, no pass"),
    ]
    for stock, got, want, why in cases:
        v = stock_class.verdict(stock, got)
        mark = "ok" if v["ok"] == want else "WRONG"
        print(f"  verdict {stock:<12} {str(got):<30} -> {'pass' if v['ok'] else 'fail'}"
              f"  [{mark}] {why}")
        if v["ok"] != want:
            failures.append(f"verdict({stock!r}, {got}) is {v['ok']}, and {why}")

    # And the tools that apply a floor take it from here. A literal left behind in one of them is
    # how a floor drifts: flat_fill.py and paper_tooth.py both carried `FLOOR_STD = 8.0` for
    # seventeen firings after §5a declared three.
    for rel in ("tools/paper_tooth.py", "tools/check/flat_fill.py"):
        with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
            src = f.read()
        if re.search(r"^FLOOR_STD\s*=", src, re.M) or "stock_class" not in src:
            failures.append(f"{rel} carries its own floor instead of reading stock_class.FLOORS")

    print()
    if failures:
        print(f"{len(failures)} failure(s):", file=sys.stderr)
        for line in failures:
            print("  " + line, file=sys.stderr)
        return 1
    print(f"the ruler discriminates: defect {defect['median_std']} < floor {floor_std} "
          f"<= repair {repair_median}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
