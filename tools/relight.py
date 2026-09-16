#!/usr/bin/env python3
"""What the captured stills would measure if the library were re-rendered under today's rig.

    python3 tools/relight.py
    python3 tools/relight.py --sky 0.92 0.84 0.70          # try a fill without rendering anything
    python3 tools/relight.py --out evidence/logs/relight.json

A full ./capture.sh is forty-five minutes and a full re-render of assets/ is several hours on four
cores, so the feedback loop on "should the lamp be warmer" was most of a day. It does not have to
be. A Lambertian surface under a uniform illuminant renders as albedo x illuminant, so changing the
illuminant multiplies the linear-light render by (new / old) per channel; every still in evidence/
is a composite of things rendered that way, so the same multiply applied to the still predicts the
still. This runs in a few seconds and it chose the value that shipped at firing 5.

It is a PREDICTOR and not a gate. It does not replace a capture and nothing may be closed on it.
Its errors are known and they all point the same way, which is what makes it safe to steer by:

  - The app's own flat Dart colours -- ink, chrome fills, the composer -- are not lit by the rig and
    would not move. Here they move with everything else. They are a few percent of a frame and they
    are the FIGURE band, so treat figure numbers as the loose ones and ground and mid as the tight
    ones.
  - Interreflection is ignored. The desk bouncing into a sheet above it would warm that sheet a
    little more than this predicts, so the prediction is conservative.
  - Clipping at white is applied after the multiply, as the renderer would.

Checked against the first asset that was actually re-rendered. On assets/shell/desk.png the
predictor said mean chroma 0.0413 and blender produced 0.0418 -- 1.1% out -- and said L p50 0.4052
against a rendered 0.4039, 0.0012 out. One asset is one asset and that is the whole of the
validation there is; it is quoted so the next person knows how much to trust this and no more.
"""
import argparse
import importlib.util
import json
import math
import os
import sys
import types

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "check"))
import palette as P  # noqa: E402

# The illuminant the committed evidence set was rendered and captured under: a 6125 K sun annotated
# "~5200 K" and an open-sky world fill. This is a historical fact and it is written down here
# because the moment blender/rig/common.py was corrected it stopped being readable anywhere else.
# A future correction should ADD a line here rather than edit this one.
CAPTURED_UNDER = {
    "sun": (1.0, 0.965, 0.905), "sun_strength": 2.6,
    "sky": (0.80, 0.83, 0.87), "sky_strength": 0.55,
    "elevation_deg": 50.0,
    "commit": "assets as of a6f46fd, evidence as of the 2026-09-16 capture",
}


def load_rig():
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    spec = importlib.util.spec_from_file_location(
        "_rig_common", os.path.join(ROOT, "blender", "rig", "common.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def net(sun, sun_strength, sky, sky_strength, elevation_deg):
    """Sun and world as they land on a horizontal sheet, in linear sRGB. Same arithmetic as
    tools/check/illuminant.py, and it is duplicated rather than imported so that this file can be
    read on its own; if they ever disagree the gate is the one that is right."""
    return (math.sin(math.radians(elevation_deg)) * sun_strength * np.array(sun, float)
            + math.pi * sky_strength * np.array(sky, float))


def ratio(new, old):
    """The per-channel multiply, normalised to hold luminance. Exposure is deliberately NOT part of
    a white-balance prediction: it is a separate knob, and it moves chroma the wrong way anyway
    because OKLab chroma goes as the cube root of a uniform scaling."""
    r = new / old
    return r / (0.2126 * r[0] + 0.7152 * r[1] + 0.0722 * r[2])


def relight(srgb_u8, r):
    c = srgb_u8.astype(np.float64) / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    lin = np.clip(lin * r[None, None, :], 0.0, 1.0)
    out = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)
    return np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sky", type=float, nargs=3, metavar=("R", "G", "B"),
                    help="try a world fill instead of the rig's, without rendering anything")
    ap.add_argument("--sun", type=float, nargs=3, metavar=("R", "G", "B"))
    ap.add_argument("--evidence", default=os.path.join(ROOT, "evidence"))
    ap.add_argument("--out")
    args = ap.parse_args()

    rig = load_rig()
    sun = tuple(args.sun) if args.sun else tuple(rig.DAY_COLOR)
    sky = tuple(args.sky) if args.sky else tuple(rig.DAY_SKY)
    old = net(**{k: v for k, v in CAPTURED_UNDER.items() if k != "commit"})
    new = net(sun, rig.DAY_STRENGTH, sky, rig.DAY_SKY_STRENGTH, rig.DAY_ELEVATION_DEG)
    r = ratio(new, old)

    stills = sorted(f for f in os.listdir(args.evidence)
                    if f.endswith(".png") and f[0].isdigit())
    report = {
        "captured_under": [round(float(v / old[0]), 4) for v in old],
        "predicted_under": [round(float(v / new[0]), 4) for v in new],
        "multiply": [round(float(v), 4) for v in r],
        "stills": {},
        "note": "a prediction, not a measurement; nothing may be closed on it",
    }
    means, pixels = [], []
    for s in stills:
        rgb = relight(P.read(os.path.join(args.evidence, s)), r)
        report["stills"][s] = P.describe(rgb)
        means.append(report["stills"][s]["chroma"]["mean"])
        pixels.append(rgb.reshape(-1, 3))
    union = P.describe(np.concatenate(pixels)[None, ...])
    report["across_the_set"] = {
        "mean_chroma": round(float(np.mean(means)), 4),
        "widest_hue_gap_deg": union["widest_hue_gap_deg"],
        "named_families": len(P.named_families(union["hue_centres_deg"])),
    }

    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
        print(f"wrote {args.out}")
    else:
        print(text)

    a = report["across_the_set"]
    print(f"\npredicted across_the_set: mean_chroma {a['mean_chroma']:.4f} (floor 0.045), "
          f"widest_hue_gap {a['widest_hue_gap_deg']:.0f} (ceiling 150), "
          f"named_families {a['named_families']} (floor 4)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
