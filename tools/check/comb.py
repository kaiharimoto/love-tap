#!/usr/bin/env python3
"""Is there a barcode of hard vertical bars lying across the paper?

    python3 tools/check/comb.py 13_messenger_states
    python3 tools/check/comb.py --all --out evidence/logs/comb.json

This is the artifact clause of `a-barcode-of-vertical-bars-is-painted-across-the-paper-on-four-
artifacts`, and it exists because that item's measurement -- "a column-profile check reports <= 8
mean-crossings in any 30-row band inside a paper surface's own rect, against today's 21-68" -- was
stated only in prose. No committed tool computed a mean-crossing, so the item could be neither
closed nor reopened by anything but an eye. Firing 29 replaced both drawing sites and could
measure the WIDGET; the artifact clause has been waiting for this since.

What it reads, and why it reads it that way:

  * The population is every paper surface the app DECLARES in `<name>.surfaces.json`, and the
    bands are tiled down each declared rect at a fixed stride. Never a coordinate, never "a paper
    region" -- WORKER_PROMPT 3d, and the reason this item was re-expressed at firing 32.
  * A crossing counts only when the profile actually travels. Paper is noisy: an unbarred sheet's
    column profile crosses its own mean dozens of times by a fraction of a luminance level, and a
    naive zero-crossing count reads flat paper as a comb. So the crossing is hysteretic -- the
    profile must reach MEAN +/- `HYSTERESIS` to change state -- and the band's own L range is
    printed beside the count so nobody has to take the count on trust.
  * `flat_columns` is the item's second clause, "bar interiors perfectly constant". It is counted
    on the raw pixels rather than on the profile: a column inside the band whose every value is
    EXACTLY equal is what a `Canvas.drawRect` leaves and what a render never does.

EARNED AGAINST A PAIR WHOSE ANSWER WAS ALREADY KNOWN, AND IT DID NOT DISCRIMINATE. The pair is
`2a03a77` -- the last capture taken before firing 29 replaced the two `drawRect` sites with hand
strokes -- and the capture committed at firing 41. Firing 42 ran this over both:

    13_messenger_states   before 114 crossings   after 110    floor 8
    02_chat               before 120 crossings   after 110    floor 8

So by WORKER_PROMPT 3d's rule this ruler MAY NOT BE CITED to close
`a-barcode-of-vertical-bars-is-painted-across-the-paper-on-four-artifacts`, and it is committed
anyway because what it establishes is worth more than a pass would have been: the item's stated
measurement cannot close it, and three separate reasons why are now written down instead of being
rediscovered.

  1. The count is dominated by everything else standing on the declared rect. `pad.chat` is a
     legal pad the size of the screen and every note, tear, shadow and edge in the picture lies on
     top of it, so a column profile across its rect crosses its own mean about once every thirteen
     columns whatever the bars are doing. A rect is not the same thing as the paper you can SEE,
     and this ruler has no occlusion.
  2. Writing satisfies both clauses on its own -- see `without_writing`, which takes the declared
     runs out and was worth 206-544 bar interiors per artifact before it existed.
  3. The item's own numbers (21-68) do not reproduce at the band size it names. The one figure
     that DID move across the repair is the band's luminance range: 183-202 before, 43-61 after.

A fourth reason is a fault of this file rather than of the item, and is recorded because it took
two wrong readings to find: the first draft profiled `axis=1`, which is a thirty-sample profile of
the band's ROWS, and a thirty-sample profile cannot exceed thirty crossings however barred the
paper is. It read 4 on every artifact on both sides of the repair and looked like a pass.
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

BAND = 30          # rows, as the item states it
STRIDE = 30        # non-overlapping, so one bar cannot be counted by two bands
HYSTERESIS = 4.0   # L, the travel a crossing has to make to be a crossing
MIN_W = 120        # a rect narrower than this has no room for a barcode
MIN_H = BAND
FLOOR = 8          # the item's number
FLAT_RUN = 8       # rows: a perfectly constant run this long is a drawn rectangle, not a render
FLAT_COLS = 4      # columns: one constant column is a column; four abreast is a bar
FLAT_APART = 6.0   # L: and it has to stand clear of the paper it is supposed to be lying on


def crossings(profile, h=HYSTERESIS):
    """How many times the profile travels across its own mean, by at least h each way."""
    mean = float(profile.mean())
    state = 0
    n = 0
    for v in profile:
        if state <= 0 and v > mean + h:
            if state != 0:
                n += 1
            state = 1
        elif state >= 0 and v < mean - h:
            if state != 0:
                n += 1
            state = -1
    return n


def flat_columns(block):
    """Bar interiors: a block of ONE exact value, standing clear of the paper around it.

    The item's clause is "bar interiors perfectly constant (195,195,195,...) against a 240
    ground", so all three parts are required and the third is what makes it mean anything:
    exactly one value, over a run of at least FLAT_RUN rows and FLAT_COLS columns, and at least
    FLAT_APART luminance levels away from the band's own median. Counting merely-constant runs
    instead reads smooth paper as a barcode -- an 8-bit render quantises a gentle gradient into
    constant runs everywhere, and the first draft of this counted 1,046 of them on a still with
    no bars on it at all."""
    med = float(np.nanmedian(block))
    h, w = block.shape
    cols = np.zeros(w, dtype=bool)
    for c in range(w):
        col = block[:, c]
        if np.isnan(col).any():
            continue
        run, best, bestv = 1, 1, col[0]
        for i in range(1, h):
            if col[i] == col[i - 1]:
                run += 1
                if run > best:
                    best, bestv = run, col[i]
            else:
                run = 1
        cols[c] = best >= FLAT_RUN and abs(float(bestv) - med) >= FLAT_APART
    # and they have to stand next to each other, because one constant column is a column and a
    # bar is a band of them
    n, run = 0, 0
    for c in range(w):
        run = run + 1 if cols[c] else 0
        if run >= FLAT_COLS:
            n += 1
    return n


def read(name, d):
    png = os.path.join(d, name + ".png")
    side = os.path.join(d, name + ".surfaces.json")
    if not os.path.exists(png) or not os.path.exists(side):
        return None
    im = np.asarray(Image.open(png).convert("L"), dtype=np.float32)
    return im, json.load(open(side, encoding="utf-8"))


def without_writing(im, name, d):
    """The frame with every run the app declares masked out, and how many were masked.

    Writing satisfies both of this item's clauses by itself: a glyph's stem is a run of one exact
    value standing clear of the paper, and a line of them crosses a column profile's mean once per
    letter. Measured on the committed stills, the bar-interior count with the writing left in is
    206-544 per artifact on captures taken either side of the repair -- it is counting letters.
    So the runs are taken out first, by the rects the app itself declares in `<name>.text.json`,
    which is the same anchor WORKER_PROMPT 3d asks every other measurement here to use.
    """
    path = os.path.join(d, name + ".text.json")
    if not os.path.exists(path):
        return im, None
    doc = json.load(open(path, encoding="utf-8"))
    out = im.copy()
    H, W = out.shape
    n = 0
    for run in doc.get("runs", []):
        l, t, w, h = run["rect"]
        x0, x1 = max(0, l), min(W, l + w)
        y0, y1 = max(0, t), min(H, t + h)
        if x1 > x0 and y1 > y0:
            out[y0:y1, x0:x1] = np.nan
            n += 1
    return out, n


def measure(name, d):
    got = read(name, d)
    if got is None:
        return {"artifact": name, "read": False,
                "why": "no PNG or no surfaces sidecar, so there is no declared rect to read"}
    im, surfaces = got
    im, masked = without_writing(im, name, d)
    H, W = im.shape
    bands = []
    papers = 0
    for s in surfaces:
        if "/paper/" not in s.get("asset", ""):
            continue
        l, t, w, h = s["rect"]
        x0, x1 = max(0, l), min(W, l + w)
        y0, y1 = max(0, t), min(H, t + h)
        if x1 - x0 < MIN_W or y1 - y0 < MIN_H:
            continue
        papers += 1
        for y in range(y0, y1 - BAND + 1, STRIDE):
            block = im[y:y + BAND, x0:x1]
            if np.isnan(block).mean() > 0.5:
                continue        # more than half of this band is writing; there is no paper to read
            # axis=0: ONE VALUE PER COLUMN, averaged down the band's rows. The first draft of
            # this took axis=1 and measured a thirty-sample profile of the rows -- which cannot
            # exceed thirty crossings however barred the paper is, and read 4 on every artifact
            # either side of the repair. A column profile is what the item says and what a
            # barcode is a barcode along.
            prof = np.nanmean(block, axis=0)
            keep = ~np.isnan(prof)
            if keep.sum() < MIN_W:
                continue
            prof = prof[keep]
            rng = float(prof.max() - prof.min())
            bands.append({
                "asset": s["asset"].split("/")[-1],
                "piece": s.get("piece", ""),
                "band": [x0, y, x1 - x0, BAND],
                "crossings": crossings(prof),
                "l_range": round(rng, 1),
                # counted only where there is something to count; a flat band of paper has no
                # bar interiors and walking every column of every band costs more than it says
                "flat_columns": flat_columns(block) if rng > 2.0 else 0,
            })
    if not bands:
        return {"artifact": name, "read": False,
                "why": f"{papers} paper surfaces declared and none of them is "
                       f"{MIN_W}x{MIN_H} on screen, so nothing was measured"}
    worst = max(bands, key=lambda b: b["crossings"])
    flattest = max(bands, key=lambda b: b["flat_columns"])
    return {
        "artifact": name,
        "read": True,
        "paper_surfaces": papers,
        "bands": len(bands),
        "text_runs_masked": masked,
        "max_crossings": worst["crossings"],
        "at": worst,
        "max_flat_columns": flattest["flat_columns"],
        "flat_at": flattest,
        "passes": worst["crossings"] <= FLOOR and flattest["flat_columns"] == 0,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--dir", default=EVIDENCE)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--out")
    a = ap.parse_args()
    names = a.names
    if a.all or not names:
        names = sorted(os.path.basename(p)[:-len(".surfaces.json")]
                       for p in glob.glob(os.path.join(a.dir, "*.surfaces.json")))
    out = [measure(n, a.dir) for n in names]
    for r in out:
        if not r["read"]:
            print(f"{r['artifact']:24s} — {r['why']}")
            continue
        print(f"{r['artifact']:24s} {r['bands']:4d} bands over {r['paper_surfaces']:3d} paper "
              f"surfaces — max {r['max_crossings']:3d} crossings "
              f"(L range {r['at']['l_range']:6.1f}, {r['at']['asset']}"
              f"{', ' + r['at']['piece'] if r['at']['piece'] else ''}), "
              f"flat columns {r['max_flat_columns']:4d}  "
              f"{'ok' if r['passes'] else 'OVER'}")
    read = [r for r in out if r["read"]]
    bad = [r for r in read if not r["passes"]]
    print(f"— {len(read)} artifacts read, {len(bad)} over the floor of {FLOOR} crossings "
          f"or carrying a perfectly constant bar interior")
    if a.out:
        with open(a.out, "w", encoding="utf-8") as f:
            json.dump({"floor": FLOOR, "band_rows": BAND, "hysteresis_l": HYSTERESIS,
                       "artifacts": out}, f, indent=1)
    return 1 if bad or not read else 0


if __name__ == "__main__":
    sys.exit(main())
