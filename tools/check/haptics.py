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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--strip", default="")
    ap.add_argument("--out", default="")
    ap.add_argument("--felt-floor", type=float, default=18.0,
                    help="two patterns closer than this are one pattern as far as a hand is "
                         "concerned; calibrated on the vocabulary, whose median pair is about 130")
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
    felts = {f["id"]: felt(f["segments"]) for f in rows}
    ids = list(shapes)
    near = []
    close = []
    all_felt = []
    for i in range(len(ids)):
        for j in range(i + 1, len(ids)):
            d = float(np.abs(shapes[ids[i]] - shapes[ids[j]]).mean())
            if d < 0.04:
                near.append({"a": ids[i], "b": ids[j], "shape_distance": round(d, 4)})
            fd = felt_distance(felts[ids[i]], felts[ids[j]])
            all_felt.append(fd)
            if fd < a.felt_floor:
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
                   "difference times a hundred. Two patterns a finger cannot separate score near "
                   "zero however different their strings are.",
            "floor": a.felt_floor,
            "median": round(float(np.median(all_felt)), 2) if all_felt else None,
            "smallest": round(float(min(all_felt)), 2) if all_felt else None,
            "closest_pairs": sorted(
                [{"a": ids[i], "b": ids[j],
                  "felt_distance": round(felt_distance(felts[ids[i]], felts[ids[j]]), 2)}
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
