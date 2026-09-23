#!/usr/bin/env python3
"""The hands remember a letter for twelve glyphs, and a letter that comes round again inside that
takes the next outline.

`tools/handwriting/build.py` writes a third `calt` pass since firing 55 (`memory_text`): a letter
looks back up to CALT_MEMORY glyphs for its own nearest earlier instance and takes the variant one
on from it. This holds that property exactly, over every run the app declares in
`evidence/*.text.json` and over the Chat hero, shaped through the shipped fonts with HarfBuzz --
so it does not move when a capture changes which runs are on the glass. It also prints what
`hands.py` counts, so the effect is on the page beside the property:

    firing 55, over the committed sidecars: avoidable repeats 256 -> 107, same-letter stalls 2 -> 0,
    and 02_chat, the hero, 19 -> 2.

RE-BREAK: point it at the fonts from before firing 55 (`git show <rev>:assets/fonts/NoorHand.ttf`)
and it fails, naming the pairs that took the same outline inside the memory.

Needs `uharfbuzz` and `fonttools`. Exits non-zero on a failure.
"""
import argparse
import glob
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools' / 'handwriting'))
sys.path.insert(0, str(ROOT / 'tools' / 'check'))

HERO = 'week one, and the room smells right again'


def _variant(name):
    return (name.rsplit('.v', 1)[0], int(name.rsplit('.v', 1)[1])) if '.v' in name else (name, 0)


def shaper(font_dir, family):
    import uharfbuzz as hb
    from fontTools.ttLib import TTFont
    path = pathlib.Path(font_dir) / f'{family}.ttf'
    order = TTFont(str(path)).getGlyphOrder()
    font = hb.Font(hb.Face(hb.Blob.from_file_path(str(path))))

    def shape(text):
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(font, buf, {})
        return [(order[i.codepoint], i.cluster) for i in buf.glyph_infos]
    return shape


def breaks(shaped, text, memory, variants):
    """Pairs of one letter within `memory` glyphs of each other where the later did not take the
    variant one on from the earlier."""
    last = {}
    out = []
    for pos, (name, cl) in enumerate(shaped):
        if cl >= len(text) or not text[cl].isalnum():
            continue
        base, v = _variant(name)
        if base in last:
            ppos, pv = last[base]
            if pos - ppos <= memory and v != (pv + 1) % variants:
                out.append({'letter': text[cl], 'gap': pos - ppos, 'variants': [pv, v]})
        last[base] = (pos, v)
    return out


def main():
    import build
    ap = argparse.ArgumentParser()
    ap.add_argument('--fonts', default=str(ROOT / 'assets' / 'fonts'))
    args = ap.parse_args()
    hands = json.loads((ROOT / 'tools' / 'handwriting' / 'hands.json').read_text())
    memory = build.CALT_MEMORY
    shapes = {f: shaper(args.fonts, f) for f in ('NoorHand', 'TeoHand')}

    failures, runs = [], 0
    texts = [('hero', 'NoorHand', HERO), ('hero', 'TeoHand', HERO)]
    for t in sorted(glob.glob(str(ROOT / 'evidence' / '*.text.json'))):
        for r in json.loads(pathlib.Path(t).read_text()).get('runs') or []:
            text = r.get('text') or r.get('says') or ''
            if r.get('family') in shapes and text:
                texts.append((pathlib.Path(t).name, r['family'], text))
    for where, fam, text in texts:
        runs += 1
        shaped = shapes[fam](text)
        bad = breaks(shaped, text, memory, hands[fam]['variants'])
        for b in bad:
            failures.append({'where': where, 'family': fam, 'run': text[:60], **b})

    # the hero, said out loud: both o's of `room`
    room = []
    for fam, shape in shapes.items():
        shaped = shape(HERO)
        i = HERO.index('room')
        os_ = [n for n, cl in shaped if cl in (i + 1, i + 2)]
        room.append({'family': fam, 'o': os_})
        if len(set(os_)) != 2:
            failures.append({'where': 'hero', 'family': fam, 'run': HERO, 'room': os_})

    import hands as H
    counts = {'avoidable': 0, 'stalls_same_letter': 0}
    for t in sorted(glob.glob(str(ROOT / 'evidence' / '*.text.json'))):
        o = H.read(args.fonts, t, set(shapes), calt=True)
        counts['avoidable'] += o['pairs_avoidable']
        counts['stalls_same_letter'] += o['stalls_same_letter']

    out = {'fonts': args.fonts, 'memory': memory, 'runs': runs, 'room': room, 'hands_py': counts,
           'failures': failures[:40], 'failed': len(failures), 'ok': not failures and runs > 2}
    print(json.dumps(out, indent=1))
    return 0 if out['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
