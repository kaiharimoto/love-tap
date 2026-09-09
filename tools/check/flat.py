#!/usr/bin/env python3
"""No pale rectangle on the glass may be flatter than real paper.

The material row's hard rule is that a surface must not read as an approximation of paper, and the
one shape that always does is a flat fill with a shadow under it. Every check the build had for
that read the *assets* — the paper floor in surfaces.py, the tooth measured on a stock. None of
them read the glass, and the thing they missed was on the glass for a second and a half of a clip:
an authored feeling landing on a pale, square-cornered, untextured card, luma standard deviation
0.87 over 80 device pixels against 32.5 and 43.2 on the module strips either side of it in the
same frame.

The floor is measured rather than chosen. Over a full screen of paper — 02_chat.png, 288 pale
80-pixel windows — the flattest real paper reads 4.58 and the median 33.6. Anything paler than
`--pale` and flatter than `--floor` is not paper being photographed; it is a rectangle.

    python3 tools/check/flat.py --out evidence/logs/flat.json
    python3 tools/check/flat.py evidence/02_chat.png --floor 2.0

It records rather than gates, for now, and the reason is written here rather than left as a habit:
on the capture it was written against it finds 20 windows on 03_us, 32 on 05_settings and 20 on
17_setup_pwa, and I have not yet established, window by window, which of those are a fill and which
are a real stock rendered so large that its tooth is spread under the eye. Gating on a number
nobody has read is how a check comes to be ignored. The numbers ship in evidence/logs/flat.json so
a reader can take them, and the next cycle drives them to nothing and turns the gate on.
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVIDENCE = os.path.join(ROOT, "evidence")


def windows(path, box, step, pale):
    """Every pale, paper-coloured window, with how flat it is.

    Paper-coloured, not merely pale: a photograph of a bright sky is flat and pale too — 305
    windows of 14_media_viewer read a standard deviation of 0.00, and every one of them is the
    sky over the water in the picture somebody sent. That is content, not a rectangle standing in
    for paper. The app's paper is cream and warm, so a window counts only when its red channel
    leads its blue by between four and forty levels, which the sky never does and the wood never
    reaches.
    """
    import numpy as np
    from PIL import Image
    with Image.open(path) as im:
        rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
    a = rgb.mean(axis=2)
    warm = rgb[..., 0] - rgb[..., 2]
    h, w = a.shape
    worst = (1e9, None)
    flat = []
    for y in range(0, h - box, step):
        for x in range(0, w - box, step):
            q = a[y:y + box, x:x + box]
            if q.mean() < pale:
                continue
            k = float(warm[y:y + box, x:x + box].mean())
            if k < 4.0 or k > 40.0:
                continue
            s = float(q.std())
            if s < worst[0]:
                worst = (s, [x, y])
            flat.append((s, x, y))
    return worst, flat


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--box", type=int, default=80, help="window side in device pixels")
    ap.add_argument("--step", type=int, default=40)
    ap.add_argument("--pale", type=float, default=190.0, help="mean luma above which a window is paper-coloured")
    ap.add_argument("--floor", type=float, default=2.0,
                    help="a pale window flatter than this is a fill, not a photograph")
    ap.add_argument("--allow", type=int, default=0, help="how many such windows a file may have")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    files = a.files or sorted(glob.glob(os.path.join(EVIDENCE, "*.png")))
    report = {
        "box": a.box, "pale": a.pale, "floor": a.floor,
        "known_false_positive": "the sky of the photograph open in 14_media_viewer. It is pale, "
                "warm enough to pass the colour test, and genuinely flat, and it is content rather "
                "than a surface this build answers for. An anti-goal critic reproduced these "
                "numbers and disagreed with that one verdict, correctly. A filter that excluded it "
                "by looking at how busy the surroundings are also excluded every real slab — a "
                "pale card beside a torn note has exactly the same neighbourhood — so it is named "
                "here rather than hidden by a test that costs more than it saves.",
        "note": "a pale window flatter than the floor is a flat fill standing in for paper. The "
                "floor is measured: over a full screen of paper the flattest real 80 px window "
                "reads 4.58 and the median 33.6, so 2.0 is well under anything the material makes.",
        "stills": {},
    }
    bad = 0
    for f in files:
        if not os.path.exists(f):
            continue
        worst, flat = windows(f, a.box, a.step, a.pale)
        offenders = [{"at": [x, y], "std": round(s, 3)} for s, x, y in flat if s < a.floor]
        offenders.sort(key=lambda o: o["std"])
        report["stills"][os.path.basename(f)] = {
            "flattest": round(worst[0], 3) if worst[1] else None,
            "where": worst[1],
            "windows_under_the_floor": len(offenders),
            "worst_few": offenders[:5],
        }
        if len(offenders) > a.allow:
            bad += 1
    report["ok"] = bad == 0
    report["files_with_a_flat_fill"] = bad
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
