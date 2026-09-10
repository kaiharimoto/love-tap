#!/usr/bin/env python3
"""A torn edge must not repeat.

A material critic autocorrelated one feeling object's left edge at 0.50 on lag 31 px and 0.49 on
lag 60 — one period and two — and counted four V-notches with straight sides over 125 px. That is
what `0.0013 * sin(y * 900) + 0.0007 * sin(y * 2400)` draws, and three places in the rig drew their
torn edges that way: the dog-eared card, the bookmark's head, the pinch strip's two ends, and the
fold rig's own sheet. Two sines are two periods however they are weighted.

This checks the profile the rig now uses — blender/rig/common.torn_edge — rather than a rendered
silhouette, because a rendered silhouette is a cloud of loose fibres and where its edge *is* is a
judgement. The profile is what the mesh is built from, and it is testable exactly.

Three things are asserted, all measured:

  · no self-correlation above --max-corr at any lag from four samples up. The old two-sine profile
    reads 0.72 on the fold sheet's edge and 0.50 on the object's; noise with no period reads well
    under a third.
  · the edge uses the depth it is given: peak-to-peak at least --min-span of it, so a tear is not
    a straight line with a wobble.
  · it is deterministic: the same seed gives the same edge, on both phones and on every render.

    python3 tools/check/torn.py --out evidence/logs/torn.json
"""
import argparse
import importlib.util
import json
import math
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COMMON = os.path.join(ROOT, "blender", "rig", "common.py")


def load_torn_edge():
    """common.py imports bpy at the top, so take the one function out of the source.

    Reading the file the rig actually uses, not a copy: a check that tests its own copy of the
    code tests nothing.
    """
    src = open(COMMON, encoding="utf-8").read()
    i = src.find("def torn_edge(")
    j = src.find("\ndef ", i + 1)
    if i < 0 or j < 0:
        raise SystemExit("torn_edge is not in blender/rig/common.py any more")
    ns = {"np": np, "math": math}
    exec(compile(src[i:j], COMMON, "exec"), ns)  # noqa: S102 - the rig's own source
    return ns["torn_edge"]


def measure(fn, seed, span_mm, deep_mm, samples):
    f = fn(seed, span_mm, deep_mm=deep_mm)
    u = np.linspace(0.0, span_mm, samples, endpoint=False)
    y = np.array([f(x) for x in u]) * 1000.0          # metres -> mm
    k = 31
    pad = np.pad(y, (k // 2, k // 2), mode="edge")
    smooth = np.convolve(pad, np.ones(k) / k, "valid")[:len(y)]
    hp = y - smooth
    hp = hp - hp.mean()
    ac = np.correlate(hp, hp, "full")[len(hp) - 1:]
    ac = ac / ac[0]
    # Past the central lobe, and that qualifier is the whole measurement. Any continuous profile
    # correlates with itself at small lags — that is what continuous means, and a torn edge is
    # continuous. What a *period* does is bring the correlation back up after it has fallen
    # through zero, at the period and again at twice it. So: find where the central lobe ends,
    # and take the largest thing after it.
    zero = int(np.argmax(ac < 0.0)) if (ac < 0.0).any() else len(ac)
    tail = ac[zero:samples // 3]
    if tail.size == 0:
        return {"seed": int(seed), "peak_to_peak_mm": round(float(y.max() - y.min()), 3),
                "uses_of_its_depth": round(float((y.max() - y.min()) / deep_mm), 3),
                "worst_self_correlation": 0.0, "at_lag": None,
                "central_lobe_ends_at_lag": zero}
    top = int(np.argmax(tail)) + zero
    return {
        "seed": int(seed),
        "peak_to_peak_mm": round(float(y.max() - y.min()), 3),
        "uses_of_its_depth": round(float((y.max() - y.min()) / deep_mm), 3),
        "worst_self_correlation": round(float(ac[top]), 3),
        "at_lag": top,
        "central_lobe_ends_at_lag": zero,
    }


def library_contours(box=31):
    """How far the packed tear masks' own contours wander, in pixels of the mask.

    The profile above is what the *rig* draws. This is what the *library* holds, which is a
    different question and one a material critic asked on the glass: "those edges deviate by rms
    0.36-0.59 px ... only three of fourteen edges on this screen have contour excursions worth the
    name". Measured here at the source: the first opaque pixel down each column of the middle sixty
    per cent of a mask, high-passed over a 31-column window, on whichever of the top and bottom
    edges is the quieter.

    Reported and not gated, because the fix is fifty-six Blender renders of the relief and the
    shadow behind them, and a gate nobody can turn green is a gate that gets ignored.
    """
    import glob as _glob
    from PIL import Image
    out = []
    for path in sorted(_glob.glob(os.path.join(ROOT, "app", "assets", "tears", "tear_*.webp"))):
        name = os.path.basename(path)
        if "_edge" in name or "_shadow" in name:
            continue
        with Image.open(path) as im:
            al = np.asarray(im.convert("RGBA"))[..., 3].astype(float)
        h, w = al.shape
        got = []
        for side in ("top", "bottom"):
            prof = []
            whole = True
            for x in range(int(w * 0.2), int(w * 0.8)):
                col = al[:, x] if side == "top" else al[::-1, x]
                if col.max() <= 127:
                    whole = False
                    break
                prof.append(int(np.argmax(col > 127)))
            if not whole or len(prof) < 50:
                continue
            v = np.array(prof, float)
            pad = np.pad(v, (box // 2, box // 2), mode="edge")
            smooth = np.convolve(pad, np.ones(box) / box, "valid")[:len(v)]
            got.append(float((v - smooth).std()))
        if got:
            out.append((name.rsplit(".", 1)[0], round(min(got), 2)))
    if not out:
        return None
    vals = np.array([v for _, v in out])
    out.sort(key=lambda r: r[1])
    return {
        "masks": len(out),
        "how": "the first opaque pixel down each column of the middle sixty per cent, high-passed "
               "over 31 columns, on whichever of the top and bottom edges wanders less",
        "rms_px": {"min": round(float(vals.min()), 2),
                   "p25": round(float(np.percentile(vals, 25)), 2),
                   "median": round(float(np.median(vals)), 2),
                   "max": round(float(vals.max()), 2)},
        "under_2px": int((vals < 2.0).sum()),
        "quietest_ten": out[:10],
        "what_it_means": "a critic measured the note edges they were content with at rms 2.88 to "
                         "5.14 on the glass and the ones they were not at 0.36 to 0.59. Half this "
                         "library is under 2. The cause is in tools/tears/tear.py: the fracture's "
                         "Hurst exponent runs to 1.15, and 1.15 is a clean pull, and a clean pull "
                         "is too clean. Not re-rendered this cycle — it is fifty-six masks and "
                         "their relief and their shadows, behind a capture already waiting on "
                         "thirty-six stock renders — and it is written here so the next cycle "
                         "starts from a number instead of from an impression.",
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-corr", type=float, default=0.45,
                    help="past the central lobe. Measured: the six edges the rig makes read "
                         "0.16 to 0.34, the two-sine shape they replaced reads 0.80 to 0.81, and "
                         "the report carries both so the gate can be seen to sit between them")
    ap.add_argument("--min-span", type=float, default=0.7,
                    help="how much of the depth it is given the edge must actually use")
    ap.add_argument("--samples", type=int, default=311, help="as many as a rendered edge has rows")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    torn_edge = load_torn_edge()
    rows = []
    for seed, span, deep in ((0xD09EA2, 30.0, 1.5), (0xB00C1, 17.0, 1.4), (0x91C4A, 17.0, 0.8),
                             (12345, 148.0, 4.2), (999, 148.0, 4.2), (7, 105.0, 4.2)):
        rows.append(measure(torn_edge, seed, span, deep, a.samples))

    # The control: the shape this replaced, measured by the same code. A check that can no longer
    # see a period would pass everything, so it says here what it can see.
    def two_sines(seed, span_mm, deep_mm=1.6):
        a = (seed % 1000) / 1000.0 * 6.28
        b = (seed % 997) / 997.0 * 6.28

        def at(u_mm):
            d = (0.62 * (0.5 + 0.5 * math.sin(2.0 * math.pi * u_mm / 12.0 + a))
                 + 0.38 * (0.5 + 0.5 * math.sin(2.0 * math.pi * u_mm / 2.2 + b)))
            return (d ** 1.4) * deep_mm / 1000.0
        return at

    control = [measure(two_sines, s, 105.0, 4.2, a.samples) for s in (12345, 999, 7)]

    same = torn_edge(4242, 60.0, deep_mm=2.0)
    again = torn_edge(4242, 60.0, deep_mm=2.0)
    deterministic = all(abs(same(x) - again(x)) < 1e-15 for x in np.linspace(0, 60, 97))

    worst = max(r["worst_self_correlation"] for r in rows)
    least = min(r["uses_of_its_depth"] for r in rows)
    report = {
        "what": "blender/rig/common.torn_edge, the profile every torn edge in the rig is built "
                "from, measured the way a critic measures a silhouette",
        "max_corr": a.max_corr,
        "min_span": a.min_span,
        "the_shape_this_replaced": {
            "what": "two sines with random phases, one about a finger's width and one about a "
                    "fibre bundle's, raised to a power — what the fold rig and three objects drew "
                    "their torn edges with. On the rendered silhouettes it self-correlated 0.72 at "
                    "lag 34 (the fold sheet) and 0.50 at lag 31 with 0.49 at lag 60 (the "
                    "dog-eared card, a critic's measurement): one period and its harmonic.",
            "measured_here_by_the_same_code": control,
        },
        "edges": rows,
        "worst_self_correlation": worst,
        "least_of_its_depth_used": least,
        "deterministic": deterministic,
        "the_library_the_app_holds": library_contours(),
    }
    report["the_control_is_caught"] = min(c["worst_self_correlation"] for c in control) > a.max_corr
    report["ok"] = (worst <= a.max_corr and least >= a.min_span and deterministic
                    and report["the_control_is_caught"])
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
