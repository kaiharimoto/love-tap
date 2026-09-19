#!/usr/bin/env python3
"""Proof that declared text runs remove fibre from the tally and leave writing where it was.

    python3 tools/check/legibility_selftest.py

`tools/check/legibility.py` found writing by looking for marks shaped like glyphs, and a surface
that acquires texture acquires glyph-shaped marks. When the corrected day illuminant stopped the
torn paper lips clipping to flat white, 137 runs arrived in the capture that had never existed,
102 of them below the floor -- a 74% failure rate against 21% on the 622 runs that were really
there. The instrument's noise was larger than the change it was being used to judge.

The answer is `window.__deskTextRuns`: the app declares the rects it drew text into, the capture
writes them beside the still as `<name>.text.json`, and the tool measures only inside them. This
is the proof that the declaration is what does it.

It builds a still with two things on it that are indistinguishable to a mark detector -- a line of
writing, and a band of torn-lip fibre steps of the same size, shape and spacing -- and then:

  1. with no sidecar, both are found, and the fibre is counted as failing text;
  2. with a sidecar that declares the writing, the fibre is gone, and the writing measures the
     same number it measures on a page that has no torn lip on it at all;
  3. with a sidecar that *also* declares the fibre band, the failures come straight back.

(3) is the re-break. Without it, (2) is satisfied by a tool that has quietly stopped finding
anything, which is the one way this change could hide true failures instead of false ones. The
item this serves says both halves have to be quoted together or it can be closed by deleting real
findings.

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

W, H = 1080, 2340          # the PWA still's own size, so the fraction-of-height filters in
                           # legibility.py mean what they mean in a real capture
PAPER = 0.92               # cream stock, in gamma space
INK = 0.15                 # a hand, well clear of the body floor
LIP = 0.72                 # the lit face of a torn edge
FIBRE = 0.60               # a step in that edge: about 1.4:1 against the lip, and the same size
                           # and shape as a letter

WRITING_Y = 620
FIBRE_Y = 1500
# Section 6's two lines: one with the app's own rules drawn through its band, one written across a
# hole in the paper with the desk showing through it.
RULED_Y = 1900
HOLED_Y = 2150
RULE = 0.30                # a drawn rule: far off the paper, and LIGHTER than the ink, which is
                           # the case that gets past `on_the_far_side` and becomes the ground
HOLE = 0.30                # the desk, seen through a tear that runs past the line both ways
# Section 7's line: the same writing, with a surface showing through a gap in it AND something
# darker than the letters sitting in the ring beside them.
NEAR_Y = 1150
DESK = 0.10                # the wood seen through a gap in the sheet: DARKER than the ink, and
                           # taller than the line, so it stays in the ground. Darker than the ink
                           # is the whole point -- it is what makes `on_the_far_side` the thing
                           # that decides this run, and the real case is the same way round:
                           # 12_search's letters read 0.0615 against a gated ground of 0.0114
DEEP = 0.04                # a mark darker than the writing: the shadow in a tear, a printed bar,
                           # anything the glyph filters throw out. Shorter than the line, so it
                           # leaves the ground -- and it was still being taken as the ink
RULED_SAYS = "the six words"
HOLED_SAYS = "written across a tear"
NEAR_SAYS = "darker things beside it"
GLYPH_W, GLYPH_H, GAP, COUNT = 20, 30, 12, 12
WRITING_SAYS = "in the morning then"
FIBRE_SAYS = "not writing at all"


def blocks(img, y, x0, value, count=None):
    """A line of glyph-sized marks: 20x30, area 600, which passes every filter in legibility.py."""
    boxes = []
    x = x0
    for _ in range(count if count is not None else COUNT):
        img[y:y + GLYPH_H, x:x + GLYPH_W] = value
        boxes.append((x, y, GLYPH_W, GLYPH_H))
        x += GLYPH_W + GAP
    return boxes


def still(path, with_lip):
    """A sheet with a line of writing on it, and optionally a torn lip lower down."""
    rng = np.random.default_rng(11)
    # A little grain, an order of magnitude under INK_DELTA, so the ground is not a flat plate and
    # nothing in it is ever mistaken for a mark.
    img = PAPER + rng.normal(0.0, 0.004, size=(H, W))
    writing = blocks(img, WRITING_Y, 120, INK)
    fibre = None
    if with_lip:
        # Everything about these is a letter except that nobody wrote them.
        img[FIBRE_Y - 60:FIBRE_Y + 140, 80:1000] = LIP + rng.normal(0.0, 0.004, size=(200, 920))
        fibre = blocks(img, FIBRE_Y, 120, FIBRE)
    a = np.clip(img, 0.0, 1.0)
    rgb = np.repeat((a * 255.0).round().astype(np.uint8)[:, :, None], 3, axis=2)
    Image.fromarray(rgb, "RGB").save(path)
    return writing, fibre


def still_ruled(path):
    """One declared line with the app's own rules drawn immediately above and below it.

    900x8, thrown out of the glyph filters on aspect, and LIGHTER than the ink so that they get
    past `on_the_far_side` and are taken as the ground. That is `05_settings`'s "the six words",
    which measured 1.14:1 against them on the committed capture while being plainly legible at
    400%. They are inside the line's band -- the band is GLYPH_H // 2 = 15 -- and inside its
    padded rect, which is the whole point: they are near the writing, and they are not what it is
    written on.
    """
    rng = np.random.default_rng(29)
    img = PAPER + rng.normal(0.0, 0.004, size=(H, W))
    ruled = blocks(img, RULED_Y, 120, INK)
    img[RULED_Y - 12:RULED_Y - 4, 100:1000] = RULE
    img[RULED_Y + GLYPH_H + 4:RULED_Y + GLYPH_H + 12, 100:1000] = RULE
    a = np.clip(img, 0.0, 1.0)
    Image.fromarray(np.repeat((a * 255.0).round().astype(np.uint8)[:, :, None], 3, axis=2),
                    "RGB").save(path)
    return ruled


def still_holed(path):
    """One declared line written across a tear, with the desk showing through the gap in it.

    `12_search`'s `PHOTOGRAPHS` is a torn tab in two halves with the desk visible between the O
    and the T, so this is the same shape: the word in two groups, and one dark region in the gap
    that runs well past the line above and below. It is the same luminance as the rules in
    [still_ruled] and the same distance from the ink. Only its SCALE against the line differs,
    and that must be enough to keep it as the ground -- a ruler that cannot see a hole in the
    paper a word is written across is not the one to have.
    """
    rng = np.random.default_rng(31)
    img = PAPER + rng.normal(0.0, 0.004, size=(H, W))
    # Two halves of one word. The left ends at x=268 and the right starts at x=300, and the desk
    # fills the 30px between them with a pixel of paper either side of it, so it is its own
    # connected component and never merges with a letter. The gap is narrow on purpose: the
    # band this is measured against reaches GLYPH_H // 2 = 15 either side of a stroke, so a tear
    # much further from the writing than this is not the writing's ground at all and a test
    # built on one would prove nothing. At 30px it is about a quarter of the band, which is what
    # puts it under the fifth percentile the adversarial end is read from.
    left = blocks(img, HOLED_Y, 120, INK, count=5)
    right = blocks(img, HOLED_Y, 300, INK, count=5)
    img[HOLED_Y - 60:HOLED_Y + GLYPH_H + 60, 270:298] = HOLE + rng.normal(
        0.0, 0.004, size=(GLYPH_H + 120, 28))
    a = np.clip(img, 0.0, 1.0)
    Image.fromarray(np.repeat((a * 255.0).round().astype(np.uint8)[:, :, None], 3, axis=2),
                    "RGB").save(path)
    return left + right


def still_darker_near(path):
    """One declared line with a surface darker than its ink above it, and darker marks below it.

    This is `12_search`'s `PHOTOGRAPHS` in miniature, and it is the case the ink sample was
    getting wrong. Three things are in the ring, and only one of them is the writing:

      the letters   at INK,  which is the writing;
      a surface     at DESK, DARKER than the letters and taller than the line, so `figure_of`
                    leaves it in the ground and it becomes the ground band's dark end;
      dark marks    at DEEP, darker still, shorter than the line so they leave the ground as the
                    app's own ink, and thrown out of the glyph filters on aspect.

    Both of the last two are dark marks, so both are in the polarity mask the ink used to be read
    from, and the DEEP marks are the darkest thing in it. Taking the tenth percentile of that puts
    the ink at DEEP instead of at INK -- and the ink then reads darker than its own ground, so
    `on_the_far_side` concludes the ground is a second surface behind the writing and gates the
    run against it. The run comes out at about one to one for text that is plainly legible.

    The guard is right and it is doing its job; it was being handed the wrong ink. Measured on the
    capture this is drawn from: the letters are a flat 0.0615, the gated ground 0.0114, and the
    polluted sample 0.0072 -- contrast(0.0072, 0.0114) = 1.07, where the letters alone give
    contrast(0.0615, 0.0114) = 1.82 and the guard declines to gate at all, leaving the ring
    reading of 15.16 standing.

    Two pieces of geometry are load-bearing, and the first two attempts at this page got both
    wrong, so they are written down. The ground band reaches `(y1 - y0) // 2` -- fifteen pixels
    for this line -- from a GLYPH, so a surface off to one side of the line contributes a sliver
    far under the fifth percentile the adversarial end is read from, and the band comes back flat
    paper. It has to run along the line. And the ring is `max(RING, (y1 - y0) // 2)` around the
    run, so marks placed a comfortable-looking distance from the writing are simply outside it.
    """
    rng = np.random.default_rng(37)
    img = PAPER + rng.normal(0.0, 0.004, size=(H, W))
    left = blocks(img, NEAR_Y, 120, INK, count=6)
    right = blocks(img, NEAR_Y, 460, INK, count=6)
    # the surface, along the line and six pixels off it: forty tall against a thirty-tall line, so
    # its height over the line clears FIGURE_MAX_H_OVER_LINE and it stays in the ground
    img[NEAR_Y - 46:NEAR_Y - 6, 110:740] = DESK + rng.normal(0.0, 0.004, size=(40, 630))
    # and the darker marks, just under the line and inside the ring. 70x12 is 5.8:1, thrown out on
    # aspect; twelve against thirty is shorter than the line, so they are ink and not a surface
    for k in range(8):
        x = 120 + k * 78
        img[NEAR_Y + GLYPH_H + 2:NEAR_Y + GLYPH_H + 14, x:x + 70] = DEEP + rng.normal(
            0.0, 0.003, size=(12, 70))
    a = np.clip(img, 0.0, 1.0)
    Image.fromarray(np.repeat((a * 255.0).round().astype(np.uint8)[:, :, None], 3, axis=2),
                    "RGB").save(path)
    return left + right


def sidecar(path, name, groups):
    """A sidecar in the shape tools/capture/scene.js writes, one run per group of boxes."""
    runs = []
    for boxes, text in groups:
        x0 = min(b[0] for b in boxes)
        y0 = min(b[1] for b in boxes)
        x1 = max(b[0] + b[2] for b in boxes)
        y1 = max(b[1] + b[3] for b in boxes)
        rect = [x0, y0, x1 - x0, y1 - y0]
        runs.append({
            "rect": rect, "lines": [rect],
            "points": 13.3, "px": 40.0,          # body: under LARGE_PX, so the 4.5 floor
            "family": "NoorHand", "role": "hand", "ink": "ff1f2a44",
            "text": text, "chars": len(text),
        })
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"of": name, "size": [W, H], "dpr": 3, "declared": len(runs),
                   "offscreen": 0, "runs": runs}, f, indent=1)


def measure(d, *extra):
    out = os.path.join(d, "report.json")
    p = subprocess.run([sys.executable, LEGIBILITY, "--dir", d, "--out", out, "--worst", "0",
                        *extra], capture_output=True, text=True)
    if not os.path.exists(out):
        return p, None
    with open(out, encoding="utf-8") as f:
        return p, json.load(f)


def near(box, y):
    _, top, _, h = box
    return y - 40 <= top + h / 2 <= y + 80


def main():
    failures = []

    def check(ok, line):
        print(("ok    " if ok else "FAIL  ") + line)
        if not ok:
            failures.append(line)

    name = "synthetic.png"
    with tempfile.TemporaryDirectory() as clean, tempfile.TemporaryDirectory() as d:
        # A page with nothing on it but the writing, measured the old way. This is what the
        # writing's contrast IS, with no lip anywhere near it to argue about.
        still(os.path.join(clean, name), with_lip=False)
        _, alone = measure(clean, "--text-runs", "off")
        alone_core = alone["artifacts"][name]["worst_ink_core"]
        check(alone["artifacts"][name]["runs"] == 1,
              f"a page with one line on it reads one run ({alone['artifacts'][name]['runs']})")
        check(alone["total_below_floor"] == 0,
              f"and that line is above its floor at {alone_core}:1")

        writing, fibre = still(os.path.join(d, name), with_lip=True)
        side = os.path.join(d, "synthetic.text.json")

        # ---- 1. the instrument as it was: the lip is writing too -------------------------------
        p, before = measure(d, "--text-runs", "off")
        art = before["artifacts"][name]
        lip_before = [f for f in before["failures"] if near(f["box"], FIBRE_Y)]
        check(art["text_runs"] == "found-by-shape", "with no sidecar the report says so")
        check(art["runs"] >= 2, f"it finds both lines by shape ({art['runs']} runs)")
        check(len(lip_before) >= 1,
              f"and counts the torn-lip steps as text below its floor ({len(lip_before)})")
        check(p.returncode == 1, "so the artifact fails on marks nobody wrote")

        # ---- 2. declare the writing, and only the writing --------------------------------------
        sidecar(side, name, [(writing, WRITING_SAYS)])
        p, after = measure(d)
        art = after["artifacts"][name]
        lip_after = [f for f in after["failures"] if near(f["box"], FIBRE_Y)]
        check(art["text_runs"] == "declared", "with a sidecar it measures from the declaration")
        check(not lip_after, f"the torn-lip steps are not text any more ({len(lip_after)} left)")
        check((art["marks_outside_text"] or 0) >= COUNT,
              f"and are counted as what they are: {art['marks_outside_text']} marks outside text")
        check(art["runs"] == 1, f"the one declared line is the one run read ({art['runs']})")
        check(p.returncode == 0, "and the artifact passes")
        # The half that makes this honest: a filter that also moves the number it leaves behind is
        # not a filter. The writing on the torn page must read as the writing on the clean one.
        check(art["worst_ink_core"] is not None and alone_core is not None
              and abs(art["worst_ink_core"] - alone_core) <= 0.05,
              f"the writing reads what it reads with no lip on the page "
              f"({alone_core} -> {art['worst_ink_core']})")

        # ---- 3. the re-break: declare the lip too and the failures come back --------------------
        sidecar(side, name, [(writing, WRITING_SAYS), (fibre, FIBRE_SAYS)])
        p, rebroken = measure(d)
        lip_again = [f for f in rebroken["failures"] if near(f["box"], FIBRE_Y)]
        check(len(lip_again) >= 1,
              f"declaring the lip brings the failures straight back ({len(lip_again)})")
        check(p.returncode == 1,
              "so it is the declaration doing the work, not a tool that stopped looking")
        check(any(f.get("says") == FIBRE_SAYS for f in lip_again),
              "and a failure says what the app says it says, instead of being cropped out by eye")

        # ---- 4. a sidecar for a different frame is refused rather than believed -----------------
        with open(side, encoding="utf-8") as f:
            wrong = json.load(f)
        wrong["size"] = [W, H + 1]
        with open(side, "w", encoding="utf-8") as f:
            json.dump(wrong, f)
        p = subprocess.run([sys.executable, LEGIBILITY, "--dir", d, "--worst", "0"],
                           capture_output=True, text=True)
        check(p.returncode != 0 and "sidecar" in (p.stderr + p.stdout),
              "a sidecar written for another frame is refused, not used")

        # ---- 5. --text-runs require names what has no declaration -------------------------------
        os.remove(side)
        p = subprocess.run([sys.executable, LEGIBILITY, "--dir", d, "--worst", "0",
                            "--text-runs", "require"], capture_output=True, text=True)
        check(p.returncode == 2 and name in p.stderr,
              "require names the stills that have no declaration beside them")

        # ---- 6. the app's own ink is not the surface, and a hole in the paper still is --------
        # Two pages, each with one declared line and one dark thing in its band. The two dark
        # things are the same luminance and the same distance from the ink; they differ only in
        # scale against the line, and that alone decides which is the ground.
        with tempfile.TemporaryDirectory() as rd:
            rname = "ruled.png"
            sidecar(os.path.join(rd, "ruled.text.json"), rname,
                    [(still_ruled(os.path.join(rd, rname)), RULED_SAYS)])
            p6, ruled = measure(rd)
            rart = ruled["artifacts"][rname]
            check(rart["runs"] == 1, f"the ruled line reads as one run ({rart['runs']})")
            check(p6.returncode == 0 and ruled["total_below_floor"] == 0,
                  "a rule the app drew through a line's band is not that line's ground")
            # The half that keeps this from being met by a tool that stopped looking: the line has
            # to read what the same writing reads on clean paper, not merely stop failing.
            check(rart["worst_ink_core"] is not None
                  and abs(rart["worst_ink_core"] - alone_core) <= 0.25,
                  f"and it reads what that writing reads on a clean page "
                  f"({alone_core} -> {rart['worst_ink_core']})")

        with tempfile.TemporaryDirectory() as hd:
            hname = "holed.png"
            sidecar(os.path.join(hd, "holed.text.json"), hname,
                    [(still_holed(os.path.join(hd, hname)), HOLED_SAYS)])
            p6, holed = measure(hd)
            hart = holed["artifacts"][hname]
            check(hart["runs"] == 1, f"the torn line reads as one run ({hart['runs']})")
            check(p6.returncode == 1 and holed["total_below_floor"] >= 1,
                  f"and the desk seen through a tear it is written across still is its ground "
                  f"({hart['worst_ink_core']}:1)")
            check(any(f.get("says") == HOLED_SAYS for f in holed["failures"]),
                  "so the rule is a rule about scale, not a licence to empty the ground")

        # ---- 7. a run's ink is the glyphs, not every mark near them ---------------------------
        # The page has the writing, a surface showing through a gap in it, and four marks DARKER
        # than the writing sitting in the band. Only the letters are the writing. Reading the ink
        # as every mark of that polarity in the ring puts the tenth percentile inside those four,
        # which makes the ink look darker than its own ground -- so `on_the_far_side` decides the
        # ground is a second surface, gates the run against it, and reports about one to one for
        # text that is plainly legible.
        with tempfile.TemporaryDirectory() as nd:
            nname = "darker_near.png"
            sidecar(os.path.join(nd, "darker_near.text.json"), nname,
                    [(still_darker_near(os.path.join(nd, nname)), NEAR_SAYS)])
            p7, near_d = measure(nd)
            nart = near_d["artifacts"][nname]
            check(nart["runs"] == 1, f"the line reads as one run ({nart['runs']})")
            check(p7.returncode == 0 and near_d["total_below_floor"] == 0,
                  f"a mark darker than the writing is not the writing "
                  f"({nart['worst_ink_core']}:1)")
            # The half that makes it a measurement rather than a threshold: the letters' own
            # luminance has to be what came out, so this cannot be met by a tool that widened a
            # tolerance or stopped reading the run at all.
            check(nart["worst_ink_core"] is not None
                  and abs(nart["worst_ink_core"] - alone_core) <= 0.25,
                  f"and it reads what that writing reads on a clean page "
                  f"({alone_core} -> {nart['worst_ink_core']})")
            # `marks_outside_text` is 0 on this page and that is correct: the surface and the
            # dark marks both lie inside this line's own declared span, so there is nothing
            # outside it to count. The property that they are seen rather than erased is section
            # 2's, on a page built for it. What this section proves is the one thing that page
            # cannot: which of the marks inside a declared run is the run's ink.

    if failures:
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        return 1
    print("\nevery check passed: the declaration removes fibre, keeps writing, and can be undone")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
