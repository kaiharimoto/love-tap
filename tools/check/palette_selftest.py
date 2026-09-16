#!/usr/bin/env python3
"""Proof that the floors in `palette.py --floors` can be passed, and that each one can be failed.

    python3 tools/check/palette_selftest.py

A gate that is red on every input it will ever see is indistinguishable from a gate that is broken,
and the committed evidence set breaches 62 floors, so it cannot tell the two apart. This builds a
synthetic still out of flat OKLab patches chosen to clear every floor in `docs/COLOR.md` by a
margin, checks that `--floors` exits 0 on it, and then breaks one quantity at a time and checks
that the matching floor — and only work of that shape — comes back.

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
PALETTE = os.path.join(HERE, "palette.py")
ROOT = os.path.dirname(os.path.dirname(HERE))


def oklab_to_srgb(L, C, h_deg):
    """One OKLab lightness/chroma/hue to one sRGB triple, 0..255. Ottosson's inverse matrices."""
    h = np.radians(h_deg)
    a, b = C * np.cos(h), C * np.sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    rgb = np.array([
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ])
    rgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.abs(rgb) ** (1 / 2.4) - 0.055)
    return np.clip(np.round(rgb * 255.0), 0, 255).astype(np.uint8)


# A room that passes. Each row is (share of the frame, L, C, hue) and the shares sum to 1.
# The three L levels land in the three value bands; the four accents put one of each named family
# from docs/COLOR.md section 4 above the accent chroma of 0.09, in the figure band where section 5
# asks for them.
PASSING = [
    ("desk",        0.350, 0.42, 0.050, 62.0),
    ("shadow",      0.120, 0.62, 0.040, 70.0),
    ("paper",       0.482, 0.90, 0.050, 85.0),
    ("rose_sticky", 0.012, 0.80, 0.120, 15.0),
    ("cool_sticky", 0.012, 0.78, 0.110, 240.0),
    ("clover",      0.012, 0.82, 0.110, 140.0),
    ("foil_star",   0.012, 0.90, 0.110, 90.0),
]


def build(rows, side=700):
    """Paint the rows as horizontal bands. Flat patches, so no quantity is an artefact of a blend."""
    img = np.zeros((side, side, 3), dtype=np.uint8)
    y = 0
    for i, (_, share, L, C, h) in enumerate(rows):
        n = side - y if i == len(rows) - 1 else int(round(share * side))
        img[y:y + n, :, :] = oklab_to_srgb(L, C, h)
        y += n
    return Image.fromarray(img)


def run(rows, name="01_pulse.png"):
    """Write the still into a scratch directory and return (exit code, breached quantities)."""
    with tempfile.TemporaryDirectory() as d:
        build(rows).save(os.path.join(d, name))
        out = os.path.join(d, "report.json")
        r = subprocess.run(
            [sys.executable, PALETTE, "--dir", d, "--floors", "--classes", "", "--out", out],
            capture_output=True, text=True, cwd=ROOT)
        with open(out, encoding="utf-8") as f:
            report = json.load(f)
        return r.returncode, [b["quantity"] for b in report["floors"]["breached"]]


KEYS = ("name", "share", "L", "C", "h")


def edit(*names, **changes):
    """The passing rows with the named patches altered. Shares are renormalised, so a case that
    shrinks one patch grows the others rather than leaving the frame short."""
    out = []
    for row in PASSING:
        if row[0] in names:
            row = tuple(changes.get(k, v) for k, v in zip(KEYS, row))
        out.append(row)
    out = [r for r in out if r[1] > 0]
    total = sum(r[1] for r in out)
    return [(r[0], r[1] / total, r[2], r[3], r[4]) for r in out]


ACCENTS = ("rose_sticky", "cool_sticky", "clover", "foil_star")


# Each case: a description, the rows, and the floor that must appear among the breaches.
BREAKS = [
    ("the paper goes dark, so the median pixel is no longer paper",
     edit("paper", L=0.55), "lightness.p50"),
    ("the desk takes over the frame, so the room is a plank with a note on it",
     edit("desk", share=1.40), "value_bands.ground"),
    ("the shadow between plank and paper is removed",
     edit("shadow", share=0.004), "value_bands.mid"),
    ("every accent is drained below the accent chroma",
     edit(*ACCENTS, C=0.020), "chroma.accent_fraction"),
    ("the accents all collapse onto one hue, so three families go missing",
     edit("cool_sticky", "clover", h=85.0), "across_the_set.widest_hue_gap_deg"),
    ("something on the paper is more saturated than a red biro",
     edit("foil_star", C=0.24), "chroma_by_band.figure.p99_chroma"),
    ("the whole room goes neutral grey",
     edit(*[r[0] for r in PASSING], C=0.0), "chroma.grey_fraction"),
]


def main():
    failures = []

    code, breached = run(PASSING)
    if code != 0:
        failures.append("the passing still did not pass: " + ", ".join(breached))
        print("FAIL  a still built to meet every floor breached: " + ", ".join(breached))
    else:
        print("ok    a still built to meet every floor exits 0")

    for why, rows, expect in BREAKS:
        code, breached = run(rows)
        if code == 0:
            failures.append(f"{expect}: broke it and the gate stayed green ({why})")
            print(f"FAIL  {expect:<38} stayed green when {why}")
        elif expect not in breached:
            failures.append(f"{expect}: broke it and a different floor caught it ({why})")
            print(f"FAIL  {expect:<38} did not fire when {why}; fired: {sorted(set(breached))}")
        else:
            print(f"ok    {expect:<38} fires when {why}")

    if failures:
        print(f"\n{len(failures)} of {len(BREAKS) + 1} checks failed", file=sys.stderr)
        return 1
    print(f"\n{len(BREAKS) + 1} checks passed: the gate can be passed and each floor can be failed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
