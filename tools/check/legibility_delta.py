#!/usr/bin/env python3
"""The same words, read twice, so that a change in the light is not read as a change in the text.

    python3 tools/check/legibility_delta.py --before /tmp/before --after evidence
    python3 tools/check/legibility_delta.py --before /tmp/before --after evidence --gate

`legibility.py` reports `total_below_floor / total_runs` over one capture. Comparing that number
across two captures is only sound if the two captures contain the same runs, and they do not. A run
is not a declared thing: it is found in the pixels, by a mark detector, and anything that changes
the pixels changes how many runs there are. Between the pre-relight capture at `e5d6ce8` and the
post-relight one at `097bea5` the count went 708 to 759 with `legibility.py` byte-identical across
the two -- 86 runs of the old set were not found in the new one, and 137 runs of the new set had
not existed before.

So the headline moved for two reasons at once and the ratio cannot separate them. This can:

    matched   a run found in both captures, at the same place. The same text on the same surface,
              lit twice. Its failure count is the only number in this file that means "the writing
              got harder to read", and it is the number to gate on.
    gone      found before, not after.
    new       found after, not before. These are not necessarily writing. The detector looks for
              glyph-shaped marks, and a surface that acquires texture acquires glyph-shaped marks:
              when the relight stopped the torn paper lips clipping to flat white, their fibre
              steps became marks, and 102 of the 137 new runs read below floor at a median
              `ink_core` of 1.18 -- stroke and ground the same luminance, which is what a piece of
              one surface reads as, not ink on paper.

Runs are matched by intersection-over-union of their boxes within an artifact, greedily, best pair
first. IoU is the right shape of test here because a run's box is the bounding box of the marks
that composed it, so the same line of text re-found under a different light lands in very nearly
the same rectangle but rarely the identical one.

To get a `--before` directory out of git without touching `evidence/`:

    mkdir /tmp/before
    for f in evidence/*.png; do git show <rev>:$f > /tmp/before/$(basename $f); done

Both directories are read, never written. This file measures; it does not retouch.
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import legibility as L  # noqa: E402

# How much two boxes have to overlap before they are the same run seen twice. Chosen against the
# e5d6ce8 -> 097bea5 pair: at 0.30 the matched set is 622 runs and is stable to +-6 runs anywhere
# between 0.20 and 0.45, so nothing here rests on the exact value. Below 0.15 adjacent lines of a
# paragraph start pairing with each other; above 0.6 a line that gained one glyph stops matching
# itself.
IOU = 0.30


def iou(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    x0, y0 = max(ax, bx), max(ay, by)
    x1, y1 = min(ax + aw, bx + bw), min(ay + ah, by + bh)
    if x1 <= x0 or y1 <= y0:
        return 0.0
    inter = (x1 - x0) * (y1 - y0)
    return inter / float(aw * ah + bw * bh - inter)


def pair_up(before, after, thr=IOU):
    """Greedy best-first pairing of two run lists. Returns (pairs, gone, new) as index lists."""
    cand = []
    for i, b in enumerate(before):
        for j, n in enumerate(after):
            v = iou(b["box"], n["box"])
            if v >= thr:
                cand.append((v, i, j))
    cand.sort(key=lambda t: (-t[0], t[1], t[2]))
    ub, un, pairs = set(), set(), []
    for v, i, j in cand:
        if i in ub or j in un:
            continue
        ub.add(i)
        un.add(j)
        pairs.append((i, j))
    gone = [i for i in range(len(before)) if i not in ub]
    new = [j for j in range(len(after)) if j not in un]
    return pairs, gone, new


def failing(r):
    return r["ink_core"] < r["floor"]


def read_dir(d, dusk):
    out = {}
    for f in sorted(os.listdir(d)):
        if not f.endswith(".png"):
            continue
        m = L.measure(os.path.join(d, f),
                      L.FLOOR_BODY_DUSK if f in dusk else L.FLOOR_BODY,
                      L.FLOOR_LARGE_DUSK if f in dusk else L.FLOOR_LARGE)
        out[f] = m.get("runs", [])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", required=True, help="directory of the earlier stills")
    ap.add_argument("--after", default=L.EVIDENCE, help="directory of the later stills")
    ap.add_argument("--out", default="", help="write the full comparison as JSON")
    ap.add_argument("--iou", type=float, default=IOU)
    ap.add_argument("--dusk", default="", help="comma-separated artifacts held to the dusk floors")
    ap.add_argument("--gate", action="store_true",
                    help="exit 1 if the matched-run failure rate rose. Without it this file "
                         "reports and exits 0, the same contract palette.py has with --floors.")
    ap.add_argument("--tolerance", type=float, default=0.0,
                    help="how much the matched-run rate may rise before --gate fails it")
    args = ap.parse_args()
    dusk = {n.strip() for n in args.dusk.split(",") if n.strip()}

    for d in (args.before, args.after):
        if not os.path.isdir(d):
            print(f"legibility_delta: not a directory: {d}", file=sys.stderr)
            return 2

    before, after = read_dir(args.before, dusk), read_dir(args.after, dusk)
    shared = sorted(set(before) & set(after))
    if not shared:
        print("legibility_delta: the two directories share no artifact filenames", file=sys.stderr)
        return 2
    only_b = sorted(set(before) - set(after))
    only_a = sorted(set(after) - set(before))

    report = {"before": args.before, "after": args.after, "iou": args.iou,
              "dusk": sorted(dusk), "artifacts": {},
              "not_in_after": only_b, "not_in_before": only_a}
    T = {k: 0 for k in ("runs_b", "runs_a", "matched", "gone", "new",
                        "m_fail_b", "m_fail_a", "gone_fail", "new_fail",
                        "fail_b", "fail_a")}

    for name in shared:
        B, A = before[name], after[name]
        pairs, gone, new = pair_up(B, A, args.iou)
        row = {
            "runs_b": len(B), "runs_a": len(A),
            "matched": len(pairs), "gone": len(gone), "new": len(new),
            "m_fail_b": sum(1 for i, j in pairs if failing(B[i])),
            "m_fail_a": sum(1 for i, j in pairs if failing(A[j])),
            "gone_fail": sum(1 for i in gone if failing(B[i])),
            "new_fail": sum(1 for j in new if failing(A[j])),
            "fail_b": sum(1 for r in B if failing(r)),
            "fail_a": sum(1 for r in A if failing(r)),
        }
        # The runs that changed verdict without moving: the only place where a specific line of
        # text can be said to have got harder or easier to read.
        row["turned_bad"] = [
            {"box": A[j]["box"], "ink_core_b": B[i]["ink_core"], "ink_core_a": A[j]["ink_core"],
             "floor": A[j]["floor"], "role": A[j]["role"], "polarity": A[j]["polarity"]}
            for i, j in pairs if not failing(B[i]) and failing(A[j])
        ]
        row["turned_good"] = [
            {"box": A[j]["box"], "ink_core_b": B[i]["ink_core"], "ink_core_a": A[j]["ink_core"]}
            for i, j in pairs if failing(B[i]) and not failing(A[j])
        ]
        # What the new runs look like as a population. A median ink_core near 1.0 says the
        # detector has boxed one surface and called part of it ink, which is texture, not writing.
        if new:
            nf = [A[j] for j in new]
            row["new_median_ink_core"] = round(float(np.median([r["ink_core"] for r in nf])), 2)
            row["new_median_glyphs"] = int(np.median([r["glyphs"] for r in nf]))
        report["artifacts"][name] = row
        for k in T:
            T[k] += row[k]

    rate = lambda f, n: (f / n) if n else 0.0  # noqa: E731
    T["matched_rate_b"] = round(rate(T["m_fail_b"], T["matched"]), 4)
    T["matched_rate_a"] = round(rate(T["m_fail_a"], T["matched"]), 4)
    T["whole_rate_b"] = round(rate(T["fail_b"], T["runs_b"]), 4)
    T["whole_rate_a"] = round(rate(T["fail_a"], T["runs_a"]), 4)
    T["new_fail_rate"] = round(rate(T["new_fail"], T["new"]), 4)
    report["totals"] = T

    w = 24
    print(f"{'artifact':{w}}{'runs':>13}{'matched':>9}{'gone':>6}{'new':>6}"
          f"{'matched fails':>16}{'new fails':>11}")
    for name in shared:
        r = report["artifacts"][name]
        print(f"{name:{w}}{r['runs_b']:6d}->{r['runs_a']:5d}{r['matched']:9d}{r['gone']:6d}"
              f"{r['new']:6d}{r['m_fail_b']:9d}->{r['m_fail_a']:4d}"
              f"{r['new_fail']:7d}/{r['new']:<3d}")
    print(f"{'TOTAL':{w}}{T['runs_b']:6d}->{T['runs_a']:5d}{T['matched']:9d}{T['gone']:6d}"
          f"{T['new']:6d}{T['m_fail_b']:9d}->{T['m_fail_a']:4d}"
          f"{T['new_fail']:7d}/{T['new']:<3d}")
    if only_b or only_a:
        print(f"\nartifacts on one side only: before-only {only_b}, after-only {only_a} "
              f"(excluded from every number above)")

    print(f"\n  the same text, lit twice   {T['m_fail_b']} -> {T['m_fail_a']} of {T['matched']} "
          f"matched runs     {T['matched_rate_b']:.4f} -> {T['matched_rate_a']:.4f}")
    print(f"  the whole-set ratio        {T['fail_b']} -> {T['fail_a']} of "
          f"{T['runs_b']} -> {T['runs_a']} runs   {T['whole_rate_b']:.4f} -> {T['whole_rate_a']:.4f}")
    print(f"  runs that went, and failed {T['gone']:5d}, {T['gone_fail']} of them failing")
    print(f"  runs that arrived, failing {T['new']:5d}, {T['new_fail']} of them failing "
          f"({T['new_fail_rate']:.0%} against {T['matched_rate_a']:.0%} on matched runs)")
    delta = T["fail_a"] - T["fail_b"]
    same = T["m_fail_a"] - T["m_fail_b"]
    print(f"\n  so of the {delta:+d} in the headline, {same:+d} is the same text reading "
          f"differently and {delta - same:+d} is the run population changing under the detector.")

    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=1)
        print(f"\nwrote {args.out}")

    if not args.gate:
        return 0
    rose = T["matched_rate_a"] - T["matched_rate_b"]
    if rose > args.tolerance:
        print(f"\nFAIL: the matched-run failure rate rose by {rose:.4f}, "
              f"over a tolerance of {args.tolerance:.4f}")
        return 1
    print(f"\nOK: the matched-run failure rate moved by {rose:+.4f}, "
          f"within a tolerance of {args.tolerance:.4f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
