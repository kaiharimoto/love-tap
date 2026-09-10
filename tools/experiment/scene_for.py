#!/usr/bin/env python3
"""Write a copy of the scroll scene whose outputs are named for one arm of the experiment."""
import json, os, sys

out, name = sys.argv[1], sys.argv[2]
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
d = json.load(open(os.path.join(root, 'evidence/scenes/11_chat_scroll.json')))
for s in d['steps']:
    do = s.get('do')
    if do == 'timings':
        s['out'] = 'evidence/logs/scroll_webkit_%s.json' % name
    elif do == 'frames':
        s['dir'] = 'evidence/frames/11_%s' % name
    elif do == 'flingLog':
        s['out'] = 'evidence/logs/11_%s.fling.json' % name
    elif do == 'report':
        s['out'] = 'evidence/logs/11_%s.report.json' % name
d['log'] = 'evidence/logs/11_%s.json' % name
json.dump(d, open(out, 'w'), indent=1)
