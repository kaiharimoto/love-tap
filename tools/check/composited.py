#!/usr/bin/env python3
"""Is a feeling object lit by the same lamp as the paper it is lying on?

    python3 tools/check/composited.py evidence/01_pulse.png evidence/crops/dusk_pulse.png

`docs/DIRECTION.md` has two rigs and the dusk one is not a dim overlay: it is a low cool sky and a
warm desk lamp on the right, and every surface in the frame is re-rendered under it. Anti-goal 2 is
the 3D gradient blob standing in for a feeling, and the item
`the-feeling-objects-are-sprites-composited-over-the-scene` says the objects are not re-rendered at
all.

**THE APP DECLARES THE DEFECT ITSELF AND NO PIXEL IS NEEDED TO ESTABLISH IT.** In
`crops/dusk_pulse.surfaces.json` the same object contributes two surfaces: the shadow is
`obj_candle_shadow_dusk.webp` and the body is `obj_candle.webp` -- no suffix, the day render -- while
every paper surface beside it is a `*_dusk` stock. `material/objects.dart:118` is the line:
`'${id}_shadow${dusk ? '_dusk' : ''}'` for the shadow and a bare `objectAsset(id)` for the body.
And `blender/objects/objects.py:541` is why: `if pass_kind == "object" and condition != "day":
continue` -- the generator SKIPS an object's colour pass at dusk on purpose, so the render does not
exist to be asked for.

What this tool adds is the magnitude, which is what a ranking needs: how far the object moves
between the two lights against how far the paper under it moves. It takes the object's own opaque
pixels -- the asset's alpha, scaled into the rect the app declared -- so it is measuring the object
and not the box around it (WORKER_PROMPT 3d: a window is placed by the object, never by the frame).

A ratio near 1.0 is an object lit by the scene's lamp. A ratio near 0 is a sticker.

**IT IS EARNED INSIDE ONE FRAME, which is the cheapest form of the qualification WORKER_PROMPT
demands.** A ruler that scores the defect at or above the repair is disqualified, so this one is
asked to separate two surfaces whose status is already known and which sit in the same pair of
stills. `01_pulse` -> `crops/dusk_pulse` reads: paper, which IS re-rendered at dusk, 27.515; the
object bodies, which are not, 13.721 and 16.546. The relit surface reads roughly twice the
composited one and in the right order, and the declaration half agrees with it without touching a
pixel -- every shadow `relit: true`, every body `relit: false`.

**AND IT REFUTES THE NUMBER THE ITEM WAS FILED ON.** The item says the spool is *byte-identical*
between the two lights at a day-to-dusk difference of 0.02. Over their own opaque pixels the two
objects in this frame move 13.721 and 16.546, which is not nothing -- a dusk grade and a re-rendered
shadow behind them do move a composited sprite. What is true, and is the number to rank on, is that
they move HALF AS FAR as the paper they are lying on: 0.499 and 0.601 against a floor of 0.5. An
object that moves at 0.02 would be a sprite pasted over an untouched scene, and that is not what
this is; it is an object carrying the day's key direction through a dusk grade.
"""
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image


def _surfaces(png):
    p = pathlib.Path(png)
    for cand in (p.with_suffix('.surfaces.json'),
                 p.parent / f'{p.stem}.surfaces.json'):
        if cand.exists():
            return json.loads(cand.read_text())
    return None


def _alpha_mask(asset, w, h):
    """The object's own opaque pixels, at the size the app drew it."""
    for root in ('assets', 'app/assets'):
        for ext in ('.png', '.webp'):
            p = pathlib.Path(root) / pathlib.PurePosixPath(asset).relative_to('assets')
            p = p.with_suffix(ext)
            if p.exists():
                im = Image.open(p).convert('RGBA').resize((w, h), Image.BILINEAR)
                return np.asarray(im)[:, :, 3] > 160
    return None


def read(day_png, dusk_png):
    day = np.asarray(Image.open(day_png).convert('RGB')).astype(float)
    dusk = np.asarray(Image.open(dusk_png).convert('RGB')).astype(float)
    if day.shape != dusk.shape:
        return {'ok': False, 'why': f'{day_png} is {day.shape} and {dusk_png} is {dusk.shape}'}
    diff = np.abs(day - dusk).mean(axis=2)
    H, W = diff.shape

    s_day, s_dusk = _surfaces(day_png), _surfaces(dusk_png)
    out = {'day': str(day_png), 'dusk': str(dusk_png), 'frame': [W, H],
           'frame_mean_diff': round(float(diff.mean()), 3),
           'objects': [], 'paper_mean_diff': None, 'declared': []}
    if s_day is None or s_dusk is None:
        out['ok'] = False
        out['why'] = 'one of the two stills has no surfaces sidecar, so nothing can be placed by ' \
                     'the object rather than by the frame'
        return out

    def crop(rect):
        x, y, w, h = rect
        x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
        if x1 <= x0 or y1 <= y0:
            return None, None
        return (x0, y0, x1, y1), (x - x0, y - y0)

    # the paper's own movement, over the paper surfaces the dusk still declares
    paper = []
    for s in s_dusk:
        if not s.get('asset', '').startswith('assets/paper/'):
            continue
        box, _ = crop(s['rect'])
        if box is None:
            continue
        x0, y0, x1, y1 = box
        paper.append(float(diff[y0:y1, x0:x1].mean()))
    if paper:
        out['paper_mean_diff'] = round(float(np.median(paper)), 3)

    # what each still says it drew for the same object
    by_stem = {}
    for tag, ss in (('day', s_day), ('dusk', s_dusk)):
        for s in ss:
            a = s.get('asset', '')
            if not a.startswith('assets/objects/'):
                continue
            stem = pathlib.PurePosixPath(a).stem
            kind = 'shadow' if '_shadow' in stem else 'body'
            # `obj_candle_dusk` is obj_candle's dusk body (firing 51), not an object of its own:
            # left unstripped, each light's body paired with nothing, read `relit` against None,
            # and the ruler passed a still on which no body had been compared at all
            base = stem.split('_shadow')[0]
            if base.endswith('_dusk'):
                base = base[:-len('_dusk')]
            by_stem.setdefault((base, kind), {})[tag] = a
    for (base, kind), got in sorted(by_stem.items()):
        out['declared'].append({'object': base, 'pass': kind,
                                'day': got.get('day'), 'dusk': got.get('dusk'),
                                'relit': got.get('day') != got.get('dusk')})

    for s in s_dusk:
        a = s.get('asset', '')
        if not a.startswith('assets/objects/') or '_shadow' in a:
            continue
        box, off = crop(s['rect'])
        if box is None:
            continue
        x0, y0, x1, y1 = box
        _, _, w, h = s['rect']
        mask = _alpha_mask(a, w, h)
        row = {'asset': a, 'rect': s['rect']}
        if mask is None:
            row['why'] = 'the asset is not on disk, so its own alpha could not be used'
        else:
            mask = mask[off[1]:off[1] + (y1 - y0), off[0]:off[0] + (x1 - x0)]
            sub = diff[y0:y1, x0:x1]
            if mask.shape == sub.shape and mask.any():
                row['object_mean_diff'] = round(float(sub[mask].mean()), 3)
                row['around_mean_diff'] = round(float(sub[~mask].mean()), 3) if (~mask).any() else None
                if out['paper_mean_diff']:
                    row['ratio_to_paper'] = round(row['object_mean_diff'] / out['paper_mean_diff'], 3)
                row['opaque_px'] = int(mask.sum())
        out['objects'].append(row)

    bodies = [d for d in out['declared'] if d['pass'] == 'body']
    out['bodies_relit'] = sum(1 for d in bodies if d['relit'])
    out['bodies'] = len(bodies)
    ratios = [o['ratio_to_paper'] for o in out['objects'] if 'ratio_to_paper' in o]
    out['ok'] = bool(bodies) and out['bodies_relit'] == len(bodies) and \
        all(0.5 <= r <= 2.0 for r in ratios)
    if not out['ok']:
        out['why'] = (
            f"{len(bodies) - out['bodies_relit']} of {len(bodies)} feeling objects draw the SAME "
            f"asset in both lights while the paper under them is re-rendered"
            + (f"; ratios to paper {sorted(ratios)}" if ratios else ''))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('day', nargs='?', default='evidence/01_pulse.png')
    ap.add_argument('dusk', nargs='?', default='evidence/crops/dusk_pulse.png')
    ap.add_argument('--out', default='')
    args = ap.parse_args()
    out = read(args.day, args.dusk)
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(out, indent=1))
    print(json.dumps(out, indent=1))
    return 0 if out.get('ok') else 1


if __name__ == '__main__':
    sys.exit(main())
