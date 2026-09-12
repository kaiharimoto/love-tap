#!/usr/bin/env python3
"""The contact shadow a torn sheet casts, baked from the tear it is cut by.

    python3 tools/bake_tear_shadows.py               # every packed tear
    python3 tools/bake_tear_shadows.py --dry-run

`<tear>_shadow.webp` used to come out of Blender beside the mask, and it never showed. Measured
over all 56 packed tears, that render's alpha is 0.095 at the paper's own edge and gone within two
per cent of the piece: in the render the sheet lies nearly flat and its shadow is genuinely
underneath it, where opaque paper covers it. The eleventh capture is the first to measure the
result — the desk four to fourteen pixels under a sheet reads 3.6 grey levels darker than
forty-five to sixty-five below it in the chat hero, 0.05 in search, −0.17 in the pulse and −1.64 in
Moments, against a floor of 6 that holes.py takes from a capture where it worked. Eight of ten
stills failed. The one that passed was Settings, whose cards are cut rather than torn and get the
shadow the app *draws*.

So the shadow is made from the thing that casts it. The mask is the paper's silhouette at the size
it was rendered, fibre for fibre; displaced by the lift, blurred, and taken twice — a tight dark
line where the sheet is down on the desk and a wider softer one the lift throws past it — it is a
contact shadow that follows every strand of a torn edge, which no rectangle can.

Baked rather than drawn, for one reason: two blurred layers per piece, sixty pieces in the window
of a scroll, is a hundred and twenty blurred layers a frame, and the scroll is the row's own named
failure. A blur of a fixed image is a constant, so it is computed once here. The app draws one
image, nine-sliced with the mask's own bands so the offset and the blur keep the size they were
baked at whatever shape the piece turns out to be — the same rule the fibres already follow.

The numbers are `_CutShadow`'s, which is the shadow a cut card has cast for four cycles and which
measures 16 grey levels under a sheet: dx = 0.6 + lift*1.1, dy = 1.2 + lift*2.2, blur = 1.4 +
lift*2.4, in logical points at lift 0.8 mm, times three for the device pixels a tear is baked in.
"""
import argparse
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEARS = os.path.join(ROOT, "app", "assets", "tears")

# The desk lamp is on the right at dusk and the sky is low, but the app has only ever moved a
# paper shadow by one direction — `kShadowDirection`, from the one rig — and `_cutShadow` differs at
# dusk only by being a tenth lighter. The same here, so the two conditions do not disagree about
# where the light is.
#
# the lift a sheet rests at (PaperPiece.liftMm's default) and the scale a mask is baked in
LIFT_MM = 0.8
DPR = 3.0


def _offset_blur(alpha, dx, dy, sigma, gain):
    """The alpha, moved by (dx, dy) and softened by [sigma], at [gain] of its own opacity."""
    h, w = alpha.shape
    out = np.zeros_like(alpha)
    sx, sy = int(round(dx)), int(round(dy))
    x0, y0 = max(0, sx), max(0, sy)
    x1, y1 = min(w, w + sx), min(h, h + sy)
    out[y0:y1, x0:x1] = alpha[y0 - sy:y1 - sy, x0 - sx:x1 - sx]
    if sigma > 0:
        out = np.asarray(
            Image.fromarray((out * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(sigma)),
            dtype=np.float32,
        ) / 255.0
    return np.clip(out * gain, 0.0, 1.0)


def bake(path, out_path, lift=LIFT_MM, dusk=False):
    im = Image.open(path).convert("RGBA")
    alpha = np.asarray(im.getchannel("A"), dtype=np.float32) / 255.0
    # Centred, not displaced. The displacement happens at draw time, in logical points, because
    # this render is nine-sliced by the *mask's* bands — the tear's own — and a silhouette shifted
    # inside its canvas no longer lines up with them: the solid core lands in cells the nine-patch
    # stretches, and a piece's whole interior is filled with shadow at full strength. Measured on
    # 01_pulse, where a shelf of six scraps overlaps: the desk went from a mean of 106 grey levels
    # to 56, with 76 per cent of a 500 by 200 patch under luma 30, which is the hole in the desk
    # this check exists to catch.
    blur = (1.4 + lift * 2.4) * DPR
    # shadowOpacityFor(0.8) in app/lib/material/light.dart, clamped the way _cutShadow clamps it
    a = min(max(0.62 - 0.06 * lift, 0.22), 0.7) * (0.9 if dusk else 1.0)
    # A warm shadow at full opacity over the desk reads luma 48, which is above ink at 30 however
    # many of them overlap — the hole the thirteenth capture measured came from the displacement
    # being baked into the canvas, not from the opacity. So these are the numbers `_CutShadow`
    # uses, which have cast a measurable shadow under a cut card for four cycles.
    wide = _offset_blur(alpha, 0, 0, blur, a * 0.72)
    tight = _offset_blur(alpha, 0, 0, blur * 0.35, a)
    both = np.maximum(wide, tight)
    # Black through its alpha, like every other shadow the app ships: PaperPiece tints it to
    # Shadow.warm at draw time, because a contact shadow on a wooden desk is the desk with the
    # light taken out of it and is never neutral.
    out = np.zeros((alpha.shape[0], alpha.shape[1], 4), dtype=np.uint8)
    out[..., 3] = (both * 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(out_path, "WEBP", quality=92, lossless=False)
    return float(both.max()), int((both > 0.02).sum())


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--lift", type=float, default=LIFT_MM)
    a = ap.parse_args(argv)
    masks = sorted(
        p for p in glob.glob(os.path.join(TEARS, "*.webp"))
        if "_shadow" not in os.path.basename(p) and "_edge" not in os.path.basename(p)
    )
    if not masks:
        print("no packed tears in app/assets/tears", file=sys.stderr)
        return 1
    n = 0
    for m in masks:
        stem = os.path.splitext(os.path.basename(m))[0]
        for suffix in ("", "_dusk"):
            out = os.path.join(TEARS, f"{stem}_shadow{suffix}.webp")
            if a.dry_run:
                print("would bake", os.path.relpath(out, ROOT))
                continue
            peak, covered = bake(m, out, a.lift, dusk=suffix == "_dusk")
            n += 1
    print(f"{n} shadow(s) baked from {len(masks)} tear(s) at lift {a.lift} mm")
    return 0


if __name__ == "__main__":
    sys.exit(main())
