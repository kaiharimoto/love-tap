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
GLYPH_W, GLYPH_H, GAP, COUNT = 20, 30, 12, 12
WRITING_SAYS = "in the morning then"
FIBRE_SAYS = "not writing at all"


def blocks(img, y, x0, value):
    """A line of glyph-sized marks: 20x30, area 600, which passes every filter in legibility.py."""
    boxes = []
    x = x0
    for _ in range(COUNT):
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

    if failures:
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        return 1
    print("\nevery check passed: the declaration removes fibre, keeps writing, and can be undone")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
