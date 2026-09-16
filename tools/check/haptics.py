#!/usr/bin/env python3
"""Every feeling's haptic, written down, because a haptic cannot be screenshotted.

    python3 tools/check/haptics.py --out evidence/haptics.json

The evidence set has a still or a clip for everything the eye can check and nothing at all for the
one channel the brief cares most about. `docs/FEELINGS.md` says each feeling is "one object, one
haptic sequence, one sound, one colour", and rubric row emotional_transmission is the row this
build scores worst on -- 6 of 17 -- so "the haptics exist and are distinct" should not be a thing
anyone has to take on trust. A photograph cannot carry it. A table can.

For each feeling it records:

  duration   total milliseconds, on and off together: how long the phone is busy.
  envelope   the segments, as (ms, amplitude) pairs, plus the peak and the mean amplitude
             weighted by time -- which is what separates a tap from a press of the same length.
  strip      the sequence drawn as characters at 20 ms a column, so two feelings can be compared
             by eye in a diff. This is the artifact standing in for the screenshot.

And it checks what `docs/FEELINGS.md` states as a rule: no two feelings share a haptic sequence,
and no two share an object asset. A palette of feelings that repeat itself is a palette that
transmits less than it claims to.

The notation is `80@90 off40 160@160`, with `(...) ×N` and `... ×N` repeats, and it is parsed here
in the same terms as `parseHaptic` in `app/lib/feelings/builtins.dart`. Two parsers is one too
many, so `app/test/the_haptics_are_written_down_test.dart` asserts the Dart agrees with the file
this writes; if they ever drift, the Dart test fails rather than the drift going unnoticed.
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILTINS = os.path.join(ROOT, "app", "lib", "feelings", "builtins.dart")

MS_PER_COLUMN = 20
AMP_MAX = 255
RAMP = " .:-=+*#%@"     # ten steps, off to full


def expand(text):
    """`(a b) ×3` and `a b ×3`, the two repeat forms the notation allows."""
    text = text.strip()
    text = re.sub(r"\(([^)]+)\)\s*[×x](\d+)",
                  lambda m: " ".join([m.group(1)] * int(m.group(2))), text)
    m = re.match(r"^(.*?)\s*[×x](\d+)$", text)
    if m:
        text = " ".join([m.group(1)] * int(m.group(2)))
    return text


def segments(spec):
    """`80@90 off40` -> [(80, 90), (40, 0)]."""
    out = []
    for tok in expand(spec).split():
        if tok.startswith("off"):
            out.append((int(tok[3:]), 0))
        else:
            ms, amp = tok.split("@")
            out.append((int(ms), int(amp)))
    return out


def strip(segs):
    """The sequence as characters, one column per MS_PER_COLUMN, so a diff shows the shape."""
    out = []
    for ms, amp in segs:
        columns = max(1, round(ms / MS_PER_COLUMN))
        out.append(RAMP[min(len(RAMP) - 1, round(amp / AMP_MAX * (len(RAMP) - 1)))] * columns)
    return "".join(out)


FIELDS = ("id", "name", "family", "object", "haptic", "sound", "colour")


def feelings(path=BUILTINS):
    """The built-in feelings, in the order `builtins.dart` declares them.

    Each row is cut at `Feeling(` and then at the end of its line before its fields are read,
    rather than matched by one pattern across the file. Two earlier versions each lost two rows
    and neither said so. One pattern with a lazy `.*?` under re.DOTALL ran past the end of a row
    and took the next row's field, swallowing `steady` and `hold`; cutting the row at its first
    `)` instead lost `overwhelmed` and `grey`, whose haptics are written `(60@70 off60) ×8` and
    end at that bracket. Both produced a file that looked complete and was short by two. The Dart
    test in `app/test/the_haptics_are_written_down_test.dart` caught each of them on the first
    run, which is the entire reason that test exists.
    """
    with open(path, encoding="utf-8") as f:
        src = f.read()
    out = []
    for chunk in src.split("Feeling(")[1:]:
        # to the end of the line, not to the first ')': `overwhelmed` and `grey` write their
        # haptics as `(60@70 off60) ×8`, and cutting at that bracket loses the last two fields.
        chunk = chunk.split("\n", 1)[0]
        row = {}
        for field in FIELDS:
            m = re.search(r"\b" + field + r":\s*(?:Family\.)?'?([^',]+)'?", chunk)
            if m is None:
                break
            row[field] = m.group(1)
        if len(row) == len(FIELDS):
            out.append(row)
    return out


def describe(f):
    segs = segments(f["haptic"])
    total = sum(ms for ms, _ in segs)
    buzzing = sum(ms for ms, amp in segs if amp > 0)
    peak = max((amp for _, amp in segs), default=0)
    weighted = sum(ms * amp for ms, amp in segs) / total if total else 0.0
    return {
        **f,
        "duration_ms": total,
        "buzzing_ms": buzzing,
        "silent_ms": total - buzzing,
        "pulses": sum(1 for _, amp in segs if amp > 0),
        "peak_amp": peak,
        "mean_amp_over_time": round(weighted, 1),
        "envelope": [{"ms": ms, "amp": amp} for ms, amp in segs],
        "strip": strip(segs),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    rows = feelings()
    if not rows:
        print(f"haptics: no feelings parsed from {BUILTINS}", file=sys.stderr)
        return 2
    described = [describe(f) for f in rows]

    problems = []
    for key, what in (("haptic", "haptic sequence"), ("object", "object asset")):
        seen = {}
        for f in described:
            seen.setdefault(f[key], []).append(f["id"])
        for value, ids in sorted(seen.items()):
            if len(ids) > 1:
                problems.append(f"{what} {value!r} is shared by {', '.join(ids)} — "
                                f"docs/FEELINGS.md says no two rows share one")

    report = {
        "what": "every built-in feeling's haptic, from app/lib/feelings/builtins.dart",
        "notation": "ms@amp, offN for a gap, (…) ×N to repeat; amp is 0–255",
        "strip_ms_per_column": MS_PER_COLUMN,
        "strip_ramp": RAMP,
        "feelings": len(described),
        "families": sorted({f["family"] for f in described}),
        "duration_ms": {
            "shortest": min(f["duration_ms"] for f in described),
            "longest": max(f["duration_ms"] for f in described),
            "mean": round(sum(f["duration_ms"] for f in described) / len(described), 1),
        },
        "problems": problems,
        "rows": described,
    }

    text = json.dumps(report, indent=1, ensure_ascii=False)
    if args.out:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"haptics: {len(described)} feelings -> {args.out}")
    else:
        print(text)
    for f in described:
        print(f"  {f['id']:<14} {f['family']:<9} {f['duration_ms']:>5} ms  "
              f"{f['pulses']} pulses  peak {f['peak_amp']:>3}  |{f['strip']}|")
    if problems:
        for p in problems:
            print(f"haptics: {p}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
