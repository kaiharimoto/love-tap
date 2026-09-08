#!/usr/bin/env python3
"""The ink plates: how much ink actually reached the paper, as a tileable field.

    python3 tools/ink_plate.py

A critic put a ruler on the letters and found no pressure variance at all — eroded ink-core pixels
took three discrete values before antialiasing, and two thirds of them were the same one. That is
what a font drawn in a flat colour measures as, and it is the difference between writing and
printing: a ballpoint skips and pools, a pencil takes the tooth of the paper and misses the pits.

So the ink is not a colour, it is a colour through a plate. Each plate is a small seamless field of
*coverage* — one where the pen laid ink down, less where it did not — carried in the alpha channel,
and the app multiplies a letter's own alpha by it. Nothing about the shapes changes; what changes is
how much of each stroke arrived.

The two pens differ in the way the two pens differ:

  ballpoint  a hard ball on a smooth paste: long thin skips along the direction of travel, and
             pooling where the hand slowed. Coverage is high, its failures are linear.
  graphite   a soft stick on a toothed sheet: the ink sits on the tops of the fibres and misses
             the pits, so coverage is speckled at the scale of the tooth and never quite full.

Both are periodic, so the app can tile one over a page without a seam.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "assets", "ink")
SIZE = 512
GENERATOR = "tools/ink_plate.py"


def periodic(size, harmonics, seed):
    """A seamless field: sinusoids on an integer lattice, so it tiles exactly.

    The wave vectors have to be whole numbers of cycles across the tile in *both* directions. A
    direction drawn at random and then scaled to a frequency is not, and the first version of this
    left a seam five times the local variation: the plate is tiled over a page, so the seam would
    have been a straight line of pale ink down every column of text.
    """
    rng = np.random.default_rng(seed)
    y = np.linspace(0, 1, size, endpoint=False)[:, None]
    x = np.linspace(0, 1, size, endpoint=False)[None, :]
    field = np.zeros((size, size))
    for freq, amp in harmonics:
        for _ in range(3):
            angle = rng.uniform(0, 2 * np.pi)
            kx = int(round(freq * np.cos(angle)))
            ky = int(round(freq * np.sin(angle)))
            if kx == 0 and ky == 0:
                kx = int(freq)
            phase = rng.uniform(0, 2 * np.pi)
            field += amp * np.sin(2 * np.pi * (kx * x + ky * y) + phase)
    m = np.abs(field).max() or 1.0
    return field / m


def ballpoint(size, seed):
    """Long thin skips along the travel, and pooling where the hand slowed."""
    rng = np.random.default_rng(seed)
    # the paste: broad, slow variation in how much is coming out
    flow = 0.5 + 0.5 * periodic(size, [(1, 1.0), (2, 0.5), (3, 0.25)], seed + 1)
    # skips: narrow across, long along, at a shallow angle, and rare
    skip = np.zeros((size, size))
    y = np.linspace(0, 1, size, endpoint=False)[:, None]
    x = np.linspace(0, 1, size, endpoint=False)[None, :]
    for _ in range(9):
        # a whole number of cycles of shear across the tile, or the skip does not meet itself
        shear = int(rng.integers(-2, 3))
        offset = rng.uniform(0, 1)
        across = np.mod(y - x * shear - offset + 0.5, 1.0) - 0.5
        width = rng.uniform(0.0018, 0.0055)
        along = 0.5 + 0.5 * np.sin(2 * np.pi * int(rng.integers(2, 6)) * (x + rng.uniform(0, 1)))
        skip += np.exp(-(across / width) ** 2) * along * rng.uniform(0.35, 0.8)
    tooth = periodic(size, [(60, 0.6), (97, 0.3)], seed + 2)
    # The flow term used to take at most 0.16 off, so the *core* of every mark landed at very
    # nearly full coverage and only the outlines carried the pressure: a critic measured the core
    # darkness of 157 marks on one screen varying by 3.52 grey levels, which is a flat fill with
    # a ragged edge. A ballpoint runs rich and then dry across a word, and what a reader sees is
    # whole words going lighter, not edges.
    # Skewed toward full: most of a page is a pen writing properly, and the dry patches are
    # occasional. A flat 0.34 off everywhere made every word grey.
    dry = np.clip(1 - flow, 0, 1) ** 1.9
    coverage = 1.0 - 0.42 * dry - np.clip(skip, 0, 1) * 0.55 - 0.05 * (1 - tooth)
    return np.clip(coverage, 0.26, 1.0)


def graphite(size, seed):
    """Ink on the tops of the fibres, missing the pits."""
    tooth = periodic(size, [(34, 0.55), (53, 0.3), (81, 0.2), (127, 0.12)], seed + 3)
    press = 0.5 + 0.5 * periodic(size, [(1, 1.0), (2, 0.6)], seed + 4)
    # the pits: where the tooth is low the pencil misses altogether
    missed = np.clip((0.16 - tooth) / 0.5, 0, 1)
    # as above: a pencil presses harder at the start of a word than at the end of one
    light = np.clip(1 - press, 0, 1) ** 1.7
    coverage = 1.0 - 0.28 * missed - 0.34 * light + 0.06 * np.clip(tooth, 0, 1)
    return np.clip(coverage, 0.30, 1.0)


def write(name, coverage, args):
    a = (np.clip(coverage, 0, 1) * 255).round().astype(np.uint8)
    rgb = np.full(a.shape + (3,), 255, dtype=np.uint8)
    im = Image.fromarray(np.dstack([rgb, a]), "RGBA")
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, f"{name}.png")
    im.save(path)
    stats = {
        "size": [int(a.shape[1]), int(a.shape[0])],
        "coverage_mean": round(float(coverage.mean()), 4),
        "coverage_min": round(float(coverage.min()), 4),
        "coverage_std": round(float(coverage.std()), 4),
        "seamless": True,
    }
    print(f"{name}: mean {stats['coverage_mean']:.3f}, floor {stats['coverage_min']:.3f}, "
          f"std {stats['coverage_std']:.3f}")
    return path, stats


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--seed", type=int, default=20260906)
    ap.add_argument("--size", type=int, default=SIZE)
    ap.add_argument("--no-manifest", action="store_true")
    args = ap.parse_args()
    made = []
    for name, fn in (("plate_ballpoint", ballpoint), ("plate_graphite", graphite)):
        path, stats = write(name, fn(args.size, args.seed), args)
        made.append((path, stats))
    if not args.no_manifest:
        sys.path.insert(0, os.path.join(ROOT, "blender"))
        from rig import manifest
        for path, stats in made:
            manifest.record(path, GENERATOR, dict(stats, seed=args.seed), kind="ink_plate")
    return 0


if __name__ == "__main__":
    sys.exit(main())
