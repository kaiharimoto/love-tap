#!/usr/bin/env python3
"""Does a letter that comes round again get a different outline?

`docs/BRIEF.md` 07 asks for handwriting with multiple variants per glyph, and the rubric row
`material_truth` is judged on it at three hundred percent zoom on the Chat hero. The hands carry
the variants and `calt` applies them: firing 42 established that, and firing 46 established that
the pool is exactly big enough -- five variants against a longest same-letter repeat of five in
the runs the app declares. What fails is the CYCLE, not the supply.

**This reads the runs the app itself declares, which is the whole point of it.**
`app/test/a_repeated_letter_is_not_a_stamp_test.dart` measured `eeeeeeee`: eight instances against
five variants, so by pigeonhole two must share an outline and its minimum distance is 0.00 before
anything is built. Every number this build has quoted about the hands came from that string, and
the app never draws it. WORKER_PROMPT 3d says a measurement is anchored to something the app
declares; for text that is `<artifact>.text.json` and its `says`/`text` runs, so that is what this
shapes.

Two numbers, and the second is the one nobody had:

  repeats   for every character that occurs more than once inside ONE declared run, whether all
            its instances took different glyph ids. This is the item's clause three.
  avoidable the same, counting only a character whose instances took FEWER distinct outlines than
            min(instances, variants). A run with nine `e`s against five variants must repeat four
            outlines by pigeonhole, at any effort; firing 53 found clause three impossible as
            written for exactly that reason (up to 9 instances in one run on 5 of 11 stills) and
            re-scoped it to this count. `variants` is read per face from
            tools/handwriting/hands.json, so the ruler cannot drift from the build.
  stalls    how often a glyph takes the same variant as the glyph immediately before it, and how
            often that glyph is the SAME LETTER -- which is one outline printed twice in a row,
            the most visible form the defect has, and it is in the set: `room` in the Chat hero
            draws both of its `o`s as the identical outline.

Needs `uharfbuzz` and `fonttools`; neither is in a fresh container
(`python3 -m pip install uharfbuzz fonttools`). Exits non-zero when a floor is breached, which is
the normal state of this build and not a failure of the tool.
"""
import argparse
import collections
import json
import pathlib
import sys


def _variant(name):
    return (name.rsplit('.v', 1)[0], int(name.rsplit('.v', 1)[1])) if '.v' in name else (name, 0)


def read(font_dir, text_json, families, calt=True):
    import uharfbuzz as hb
    from fontTools.ttLib import TTFont

    doc = json.loads(pathlib.Path(text_json).read_text())
    runs = doc.get('runs') or []
    fonts = {}
    out = {
        'text': str(text_json),
        'calt': calt,
        'runs_read': 0,
        'pairs': 0,
        'pairs_repeating': 0,
        'pairs_avoidable': 0,
        'worst': [],
        'glyphs': 0,
        'stalls': 0,
        'stalls_same_letter': 0,
        'stalled_words': [],
    }
    hands = pathlib.Path(__file__).resolve().parents[1] / 'handwriting' / 'hands.json'
    variants = {k: v.get('variants', 1) for k, v in json.loads(hands.read_text()).items()
                if isinstance(v, dict)}
    for r in runs:
        fam = r.get('family')
        if fam not in families:
            continue
        text = r.get('text') or r.get('says') or ''
        if not text:
            continue
        px = float(r.get('px') or 51)
        if fam not in fonts:
            path = pathlib.Path(font_dir) / f'{fam}.ttf'
            if not path.exists():
                continue
            tt = TTFont(str(path))
            blob = hb.Blob.from_file_path(str(path))
            face = hb.Face(blob)
            fonts[fam] = (hb.Font(face), tt.getGlyphOrder())
        font, order = fonts[fam]
        font.scale = (int(px * 64), int(px * 64))
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(font, buf, {'calt': calt})
        glyphs = [(order[i.codepoint], i.cluster) for i in buf.glyph_infos]
        out['runs_read'] += 1

        by_char = collections.defaultdict(list)
        for name, cl in glyphs:
            if cl < len(text) and text[cl].isalpha():
                by_char[text[cl]].append(name)
        for ch, names in by_char.items():
            if len(names) < 2:
                continue
            out['pairs'] += 1
            if len(set(names)) < len(names):
                out['pairs_repeating'] += 1
                avoidable = len(set(names)) < min(len(names), variants.get(fam, 1))
                if avoidable:
                    out['pairs_avoidable'] += 1
                out['worst'].append({
                    'family': fam, 'char': ch, 'instances': len(names),
                    'distinct': len(set(names)), 'avoidable': avoidable, 'run': text[:60],
                })

        for i in range(1, len(glyphs)):
            out['glyphs'] += 1
            a, b = _variant(glyphs[i - 1][0]), _variant(glyphs[i][0])
            if a[1] == b[1]:
                out['stalls'] += 1
                if a[0] == b[0]:
                    out['stalls_same_letter'] += 1
                    out['stalled_words'].append({
                        'family': fam, 'letter': a[0], 'variant': a[1], 'run': text[:60],
                    })
    out['worst'].sort(key=lambda w: (w['distinct'] - w['instances'], -w['instances']))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('text', nargs='?', default='evidence/02_chat.text.json',
                    help='an artifact\'s text sidecar: the runs the app declared it drew')
    ap.add_argument('--fonts', default='app/assets/fonts')
    ap.add_argument('--families', default='NoorHand,TeoHand')
    ap.add_argument('--out', default='')
    ap.add_argument('--no-calt', action='store_true',
                    help='shape with the contextual alternates OFF. This is the ruler EARNING ITS '
                         'PLACE and not a thing to measure the app by: with calt off every glyph '
                         'is variant zero, so every repeated letter repeats an outline and every '
                         'pair of adjacent letters stalls. A ruler that does not read that as '
                         'strictly worse than the shipped font cannot discriminate a repair from '
                         'the defect and may not be cited -- see WORKER_PROMPT, the disqualified '
                         'rulers.')
    args = ap.parse_args()

    out = read(args.fonts, args.text, set(args.families.split(',')), calt=not args.no_calt)
    # The floor is clause three of `one-variant-per-glyph-and-zero-pressure-variance` as firing 53
    # re-scoped it, plus the stall count this tool adds: no repeated letter inside one declared run
    # may take fewer distinct outlines than it could, and no glyph may be the same letter and the
    # same variant as the one before it. `pairs_repeating`, which counts the pigeonhole too, is
    # still reported beside it.
    out['ok'] = out['pairs_avoidable'] == 0 and out['stalls_same_letter'] == 0
    if not out['ok']:
        out['why'] = (
            f"{out['pairs_avoidable']} of {out['pairs']} repeated letters inside one declared run "
            f"take fewer outlines than they could ({out['pairs_repeating']} repeat one at all), and "
            f"{out['stalls_same_letter']} of {out['glyphs']} glyphs are the same letter AND the same "
            f"variant as the glyph immediately before them")
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(out, indent=1))
    print(json.dumps(out, indent=1))
    return 0 if out['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
