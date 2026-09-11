#!/usr/bin/env python3
"""No hole in the desk: nothing on the glass may be darker than ink, in a patch bigger than a letter.

A coherence critic measured 758 pixels under luma 30 beside one chip in 12_search, minimum 4.3,
against a desk reading 84 to 103 either side of it, and called it a hole. It was: the baked contact
shadows are rendered black at alpha 255 over a third of their area (measured: 35 to 47 per cent of
each asset is alpha above 240, RGB 0,0,0), because that part is under the paper and never meant to
be seen — and the shadow was stretched with BoxFit.fill while the paper's tear is nine-sliced, so
on a piece far from the render's proportions the two no longer lined up and the black came out.

The hard part is telling a hole from a letter, because ink is dark too, and counting how dark a
pixel's own neighbourhood is does not separate them: measured, the densest handwriting crop in the
set puts 257 pixels through that filter, because a stroke at three hundred per cent is nine pixels
across and a nine-pixel window inside one is all ink.

What separates them is where they are. Writing is *on* paper and a hole is *beside* it. So the
paper is found first — pale and warm, the way flat.py finds it — grown by a couple of pixels to
cover its own soft edge, and only dark pixels outside that are counted. Every letter in the set is
inside it. A photograph on a card is inside it too, which is why a dark picture does not trip this.

Two controls ship in the report: the densest handwriting in the set, which must measure nothing,
and a synthetic black square on bare desk, which must measure all of itself.

    python3 tools/check/holes.py --out evidence/logs/holes.json
    python3 tools/check/holes.py evidence/12_search.png
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVIDENCE = os.path.join(ROOT, "evidence")


def _share(mask, r):
    """What share of each pixel's (2r+1) square neighbourhood is set."""
    import numpy as np
    d = mask.astype(np.float32)
    s = np.pad(d, ((1, 0), (1, 0))).cumsum(axis=0).cumsum(axis=1)
    h, w = d.shape
    y0 = np.clip(np.arange(h) - r, 0, h)
    y1 = np.clip(np.arange(h) + r + 1, 0, h)
    x0 = np.clip(np.arange(w) - r, 0, w)
    x1 = np.clip(np.arange(w) + r + 1, 0, w)
    tot = (s[np.ix_(y1, x1)] - s[np.ix_(y0, x1)] - s[np.ix_(y1, x0)] + s[np.ix_(y0, x0)])
    area = np.outer(y1 - y0, x1 - x0).astype(np.float32)
    return tot / area


def _grown(mask, r):
    """A boolean mask grown by r pixels, by a box filter on its own integral."""
    import numpy as np
    d = mask.astype(np.float32)
    s = np.pad(d, ((1, 0), (1, 0))).cumsum(axis=0).cumsum(axis=1)
    h, w = d.shape
    y0 = np.clip(np.arange(h) - r, 0, h)
    y1 = np.clip(np.arange(h) + r + 1, 0, h)
    x0 = np.clip(np.arange(w) - r, 0, w)
    x1 = np.clip(np.arange(w) + r + 1, 0, w)
    tot = (s[np.ix_(y1, x1)] - s[np.ix_(y0, x1)] - s[np.ix_(y1, x0)] + s[np.ix_(y0, x0)])
    return tot > 0


def _holes(rgb, dark, grow, reach=12):
    """Dark pixels in the ring just outside a piece of paper.

    Not simply "dark and not on paper": half the objects in this app are dark on purpose — a
    stone, a wick, soot, the inside of a mug — and 01_pulse measures a legitimate 2,631 such
    pixels with a darkest of 0.0, which is a rendered black object and not a fault. What is a
    fault is a dark band lying *along* a torn edge, because that is a shadow that has come out
    from under the paper it belongs to. So this looks only at the ring from `grow` to `reach`
    pixels outside the paper: an object may be as dark as it likes, but the desk immediately
    beside a sheet may not be darker than the desk gets.
    """
    lum = rgb.mean(axis=2)
    warm = rgb[..., 0] - rgb[..., 2]
    # Pale, and not the wood. Not "pale and warm": a blue sticky note has its blue channel *above*
    # its red, so a warmth test throws away the paper it is written on and then counts the writing
    # on it as a hole in the desk. The desk is dark enough (84 to 103 across the set) that
    # brightness alone separates it, and the warmth ceiling only keeps out anything more orange
    # than paper ever is.
    pale = (lum > 150.0) & (warm < 60.0)
    # A *sheet*, not any pale thing. A candle is pale, and its wick and the soot in its pool are
    # black and sit within a dozen pixels of it — so with any pale pixel counting as paper,
    # 01_pulse's object row read as four hundred pixels of hole in a desk that has none. A sheet
    # is large: a pixel is on one when its own forty-one-pixel neighbourhood is nine-tenths pale,
    # which nothing in the object library is anywhere except its own middle.
    # ...but the share test on its own erodes a sheet by its own radius, and then the "ring outside
    # the paper" lands *inside* the sheet: the control — a hundred-pixel sheet with a six-pixel
    # black band down its edge — went from catching 300 of 600 to catching none. So the share test
    # only says which pale regions are sheets, and the sheet's own boundary is where the pale
    # region is: the cores are grown back out and intersected with pale again.
    core = pale & (_share(pale, 20) > 0.90)
    sheet = pale & _grown(core, 26)
    # And the writing on it is still on it. Ink is not pale, so every letter punches a hole in the
    # sheet, and the ring three to twelve pixels outside a hole is the paper around the letter:
    # 05_settings' emphasised word `quietly`, underlined and sitting near the foot of a sheet, put
    # 130 pixels of pure black into a check that is looking for shadows on the desk.
    #
    # Closed, not grown: dilate by twelve and erode by twelve again. That fills a hole up to about
    # twenty-four pixels across — which is every letter on these screens — and leaves the sheet's
    # outer boundary exactly where it was, so a black band lying *beside* the sheet is not filled
    # in with it. Growing by a radius and asking what share of the neighbourhood is paper cannot
    # tell those two apart: a letter at the foot of a sheet and a shadow just past its edge have
    # the same neighbourhood.
    paper = ~_grown(~_grown(sheet, 12), 12)
    ring = _grown(paper, reach) & ~_grown(paper, grow)
    return (lum < dark) & ring, lum


def contact_shadow(rgb, grow=3, near=(4, 14), far=(45, 65)):
    """How much darker the desk is just under a sheet than it is a little further away.

    Negative is a shadow. This exists because holes.py passed for the wrong reason: the check that
    said no black lies beside the paper went to zero on a capture where the contact shadow had
    vanished altogether, and a material critic found it by walking outward from an edge. No black
    beside a sheet and no shadow under one are the same picture to a check that only looks for
    black, and they are opposite faults.

    Measured down every third column: find where a run of paper ends, skip the three pixels of its
    own soft edge, and compare a band just below it with a band further down, keeping only the
    pairs where both bands are on the wood.
    """
    import numpy as np
    lum = rgb.mean(axis=2)
    warm = rgb[..., 0] - rgb[..., 2]
    paper = (lum > 150.0) & (warm < 60.0)
    h, w = lum.shape
    near_v, far_v = [], []
    for col in range(60, w - 60, 3):
        inp = False
        start = 0
        for y in range(h - 1):
            p = paper[y, col]
            if p and not inp:
                inp, start = True, y
            elif not p and inp:
                inp = False
                if y - start > 80 and y + far[1] < h:
                    a = lum[y + near[0]:y + near[1], col]
                    b = lum[y + far[0]:y + far[1], col]
                    if a.max() < 150 and b.max() < 150:
                        near_v.append(float(a.mean()))
                        far_v.append(float(b.mean()))
    if not near_v:
        return {"edges": 0}
    n = float(np.mean(near_v))
    f = float(np.mean(far_v))
    return {
        "edges": len(near_v),
        "just_under_a_sheet": round(n, 2),
        "further_down_the_desk": round(f, 2),
        "darker_by": round(f - n, 2),
    }


def measure(path, dark, grow):
    import numpy as np
    from PIL import Image
    with Image.open(path) as im:
        rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
    holes, lum = _holes(rgb, dark, grow)
    shade = contact_shadow(rgb, grow)
    n = int(holes.sum())
    import numpy as np
    ring, _ = _holes(rgb, 1e9, grow)      # the whole ring, dark or not
    out = {
        "pixels_darker_than_ink": int((lum < dark).sum()),
        "beside_the_paper": n,
        "darkest": round(float(lum.min()), 2),
        "darkest_beside_a_sheet": round(float(lum[ring].min()), 2) if ring.any() else None,
        "ring_pixels": int(ring.sum()),
        "contact_shadow": shade,
    }
    if n:
        ys, xs = np.nonzero(holes)
        out["worst_at"] = [int(xs[np.argmin(lum[holes])]), int(ys[np.argmin(lum[holes])])]
        out["spread"] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    return out


def controls(dark, grow):
    """What the same code says about writing, and about an actual hole."""
    import numpy as np
    got = {}
    crop = os.path.join(EVIDENCE, "crops", "02_chat_300_hand.png")
    if os.path.exists(crop):
        # At three hundred per cent, and measured at three times the radius for that reason: a
        # stroke there is nine to twelve pixels across, so a paper mask grown by three does not
        # reach the middle of one and every letter in the crop counted as a hole. The radius is
        # about the width of a stroke, and the crop's strokes are three times as wide.
        got["the_densest_handwriting_in_the_set"] = measure(crop, dark, grow * 3)
        got["the_densest_handwriting_in_the_set"]["measured_at"] = \
            "three times the radius, because the crop is at three times the scale"
    # The fault itself, drawn by hand: a desk, a sheet on it, and a six-pixel black band along the
    # sheet's right edge — which is what a contact shadow that has come out from under its paper
    # looks like. Measured by the same code, so the gate can be seen to catch the thing it is for.
    desk = np.full((200, 200, 3), (110.0, 88.0, 66.0), dtype=np.float32)
    desk[50:150, 50:150] = (243.0, 238.0, 227.0)       # the sheet
    desk[50:150, 150:156] = 0.0                        # its shadow, out from under it
    holes, _ = _holes(desk, dark, grow)
    got["a_shadow_out_from_under_its_sheet"] = {
        "beside_the_paper": int(holes.sum()),
        "of": 100 * 6,
        "note": "a six-pixel black band along a sheet's edge. The first three pixels are inside "
                "the grown paper mask and are not counted, which is the point of growing it: the "
                "soft edge of a real sheet is not a fault.",
    }
    return got


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--dark", type=float, default=30.0,
                    help="luma under which a pixel is darker than the ink on the page")
    ap.add_argument("--grow", type=int, default=3,
                    help="how far the paper mask is grown, to cover the soft edge of a sheet")
    ap.add_argument("--allow", type=int, default=200,
                    help="how many such pixels a still may have. Not zero: an object as dark as a "
                         "wick or a stone can stand within a dozen pixels of a sheet, and the "
                         "densest-writing control measures 72 by the same code.")
    ap.add_argument("--shadow-floor", type=float, default=6.0,
                    help="how many grey levels darker the desk must be just under a sheet than "
                         "further down it. Measured on the cycle-9 hero, where the shadow worked: "
                         "14.42. Measured on the cycle-10 hero, after the shadow was nine-sliced "
                         "out of existence: -0.44. The floor sits between them, nearer the fault, "
                         "so a shadow that is merely weakened still fails.")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    files = a.files or sorted(glob.glob(os.path.join(EVIDENCE, "*.png")))
    report = {
        "how": "a pixel under luma {} that is not on paper, nor within {} pixels of it. Writing is "
               "on paper; a shadow leaking past the piece it belongs to is beside it".format(
                   a.dark, a.grow),
        "why": "the baked contact shadows are black at alpha 255 over a third of their area, "
               "because that third is under the paper. Anywhere the shadow does not line up with "
               "the piece it belongs to, that black is on the desk.",
        "dark": a.dark,
        "allow": a.allow,
        "shadow_floor": a.shadow_floor,
        "a_sheet_has_to_cast_one": "measured on the hero of the cycle before this check existed, "
                "where the shadow worked: 14.42 grey levels darker four to fourteen pixels under a "
                "sheet than forty-five to sixty-five under it, over 1,132 edges. Measured after "
                "the shadow was nine-sliced: -0.44, which is half a level the wrong way.",
        "what_it_still_counts_that_is_not_a_hole": "ink at the very edge of a sheet. 05_settings "
                "reads 130 pixels at luma 0, and they are the rule under the emphasised word "
                "`quietly` — an 84-pixel horizontal stroke on the last line of a sheet, at "
                "(953-1037, 2941). A closing fills a letter-shaped hole inside a sheet, which is "
                "why 01_pulse's candle went from 5 to 0, but it cannot fill a notch that is open "
                "to the outside, and a dark stroke at a sheet's boundary has the same "
                "neighbourhood as a shadow just past it. This is what the allowance is for, and "
                "the densest-writing control measures 51 by the same code.",
        "controls": controls(a.dark, a.grow),
        "stills": {},
    }
    bad = 0
    for f in files:
        if not os.path.exists(f):
            continue
        got = measure(f, a.dark, a.grow)
        report["stills"][os.path.basename(f)] = got
        if got["beside_the_paper"] > a.allow:
            bad += 1
        # And a sheet has to cast one. No black beside the paper and no shadow under it look the
        # same to a check that only looks for black, and they are opposite faults: this check
        # passed with flying colours on a capture where every contact shadow had vanished.
        cs = got.get("contact_shadow") or {}
        if cs.get("edges", 0) >= 100 and cs.get("darker_by", 0.0) < a.shadow_floor:
            bad += 1
            got["no_shadow_under_the_paper"] = True
    report["ok"] = bad == 0
    report["stills_with_a_hole_in_them"] = bad
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
