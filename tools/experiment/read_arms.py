#!/usr/bin/env python3
"""What each arm of the scroll experiment cost, side by side."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    try:
        with open(path) as f:
            d = json.load(f)
    except Exception as e:
        return {'error': str(e)}
    per = [x for x in (d.get('per_frame') or []) if isinstance(x, dict)]
    b = sorted(x.get('build_ms', 0) for x in per)
    n = len(b)
    q = lambda p: b[min(n - 1, int(n * p))] if n else None
    tail = per[-300:]
    tb = sorted(x.get('build_ms', 0) for x in tail)
    heavy = [v for v in tb if v > 400]
    return {
        'frames': n,
        'build_ms': {'p50': q(.5), 'p90': q(.9), 'p95': q(.95), 'max': b[-1] if n else None},
        'the_fling_alone': {
            'frames': len(tb),
            'p50': tb[len(tb) // 2] if tb else None,
            'over_400_ms': len(heavy),
            'median_of_those': heavy[len(heavy) // 2] if heavy else None,
        },
    }


def rows(path):
    try:
        with open(path) as f:
            d = json.load(f)
    except Exception as e:
        return {'error': str(e)}
    return {k: d.get(k) for k in ('rows_built_total', 'rows_built_worst_tick', 'travelled')}


def main():
    out = {
        'what': 'the same fling, the same seeded year, the same driven clock, against builds of '
                'one commit that differ only in the flag named. Both arms are built here rather '
                'than reading the capture\'s own record as a control, because a capture taken '
                'before this commit differs by more than the fonts.',
        'why': 'a fling frame that builds no rows costs 4 ms and one that builds two and a half '
               'costs 688 — about 276 ms a row. The test that was read as ruling the fonts out '
               'runs under flutter test, which passes --use-test-fonts --disable-asset-fonts, so '
               'it laid its paragraphs out in a font with nothing to shape.',
        'with_the_alternates': read(f'{ROOT}/evidence/logs/scroll_webkit_alternates.json'),
        'without_them': read(f'{ROOT}/evidence/logs/scroll_webkit_plain.json'),
        'rows_with_the_alternates': rows(f'{ROOT}/evidence/logs/11_alternates.fling.json'),
        'rows_without_them': rows(f'{ROOT}/evidence/logs/11_plain.fling.json'),
    }
    a = out['with_the_alternates'].get('the_fling_alone') or {}
    b = out['without_them'].get('the_fling_alone') or {}
    out['heavy_frames'] = {'with': a.get('over_400_ms'), 'without': b.get('over_400_ms'), 'of': 300}
    if a.get('median_of_those') and b.get('median_of_those'):
        out['what_a_heavy_frame_costs'] = {
            'with': a['median_of_those'],
            'without': b['median_of_those'],
            'share_the_alternates_are': round(1 - b['median_of_those'] / a['median_of_those'], 3),
        }
    with open(sys.argv[1], 'w') as f:
        f.write(json.dumps(out, indent=1) + '\n')
    print(json.dumps({k: out[k] for k in ('heavy_frames', 'what_a_heavy_frame_costs') if k in out},
                     indent=1))


if __name__ == '__main__':
    main()
