#!/usr/bin/env python3
"""The 1-D falloff the contact-shadow renders carry, measured off the renders themselves.

WHAT THIS IS FOR. `the-tear-shadow-is-stretched-six-to-one-and-becomes-a-hard-bar` was settled at
firing 43 onto route (b): stop stretching a photographic falloff to the shape of whatever piece it
lands on, and lay the render's OWN falloff around the outline at the physical scale the piece's
lift asks for. docs/BRIEF.md 05 asks for `contact shadows baked from the render's own lighting
rather than applied as a uniform blur`, so the profile has to be MEASURED rather than invented --
a MaskFilter.blur is the anti-goal, and this is what keeps route (b) on the right side of it.

Firing 43 named the experiment that could refute the whole route before any widget code is
written: read the spill band of the shadow renders and check it carries a monotone 1-D profile
that survives being resampled to the ~11 px of spill a margin strip has room for. This is that
read, and it is also where the profile itself comes from afterwards.

WHAT IT IS NOT. It is not the gate that closes the item. That measurement is the contact band
read off each piece's own declared rect in `evidence/<artifact>.surfaces.json`, and it lives with
the item. This tool reads the library; it never looks at a capture.

HOW IT REGISTERS THE TWO IMAGES, which is the one thing worth getting right. The packed mask is
the piece's box exactly and the packed shadow is `shadow_frame` times it, centred -- and
`shadow_frame` in `app/assets/INDEX.json` is the PACKING margin (1.25), not the `shadow_frame` in
`assets/tears/relief.json`, which is what Blender framed the render at (1.2). tools/pack_assets.py
crops the shadow about the piece's own box and overwrites the number on the way past. Reading the
source file instead puts the outline about 4% out, which reads as a shadow with no spill at all:
alpha 211 under the paper and 4 one pixel outside it. Ask the packed index, which is what the app
asks.
"""
import argparse
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(HERE)
PACKED = os.path.join(ROOT, "app", "assets")


def profile_of(tear, frame, per_mm, suffix=""):
    import cv2
    import numpy as np
    from PIL import Image

    mask = np.array(Image.open(os.path.join(PACKED, "tears", f"{tear}.webp")).convert("L"))
    shadow = np.array(
        Image.open(os.path.join(PACKED, "tears", f"{tear}_shadow{suffix}.webp")).convert("RGBA")
    )[..., 3].astype(np.float32)
    h, w = shadow.shape
    pw, ph = int(round(w / frame)), int(round(h / frame))
    ox, oy = (w - pw) // 2, (h - ph) // 2
    paper = np.zeros((h, w), np.uint8)
    paper[oy:oy + ph, ox:ox + pw] = (
        cv2.resize(mask, (pw, ph), interpolation=cv2.INTER_AREA) > 128
    ).astype(np.uint8)
    # distance outward from the paper outline, in packed pixels
    d = cv2.distanceTransform((1 - paper).astype(np.uint8), cv2.DIST_L2, 5)
    ppm = pw / per_mm if per_mm else None
    rings = []
    for k in range(0, 81):
        sel = (d >= k) & (d < k + 1)
        rings.append(round(float(shadow[sel].mean()), 2) if sel.sum() >= 50 else None)
    return {
        "tear": tear,
        "render": f"{tear}_shadow{suffix}",
        "px_per_mm": round(ppm, 3) if ppm else None,
        "under_the_paper": round(float(shadow[paper > 0].mean()), 2),
        "rings": rings,
    }


def one(condition, frame, lib, step_mm, to_mm):
    """The profile over every render in the library under one light condition."""
    import numpy as np

    suffix = "" if condition == "day" else "_dusk"
    tears = sorted(
        os.path.basename(p)[: -len(f"_shadow{suffix}.webp")]
        for p in glob.glob(os.path.join(PACKED, "tears", f"*_shadow{suffix}.webp"))
        if (suffix == "_dusk") == ("_dusk" in os.path.basename(p))
    )
    rows = []
    for t in tears:
        settings = lib.get(f"assets/tears/{t}.png", {}).get("settings", {})
        w_mm = settings.get("w_mm")
        if not w_mm or not os.path.exists(os.path.join(PACKED, "tears", f"{t}.webp")):
            continue
        rows.append(profile_of(t, frame, w_mm, suffix))
    if not rows:
        return None

    # Every render on one millimetre axis, so the profile is a physical thing rather than a
    # per-mask one. This is the whole claim route (b) rests on: that there IS one profile.
    mm = np.arange(0.0, to_mm + 1e-9, step_mm)
    stack = []
    for r in rows:
        px = np.arange(len(r["rings"]), dtype=float)
        v = np.array([np.nan if x is None else x for x in r["rings"]])
        ok = ~np.isnan(v)
        stack.append(np.interp(mm * r["px_per_mm"], px[ok], v[ok]))
    stack = np.array(stack)
    # Each render's own profile, on the same axis. A single render is noisier than the median of
    # fifty-six, so it is made monotone by taking a running minimum outward -- the falloff cannot
    # rise with distance, and a sample that says it does is noise in one render rather than a
    # feature of the light. How many samples that moved is reported, so it can never be silent.
    clamped = 0
    for r, row in zip(rows, stack):
        mono = np.minimum.accumulate(np.nan_to_num(row, nan=0.0))
        clamped += int((mono < row - 1e-9).sum())
        r["mm_profile"] = [round(float(x), 3) for x in mono]
    median = np.nanmedian(stack, axis=0)
    p10 = np.nanpercentile(stack, 10, axis=0)
    p90 = np.nanpercentile(stack, 90, axis=0)
    falling = bool(np.all(np.diff(median) <= 0.01))

    def reaches(frac):
        first = median[1]
        below = np.argmax(median < first * frac)
        return round(float(mm[below]), 3) if below else None

    return {
        "condition": condition,
        "renders": len(rows),
        "samples_clamped_to_monotone": clamped,
        "samples_total": int(stack.size),
        "monotone_falling": falling,
        "under_the_paper": round(float(np.median([r["under_the_paper"] for r in rows])), 2),
        "mm": [round(float(x), 3) for x in mm],
        "median": [round(float(x), 2) for x in median],
        "p10": [round(float(x), 2) for x in p10],
        "p90": [round(float(x), 2) for x in p90],
        "reaches": {f"{int(f * 100)}%": reaches(f) for f in (0.5, 0.25, 0.1, 0.05)},
        "per_render": rows,
    }


DART_HEAD = """// GENERATED by tools/check/shadow_falloff.py --dart. Do not hand-edit; re-run the tool.
//
// The 1-D falloff a contact shadow has, MEASURED off the library's own shadow renders rather than
// invented. docs/BRIEF.md 05 asks for `contact shadows baked from the render's own lighting rather
// than applied as a uniform blur`, and this table is what keeps `app/lib/material/paper.dart`'s
// [ContactShadow] on the right side of that: a MaskFilter.blur would be the uniform blur and is the
// anti-goal, so the shape laid around a piece's outline is this one, read off the renders.
//
// Each list is the shadow's alpha, 0..1, at [stepMm] millimetre intervals outward from the paper's
// outline, starting at 0. Entry 0 is the value UNDER the paper, which the piece itself covers.
//
// Why there are two. `a_note_at_dusk_asks_for_its_dusk_shadow_test.dart` holds the app to using the
// dusk rig's own lighting at dusk rather than the day one dimmed, and that requirement outlives the
// mechanism the test used to check it. The two tables are measured off `*_shadow.webp` and
// `*_shadow_dusk.webp` separately, so the provenance is still two sets of renders even where the
// numbers are close.
"""


def dart_of(profiles, reach_mm, step_mm):
    """Resample each profile from the JSON's own millimetre axis onto the Dart table's step.

    The JSON is measured at --step-mm (0.05 by default) and the table is emitted at
    --dart-step-mm (0.1); indexing the JSON's median list by the table's ordinal would silently
    emit a table half as wide as it says it is, which is a ruler walking off its own scale.
    """
    def row(p):
        n = int(round(reach_mm / step_mm)) + 1
        mm = p["mm"]
        out = []
        for i in range(n):
            want = i * step_mm
            j = min(range(len(mm)), key=lambda k: abs(mm[k] - want))
            assert abs(mm[j] - want) < 1e-6, (
                f"the profile has no sample at {want} mm; "
                f"--dart-step-mm must be a multiple of --step-mm")
            out.append(f"{p['median'][j] / 255.0:.5f}")
        return ", ".join(out)

    def rows_for(p):
        out = []
        n = int(round(reach_mm / step_mm)) + 1
        mm = p["mm"]
        idx = []
        for i in range(n):
            want = i * step_mm
            j = min(range(len(mm)), key=lambda k: abs(mm[k] - want))
            idx.append(j)
        for r in p["per_render"]:
            vals = ", ".join(f"{r['mm_profile'][j] / 255.0:.5f}" for j in idx)
            out.append(f"    '{r['tear']}': <double>[{vals}],")
        return "\n".join(out)

    lines = [DART_HEAD, "class ShadowFalloff {", "  const ShadowFalloff._();", ""]
    lines += [
        f"  /// The spacing of the samples below, in millimetres.",
        f"  static const double stepMm = {step_mm};",
        "",
        f"  /// How far out the table reaches. Past this the renders carry only their ambient floor.",
        f"  static const double reachMm = {reach_mm};",
        "",
    ]
    for cond, p in profiles.items():
        lines += [
            f"  /// Measured over {p['renders']} `*_shadow"
            f"{'' if cond == 'day' else '_dusk'}` renders; "
            f"monotone falling: {str(p['monotone_falling']).lower()}.",
            f"  static const List<double> {cond} = <double>[{row(p)}];",
            "",
        ]
    for cond, p in profiles.items():
        suffix = "" if cond == "day" else "_dusk"
        name = "byTear" + cond.capitalize()
        lines += [
            f"  /// Each tear's own `*_shadow{suffix}` render, measured the same way. The pooled",
            f"  /// table above is the fallback for a tear the library has no render for.",
            f"  /// {p['samples_clamped_to_monotone']} of {p['samples_total']} samples were clamped",
            f"  /// to keep each render's profile falling.",
            f"  static const Map<String, List<double>> {name} = <String, List<double>>{{",
            rows_for(p),
            "  };",
            "",
        ]
    lines += [
        "  /// The pooled table for a light condition, by the name the app uses for it.",
        "  static List<double> of(String condition) => condition == 'dusk' ? dusk : day;",
        "",
        "  /// The tear's OWN profile where the library has its render, and the pooled one where it",
        "  /// does not. `tear` is the bare id, e.g. `tear_004`.",
        "  static List<double> forTear(String tear, String condition) =>",
        "      (condition == 'dusk' ? byTearDusk : byTearDay)[tear] ?? of(condition);",
        "",
        "  /// The render a tear's profile actually came from, e.g. `tear_004_shadow_dusk`, or null",
        "  /// where the library has none and the pooled profile was used. This is what a contact",
        "  /// shadow declares to `CaptureHooks.paperSurfaces`, and it is what holds the app to",
        "  /// using the dusk rig's own lighting at dusk rather than the day one dimmed.",
        "  static String? renderFor(String tear, String condition) {",
        "    final suffix = condition == 'dusk' ? '_dusk' : '';",
        "    return (condition == 'dusk' ? byTearDusk : byTearDay).containsKey(tear)",
        '        ? "${tear}_shadow$suffix"',
        "        : null;",
        "  }",
        "}",
        "",
    ]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=None, help="where to write the JSON; stdout if absent")
    ap.add_argument("--dart", default=None, help="also write the generated Dart table here")
    ap.add_argument("--step-mm", type=float, default=0.05)
    ap.add_argument("--to-mm", type=float, default=4.0)
    ap.add_argument("--dart-step-mm", type=float, default=0.1)
    ap.add_argument("--reach-mm", type=float, default=1.2)
    args = ap.parse_args()

    index = json.load(open(os.path.join(PACKED, "INDEX.json"), encoding="utf-8"))
    frame = float(index["relief"]["shadow_frame"])
    lib = json.load(open(os.path.join(ROOT, "assets", "MANIFEST.json"), encoding="utf-8"))["files"]

    profiles = {}
    for condition in ("day", "dusk"):
        p = one(condition, frame, lib, args.step_mm, args.to_mm)
        if p is not None:
            profiles[condition] = p
    if "day" not in profiles:
        print("shadow_falloff: no packed shadow renders to read", file=sys.stderr)
        return 2

    out = {
        "what": "the alpha of the packed contact-shadow renders as a function of distance outside "
                "the paper outline, in millimetres, over every shadow render in the library",
        "shadow_frame": frame,
        "step_mm": args.step_mm,
        "conditions": profiles,
        # kept at the top level too, so a reader of the day half does not have to know the shape
        # changed when the dusk half was added
        "renders": profiles["day"]["renders"],
        "monotone_falling": profiles["day"]["monotone_falling"],
        "under_the_paper": profiles["day"]["under_the_paper"],
        "mm": profiles["day"]["mm"],
        "median": profiles["day"]["median"],
        "p10": profiles["day"]["p10"],
        "p90": profiles["day"]["p90"],
        "reaches": profiles["day"]["reaches"],
    }
    text = json.dumps(out, indent=1)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)

    if args.dart:
        need = {k: v for k, v in profiles.items() if k in ("day", "dusk")}
        if len(need) < 2:
            print("shadow_falloff: --dart needs both a day and a dusk profile", file=sys.stderr)
            return 2
        with open(args.dart, "w", encoding="utf-8") as f:
            f.write(dart_of(need, args.reach_mm, args.dart_step_mm))
        print(f"-> {args.dart}")

    for cond, p in profiles.items():
        print(f"{cond}: {p['renders']} renders; monotone_falling={p['monotone_falling']}; "
              f"5% of its peak by {p['reaches']['5%']} mm")
    # A profile that is not monotone has nothing to lay down, which is the refutation firing 43
    # asked for. Say so in the exit code as well as in the JSON.
    return 0 if all(p["monotone_falling"] for p in profiles.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
