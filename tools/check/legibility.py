#!/usr/bin/env python3
"""Every word in the evidence is read off the surface it was actually written on.

    python3 tools/check/legibility.py
    python3 tools/check/legibility.py --out evidence/legibility.json
    python3 tools/check/legibility.py --only 02_chat.png --worst 40

There is already a test for this — `app/test/legible_on_what_it_is_on_test.dart` — and it passes,
and the text is still hard to read. It passes because it checks three declared constants against
two declared grounds: `Pen.ballpoint` on `#F1ECDF`, `Pen.margin` on the desk, and the two hands on
the palest stock. That is six numbers out of a build whose grounds are photographs.

What it cannot see is everything that actually happens:

- ink over *rendered* paper, where the ground is not `#F1ECDF` but a fibre field that runs several
  grey levels either side of it, with printed rules and a shadow gradient crossing the letters;
- a stamped label on an index-card tab, which is a different stock at a different exposure;
- anything at dusk, where the whole library is re-rendered against a desk lamp and not one
  declared constant moved;
- a caption over a photograph, where the ground is whatever the photograph is;
- and the antialiasing, which is most of a thin handwritten stroke. A 2px ballpoint line specified
  at 8.9:1 does not put 8.9:1 on the glass; it puts a core of that and a halo of much less.

So this reads the captured artifacts instead of the source, finds the marks that are shaped like
writing, and measures each one against the pixels immediately around it.

Finding writing by its shape is the part that went wrong, and it went wrong in the way the line
above admits it could. A surface that acquires texture acquires glyph-shaped marks: when the
corrected day illuminant stopped the torn paper lips clipping to flat white, their fibre steps
became marks, and 137 runs arrived in one capture that had never existed, 102 of them below the
floor — a 74% failure rate against 21% on the 622 runs that were really there. The instrument's
noise was larger than the change it was being used to judge.

The app knows where its text is. `window.__deskTextRuns` (app/lib/capture/hooks.dart) walks the
render tree at the moment of the shot and writes every drawn paragraph's line rects, type size in
device pixels, font and declared ink beside the PNG as `<name>.text.json`. Where that sidecar
exists, a mark is measured only if it sits inside a line the app says it drew, and a run is a
declared line rather than a group of shapes that happened to queue up. Nothing about the
measurement changes: the contrast is still read off the real pixels, with the real antialiasing and
the real fibre in the ground, because that is the whole reason for reading the artifact. What the
sidecar changes is only *where this is allowed to look*.

Where the sidecar does not exist — every capture taken before the handle did — this behaves exactly
as it always has, so an older artifact is still measurable and `legibility_delta.py` still pairs.
Which of the two happened is reported per artifact as `text_runs`, because a number measured by one
and compared against the other is not a comparison.

Two numbers are reported per run, because they answer two different questions:

  ink_core    the darkest tenth of the stroke against its ground. This is the fair comparison to
              WCAG, which is specified against flat colour, and it is what the floors gate on.
  ink_median  the whole stroke against its ground — what the eye is actually given once the
              antialiasing is counted. Always the lower of the two. Reported, never gated, because
              gating on it would fail every hairline in every hand-drawn face ever made.

A run is not asked to be a paragraph. It is a connected group of glyph-shaped marks sitting on one
line, which is the unit a person reads and the unit a bad ground ruins.
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

# WCAG 2.1 non-text and large-text is 3:1, body is 4.5:1. The split here is by rendered height
# because that is all an image knows: WCAG's "large" is 18.66px bold or 24px regular at CSS scale,
# and these artifacts are captured at 3x, so the boundary lands at 72 device pixels. Anything
# shorter is asked for 4.5.
# WCAG 2.1 non-text and large-text is 3:1, body is 4.5:1. The split here is by rendered height,
# because a captured image is all this has: WCAG's "large" is 24px regular at CSS scale, and these
# artifacts are captured at about 3x device pixel ratio, so the boundary lands near 72 device
# pixels. Anything shorter is asked for 4.5.
LARGE_PX = 72
FLOOR_BODY = 4.5
# docs/COLOR.md section 6 raises large from WCAG's 3.0 to 4.0. WCAG's large-text exemption exists
# because a larger glyph has a thicker stroke, which is true of the bold sans the standard was
# calibrated against and is not true here: large text in this app is handwriting, whose stroke
# width comes from a pen model and barely moves with the point size, so setting it larger buys
# height and not weight. The exemption is not one this build ever earned.
FLOOR_LARGE = 4.0
# Dusk gets half a point more at both sizes. WCAG's formula carries a constant 0.05 that models
# roughly 5 percent viewing flare in a lit room; in a dark room the real flare is lower, so the
# formula overstates the contrast of dark pairs. docs/COLOR.md section 6 records that this pair is
# a judgment rather than a measurement, and names the capture that would settle it.
FLOOR_BODY_DUSK = 5.0
FLOOR_LARGE_DUSK = 4.5

# What counts as a mark shaped like writing. Expressed as a fraction of image height rather than
# in pixels, because the Android stills are 1440x3120 and the PWA stills are 1080x2340 and a
# constant would mean something different in each. At 2340 tall these are 14px and 117px.
GLYPH_MIN_H_FRAC = 0.006
GLYPH_MAX_H_FRAC = 0.050
GLYPH_MIN_AREA = 24
GLYPH_MAX_AREA = 12000

# How far a mark has to sit from the paper before it is a mark at all. This is measured in gamma
# space — the 0..1 sRGB value, not relative luminance — because luminance is so compressed at the
# dark end that one threshold cannot serve both a pencil line on cream paper and a stamped label
# on waxed oak. In luminance, 0.055 is most of the range below mid grey and almost none of the
# range above it, which is how the first version of this file managed to report 1.00:1 on the
# desk: it swallowed the whole dark region as ink and then had no ground left to compare it to.
INK_DELTA = 0.07
GROUND_WINDOW = 81      # the box the ink threshold is taken over, odd, in pixels
RING = 10               # the least distance around a run that the ground is sampled from
GROUND_PCTL = 90        # the ground under dark ink is the light end of what surrounds it
# How wide the ground's own variation has to be before the flattering end stops being a fair
# reading of it. A sheet of stock swings a few percent and reads the same everywhere under a
# letter; a plank of waxed oak swings 1.62:1 by day and 1.53:1 at dusk, so a pair computed against
# one point of it is a number about a surface the letters are not sitting on. Below this gate the
# ring percentile above is kept, because it is the right answer for flat paper and was arrived at
# the hard way (see the note below). At or above it the floor is required against the adversarial
# end instead -- the darkest ground under dark ink, the lightest under light ink.
GROUND_SWING_GATE = 1.20
# The ground is sampled with every mark, and a couple of pixels of halo around each mark, taken
# out of it. That exclusion is what makes a low percentile meaningful at all: the ring around a
# letter is mostly that letter's own antialiasing, so the dark end of "every pixel in the ring"
# is the halo rather than the paper, and gating on it would report every word in the build at
# about one to one. GROUND_PCTL dodges that by reading the light end; this reads the real ground.
GROUND_HALO = 2
# A pale mark only means writing when the thing under it is dark. On paper, "lighter than the
# local mean" is a highlight, the lit side of a curl, or correction fluid, and reading those as
# letters put a line of ordinary body text at 1.66:1 when its pair is 4.55:1. So the pale pass
# only reports where the ground is genuinely dark — the desk, a photograph, a dusk render.
LIGHT_ON_DARK_MAX_GROUND = 0.30

# How far outside a declared line a mark may sit and still be that line's. A line box runs from
# the ascent to the descent of the type, so an upright glyph is comfortably inside it; what needs
# the slack is the two hands, which are slanted and pressure-varying and overhang their own metrics
# at the ends of strokes, and the antialiasing, which is most of a hairline. Expressed as a
# fraction of the line's own height so it means the same thing on a 12.5pt margin note and a 19pt
# hand, with a floor in pixels for the short ones. It is deliberately generous: this test exists to
# throw out fibre in the middle of a torn lip, which is nowhere near a line of writing, not to
# adjudicate a millimetre at the end of a descender.
DECLARED_PAD_FRAC = 0.35
DECLARED_PAD_MIN = 6

# The ground is taken over every pixel in the ring box and not only the ones outside the stroke
# mask. That is deliberate and it was wrong the first time: in a dense paragraph the pixels around
# a letter are mostly its own antialiasing, so "everything that is not ink" has a light end that
# is not the paper but the halo, and the ground sinks toward the ink. It read a line of Pen.margin
# on lined stock at 2.83:1 when the pair is 4.55:1. A high percentile over the whole ring finds
# the paper whether or not the halo is in the sample.

# A RUN'S GROUND IS THE SURFACE THE LETTERS ARE ON, AND THE APP'S OWN INK IS NOT THAT SURFACE.
#
# The glyph filters above are deliberately strict, because their job is to decide what gets
# *measured*. Using the same filters to decide what gets *excluded from the ground* is a different
# question with a different answer, and conflating the two is what made this file fail writing
# against its own ink. Three kinds of the app's own mark miss those filters and so stayed in the
# ground as the adversarial dark end the floor was taken against:
#
#   - the two dots of a `:`, 5x5 and area 18, under both GLYPH_MIN_AREA and min_h;
#   - digits that touch a printed rule of the stock and merge into one 543x31 component, thrown
#     out on the 14:1 aspect filter;
#   - a drawn rule or an underline, thrown out on aspect on its own.
#
# So "Wed 22 Apr 16:44" was failed at 1.02:1 against the ink of its own colon and its own 44, and
# "the six words" -- black ink on cream, legible at 400% -- at 1.14:1 against the two heavy rules
# the widget draws above and below it. This is the mirror image of the fibre problem the sidecar
# was built for: that was the detector reading a surface as writing, this is it reading writing as
# a surface.
#
# The rule that separates them is SCALE, measured against the line the mark sits in, and it is the
# app that supplies the scale. A mark drawn on a surface is no taller than the writing it sits
# among; a surface is taller than the writing on it. Both halves matter, and the second is the one
# that kept this honest -- 12_search's `PHOTOGRAPHS` is a torn tab in two halves with the desk
# showing through the gap between the O and the T, and that desk is one 1408x685 component against
# a 37px line. A ruler that cannot see a hole in the paper a word is written across is not the one
# to have, and a height test sees it: 685 is not 37. Every giant surface component on the set is
# five to twenty times its line's height, and every piece of the app's own ink is under it.
#
# What this does NOT do is anchor the ground band anywhere new: the band is still grown from the
# accepted glyphs alone (`glyph_px`), so it still hugs real letters. The extra ink is only denied
# the right to *be* the ground. And it applies only where the app declared its text, so a capture
# taken before the sidecar existed reads exactly as it did.
FIGURE_MAX_H_OVER_LINE = 1.0


def srgb_to_linear(a):
    return np.where(a <= 0.03928, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def luminance(rgb):
    """WCAG relative luminance, per pixel, from 8-bit sRGB."""
    lin = srgb_to_linear(rgb.astype(np.float64) / 255.0)
    return 0.2126 * lin[..., 0] + 0.7152 * lin[..., 1] + 0.0722 * lin[..., 2]


def contrast(a, b):
    hi, lo = (a, b) if a >= b else (b, a)
    return (hi + 0.05) / (lo + 0.05)


def box_mean(a, k):
    """Mean over a k x k window, by summed-area table. Edges repeat rather than darken."""
    pad = k // 2
    p = np.pad(a, pad, mode="edge")
    s = p.cumsum(axis=0).cumsum(axis=1)
    s = np.pad(s, ((1, 0), (1, 0)), mode="constant")
    h, w = a.shape
    tot = s[k:k + h, k:k + w] - s[0:h, k:k + w] - s[k:k + h, 0:w] + s[0:h, 0:w]
    return tot / float(k * k)


def dilate(mask, r):
    """Grow a boolean mask by r pixels, so a mark's antialiasing comes with it."""
    if r <= 0:
        return mask
    k = 2 * r + 1
    return box_mean(mask.astype(np.float64), k) > (0.5 / (k * k))


def label(ink):
    """Connected components of a boolean mask, by union-find over the set pixels only.

    The first version of this propagated the largest index through the whole array until it
    stopped changing, which is elegant and reads well and took a hundred and four seconds for one
    still. Ink is one or two percent of an image, so there is no reason to do arithmetic on the
    other ninety-eight: this walks the set pixels, unions each with the neighbour above and the
    neighbour to the left, and is done in about a second.
    """
    ys, xs = np.nonzero(ink)
    n = ys.size
    if n == 0:
        return ys, xs, np.empty(0, dtype=np.int64)
    at = -np.ones(ink.shape, dtype=np.int64)
    at[ys, xs] = np.arange(n)

    up = np.where(ys > 0, at[np.maximum(ys - 1, 0), xs], -1)
    left = np.where(xs > 0, at[ys, np.maximum(xs - 1, 0)], -1)

    parent = list(range(n))

    def find(a):
        root = a
        while parent[root] != root:
            root = parent[root]
        while parent[a] != root:       # path compression, iterative: these chains get long
            parent[a], a = root, parent[a]
        return root

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    for nbr in (up, left):
        idx = np.nonzero(nbr >= 0)[0]
        nb = nbr[idx]
        for a, b in zip(idx.tolist(), nb.tolist()):
            union(a, b)

    roots = np.fromiter((find(i) for i in range(n)), dtype=np.int64, count=n)
    return ys, xs, roots


def declared_lines(sidecar):
    """Every declared line in one sidecar, as arrays of y0, y1, x0, x1 and the run it belongs to.

    Flattened across paragraphs because the unit being matched is the line: a paragraph of four
    lines is four separate readings, each against its own ground, which is what a person does and
    what this file has always reported.
    """
    y0, y1, x0, x1, owner = [], [], [], [], []
    for i, run in enumerate(sidecar.get("runs", [])):
        for rect in run.get("lines") or [run.get("rect")]:
            if not rect:
                continue
            x, y, w, h = rect
            if w < 1 or h < 1:
                continue
            y0.append(y); y1.append(y + h); x0.append(x); x1.append(x + w); owner.append(i)
    return (np.array(y0, dtype=np.float64), np.array(y1, dtype=np.float64),
            np.array(x0, dtype=np.float64), np.array(x1, dtype=np.float64),
            np.array(owner, dtype=np.int64))


def line_of(boxes, lines):
    """Which declared line each glyph box belongs to, or -1 for none of them.

    A box is placed by its centre inside the padded line, and where two padded lines both take it
    — set solid, they overlap — the nearer centre wins. Returns one index per box, into the
    flattened line arrays.
    """
    ly0, ly1, lx0, lx1, _ = lines
    n = len(boxes)
    if n == 0 or ly0.size == 0:
        return np.full(n, -1, dtype=np.int64)
    b = np.asarray(boxes, dtype=np.float64)            # (n, 4) as y0, y1, x0, x1
    cy = ((b[:, 0] + b[:, 1]) / 2.0)[:, None]
    cx = ((b[:, 2] + b[:, 3]) / 2.0)[:, None]
    pad = np.maximum(DECLARED_PAD_MIN, DECLARED_PAD_FRAC * (ly1 - ly0))[None, :]
    inside = ((cy >= ly0[None, :] - pad) & (cy <= ly1[None, :] + pad) &
              (cx >= lx0[None, :] - pad) & (cx <= lx1[None, :] + pad))
    mid = ((ly0 + ly1) / 2.0)[None, :]
    dist = np.where(inside, np.abs(cy - mid), np.inf)
    best = np.argmin(dist, axis=1)
    return np.where(np.isfinite(dist[np.arange(n), best]), best, -1)


def figure_of(rejected, ys, xs, lines, shape, polarity, surround):
    """The app's own marks among the components the glyph filters threw out.

    A rejected component is the app's ink -- figure -- when it overlaps the padded rect of a
    declared line *and* is no taller than that line. Anything taller is the surface the line is
    written on: a sheet, a shadow field, a photograph, or the desk showing through a hole torn in
    the paper. Returns their pixels as a mask, for removal from the ground.

    The overlap is the component's box against the line's box, not its centre against it, because
    the case this exists for is a rule that runs the width of the sheet through a line of digits:
    its centre is off in the rule and a containment test never sees it.

    A PALE MARK IS ONLY THE APP'S INK WHERE WHAT IT SITS ON IS DARK, which is the same asymmetry
    the measuring loop already applies through LIGHT_ON_DARK_MAX_GROUND and for the same reason:
    on paper, lighter-than-local is a highlight, the lit side of a curl, or the tooth of the
    stock, and all three are the surface. Taken symmetrically this rule removed the bright half
    of `02_chat`'s paper from the ground under "Wed 22 Apr · 16:34", which left the sample's dark
    tail exposed, lifted its swing from 1.07 through the 1.20 gate to 1.29 and turned a 4.70 into
    a 3.65 failure. [surround] is the local paper level -- the same box mean the ink threshold is
    taken against -- read in luminance so it can be compared to that constant.
    """
    ly0, ly1, lx0, lx1, _ = lines
    out = np.zeros(shape, dtype=bool)
    if ly0.size == 0 or not rejected:
        return out
    r = np.asarray([t[:4] for t in rejected], dtype=np.float64)   # (n, 4) y0, y1, x0, x1
    pad = np.maximum(DECLARED_PAD_MIN, DECLARED_PAD_FRAC * (ly1 - ly0))[None, :]
    lh = (ly1 - ly0)[None, :]
    hit = ((r[:, 1:2] > ly0[None, :] - pad) & (r[:, 0:1] < ly1[None, :] + pad) &
           (r[:, 3:4] > lx0[None, :] - pad) & (r[:, 2:3] < lx1[None, :] + pad) &
           ((r[:, 1:2] - r[:, 0:1]) <= FIGURE_MAX_H_OVER_LINE * lh))
    for i in np.nonzero(hit.any(axis=1))[0]:
        a, b = rejected[i][4], rejected[i][5]
        yy, xx = ys[a:b], xs[a:b]
        if polarity == "light" and float(np.median(surround[yy, xx])) > LIGHT_ON_DARK_MAX_GROUND:
            continue
        out[yy, xx] = True
    return out


def group_by_line(boxes, owner, lines, sidecar):
    """One run per declared line that actually has marks in it, in reading order.

    The run's own box is the union of the marks found in that line, not the declared rect: the
    ground is sampled around the ink, and a declared line box runs from ascent to descent across
    the full measure of the text, which on a short last line is mostly paper.

    A declared line with no marks in it produces nothing. That is not a silence to worry about --
    it is a paragraph behind another sheet, or scrolled under the fold, or inside a zero opacity.
    The handle declares what was drawn, not what can be seen, and the two are reconciled here by
    intersection.
    """
    runs = sidecar.get("runs", [])
    _, _, _, _, line_owner = lines
    by_line = {}
    for i, b in enumerate(boxes):
        by_line.setdefault(int(owner[i]), []).append(b)
    out = []
    for li in sorted(by_line):
        bs = by_line[li]
        y0 = min(b[0] for b in bs)
        y1 = max(b[1] for b in bs)
        x0 = min(b[2] for b in bs)
        x1 = max(b[3] for b in bs)
        decl = runs[int(line_owner[li])] if line_owner.size else None
        out.append((y0, y1, x0, x1, len(bs), decl))
    return out


def runs_of(boxes, gap=26):
    """Group glyph boxes that sit on one line into runs, left to right."""
    out = []
    for b in sorted(boxes, key=lambda b: (b[0] // 24, b[2])):
        y0, y1, x0, x1 = b
        placed = False
        for r in out:
            overlap = min(y1, r[1]) - max(y0, r[0])
            if overlap > 0.45 * min(y1 - y0, r[1] - r[0]) and x0 - r[3] < gap and x1 > r[2] - gap:
                r[0], r[1] = min(r[0], y0), max(r[1], y1)
                r[2], r[3] = min(r[2], x0), max(r[3], x1)
                r[4] += 1
                placed = True
                break
        if not placed:
            out.append([y0, y1, x0, x1, 1])
    return out


def marks(gam, ground_gam, polarity):
    """Pixels that sit far enough off the local paper to be a mark, in gamma space."""
    if polarity == "dark":
        return gam < (ground_gam - INK_DELTA)
    return gam > (ground_gam + INK_DELTA)


def measure(path, floor_body=FLOOR_BODY, floor_large=FLOOR_LARGE, sidecar=None):
    with Image.open(path) as im:
        rgb = np.asarray(im.convert("RGB"))
    H, W = rgb.shape[:2]
    lum = luminance(rgb)                                  # for the arithmetic WCAG specifies
    gam = rgb.astype(np.float64).mean(axis=2) / 255.0     # for deciding what is a mark
    ground_gam = box_mean(gam, GROUND_WINDOW)
    # The same local paper level again in luminance, so `figure_of` can ask whether what a pale
    # mark sits on is dark against LIGHT_ON_DARK_MAX_GROUND, which is a luminance constant.
    lum_bg = box_mean(lum, GROUND_WINDOW)

    min_h = max(7, int(GLYPH_MIN_H_FRAC * H))
    max_h = int(GLYPH_MAX_H_FRAC * H)

    # Find the writing first, in both polarities, and only then measure it. The two passes exist
    # so that the ground can have every accepted glyph taken out of it, including the ones in the
    # other polarity: a pale stamp sitting beside dark ink would otherwise be read as that ink's
    # paper.
    #
    # What is excluded is the accepted glyphs, and NOT everything `marks()` returns. That
    # distinction is the whole of this: `marks()` is a mark detector and on a plank it fires on
    # the grain, 41.6% of the frame in `02_chat.png`. Excluding all of that would take the grain
    # out of the ground, and the grain *is* the ground -- its spread is precisely what
    # `ground_swing` is asking about. So only the shapes that survived the size and aspect filters
    # come out, grown by GROUND_HALO to take their antialiasing with them.
    if sidecar is not None:
        # A sidecar written against a different frame is worse than no sidecar at all: it would
        # hand this permission to look at pixels that are somewhere else in this image. Refuse
        # rather than measure, because the failure is silent in both directions -- runs that are
        # not there, and real text that is never looked at.
        declared_size = list(sidecar.get("size") or [])
        if declared_size != [W, H]:
            raise ValueError(
                f"{os.path.basename(path)}: its text sidecar was written for {declared_size} and "
                f"the image is {[W, H]}")
    lines = declared_lines(sidecar) if sidecar else None
    if lines is not None and lines[0].size == 0:
        # A sidecar that declares nothing is a screen with no writing on it, which is a fact and
        # not a missing file. Everything the mark detector finds here is the surface.
        lines = (np.empty(0), np.empty(0), np.empty(0), np.empty(0), np.empty(0, dtype=np.int64))

    found = []
    outside = 0
    glyph_px = np.zeros((H, W), dtype=bool)
    figure_px = np.zeros((H, W), dtype=bool)
    for polarity in ("dark", "light"):
        mask = marks(gam, ground_gam, polarity)
        if mask.sum() < 60:
            continue
        ys, xs, roots = label(mask)
        if roots.size == 0:
            continue
        order = np.argsort(roots, kind="stable")
        ys, xs, roots = ys[order], xs[order], roots[order]
        starts = np.searchsorted(roots, np.unique(roots))
        bounds = list(starts) + [roots.size]

        boxes, pixels = [], []
        rejected = []                          # (y0, y1, x0, x1, a, b) for the figure test below
        for i in range(len(bounds) - 1):
            a, b = bounds[i], bounds[i + 1]
            area = b - a
            yy, xx = ys[a:b], xs[a:b]
            y0, y1 = int(yy.min()), int(yy.max()) + 1
            x0, x1 = int(xx.min()), int(xx.max()) + 1
            h, w = y1 - y0, x1 - x0
            if (GLYPH_MIN_AREA <= area <= GLYPH_MAX_AREA and min_h <= h <= max_h
                    # a printed rule, a tear edge, a stem of nothing
                    and not (w > 14 * h or h > 14 * w)):
                boxes.append((y0, y1, x0, x1))
                pixels.append((yy, xx))
            else:
                rejected.append((y0, y1, x0, x1, a, b))

        # Where the app declared its text, a shape that survived the size and aspect filters is
        # writing only if it sits in a line the app says it drew. The rest go back into the ground
        # they came out of -- which is the correct place for them, and the same reasoning as the
        # note above about the grain: fibre IS the surface, and taking it out of the ground would
        # be measuring the paper against a version of itself with its texture removed.
        if lines is not None:
            owner = line_of(boxes, lines)
            outside += int((owner < 0).sum())
            keep = [i for i in range(len(boxes)) if owner[i] >= 0]
            boxes = [boxes[i] for i in keep]
            pixels = [pixels[i] for i in keep]
            owner = owner[[i for i in keep]] if keep else np.empty(0, dtype=np.int64)
        else:
            owner = None

        for yy, xx in pixels:
            glyph_px[yy, xx] = True
        # The app's own ink that the glyph filters threw out: shorter than the line it overlaps,
        # so a mark on that surface rather than the surface itself. Out of the ground, and not
        # into `glyph_px`, because it is not measured and must not anchor the band either.
        if lines is not None and rejected:
            figure_px |= figure_of(rejected, ys, xs, lines, (H, W), polarity, lum_bg)
        found.append((polarity, mask, boxes, owner))

    figure_px |= glyph_px
    is_ground = ~dilate(figure_px, GROUND_HALO)

    out = []
    seen = 0
    for polarity, mask, boxes, owner in found:
        seen += len(boxes)
        # A run is a declared line's worth of marks where there is a sidecar, and a group of
        # shapes that queued up where there is not. The first is the unit the app authored; the
        # second is runs_of's guess at it, kept unchanged so an older artifact reads as it did.
        if owner is not None:
            grouped = group_by_line(boxes, owner, lines, sidecar)
        else:
            grouped = [(r[0], r[1], r[2], r[3], r[4], None) for r in runs_of(boxes)]
        for y0, y1, x0, x1, n, decl in grouped:
            ring = max(RING, (y1 - y0) // 2)
            ry0, ry1 = max(0, y0 - ring), min(H, y1 + ring)
            rx0, rx1 = max(0, x0 - ring), min(W, x1 + ring)
            pl = lum[ry0:ry1, rx0:rx1]
            pm = mask[ry0:ry1, rx0:rx1]
            pg = is_ground[ry0:ry1, rx0:rx1]
            pmg = glyph_px[ry0:ry1, rx0:rx1]
            # A run's ink is the glyphs, not every mark near them.
            #
            # `pm` is every pixel of this polarity the detector fired on inside the ring box --
            # the components the glyph filters rejected included, and the desk included. Taking
            # the tenth percentile of that reports the contrast of whatever is darkest in the
            # neighbourhood against the ground, and calls it the writing's contrast. Measured on
            # 12_search's `PHOTOGRAPHS`: the ink sample is 2833 px of which 994, thirty-five
            # percent, are not glyphs at all; those 994 have p10 0.0047 while the letters
            # themselves are a flat 0.0615, and the gated ground is 0.0114. So the tool read
            # contrast(0.0072, 0.0114) = 1.07 for a word that is plainly legible.
            #
            # `glyph_px` is what the tool already accepted as letters, and the ground band is
            # already grown from it alone. Using it here as well is the same rule applied to both
            # ends of the comparison. It also lets the `on_the_far_side` guard below do its job:
            # with the letters' own luminance in hand, a ground darker than the ink is recognised
            # as a second surface behind a hole in the paper rather than as this ink's ground, and
            # the ring reading stands. That guard was being defeated by being handed a wrong ink.
            stroke = pl[pm & pmg]
            if stroke.size < 40 or pl.size < 400:
                continue
            if polarity == "dark":
                core = float(np.percentile(stroke, 10))         # the darkest of the stroke
                g = float(np.percentile(pl, GROUND_PCTL))       # the lightest of the ring
            else:
                core = float(np.percentile(stroke, 90))         # the lightest of the stroke
                g = float(np.percentile(pl, 100 - GROUND_PCTL)) # the darkest of the ring

            # How wide the ground under this run actually is, and therefore whether the reading
            # above is fair.
            #
            # The sample is the band hugging the letters -- everything within half a glyph height
            # of a stroke, minus the strokes and their antialiasing -- and not the whole ring box.
            # That distinction is load-bearing: the ring is a rectangle, so for a line of text
            # near the edge of a sheet it reaches out onto whatever is beside the sheet, and an
            # adversarial end taken over the whole of it reports a surface the letters are not on.
            #
            # It is worth writing down what the readings of about one to one turned out to be,
            # because they look like a bug and are not one. They are dark marks sitting on the
            # desk, whose band has a median luminance of 0.12 -- the wood -- and whose dark grain
            # reaches 0.088, which is as dark as the marks themselves. docs/COLOR.md section 6
            # predicted exactly this from the other direction: 4.5:1 against the plank requires a
            # darker ink at Y -0.006, so a dark mark on the wood has essentially no contrast to
            # measure. The ring reading flattered these at 1.4 to 8.0 by reading the light end of
            # the grain; one to one is the truthful number.
            # The band is never abandoned for the whole ring box. Falling back to the ring is what
            # the paragraph above says is wrong -- the ring is a rectangle, and for a line near
            # the edge of a sheet it reaches out onto whatever is beside the sheet -- and this
            # file did it anyway, `ground = pl[near] if near.sum() >= 200 else pl[pg]`, whenever
            # the band came up short. Taking the app's own ink out of the ground makes a short
            # band commoner, so the fallback had to go before the rule above could land: firing
            # 14 measured `03_us`'s "18 Jul" arriving as a new failure through exactly it.
            #
            # What replaces it is nothing: where the band cannot find 200 pixels of surface, no
            # adversarial end is claimed and the ring percentile stands, which is the flat-paper
            # answer and the conservative one. GROWING the band instead was tried and is worse --
            # at two to four times it stops hugging the letters, which is the band's whole
            # meaning, and it reached a neighbouring surface and turned `02_chat`'s
            # "Wed 22 Apr · 16:34" from 4.70 into a 3.65 failure against a ground 20 points
            # darker than its paper. The short-band case is a small run enclosed by its own ink,
            # which is flat paper by construction; a run on the desk has thousands of pixels of
            # grain in its band and never reaches this.
            band = max(3, (y1 - y0) // 2)
            near = dilate(pmg, band) & pg
            ground = pl[near]
            swing, g_adv = None, None
            if ground.size >= 200:
                g_lo = float(np.percentile(ground, 5))
                g_hi = float(np.percentile(ground, 95))
                swing = round(contrast(g_hi, g_lo), 2)
                g_adv = g_lo if polarity == "dark" else g_hi
            # On flat paper the ring percentile is kept: it is the right answer there and it was
            # arrived at the hard way. On a ground that moves, the floor is required against the
            # end that is worst for this ink -- no fudge factor, just the correct comparison
            # instead of a flattering one.
            gated = g
            if swing is not None and swing >= GROUND_SWING_GATE and g_adv is not None:
                # A ground has to be on the far side of the ink from the reader, or it is not
                # this ink's ground. Dark ink is written on something lighter than itself; pale
                # ink on something darker. Where the adversarial end crosses the stroke -- a line
                # of dark text with the status bar or a photograph inside its band, a pale label
                # beside something paler still -- what has been found is a second surface rather
                # than the one the letters are on, and the ring reading is kept instead. Without
                # this, fifty runs in `02_chat.png` alone reported one to one, none of which was
                # a real failure and all of which would have drowned the ones that are.
                on_the_far_side = (g_adv > core) if polarity == "dark" else (g_adv < core)
                if on_the_far_side:
                    gated = g_adv
            # The test is the median of the surface, not its dark end. A paragraph of dark ink on
            # cream has a very dark tenth percentile — it is full of letters — and reading that as
            # "a dark ground" turns ordinary text inside out and reports the paper as failing ink.
            if polarity == "light" and float(np.median(pl)) > LIGHT_ON_DARK_MAX_GROUND:
                continue
            med = float(np.median(stroke))
            height = y1 - y0
            width = x1 - x0
            # One narrow mark on its own is a pen stroke, a rule end or a piece of a drawn
            # feeling, not writing. Writing is either several glyphs on a line or one wide
            # connected word, which is what a cursive hand produces.
            if n < 2 and width < 2 * height:
                continue
            # Which floor this run is held to. The size of type is a thing the app decided, and
            # where it has said so that is what is read: `px` is the point size in the
            # screenshot's own pixels. Measuring it off the bounding box of the found marks -- all
            # this could do before -- reads a line with no ascender and no descender in it as
            # several points smaller than it is, and asks a large heading for the body floor.
            size_px = float(decl["px"]) if decl and decl.get("px") else float(height)
            large = size_px >= LARGE_PX
            floor = floor_large if large else floor_body
            entry = {
                "box": [x0, y0, x1 - x0, height],
                "glyphs": n,
                "polarity": polarity,
                "role": "large" if large else "body",
                "floor": floor,
                # What the floors gate on: measured against the adversarial end of the ground
                # wherever the ground moves enough to have one.
                "ink_core": round(contrast(core, gated), 2),
                "ink_median": round(contrast(med, gated), 2),
                # The ring reading this file has always reported, kept alongside so that the two
                # can be compared and so that nothing that was true before quietly stops being
                # reported. On flat paper they are the same number.
                "ink_core_ring": round(contrast(core, g), 2),
                "ground_swing": swing,
                "ground_lum": round(gated, 4),
                "ground_lum_ring": round(g, 4),
            }
            if decl:
                # So a failure can be read as a sentence rather than cropped out of the PNG at
                # 300%, which is what firing 9 had to do to establish that the extra runs were
                # fibre. This is the app's own answer to "what does it say", not an inference.
                entry["says"] = decl.get("text", "")
                entry["px"] = decl.get("px")
                entry["points"] = decl.get("points")
                entry["family"] = decl.get("family", "")
                entry["hand"] = decl.get("role", "")
                entry["ink"] = decl.get("ink", "")
            out.append(entry)
    result = {"runs": out, "glyphs": seen, "size": [W, H]}
    if lines is not None:
        result["text_runs"] = "declared"
        result["declared_lines"] = int(lines[0].size)
        # The size of the problem this sidecar exists to remove: shapes that passed every test for
        # being a glyph and are not in any line the app drew.
        result["marks_outside_text"] = outside
    else:
        result["text_runs"] = "found-by-shape"
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--only", default="", help="one artifact filename")
    ap.add_argument("--worst", type=int, default=12, help="how many failures to print")
    ap.add_argument("--dir", default=EVIDENCE)
    ap.add_argument("--dusk", default="",
                    help="comma-separated artifacts captured under the dusk rig; they are held to "
                         "the dusk floors in docs/COLOR.md section 6 rather than the day ones")
    ap.add_argument("--text-runs", default="auto", choices=("auto", "off", "require"),
                    help="use the <name>.text.json the capture wrote beside each still, which is "
                         "what the app says it drew. auto: where there is one. off: never, which "
                         "is how every capture before the handle existed was measured and the "
                         "only fair way to compare against one. require: fail if any is missing")
    args = ap.parse_args()
    dusk = {n.strip() for n in args.dusk.split(",") if n.strip()}

    paths = sorted(glob.glob(os.path.join(args.dir, "*.png")))
    if args.only:
        paths = [p for p in paths if os.path.basename(p) == args.only]
    if not paths:
        print(f"legibility: no PNGs in {args.dir}", file=sys.stderr)
        return 2

    report = {
        "mode": "measured-from-pixels",
        "floors": {"body": FLOOR_BODY, "large": FLOOR_LARGE, "large_above_px": LARGE_PX,
                   "body_dusk": FLOOR_BODY_DUSK, "large_dusk": FLOOR_LARGE_DUSK,
                   "ground_swing_gate": GROUND_SWING_GATE},
        "dusk": sorted(dusk),
        "artifacts": {},
        "failures": [],
    }
    missing_sidecars = []
    for path in paths:
        name = os.path.basename(path)
        sidecar = None
        if args.text_runs != "off":
            side = path[:-4] + ".text.json" if path.endswith(".png") else path + ".text.json"
            if os.path.exists(side):
                with open(side, encoding="utf-8") as f:
                    sidecar = json.load(f)
            else:
                missing_sidecars.append(name)
        m = measure(path,
                    FLOOR_BODY_DUSK if name in dusk else FLOOR_BODY,
                    FLOOR_LARGE_DUSK if name in dusk else FLOOR_LARGE,
                    sidecar=sidecar)
        runs = m.get("runs", [])
        bad = [r for r in runs if r["ink_core"] < r["floor"]]
        worst = min((r["ink_core"] for r in runs), default=None)
        report["artifacts"][name] = {
            "runs": len(runs),
            "below_floor": len(bad),
            # Which instrument read this artifact. A number taken one way and compared against a
            # number taken the other is not a comparison, and the whole of firing 9 was spent
            # establishing that after the fact.
            "text_runs": m.get("text_runs"),
            "declared_lines": m.get("declared_lines"),
            "marks_outside_text": m.get("marks_outside_text"),
            "worst_ink_core": worst,
            "median_ink_core": round(float(np.median([r["ink_core"] for r in runs])), 2) if runs else None,
            "median_as_rendered": round(float(np.median([r["ink_median"] for r in runs])), 2) if runs else None,
            "detail": sorted(bad, key=lambda r: r["ink_core"])[:60],
        }
        for r in bad:
            f = {
                "artifact": name, "box": r["box"], "role": r["role"], "polarity": r["polarity"],
                "ink_core": r["ink_core"], "ink_median": r["ink_median"], "floor": r["floor"],
                "ink_core_ring": r["ink_core_ring"], "ground_swing": r["ground_swing"],
            }
            if "says" in r:
                f["says"] = r["says"]
                f["hand"] = r["hand"]
                f["ink"] = r["ink"]
                f["px"] = r["px"]
            report["failures"].append(f)

    report["failures"].sort(key=lambda f: f["ink_core"])
    # How much of the tally is the adversarial reading rather than the ring one. A firing that
    # wants to compare against an older report needs to know which of the two it is looking at.
    report["on_moving_ground"] = sum(
        1 for f in report["failures"]
        if f["ground_swing"] is not None and f["ground_swing"] >= GROUND_SWING_GATE)
    report["would_pass_on_ring_reading"] = sum(
        1 for f in report["failures"] if f["ink_core_ring"] >= f["floor"])
    report["read"] = len(paths)
    report["total_runs"] = sum(a["runs"] for a in report["artifacts"].values())
    report["total_below_floor"] = len(report["failures"])
    report["text_runs"] = args.text_runs
    report["measured_from_declared_text"] = sum(
        1 for a in report["artifacts"].values() if a.get("text_runs") == "declared")
    report["without_a_sidecar"] = sorted(missing_sidecars)
    report["marks_outside_text"] = sum(
        a["marks_outside_text"] or 0 for a in report["artifacts"].values()
        if a.get("marks_outside_text") is not None)
    report["ok"] = not report["failures"]

    if args.text_runs == "require" and missing_sidecars:
        print("legibility: --text-runs require, and these stills have no <name>.text.json beside "
              "them:\n  " + "\n  ".join(sorted(missing_sidecars)) +
              "\nThey were captured before window.__deskTextRuns existed, or the scene did not "
              "write one. Re-capture, or measure with --text-runs off and compare only against "
              "another run taken the same way.", file=sys.stderr)
        return 2

    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{report['total_runs']} runs read across {report['read']} artifacts "
              f"-> {args.out}")
    else:
        print(text)

    if report["failures"]:
        print(f"\n{len(report['failures'])} text run(s) below their contrast floor:", file=sys.stderr)
        for f in report["failures"][:args.worst]:
            x, y, w, h = f["box"]
            says = f"  {f['says'][:40]!r}" if f.get("says") else ""
            print(f"  {f['artifact']:<24} {f['ink_core']:>5.2f}:1 (floor {f['floor']}, "
                  f"{f['ink_median']:.2f}:1 as rendered)  {f['role']:<5} {f['polarity']:<5} "
                  f"{w}x{h} at {x},{y}{says}", file=sys.stderr)
        return 1
    print(f"{report['total_runs']} text runs, every one of them above its floor")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
