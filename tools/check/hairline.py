#!/usr/bin/env python3
"""tools/check/hairline.py — no one-pixel bright rules lying on the desk.

    python3 tools/check/hairline.py [--out evidence/logs/hairline.json] [evidence/*.png]

A material critic measured this for five review cycles and named it four different ways: "one-pixel
bright rules are drawn across the desk", "a +48-grey spike one pixel tall running 254 px", "a pale
dead-straight hairline just outside every piece of paper". It was never in the wood and never in a
render: ShaderMask multiplies a tear mask in by drawing a rectangle the size of the piece in dstIn,
and that rectangle is antialiased, so on the row where the piece's box falls between two device
pixels the blend lands at partial coverage and a third of a pixel of sheet survives where the tear
had erased it.

The fix is in app/lib/material/paper.dart and the test binding cannot see it — the fault is drawn
by CanvasKit and a widget test rasterises sixty-six piece heights at three densities without one
spike. So it is measured here, on the photographs, the way the critic measured it: a row that is
brighter than the row above it and the row below it by [--rise] grey levels or more, for [--run]
pixels or more, over desk rather than over paper.
"""
import argparse, glob, json, os, sys
import numpy as np
from PIL import Image

PAPER = 170.0   # anything this bright is a sheet, not the desk


def runs(row_mask, minimum):
    out, start, n = [], None, 0
    for x, v in enumerate(row_mask):
        if v:
            if start is None:
                start = x
            n += 1
        elif start is not None:
            if n >= minimum:
                out.append((start, n))
            start, n = None, 0
    if start is not None and n >= minimum:
        out.append((start, n))
    return out


def rules(path, rise, run):
    grey = np.asarray(Image.open(path).convert('L')).astype(np.float32)
    over = (grey[1:-1] - grey[:-2] >= rise) & (grey[1:-1] - grey[2:] >= rise)
    found = []
    for y in range(over.shape[0]):
        for x, n in runs(over[y], run):
            # on the wood: the row under it is desk, not the inside of a sheet
            if grey[y + 2, x:x + n].mean() < PAPER:
                found.append({'y': y + 1, 'x': x, 'length': int(n),
                              'lift': round(float((grey[y + 1, x:x + n] - grey[y, x:x + n]).mean()), 1)})
    return found


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='*')
    ap.add_argument('--out', default='')
    ap.add_argument('--rise', type=float, default=20.0)
    ap.add_argument('--run', type=int, default=60)
    args = ap.parse_args(argv)

    files = args.files or sorted(p for p in glob.glob('evidence/*.png') if os.path.isfile(p))
    report = {'rise': args.rise, 'run': args.run, 'stills': {}, 'note':
              'a row brighter than both its neighbours, lying on the desk: the mask rectangle '
              'catching the edge of the piece it cuts'}
    worst = 0
    for p in files:
        found = rules(p, args.rise, args.run)
        report['stills'][os.path.basename(p)] = {
            'rules': len(found),
            'longest': max((f['length'] for f in found), default=0),
            'where': found[:6],
        }
        worst = max(worst, len(found))
    report['ok'] = worst == 0
    report['worst'] = worst
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        json.dump(report, open(args.out, 'w'), indent=1)
    for name, e in report['stills'].items():
        if e['rules']:
            print(f"  {name}: {e['rules']} bright one-row rules on the desk, longest {e['longest']} px")
    print(f"{len(files)} still(s) read, {worst} the most rules on any one of them")
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
