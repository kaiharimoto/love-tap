#!/usr/bin/env python3
"""What the fold sequences cost WebKit, decoded, at the worst moment of a playback.

    python3 tools/check/texture_budget.py
    python3 tools/check/texture_budget.py --out evidence/texture_budget.json

`DIRECTION.md` has said since the beginning that "the WebKit texture budget is recorded in
`TASK_STATE.md` and enforced by `tools/check/texture_budget.py`". `TASK_STATE.md` recorded it and
this file did not exist, so for four cycles the build claimed an enforcement it did not have.
`CLAUDE.md` names it as a dangling claim. This is the file.

What it actually checks, and why each part:

  the window exists      `FoldFrames` in `app/lib/material/fold.dart` holds a rolling window of
                         decoded frames rather than the sequence. That is the whole mechanism; if
                         somebody simplifies it away, every other number here stops mattering and
                         the app holds 141 MB of texture for one animation. So the constant is
                         read out of the Dart and its absence is a failure, not a skipped check.
  the peak               window x the largest frame in the sequence x 4 bytes. The largest frame,
                         not the first: `unfold_thirds` has 88 distinct frame sizes because the
                         sheet opens, and reading the first one reports the folded state, which is
                         124 px tall against 315 at full spread. That is the difference between
                         8 MB and 21 MB, and the flattering one is the one a first-frame reading
                         gives you.
  the budget             read from `TASK_STATE.md`, which is where `DIRECTION.md` says it lives.
                         Not duplicated here: a number in two files is a number that will disagree
                         with itself.

It reads what the app actually ships -- `app/assets/folds`, written by `tools/pack_assets.py` --
and falls back to `assets/folds` when the app bundle has not been packed, saying which it used.
"""
import argparse
import glob
import json
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACKED = os.path.join(ROOT, "app", "assets", "folds")
SOURCE = os.path.join(ROOT, "assets", "folds")
FOLD_DART = os.path.join(ROOT, "app", "lib", "material", "fold.dart")
TASK_STATE = os.path.join(ROOT, "TASK_STATE.md")

BYTES_PER_PIXEL = 4          # RGBA, which is what a decoded ui.Image costs
MB = 1024.0 * 1024.0


def window_size(path=FOLD_DART):
    """`FoldFrames.window`, out of the Dart. None when the rolling window is gone."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        m = re.search(r"static const window\s*=\s*(\d+)\s*;", f.read())
    return int(m.group(1)) if m else None


def recorded_budget(path=TASK_STATE):
    """The budget line in `TASK_STATE.md`, in megabytes. None when it is not recorded."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        m = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*MB\s+peak decoded per sequence", f.read())
    return float(m.group(1)) if m else None


def sequences(directory):
    """Every fold sequence under a directory, with its frame count and its largest frame."""
    out = {}
    for d in sorted(glob.glob(os.path.join(directory, "*"))):
        if not os.path.isdir(d):
            continue
        frames = sorted(f for f in glob.glob(os.path.join(d, "*"))
                        if f.lower().endswith((".webp", ".png")))
        if not frames:
            continue
        widest = tallest = 0
        sizes = set()
        for f in frames:
            with Image.open(f) as im:
                sizes.add(im.size)
                widest = max(widest, im.size[0])
                tallest = max(tallest, im.size[1])
        out[os.path.basename(d)] = {
            "frames": len(frames),
            "widest": widest,
            "tallest": tallest,
            "distinct_frame_sizes": len(sizes),
        }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--dir", default="", help="a folds directory; the app bundle by default")
    args = ap.parse_args()

    if args.dir:
        directory, which = args.dir, args.dir
    elif os.path.isdir(PACKED) and sequences(PACKED):
        directory, which = PACKED, "app/assets/folds (what the app ships)"
    else:
        directory, which = SOURCE, "assets/folds (the renders; the app bundle is not packed)"

    seqs = sequences(directory)
    if not seqs:
        print(f"texture_budget: no fold sequences in {directory}", file=sys.stderr)
        return 2

    window = window_size()
    budget = recorded_budget()
    report = {
        "read": which,
        "window_frames": window,
        "budget_mb": budget,
        "bytes_per_pixel": BYTES_PER_PIXEL,
        "sequences": {},
    }

    problems = []
    if window is None:
        problems.append(
            "FoldFrames.window is not declared in app/lib/material/fold.dart. The rolling "
            "decoded-frame window is the mechanism this budget describes; without it the app "
            "holds the whole sequence and DIRECTION.md's claim is false.")
    if budget is None:
        problems.append(
            "TASK_STATE.md records no budget. DIRECTION.md says the WebKit texture budget lives "
            "there; a line reading 'N MB peak decoded per sequence' is what this reads.")

    for name, s in seqs.items():
        px = s["widest"] * s["tallest"] * BYTES_PER_PIXEL
        whole = s["frames"] * px / MB
        # With no window the app holds the sequence, so the peak is the whole of it. That is the
        # regression this exists to catch, and it must report rather than throw.
        held = min(window, s["frames"]) if window else s["frames"]
        peak = held * px / MB
        s = dict(s, held_frames=held, whole_sequence_mb=round(whole, 1),
                 peak_decoded_mb=round(peak, 1))
        report["sequences"][name] = s
        if budget is not None and peak > budget:
            problems.append(
                f"{name}: {peak:.1f} MB peak decoded against a budget of {budget:.0f} MB "
                f"({held} frames at {s['widest']}x{s['tallest']} RGBA)")

    report["problems"] = problems
    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"texture_budget: {len(seqs)} sequences read from {which} -> {args.out}")
    for name, s in report["sequences"].items():
        print(f"  {name:<16} {s['frames']:>4} frames, largest {s['widest']}x{s['tallest']}, "
              f"{s['distinct_frame_sizes']} distinct sizes  ·  peak {s['peak_decoded_mb']} MB "
              f"of {s['whole_sequence_mb']} MB held whole")
    if not args.out:
        print()

    if problems:
        for p in problems:
            print(f"texture_budget: {p}", file=sys.stderr)
        return 1
    print(f"texture_budget: every sequence is inside the {budget:.0f} MB recorded in "
          f"TASK_STATE.md, on a window of {window} frames")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
