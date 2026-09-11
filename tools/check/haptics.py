#!/usr/bin/env python3
"""The haptic vocabulary, drawn to scale so it can be read.

    python3 tools/check/haptics.py evidence/logs/haptics.json --strip evidence/crops/haptics_strip.png \
        --out evidence/logs/haptics.check.json

evidence/logs/haptics.json is written by the app itself in capture mode (window.__deskHaptics): every
feeling in its registry with the segments the vibrator is given and the page is moved by. This draws
those segments, one row a feeling, at one scale, so a reader can see that thirty-odd feelings are
thirty-odd rhythms — and checks the thing the brief forbids, two feelings sharing a pattern, by two
measures: the exact string, and the shape (the on/off sequence normalised in time), so a pattern that
is another one played faster is caught as well as a copy.
"""
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw


def felt(segments, bin_ms=40):
    """The pattern as a finger would take it: real milliseconds, Stevens-weighted amplitude.

    `shape` below normalises time, so two patterns of different lengths with the same outline
    compare as the same and two with the same rhythm at different lengths compare as different.
    Neither is what a hand does. An emotional critic pointed at the pair this missed: stuck with me
    at 480 ms, eight pulses at a flat 220, and overwhelmed at 500 ms, ten pulses at a mean 227.5 —
    four per cent of duration and three per cent of amplitude apart, and the check said they were
    distinct because their strings differ.

    So: forty-millisecond bins of real time, out to the longer of the two patterns, with amplitude
    raised to 0.6 — the exponent vibrotactile intensity is usually fitted with, which is why a
    pattern at half amplitude does not feel half as strong. The distance is the mean absolute
    difference over those bins, times a hundred, so it reads as a number rather than a fraction.
    """
    total = sum(s["ms"] for s in segments) or 1
    n = max(1, int(round(total / bin_ms)))
    out = np.zeros(n)
    at = 0.0
    for s in segments:
        a = at / bin_ms
        b = (at + s["ms"]) / bin_ms
        lo, hi = int(np.floor(a)), min(n, int(np.ceil(b)))
        for k in range(lo, hi):
            covered = max(0.0, min(b, k + 1) - max(a, k))
            out[k] += covered * (s["amp"] / 255.0) ** 0.6
        at += s["ms"]
    return np.clip(out, 0, 1)


def felt_distance(x, y, bin_ms=40):
    """Two terms, because a hand reads two things: what happens, and how long it goes on.

    The bins alone are not enough. A single thirty-millisecond tap and a five-hundred-millisecond
    three-part snap score close on bins alone, because the tap is one bin of signal against twelve
    bins of silence and the mean is dominated by the silence — and a finger is in no doubt at all
    about which of those two it was just given. So the difference in total length is its own term,
    scaled so that one pattern twice the length of another is worth about twenty points.
    """
    n = max(len(x), len(y))
    a = np.zeros(n); a[:len(x)] = x
    b = np.zeros(n); b[:len(y)] = y
    bins = float(np.abs(a - b).mean()) * 100.0
    da, db = len(x) * bin_ms, len(y) * bin_ms
    length = 40.0 * abs(da - db) / max(da, db, 1)
    return bins + length


def stretched(segments, k):
    """The same pattern played [k] times as slowly."""
    return [{"ms": max(1, s["ms"] * k), "amp": s["amp"]} for s in segments]


def felt_apart(a, b, bin_ms=40):
    """How far apart two patterns are to a hand — tolerating a tempo difference it cannot detect.

    `felt_distance` compares two fixed bin grids, and that makes it sensitive to something a finger
    is not: playing the same rhythm seven per cent slower slides every pulse out of its bin and
    scores as a large difference. Measured — the derivation below, on this build's own vocabulary —
    that put a pair nobody could separate (`crown` against itself at half the duration Weber
    fraction) at 32.94, above a pair anybody could separate (`poke` against itself at twice it) at
    22.50. The bands crossed, which means the number was not measuring what it was gating on.

    A tempo change inside the duration Weber fraction is not detectable, so it is quotiented out:
    the bin term is the best alignment over uniform stretches within that fraction. The overall
    length of the pattern *is* felt, so it keeps its own term — with the same fraction as a
    deadband, because the first fifteen per cent of a length difference is not felt either.
    """
    da = sum(s["ms"] for s in a) or 1
    db = sum(s["ms"] for s in b) or 1
    best = None
    for step in range(-4, 5):
        k = 1.0 + step * (JND_DURATION / 4.0)
        if k <= 0:
            continue
        x = felt(a, bin_ms)
        y = felt(stretched(b, k), bin_ms)
        n = max(len(x), len(y))
        p1 = np.zeros(n); p1[:len(x)] = x
        p2 = np.zeros(n); p2[:len(y)] = y
        d = float(np.abs(p1 - p2).mean()) * 100.0
        best = d if best is None else min(best, d)
    gap = abs(da - db) / max(da, db)
    length = 40.0 * max(0.0, gap - JND_DURATION) / (1.0 - JND_DURATION)
    return (best or 0.0) + length


def shape(segments, n=64):
    """The pattern as amplitude over normalised time, so two patterns compare as shapes."""
    total = sum(s["ms"] for s in segments) or 1
    out = np.zeros(n)
    at = 0
    for s in segments:
        a = int(n * at / total)
        b = max(a + 1, int(n * (at + s["ms"]) / total))
        out[a:b] = s["amp"] / 255.0
        at += s["ms"]
    return out


# What a finger can actually resolve, as the vibrotactile literature usually reports it. These are
# the three numbers the floor is derived from, and they are here rather than in a comment because
# the derivation is run every time the check is.
#
#   amplitude   Weber fraction of about 0.15-0.20 for suprathreshold vibrotactile intensity
#               (Craig 1972; Gescheider and colleagues, repeatedly since)
#   duration    Weber fraction of about 0.15-0.25 for the length of a burst (Gescheider 1966)
#   fusion      two pulses less than about 25 ms apart are felt as one event
#
# They are used conservatively: the pair that *cannot* be told apart is built at half the Weber
# fraction, which is comfortably inside anybody's threshold, and the pair that can is built at
# twice it, which is comfortably outside.
JND_AMPLITUDE = 0.15
JND_DURATION = 0.15
FUSION_MS = 25.0


def twin(segments, amp_change, dur_change):
    """The same pattern, changed by a stated fraction in amplitude and in duration."""
    out = []
    for s in segments:
        out.append({
            "ms": max(1, int(round(s["ms"] * (1.0 + dur_change)))),
            "amp": int(round(min(255, max(0, s["amp"] * (1.0 + amp_change))))),
        })
    return out


def derive_floor(patterns, bin_ms=40):
    """What number separates 'two rhythms' from 'one rhythm twice'.

    The floor was a bare 18.0 — a number with nothing behind it, which an emotional critic said
    plainly: unlike logs/torn.json and logs/flat.json there was no derivation and no negative
    control saying what two patterns a finger genuinely cannot separate would score. A threshold
    nobody can check is a threshold that passes whatever it is given.

    So it is measured, by this code, in these units, on this build's own vocabulary. For every
    pattern in the registry:

      * a twin changed by *half* the amplitude and duration Weber fractions — a pair a finger
        cannot separate, by any published figure. The largest distance any such pair scores is the
        highest number that still means "the same pattern".
      * a twin changed by *twice* those fractions — a pair a finger can separate. The smallest
        distance any such pair scores is the lowest number that already means "two patterns".

    The floor is the geometric midpoint of those two, which puts it as far from a false pass as
    from a false fail. If the two bands cross, the measure is not separating what it claims to and
    the report says so instead of picking a number out of the overlap.
    """
    same, different = [], []
    for name, segs in patterns:
        if not segs:
            continue
        near = twin(segs, JND_AMPLITUDE / 2, JND_DURATION / 2)
        far = twin(segs, JND_AMPLITUDE * 2, JND_DURATION * 2)
        same.append((felt_apart(segs, near, bin_ms), name))
        different.append((felt_apart(segs, far, bin_ms), name))
    if not same:
        return None
    same.sort()
    different.sort()
    worst_same, worst_same_of = same[-1]
    best_diff, best_diff_of = different[0]
    crossed = worst_same >= best_diff
    floor = float(np.sqrt(max(worst_same, 1e-6) * best_diff)) if not crossed else None
    return {
        "floor": None if floor is None else round(floor, 2),
        "how": "the geometric midpoint of the two bands below, measured by this code on this "
               "build's own patterns",
        "thresholds_used": {
            "amplitude_weber_fraction": JND_AMPLITUDE,
            "duration_weber_fraction": JND_DURATION,
            "two_pulses_fuse_below_ms": FUSION_MS,
            "source": "the figures vibrotactile psychophysics usually reports — Craig 1972 and "
                      "Gescheider 1966 onwards for the two Weber fractions, and the ~25 ms at "
                      "which successive pulses stop being felt as two events",
        },
        "a_pair_a_finger_cannot_separate": {
            "built_by": "changing every segment by half the Weber fraction in both amplitude and "
                        "duration, which is inside anybody's threshold",
            "largest": round(worst_same, 2),
            "on": worst_same_of,
            "median": round(float(np.median([d for d, _ in same])), 2),
        },
        "a_pair_a_finger_can_separate": {
            "built_by": "changing every segment by twice the Weber fraction in both",
            "smallest": round(best_diff, 2),
            "on": best_diff_of,
            "median": round(float(np.median([d for d, _ in different])), 2),
        },
        "the_bands_overlap": crossed,
        "two_copies_of_one_pattern": round(
            felt_apart(patterns[0][1], list(patterns[0][1]), bin_ms), 2),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--strip", default="")
    ap.add_argument("--out", default="")
    ap.add_argument("--felt-floor", type=float, default=0.0,
                    help="two patterns closer than this are one pattern as far as a hand is "
                         "concerned. Zero means derive it — see derive_floor, which measures it "
                         "on this build's own patterns against published vibrotactile thresholds. "
                         "A number given here overrides that and is reported as an override.")
    a = ap.parse_args()
    data = json.loads(pathlib.Path(a.src).read_text())
    feelings = data.get("feelings", [])
    rows = [f for f in feelings if not f.get("retired")]
    longest = max((f["total_ms"] for f in rows), default=1)

    problems = []
    seen = {}
    for f in rows:
        seen.setdefault(f["haptic"], []).append(f["id"])
    for k, ids in seen.items():
        if len(ids) > 1:
            problems.append(f"same pattern string: {', '.join(ids)}")
    shapes = {f["id"]: shape(f["segments"]) for f in rows}
    segs = {f["id"]: f["segments"] for f in rows}
    ids = list(shapes)

    derived = derive_floor([(f["id"], f["segments"]) for f in rows])
    if a.felt_floor > 0:
        floor = a.felt_floor
    elif derived and derived["floor"]:
        floor = derived["floor"]
    else:
        # the bands crossed, or there was nothing to measure: fall back to the old bare number and
        # say in the report that that is what happened
        floor = 18.0
    near = []
    close = []
    all_felt = []
    for i in range(len(ids)):
        for j in range(i + 1, len(ids)):
            d = float(np.abs(shapes[ids[i]] - shapes[ids[j]]).mean())
            if d < 0.04:
                near.append({"a": ids[i], "b": ids[j], "shape_distance": round(d, 4)})
            fd = felt_apart(segs[ids[i]], segs[ids[j]])
            all_felt.append(fd)
            if fd < floor:
                close.append({"a": ids[i], "b": ids[j], "felt_distance": round(fd, 2)})
    for n in near:
        problems.append(f"same shape in time: {n['a']} and {n['b']} ({n['shape_distance']})")
    close.sort(key=lambda c: c["felt_distance"])
    for c in close:
        problems.append(
            f"a finger could not separate these: {c['a']} and {c['b']} ({c['felt_distance']})")

    if a.strip:
        # one row per feeling: name, family, the pattern as bars at one time scale, the length
        left, right, row_h, top = 190, 70, 22, 34
        width = left + 620 + right
        height = top + row_h * len(rows) + 16
        im = Image.new("RGB", (width, height), (241, 236, 223))
        d = ImageDraw.Draw(im)
        d.text((12, 8), f"{len(rows)} feelings · {data.get('built_in', '?')} built in · one scale: "
                        f"{longest} ms across the bar", fill=(58, 58, 60))
        for k, f in enumerate(rows):
            y = top + k * row_h
            d.text((12, y + 4), f["name"][:22], fill=(31, 42, 68))
            d.text((132, y + 4), f["family"][:8].lower(), fill=(107, 107, 110))
            x0 = left
            span = 620
            at = 0
            d.line([(x0, y + row_h - 5), (x0 + span, y + row_h - 5)], fill=(200, 194, 180), width=1)
            for s in f["segments"]:
                xa = x0 + span * at / longest
                xb = x0 + span * (at + s["ms"]) / longest
                if s["amp"] > 0:
                    h = (row_h - 8) * s["amp"] / 255.0
                    d.rectangle([xa, y + row_h - 5 - h, max(xa + 1, xb), y + row_h - 5], fill=(58, 58, 60))
                at += s["ms"]
            d.text((x0 + span + 8, y + 4), f"{f['total_ms']} ms", fill=(107, 107, 110))
        pathlib.Path(a.strip).parent.mkdir(parents=True, exist_ok=True)
        im.save(a.strip)

    report = {
        "feelings": len(rows),
        "built_in": data.get("built_in"),
        "authored": data.get("authored"),
        "families": data.get("families"),
        "longest_ms": longest,
        "shortest_ms": min((f["total_ms"] for f in rows), default=0),
        "distinct_strings": len(seen),
        "near_shapes": near,
        "felt_distance": {
            "how": "forty-millisecond bins of real time, amplitude to the power 0.6, mean absolute "
                   "difference times a hundred — at the best alignment over the tempo changes a "
                   "finger cannot detect — plus a term for the difference in overall length, with "
                   "the same fraction as a deadband. Two patterns a finger cannot separate score "
                   "near zero however different their strings are.",
            "floor": floor,
            "floor_is": ("an override given on the command line" if a.felt_floor > 0
                         else "derived, below" if derived and derived["floor"]
                         else "the old bare 18.0: the derivation's two bands overlapped, which "
                              "means this measure is not separating what it claims to"),
            "derived": derived,
            "median": round(float(np.median(all_felt)), 2) if all_felt else None,
            "smallest": round(float(min(all_felt)), 2) if all_felt else None,
            "closest_pairs": sorted(
                [{"a": ids[i], "b": ids[j],
                  "felt_distance": round(felt_apart(segs[ids[i]], segs[ids[j]]), 2)}
                 for i in range(len(ids)) for j in range(i + 1, len(ids))],
                key=lambda c: c["felt_distance"])[:6],
            "under_the_floor": close,
        },
        "problems": problems,
        "strip": a.strip or None,
        "ok": not problems and len(rows) >= 30 and len(data.get("families") or {}) >= 5,
    }
    if a.out:
        pathlib.Path(a.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(a.out).write_text(json.dumps(report, indent=1))
    print(json.dumps({k: report[k] for k in ("feelings", "distinct_strings", "problems", "ok")}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
