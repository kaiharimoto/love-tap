#!/usr/bin/env python3
"""Proof that clipping a run's ground to its own sheet removes the plank, and that it cannot yet
be gated on.

    python3 tools/check/ground_clip_selftest.py

`tools/check/legibility.py` takes a run's ground from a ring around the run, wherever that ring
falls. A line of writing near the edge of its own sheet therefore has DESK in its ring, and
`GROUND_SWING_GATE` then holds ink ON paper against the darkest thing BEHIND the paper. That is
not a hard reading; it is the wrong reading, and unlike a flat-ground failure it is a property of
one run's position rather than of anything a person has to read.

So the ground is also taken a second way: restricted to the sheet the app says it drew under the
run, read out of `<artifact>.surfaces.json`. Sections 1 to 4 are the proof that the restriction
does what it is for -- it must move a KNOWN STRADDLE and leave a KNOWN INTERIOR RUN alone, on the
same page, at the same ink, on the same stock. A clip that moved both equally would be measuring
the clip and not the straddle.

SECTION 5 IS WHY THE FLOORS DO NOT GATE ON IT, and it is the reason this file exists rather than
a line in the queue. A declared `rect` is the box the app laid an image out into, shadow pad and
all -- not the sheet's own outline. The pad is recoverable from `drawn` for some entries and not
for others, so the clipped reading of one region of pixels depends on which artifact declared it.
Section 5 builds that case deliberately: the SAME PIXELS under two different declared rects, and
it requires that `ink_core` -- the number the floors read -- is identical across the pair while
`ink_core_clipped` is not. While that check passes, the clip may be reported and may not be
cited, which is WORKER_PROMPT 3d applied to this ruler rather than an opinion about it.

It is not a picture of love-tap and is not evidence. It is a ruler for the ruler, which is why it
lives in `tools/` and writes to a temporary directory rather than to `evidence/`.
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
LEGIBILITY = os.path.join(HERE, "legibility.py")

W, H = 1080, 2340          # the PWA still's own size, so legibility.py's fraction-of-height
                           # filters mean what they mean on a real capture
PAPER = 0.92               # cream stock
INK = 0.12                 # a hand that clears the body floor easily against its own paper
DESK = 0.35                # the plank. It has to be LIGHTER than the ink and far darker than the
                           # paper, and that is not an arbitrary choice: `on_the_far_side` in
                           # legibility.py keeps the ring reading wherever the adversarial end is
                           # darker than the stroke, on the correct reasoning that a ground behind
                           # the ink is a second surface rather than this ink's ground. A plank
                           # darker than the ink therefore never reaches the gate at all, and a
                           # page built that way proves nothing about the clip. Built that way
                           # first, measured, and corrected: at DESK 0.13 both runs read 7.27:1
                           # and the straddle was invisible.
GRAIN = 0.05               # the plank's grain, wide enough to give the ring a real dark end

GLYPH_W, GLYPH_H, GAP, COUNT = 20, 30, 12, 12
RING = 15                  # max(legibility.RING, GLYPH_H // 2), the ring this run gets

SHEET_X, SHEET_W = 60, 960
SHEET_Y, SHEET_H = 300, 900       # the sheet: y 300..1200
INTERIOR_Y = 640                  # a run in the middle of it, nowhere near an edge
STRADDLE_Y = 1162                 # a run whose ring (to y 1207) reaches over the edge at 1200

INTERIOR_SAYS = "well inside the sheet"
STRADDLE_SAYS = "written near the edge"

STOCK = "assets/paper/lined_01.webp"


def blocks(img, y, x0, value, count=COUNT):
    """A line of glyph-sized marks: 20x30, area 600, which passes every filter in legibility.py."""
    boxes = []
    x = x0
    for _ in range(count):
        img[y:y + GLYPH_H, x:x + GLYPH_W] = value
        boxes.append((x, y, GLYPH_W, GLYPH_H))
        x += GLYPH_W + GAP
    return boxes


def still(path):
    """A plank with one sheet on it, and two lines of the same ink at the same size.

    The only difference between the two is where they sit: one in the middle of the sheet, one
    close enough to its edge that the ring reaches the wood. That is the whole experiment.
    """
    rng = np.random.default_rng(17)
    img = DESK + rng.normal(0.0, GRAIN, size=(H, W))
    img[SHEET_Y:SHEET_Y + SHEET_H, SHEET_X:SHEET_X + SHEET_W] = (
        PAPER + rng.normal(0.0, 0.004, size=(SHEET_H, SHEET_W)))
    interior = blocks(img, INTERIOR_Y, 120, INK)
    straddle = blocks(img, STRADDLE_Y, 120, INK)
    a = np.clip(img, 0.0, 1.0)
    rgb = np.repeat((a * 255.0).round().astype(np.uint8)[:, :, None], 3, axis=2)
    Image.fromarray(rgb, "RGB").save(path)
    return interior, straddle


def text_sidecar(path, name, groups):
    """A `<name>.text.json` in the shape tools/capture/scene.js writes."""
    runs = []
    for boxes, text in groups:
        x0 = min(b[0] for b in boxes)
        y0 = min(b[1] for b in boxes)
        x1 = max(b[0] + b[2] for b in boxes)
        y1 = max(b[1] + b[3] for b in boxes)
        rect = [x0, y0, x1 - x0, y1 - y0]
        runs.append({"rect": rect, "lines": [rect], "points": 13.3, "px": 40.0,
                     "family": "NoorHand", "role": "hand", "ink": "ff1f2a44",
                     "text": text, "chars": len(text)})
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"of": name, "size": [W, H], "dpr": 3, "declared": len(runs),
                   "offscreen": 0, "runs": runs}, f, indent=1)


def surfaces_sidecar(path, rect, asset=STOCK, drawn=None, extra=()):
    """A `<name>.surfaces.json` in the shape the capture writes, desk first and stock over it.

    `drawn` defaults to the rect's own size, which is the case where the app laid the sheet out
    with no pad around it and the declared box IS the sheet.
    """
    x, y, w, h = rect
    layers = [{"asset": "assets/shell/desk.webp", "src": [685, 1500], "drawn": [W, H],
               "scale": 1.0, "fit": "cover", "rect": [0, 0, W, H]}]
    layers.append({"asset": asset, "src": [1073, 1500], "drawn": list(drawn or [w, h]),
                   "scale": 1.0, "fit": "cover", "rect": [x, y, w, h]})
    layers.extend(extra)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(layers, f, indent=1)


def measure(d, *extra):
    out = os.path.join(d, "report.json")
    p = subprocess.run([sys.executable, LEGIBILITY, "--dir", d, "--out", out, "--worst", "0",
                        *extra], capture_output=True, text=True)
    if not os.path.exists(out):
        return p, None
    with open(out, encoding="utf-8") as f:
        return p, json.load(f)


def run_at(report, name, y):
    """The measured run whose box sits at `y`, out of the per-artifact detail or the failures.

    `legibility.py` only writes full run entries for the runs that fail, so this reads the ones
    that pass out of `--dump-runs`. Keeping both paths here means a check does not silently stop
    discriminating because a run moved from one side of its floor to the other.
    """
    for r in report["artifacts"][name].get("all_runs", []):
        _, top, _, h = r["box"]
        if y - 40 <= top + h / 2 <= y + 80:
            return r
    return None


def main():
    failures = []

    def check(ok, line):
        print(("ok    " if ok else "FAIL  ") + line)
        if not ok:
            failures.append(line)

    name = "synthetic.png"
    with tempfile.TemporaryDirectory() as d:
        interior, straddle = still(os.path.join(d, name))
        text_sidecar(os.path.join(d, "synthetic.text.json"), name,
                     [(interior, INTERIOR_SAYS), (straddle, STRADDLE_SAYS)])
        surfaces_sidecar(os.path.join(d, "synthetic.surfaces.json"),
                         [SHEET_X, SHEET_Y, SHEET_W, SHEET_H])
        _, rep = measure(d, "--dump-runs")
        assert rep is not None, "legibility.py wrote no report"
        ins = run_at(rep, name, INTERIOR_Y)
        out = run_at(rep, name, STRADDLE_Y)
        assert ins is not None and out is not None, "the two declared runs were not both found"

        # ---- 1. the straddle is real: the plank IS in the unclipped ring ----------------------
        check(out["ground_swing"] > 2.0 * ins["ground_swing"],
              f"the run at the sheet's edge reads a ground swinging "
              f"{out['ground_swing']}:1 against {ins['ground_swing']}:1 for the one in the middle "
              f"-- same ink, same stock, same page")
        check(out["ink_core"] < ins["ink_core"],
              f"and it is held against that plank: {out['ink_core']}:1 against "
              f"{ins['ink_core']}:1 for the interior run")

        # ---- 2. the clip removes it, and the unclipped swing prints ABOVE the clipped one -----
        check(out["ground_swing_clipped"] < out["ground_swing"],
              f"clipped to its own sheet the straddling run's ground swing falls "
              f"{out['ground_swing']}:1 -> {out['ground_swing_clipped']}:1")
        check(abs(out["ground_swing_clipped"] - ins["ground_swing_clipped"]) < 0.5,
              f"and lands on the interior run's reading "
              f"({out['ground_swing_clipped']}:1 against {ins['ground_swing_clipped']}:1), "
              f"which is what says the plank is what left the ring")
        check(out["ink_core_clipped"] > out["ink_core"],
              f"so its ink reads {out['ink_core_clipped']}:1 against its own paper rather than "
              f"{out['ink_core']}:1 against the wood behind it")

        # ---- 3. and it DISCRIMINATES: the interior run is left alone --------------------------
        # A clip that moved both runs would be measuring the clip. This is the pair the item asks
        # for -- a known straddle and a known interior run -- and the second half is the half a
        # careless implementation passes by accident.
        check(ins["ink_core_clipped"] == ins["ink_core"]
              and ins["ground_swing_clipped"] == ins["ground_swing"],
              f"the interior run does not move at all: {ins['ink_core']}:1 either way, because "
              f"its ring never left the sheet")
        check(out["ground_ring_px_clipped"] < out["ground_ring_px"]
              and ins["ground_ring_px_clipped"] == ins["ground_ring_px"],
              f"and the pixel counts say the same thing: {out['ground_ring_px']} -> "
              f"{out['ground_ring_px_clipped']} at the edge, unchanged in the middle")
        check(out["ground_surface"] == STOCK and out["ground_ring_clipped"],
              f"the sheet it was clipped to is the one the app declared ({out['ground_surface']})")

    # ---- 4. the re-break, and the unmeasurable case -------------------------------------------
    with tempfile.TemporaryDirectory() as d:
        interior, straddle = still(os.path.join(d, name))
        text_sidecar(os.path.join(d, "synthetic.text.json"), name,
                     [(interior, INTERIOR_SAYS), (straddle, STRADDLE_SAYS)])
        # The clip put back: a sheet declared over the whole frame clips nothing, which is the
        # instrument as it was before any of this. The straddling run must return to its
        # unclipped reading exactly.
        surfaces_sidecar(os.path.join(d, "synthetic.surfaces.json"), [0, 0, W, H])
        _, wide = measure(d, "--dump-runs")
        out = run_at(wide, name, STRADDLE_Y)
        check(out["ink_core_clipped"] == out["ink_core"]
              and out["ground_swing_clipped"] == out["ground_swing"],
              f"RE-BREAK: with the sheet declared over the whole frame the clip removes nothing "
              f"and the straddling run is back at {out['ink_core']}:1")

    with tempfile.TemporaryDirectory() as d:
        interior, straddle = still(os.path.join(d, name))
        text_sidecar(os.path.join(d, "synthetic.text.json"), name,
                     [(interior, INTERIOR_SAYS), (straddle, STRADDLE_SAYS)])
        # A sheet smaller than the ring around one line of type: there is nothing left inside it
        # to call a ground. That run is UNMEASURABLE -- still a run, gated on by nothing.
        surfaces_sidecar(os.path.join(d, "synthetic.surfaces.json"),
                         [300, STRADDLE_Y + 9, 12, 12])
        _, tiny = measure(d, "--dump-runs")
        art = tiny["artifacts"][name]
        out = run_at(tiny, name, STRADDLE_Y)
        check(out["unmeasurable"],
              "a run whose sheet has no ring left inside it is reported unmeasurable")
        check(art["runs"] == 2 and art["unmeasurable"] == 1,
              f"and it is still counted as a run: {art['runs']} runs, {art['unmeasurable']} of "
              f"them unmeasurable -- the denominator does not move")

    # ---- 5. WHY THE FLOORS DO NOT GATE ON THE CLIP --------------------------------------------
    # The same pixels, declared twice with two different boxes over them. This is not a contrived
    # case: `02_chat` declares `assets/paper/lined_01` at drawn 1218x90 in a rect of 1462x108 --
    # a clean 1.2 on both axes -- while `13_messenger_states` declares `assets/paper/looseleaf_02`
    # at drawn 1094x494 in a rect of 1268x591, which is 1.159 and 1.196 and therefore not a
    # centred pad at all. On the committed capture the two read a byte-identical region as 8.04
    # and as a 3.04 failure. Here the same disagreement is built on purpose.
    reads = {}
    for tag, rect, drawn in (("exact", [SHEET_X, SHEET_Y, SHEET_W, SHEET_H], None),
                             ("padded", [SHEET_X - 40, SHEET_Y - 150, SHEET_W + 80, SHEET_H + 190],
                              [SHEET_W + 66, SHEET_H + 160])):
        with tempfile.TemporaryDirectory() as d:
            interior, straddle = still(os.path.join(d, name))
            text_sidecar(os.path.join(d, "synthetic.text.json"), name,
                         [(interior, INTERIOR_SAYS), (straddle, STRADDLE_SAYS)])
            surfaces_sidecar(os.path.join(d, "synthetic.surfaces.json"), rect, drawn=drawn)
            _, r = measure(d, "--dump-runs")
            reads[tag] = run_at(r, name, STRADDLE_Y)
    check(reads["exact"]["ink_core"] == reads["padded"]["ink_core"],
          f"the SAME PIXELS under two declared boxes read the same to the floors: "
          f"{reads['exact']['ink_core']}:1 both ways, because `ink_core` does not use the clip")
    check(reads["exact"]["ink_core_clipped"] != reads["padded"]["ink_core_clipped"],
          f"and differently under the clip -- {reads['exact']['ink_core_clipped']}:1 against "
          f"{reads['padded']['ink_core_clipped']}:1 -- which is exactly why it is reported and "
          f"not cited. A ruler whose reading of a region depends on which sidecar declared it "
          f"is disqualified under WORKER_PROMPT 3d. Fix the declaration, not this check.")

    if failures:
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        return 1
    print("\nevery check passed: the clip removes the plank, leaves the interior run alone, "
          "and is not what the floors read")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
