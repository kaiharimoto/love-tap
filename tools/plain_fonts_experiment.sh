#!/usr/bin/env bash
# What the hands' contextual alternates cost the scroll, measured rather than guessed.
#
# Three cycles have blamed the scroll's build spikes on something. The tear mask being baked per
# note: disproved by a counter. The scope subscription rebuilding every row on every sync round:
# real, fixed, and the row count over the same fling fell from 5,028 to 167. What is left is that a
# frame which builds nothing costs 4 ms and a frame which builds two and a half rows costs 688 —
# about 276 ms a row — and the test that was supposed to rule the fonts out runs under
# `flutter test`, which passes --use-test-fonts --disable-asset-fonts and therefore laid every one
# of its paragraphs out in a font with no alternates in it.
#
# So: the same fling, the same seeded year, the same driven clock, twice. One build with the
# alternates on and one with them off, and the frame timings of each.
#
#   bash tools/plain_fonts_experiment.sh
#
# Writes evidence/logs/what_the_alternates_cost.json.
set -uo pipefail
cd "$(dirname "$0")/.."
. ./toolchain/env.sh

SCRATCH="${TMPDIR:-/tmp}/lovetap-plain"
FROZEN_NOW="2026-09-03T19:40:00Z"
mkdir -p "$SCRATCH"
OUT="evidence/logs/what_the_alternates_cost.json"

echo "· building the seeded PWA with the alternates off"
(cd app && flutter build web --release --no-web-resources-cdn \
    --dart-define=SEED=year --dart-define=TRANSPORT=local --dart-define=CAPTURE=true \
    --dart-define=ROLE=client --dart-define=PERSON=teo --dart-define=PLAIN_FONTS=true \
    --dart-define=FROZEN_NOW="$FROZEN_NOW") >"$SCRATCH/build.log" 2>&1 \
  || { tail -20 "$SCRATCH/build.log"; exit 1; }
rm -rf "$SCRATCH/web_plain" && cp -r app/build/web "$SCRATCH/web_plain"

PAIR="$SCRATCH/pair.json"
rm -f "$PAIR" "$PAIR.do"
echo "· the far phone, serving it"
( cd app && dart run tool/host_daemon.dart --out "$PAIR" \
    --transport local --address "" --proxy "" \
    --pwa "$SCRATCH/web_plain" --seed year --now "$FROZEN_NOW" --seconds 3600 \
  ) >"$SCRATCH/host_daemon.log" 2>&1 &
DAEMON=$!
trap 'kill $DAEMON 2>/dev/null' EXIT
for _ in $(seq 1 240); do [ -f "$PAIR" ] && break; sleep 0.5; done
[ -f "$PAIR" ] || { echo "the far phone would not start"; tail -5 "$SCRATCH/host_daemon.log"; exit 1; }
BASE="$(python3 -c "import json;print(json.load(open('$PAIR'))['base'])")"

# The same scene, with its timings sent somewhere else so the capture's own record is untouched.
python3 - "$SCRATCH/scene.json" <<'PY'
import json, sys
d = json.load(open('evidence/scenes/11_chat_scroll.json'))
for s in d['steps']:
    if s.get('do') == 'timings':
        s['out'] = 'evidence/logs/scroll_webkit_plain.json'
    if s.get('do') == 'frames':
        s['dir'] = 'evidence/frames/11_plain'
    if s.get('do') == 'flingLog':
        s['out'] = 'evidence/logs/11_plain.fling.json'
    if s.get('do') == 'report':
        s['out'] = 'evidence/logs/11_plain.report.json'
d['log'] = 'evidence/logs/11_plain.json'
json.dump(d, open(sys.argv[1], 'w'), indent=1)
PY

echo "· the same fling, against the plain build"
node tools/capture/scene.js "$SCRATCH/scene.json" --url "$BASE/" --browser webkit \
  --pair "$PAIR" --profile "$SCRATCH/profile" >"$SCRATCH/scene.log" 2>&1 \
  || { tail -20 "$SCRATCH/scene.log"; exit 1; }

python3 - "$OUT" <<'PY'
import json, sys

def read(path):
    with open(path) as f:
        d = json.load(f)
    per = [x for x in (d.get('per_frame') or []) if isinstance(x, dict)]
    b = sorted(x.get('build_ms', 0) for x in per)
    n = len(b)
    q = lambda p: b[min(n - 1, int(n * p))] if n else None
    tail = per[-300:]
    tb = sorted(x.get('build_ms', 0) for x in tail)
    m = len(tb)
    return {
        'frames': n,
        'build_ms': {'p50': q(.5), 'p90': q(.9), 'p95': q(.95), 'max': b[-1] if n else None},
        'the_fling_alone': {
            'frames': m,
            'p50': tb[m // 2] if m else None,
            'over_400_ms': sum(1 for v in tb if v > 400),
            'median_of_those': sorted(v for v in tb if v > 400)[max(0, sum(1 for v in tb if v > 400) // 2)]
            if any(v > 400 for v in tb) else None,
        },
    }

def rows(path):
    try:
        with open(path) as f:
            d = json.load(f)
        return {'rows_built_total': d.get('rows_built_total'),
                'rows_built_worst_tick': d.get('rows_built_worst_tick'),
                'travelled': d.get('travelled')}
    except Exception as e:
        return {'error': str(e)}

out = {
    'what': 'the same fling, the same seeded year, the same driven clock, against two builds of '
            'the same commit: one with the hands\' contextual alternates and ligatures on, which '
            'is the app, and one with them off, which exists only to be measured against it.',
    'why': 'a fling frame that builds no rows costs 4 ms and one that builds two and a half costs '
           '688. The test that was read as ruling the fonts out runs under flutter test, which '
           'passes --use-test-fonts --disable-asset-fonts, so it laid its paragraphs out in a font '
           'with no alternates and could not have seen this either way.',
    'with_the_alternates': read('evidence/logs/scroll_webkit.json'),
    'without_them': read('evidence/logs/scroll_webkit_plain.json'),
    'rows_with_the_alternates': rows('evidence/logs/11_chat_scroll.fling.json'),
    'rows_without_them': rows('evidence/logs/11_plain.fling.json'),
}
a = out['with_the_alternates']['the_fling_alone']
b = out['without_them']['the_fling_alone']
if a.get('median_of_those') and b.get('median_of_those'):
    out['what_a_heavy_frame_costs'] = {
        'with': a['median_of_those'], 'without': b['median_of_those'],
        'share_the_alternates_are': round(1 - b['median_of_those'] / a['median_of_those'], 3),
    }
out['heavy_frames'] = {'with': a.get('over_400_ms'), 'without': b.get('over_400_ms'), 'of': 300}
with open(sys.argv[1], 'w') as f:
    f.write(json.dumps(out, indent=1) + '\n')
print(json.dumps({k: out[k] for k in ('heavy_frames', 'what_a_heavy_frame_costs') if k in out}, indent=1))
PY
rm -rf evidence/frames/11_plain
echo "PLAIN FONTS DONE"
