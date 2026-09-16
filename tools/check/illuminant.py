#!/usr/bin/env python3
"""The lamp is the colour DIRECTION.md says it is, and it is the only thing that changed.

    python3 tools/check/illuminant.py
    python3 tools/check/illuminant.py --out evidence/logs/illuminant.json

This gate exists because of a specific failure that cost this build four cycles and most of its
charm score, and the shape of it is worth stating before the checks are listed.

`DIRECTION.md` declares one day rig: "soft daylight from a window up and to the left ... warm
(5200 K)". `blender/rig/common.py` carried `DAY_COLOR = (1.0, 0.965, 0.905)` annotated `~5200 K`.
That colour is a **6125 K** sun. The annotation was nine hundred kelvin out and nothing in the
build could tell, because a comment is not a measurement.

The larger half was not a wrong number at all, it was a wrong model. The rig lit the world
background as open sky, `(0.80, 0.83, 0.87)`, at 41% of the total irradiance. Blender's world is a
full unoccluded hemisphere, so that is a sheet of paper lying on a lawn. A sheet on a desk beside a
window sees the window — a small solid angle — and then a room, every surface of which returns the
same daylight with its own warm albedo on it. Sun and sky together came to R:G:B = 1.000:0.995:0.980
and an object rendered under a neutral lamp cannot be more chromatic than its own albedo. The build
measured at mean chroma 0.0181 against a floor of 0.045 while being made entirely of warm paper.

So four things are checked, and the last one is the one nobody would think to write down:

  1. The rig's declared temperature is the temperature DIRECTION.md declares. Parsed out of the
     prose, so the law and the code cannot drift apart silently the way they already did once.
  2. `DAY_COLOR` is the blackbody at that temperature. Not "about". This is what the old comment
     claimed and did not do.
  3. The NET illuminant — sun and world together, weighted as they actually land on a horizontal
     sheet — is within tolerance of the declared temperature. A warm key that a cool fill cancels
     is a neutral lamp with a warm number written beside it, which is exactly what shipped. Only
     the net can catch that, and only the net is what an asset is rendered under.
  4. The net LUMINOUS irradiance is unchanged from what the rig has always delivered. Legibility is
     the other half of what this build is scored on and it has been clawed back from 48.4% of runs
     below floor to 26.3%. Warmth must not be paid for in exposure — and an exposure change moves
     chroma the wrong way regardless, because OKLab chroma goes as the cube root of a uniform
     scaling, so anyone reaching for exposure to fix chroma is about to make it worse.
"""
import argparse
import json
import math
import os
import re
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RIG = os.path.join(ROOT, "blender", "rig", "common.py")
DIRECTION = os.path.join(ROOT, "DIRECTION.md")

# How far the net illuminant may sit from the declared temperature. A room's bounce is a warm
# albedo on the key rather than a second colour temperature, so the net is not a blackbody and
# cannot be asked to land on one exactly. 300 K is where this is set, and the four configurations
# that fixed it are worth keeping so the next person does not loosen it back:
#
#   6125 K sun + open-sky fill (what shipped)      net 6445 K   1245 off   must fail
#   5200 K sun + open-sky fill (half the bug)      net 5830 K    630 off   must fail
#   5200 K sun + the room's own bounce (the rig)   net 5080 K    120 off   must pass
#   5200 K sun, no fill at all                     net 5200 K      0 off   must pass
#
# The second line is why this is not 700. Fixing the key alone and leaving the fill lighting an
# indoor desk as open sky is the same defect at half strength, and a gate that passes it would have
# let this build ship the same complaint one more cycle. 300 K still leaves room for any ordinary
# wall colour in ROOM_ALBEDO; it does not leave room for a fill that fights the key.
NET_TOLERANCE_K = 300.0
COLOR_TOLERANCE = 0.002        # per channel, DAY_COLOR against its own blackbody
IRRADIANCE_TOLERANCE = 0.005   # relative, the exposure invariant


def load_rig():
    """Import blender/rig/common.py without blender. It imports bpy at module scope and uses it
    only inside functions, so a stub is enough and is honest about what is being read: the
    constants, which is the whole of what this gate is about."""
    import importlib.util
    import types
    sys.modules.setdefault("bpy", types.ModuleType("bpy"))
    spec = importlib.util.spec_from_file_location("_rig_common", RIG)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def declared_temperature():
    """The colour temperature DIRECTION.md's Light section states, in kelvin."""
    text = open(DIRECTION, encoding="utf-8").read()
    start = text.find("\n## Light")
    if start < 0:
        return None, "DIRECTION.md has no Light section"
    end = text.find("\n## ", start + 1)
    section = text[start:end if end > 0 else len(text)]
    # the dusk condition declares its own temperature in the same section; the key is the first
    found = re.findall(r"(\d{3,5})\s*K\b", section)
    if not found:
        return None, "DIRECTION.md's Light section declares no colour temperature"
    return float(found[0]), None


def luma(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def net_illuminant(rig):
    """Sun and world as they land on a horizontal sheet, in linear sRGB.

    A blender SUN's energy is irradiance normal to the beam, so a horizontal sheet receives
    energy x sin(elevation). A world background of uniform radiance S lands pi x S on an
    unoccluded upward-facing plane. Both are what the renderer does, not an approximation of it.
    """
    sun = math.sin(math.radians(rig.DAY_ELEVATION_DEG)) * rig.DAY_STRENGTH * np.array(rig.DAY_COLOR)
    sky = math.pi * rig.DAY_SKY_STRENGTH * np.array(rig.DAY_SKY)
    return sun + sky


def correlated_temperature(rgb, lo=2000, hi=12000):
    """The blackbody whose linear-sRGB ratios are closest to `rgb`. A search rather than McCamy's
    approximation because the input here is already sRGB and the round trip through xy would add
    more error than the one-kelvin grid costs."""
    from_rig = load_rig()
    target = np.array(rgb, float)
    target = target / target.max()
    best, best_err = None, float("inf")
    for k in range(lo, hi + 1, 5):
        c = np.array(from_rig._blackbody_srgb(float(k)))
        err = float(np.abs(c - target).sum())
        if err < best_err:
            best, best_err = k, err
    return float(best), best_err


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out")
    args = ap.parse_args()

    rig = load_rig()
    breaches = []

    declared, why = declared_temperature()
    report = {
        "declared_by_direction_md": declared,
        "rig_temperature_k": getattr(rig, "DAY_TEMPERATURE_K", None),
        "day_color": [round(v, 4) for v in rig.DAY_COLOR],
        "day_sky": [round(v, 4) for v in rig.DAY_SKY],
        "day_strength": round(rig.DAY_STRENGTH, 4),
        "day_sky_strength": round(rig.DAY_SKY_STRENGTH, 4),
    }
    if declared is None:
        breaches.append(why)

    # 1 — the rig agrees with the law
    rig_k = report["rig_temperature_k"]
    if rig_k is None:
        breaches.append("blender/rig/common.py declares no DAY_TEMPERATURE_K; the colour is a "
                        "literal again and nothing can check it against DIRECTION.md")
    elif declared is not None and abs(rig_k - declared) > 1.0:
        breaches.append(f"the rig is lit at {rig_k:.0f} K and DIRECTION.md declares {declared:.0f} K")

    # 2 — DAY_COLOR is that temperature, not approximately it
    if rig_k is not None:
        want = rig._blackbody_srgb(rig_k)
        drift = max(abs(a - b) for a, b in zip(want, rig.DAY_COLOR))
        report["day_color_drift"] = round(drift, 5)
        if drift > COLOR_TOLERANCE:
            breaches.append(f"DAY_COLOR is {tuple(round(v, 4) for v in rig.DAY_COLOR)} and a "
                            f"{rig_k:.0f} K blackbody is {tuple(round(v, 4) for v in want)}")

    # 3 — the net illuminant, which is what an asset is actually rendered under
    net = net_illuminant(rig)
    report["net_illuminant_rgb"] = [round(float(v / net[0]), 4) for v in net]
    net_k, net_err = correlated_temperature(net)
    report["net_temperature_k"] = net_k
    report["net_fit_error"] = round(net_err, 4)
    if declared is not None and abs(net_k - declared) > NET_TOLERANCE_K:
        breaches.append(
            f"the net illuminant is {net_k:.0f} K against a declared {declared:.0f} K. The key is "
            f"only half of the lamp: sun and world together are R:G:B = "
            f"{':'.join(f'{v:.3f}' for v in report['net_illuminant_rgb'])}, and that is what every "
            f"asset in assets/ is rendered under.")

    # 4 — the exposure invariant
    have = float(luma(net))
    want_y = getattr(rig, "DAY_SUN_IRRADIANCE_Y", None), getattr(rig, "DAY_SKY_IRRADIANCE_Y", None)
    report["net_luminous_irradiance"] = round(have, 4)
    if None in want_y:
        breaches.append("the rig no longer records DAY_SUN_IRRADIANCE_Y / DAY_SKY_IRRADIANCE_Y, so "
                        "nothing holds the exposure still while the colour moves")
    else:
        want_total = float(sum(want_y))
        report["declared_luminous_irradiance"] = round(want_total, 4)
        if abs(have - want_total) > IRRADIANCE_TOLERANCE * want_total:
            breaches.append(f"the rig lands {have:.4f} of luminous irradiance on a horizontal sheet "
                            f"and declares {want_total:.4f}. Warmth is being paid for in exposure, "
                            f"which spends legibility and moves chroma the wrong way besides.")

    report["breaches"] = breaches
    report["ok"] = not breaches

    text = json.dumps(report, indent=1)
    if args.out:
        os.makedirs(os.path.dirname(args.out), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    else:
        print(text)

    if breaches:
        print(f"{len(breaches)} illuminant breach(es):", file=sys.stderr)
        for line in breaches:
            print("  " + line, file=sys.stderr)
        return 1
    print(f"the day rig is {net_k:.0f} K net at R:G:B "
          f"{':'.join(f'{v:.3f}' for v in report['net_illuminant_rgb'])}, "
          f"declared {declared:.0f} K, exposure unchanged")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
