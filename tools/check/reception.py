#!/usr/bin/env python3
"""tools/check/reception.py — did the phone draw what it was told to show?

    python3 tools/check/reception.py [evidence/logs/reception.json]

A notification is drawn by the browser, not by the page, so a machine with no notification
presenter photographs nothing — and for five cycles the reception record read three pushes
delivered and `records: []`, which was read as the app not announcing anything. What had actually
happened is that every one of those calls was refused: `silent: true` with a vibration pattern is
a TypeError in Chromium ("Silent notifications must not specify vibration patterns") and nothing
was drawn at all.

The worker writes down what it was asked, what it decided, and whether the platform drew it. This
reads that back: an arrival the phone could not draw is a failure with a reason, and a record with
nothing in it means the worker never ran.
"""
import json
import sys


def main(argv):
    path = argv[0] if argv else 'evidence/logs/reception.json'
    try:
        with open(path, encoding='utf-8') as f:
            d = json.load(f)
    except Exception as e:                                    # noqa: BLE001 - the reason is the point
        print(f'  {path} unreadable: {e}')
        return 1
    shown = d.get('shown_by_the_worker')
    if not isinstance(shown, list) or not shown:
        print('  the worker recorded nothing: no push reached it, or it never ran')
        return 1
    bad = [r for r in shown if not r.get('shown')]
    for r in bad:
        print(f"  {r.get('kind')} from {r.get('from')}: {r.get('why')}")
    drawn = len(shown) - len(bad)
    print(f'  {len(shown)} arrival(s) at the worker, {drawn} drawn, '
          f"{len(d.get('records') or [])} still held by the browser")
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
