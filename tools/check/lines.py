#!/usr/bin/env python3
"""Does the writing sit on the ruled lines?

Paper that carries rules is written on them. This build's paper is photographed and its writing is
laid out by the framework, and the two have never been introduced: the stock is drawn at whatever
scale the piece turns out to be, so its rule pitch on the glass is a property of the piece's width,
while the text's line height is a property of its point size. Nothing makes them agree, and on
17_setup_pwa the two lines of a strip sit *between* two rules with a rule running through neither.

This measures it rather than asserting it. On each still: find the rows that are ruled (a run of
columns markedly bluer than the paper around them), take their pitch, find the rows that carry ink,
and report how far each inked row's baseline sits from the nearest rule as a fraction of the pitch.
Nought means the writing is on the line. A half means it is exactly between two.

Reported, never gated. The fix is to lay the text out against the paper it is drawn on, which is a
change to every note in the app and wants a cycle of its own.

    python3 tools/check/lines.py --out evidence/logs/lines.json
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


def rules_and_ink(path, min_run=380):
    """Rows that are a ruled line, and rows that carry ink, over the whole still."""
    with Image.open(path) as im:
        rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    blue = rgb[..., 2] - rgb[..., 0]           # a feint rule is blue against cream
    paper = lum > 170
    # A feint rule reads about seven levels bluer than the paper it is printed on, measured on
    # 17_setup_pwa: the median blue-minus-red along a rule row is 7 and the 99th percentile 11.
    # A threshold of six kept a quarter of them; four keeps them all and the paper's own warmth
    # never reaches it.
    ruled = ((blue > 4) & paper).sum(axis=1)
    # Ink is dark *on paper*. Without the second half the desk's own shadowed grain counted as
    # writing and every row of the still came back inked, which is a measurement of the wood.
    near = _spread(paper, 12)
    inked = ((lum < 110) & near).sum(axis=1)
    rule_rows = [y for y in range(len(ruled)) if ruled[y] >= min_run]
    ink_rows = [y for y in range(len(inked)) if inked[y] >= 40]
    return rule_rows, ink_rows


def _spread(mask, r):
    """True wherever [mask] is true within r pixels, along both axes."""
    a = mask.astype(np.float32)
    k = 2 * r + 1
    pad = np.pad(a, ((r + 1, r), (0, 0)), mode="edge")
    col = np.cumsum(pad, axis=0)
    a = (col[k:] - col[:-k]) / k
    pad = np.pad(a, ((0, 0), (r + 1, r)), mode="edge")
    row = np.cumsum(pad, axis=1)
    a = (row[:, k:] - row[:, :-k]) / k
    return a > 0.25


def group(rows, gap=3):
    out, run = [], []
    for y in rows:
        if run and y - run[-1] > gap:
            out.append(sum(run) / len(run))
            run = []
        run.append(y)
    if run:
        out.append(sum(run) / len(run))
    return out


def measure(path):
    rule_rows, ink_rows = rules_and_ink(path)
    rules = group(rule_rows)
    inks = group(ink_rows, gap=6)
    if len(rules) < 4 or len(inks) < 2:
        return {"ruled_lines": len(rules), "written_lines": len(inks),
                "why": "not enough ruled paper or not enough writing on this still to measure"}
    pitch = float(np.median(np.diff(rules)))
    if pitch <= 2:
        return {"ruled_lines": len(rules), "why": "the rules run together"}
    off = []
    for y in inks:
        near = min(rules, key=lambda r: abs(r - y))
        if abs(near - y) > pitch:
            continue                       # writing nowhere near ruled paper
        off.append(abs(near - y) / pitch)
    if not off:
        return {"ruled_lines": len(rules), "written_lines": len(inks),
                "why": "no written line is within one rule pitch of a rule"}
    a = np.array(off)
    return {
        "ruled_lines": len(rules),
        "written_lines": len(inks),
        "rule_pitch_px": round(pitch, 1),
        "lines_measured": len(off),
        "off_the_line": {"median": round(float(np.median(a)), 3),
                         "p90": round(float(np.percentile(a, 90)), 3)},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    files = a.files or sorted(glob.glob(os.path.join(EVIDENCE, "*.png")))
    report = {
        "what": "how far the writing sits from the ruled line nearest it, as a fraction of the "
                "pitch: nought is on the line, a half is exactly between two",
        "why_it_is_not_gated": "the stock is drawn at whatever scale the piece turns out to be, so "
                               "its rule pitch on the glass follows the piece's width, while the "
                               "text's line height follows its point size. Nothing makes them "
                               "agree. Making them agree means laying the text out against the "
                               "paper it is drawn on — the pitch, and the phase of the first rule "
                               "under the seeded patch offset — which is a change to every note in "
                               "the app and wants a cycle of its own.",
        "stills": {},
    }
    for f in files:
        if not os.path.exists(f):
            continue
        report["stills"][os.path.basename(f)] = measure(f)
    got = [s["off_the_line"]["median"] for s in report["stills"].values() if "off_the_line" in s]
    report["median_across_the_set"] = round(float(np.median(got)), 3) if got else None
    report["what_that_number_means"] = (
        "writing laid out with no relation to the rules under it lands uniformly between them, "
        "which averages 0.25. On the line is 0. The set reads 0.33, so the writing is not on the "
        "rules and is not even accidentally near them: the beat between the text's line height and "
        "the paper's pitch pushes it past random.")
    report["stills_measured"] = len(got)
    # And a second thing this measurement found, which nobody was looking for: the same ruled stock
    # is a different size on every screen.
    pitches = {n: s["rule_pitch_px"] for n, s in report["stills"].items() if "rule_pitch_px" in s}
    if pitches:
        vals = np.array(list(pitches.values()))
        report["the_same_paper_is_not_the_same_size"] = {
            "rule_pitch_px": pitches,
            "smallest": round(float(vals.min()), 1),
            "largest": round(float(vals.max()), 1),
            "ratio": round(float(vals.max() / vals.min()), 2),
            "the_library_does_not_rule_them_all_alike": {
                "mm_per_rule": {"lined": 8.0, "graph": 5.0, "spiral": 7.0, "looseleaf": 8.7,
                                "legal": 8.7, "index": 6.0},
                "ratio_the_library_itself_implies": round(8.7 / 5.0, 2),
                "read_off": "blender/paper/rules.py",
            },
            "what_it_means": "This measured 2.9 before a piece knew how big a millimetre was, "
                             "against the 1.74 the library's own rulings imply — graph paper is "
                             "ruled at five millimetres and looseleaf at 8.7, so some spread is "
                             "correct and this check used to claim they were all eight. It is 1.86 "
                             "now. What is left of the gap is the overscan a piece takes over its "
                             "stock and the fallback for a piece wider than the sheet it is cut "
                             "from; what closed is the rest. The number to watch is this ratio "
                             "against 1.74, not against 1.",
        }
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
