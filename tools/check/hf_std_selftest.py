#!/usr/bin/env python3
"""What `hf_std.py` can tell apart, and — recorded on purpose — what it cannot.

    python3 tools/check/hf_std_selftest.py

The floor is 4.0 and every strip in the committed evidence set reads 13.5 to 22.5, so this
measurement has never once been red on a real input. A gate that has only ever been green is
indistinguishable from a gate that returns green — which is the `surfaces.py` failure this
repository has already filed once, a folds floor of 1.2 that a blank unruled sheet cleared for
four firings while three critics measured the flatness by hand.

So this builds images the shape `frames.py` writes and asserts, one at a time, what the definition
does with them. Four of the six assertions are ordinary: the splitter finds the frames, it refuses
a strip whose gutters are not the width `frames.py` writes rather than mis-slicing it, a uniform
image fails, and one featureless frame among five is caught rather than averaged away.

Note what the fourth one has to use to be true: a frame with NO structure whatever, not a flat
sheet on a desk. A flat sheet on a desk is not caught, which is the next paragraph.

**THE LAST TWO ASSERT A DEFECT, AND THEY ARE THE REASON THIS FILE EXISTS.** A flat beige rectangle
on a dark ground, with not one pixel of tooth in it, PASSES the floor at about 14.4 — the same
band as every real strip in the set — because on a frame that is not a sheet on a desk the
brightest-45% mask is a scattered brightness slice and HF over a scattered mask is mostly the
scatter. `hf_std.py`'s docstring has the same result on real evidence: the firing 17 strip, taken
when the fold sheet genuinely was that rectangle, reads HIGHER than today's repaired one.

These two assertions are written to pass TODAY, against the definition as firing 28 stated it. When
ADDRESS re-specifies the mask they will go red, and that is what they are for: the day the fix
lands, this file says so instead of staying quietly green. Do not delete them to get green — fix
them to assert the new behaviour, and move the numbers into `hf_std.py`'s docstring.

It writes to a temporary directory and never to `evidence/`. It is a ruler for the ruler.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
HF_STD = os.path.join(HERE, "hf_std.py")
GUTTER_RGB = (28, 24, 20)


def sheet(w, h, tooth, seed=3):
    """A pale sheet on a dark desk, with `tooth` of per-pixel grain on the sheet alone.

    tooth=0 is the flat beige rectangle rank 1 was filed against: square corners, one exact value,
    no fibre, no rules, no tear edge.
    """
    if tooth is None:
        # no desk and no structure: the one input the definition does report as flat
        return Image.new("RGB", (w, h), (246, 236, 214))
    rng = np.random.default_rng(seed)
    a = np.full((h, w, 3), (52, 44, 36), dtype=np.float64)
    y0, y1, x0, x1 = h // 8, h - h // 8, w // 8, w - w // 8
    a[y0:y1, x0:x1] = (246, 236, 214)
    if tooth:
        a[y0:y1, x0:x1] += rng.normal(0.0, tooth, (y1 - y0, x1 - x0, 1))
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def strip(tooths, gutter=4, w=148, h=320):
    """Frames side by side, the way tools/check/frames.py strip() writes them."""
    ims = [sheet(w, h, t, seed=7 + i) for i, t in enumerate(tooths)]
    out = Image.new("RGB", (sum(i.width for i in ims) + gutter * (len(ims) - 1), h), GUTTER_RGB)
    x = 0
    for im in ims:
        out.paste(im, (x, 0))
        x += im.width + gutter
    return out


def run(im, tmp, name, *args):
    path = os.path.join(tmp, name + ".png")
    im.save(path)
    p = subprocess.run([sys.executable, HF_STD, path, *args], capture_output=True, text=True)
    return p.returncode, p.stdout.strip()


CASES = [
    # why                                                 image                     exit  in stdout
    ("a strip splits into its six frames on the gutters",
     lambda: strip([14.0] * 6), 0, "strip 6 frame(s) at 148x320"),
    ("a strip with 6-px gutters is refused, not mis-sliced",
     lambda: strip([14.0] * 6, gutter=6), 0, "whole 1 frame(s)"),
    ("a uniform image with no structure at all fails",
     lambda: Image.new("RGB", (300, 120), (252, 226, 198)), 2, "1 of 1 frames read under"),
    ("one featureless frame among five is caught, not averaged away",
     lambda: strip([14.0, 14.0, None, 14.0, 14.0, 14.0]), 2, "1 of 6 frames read under"),
    # the two that assert the defect
    ("DEFECT: a flat beige rectangle on a dark ground passes",
     lambda: strip([0.0] * 6), 0, "strip 6 frame(s)"),
    ("DEFECT: it passes in the same band as a toothed sheet",
     lambda: strip([0.0] * 6), 0, "HF_std 14."),
]


def main():
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        for i, (why, make, want_code, want_text) in enumerate(CASES):
            code, out = run(make(), tmp, "case%d" % i)
            if code != want_code:
                failures.append("%s: exit %d, wanted %d" % (why, code, want_code))
                print("FAIL  %-54s exit %d, wanted %d\n      %s" % (why, code, want_code, out))
            elif want_text not in out:
                failures.append("%s: did not report %r" % (why, want_text))
                print("FAIL  %-54s did not report %r\n      %s" % (why, want_text, out))
            else:
                print("ok    %-54s exit %d" % (why, code))

    if failures:
        print("\n%d of %d checks failed" % (len(failures), len(CASES)), file=sys.stderr)
        if any("DEFECT" in f for f in failures):
            print("A DEFECT assertion went red. If the mask was re-specified on purpose, that is "
                  "the fix landing: rewrite those two to assert the new behaviour rather than "
                  "deleting them.", file=sys.stderr)
        return 1
    print("\n%d checks passed: four of what it can tell apart, two of what it cannot" % len(CASES))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
