"""blender/paper/cut_relief.py — the contact shadow of a sheet with cut edges.

    bash blender/run.sh blender/paper/cut_relief.py -- --res 512 --samples 16
    bash blender/run.sh blender/paper/cut_relief.py -- --res 1400 --samples 48

Every shadow in `assets/tears/` is keyed to a torn mask: 57 of them, all `tear_NNN_shadow*.png`,
and `app/lib/material/paper.dart` only draws one `if (tearId != null)`. So the largest piece of
paper in the build — the region pad, which is a whole screen of it — casts no contact shadow at
all, because it is a cut sheet and there has never been a cut-edge shadow to draw. On a seeded
screen the notes' own tear shadows supply the mid band; on `10_first_run`, which is a fresh
install with no notes on it, nothing does, and `value_bands.mid` reads 0.0203 against a floor of
0.04. `docs/COLOR.md` §2 calls the contact shadow "the ladder's missing rung" and this is
literally it.

This is `tear_relief.py`'s shadow pass with the torn parts taken out rather than a new idea:

  - **No fibre band and no flare.** `tear_relief.py` says it itself — *torn edges only: a cut edge
    is flat* — and a cut edge is where that sentence lands. `FLARE_MM` and `FIBRE_BAND_MM` are
    gone, not set to zero, so nobody has to wonder whether they were meant to apply.
  - **No corner lift.** `LIFT_MM` 2.4 is a small note lying loose on a desk. A pad that covers the
    whole region is held down by its own weight and by the sheets under it; lifting a corner of it
    would be drawing a note the size of a screen.
  - **The curl and the cockle stay**, at `tear_relief.py`'s own numbers, because they are what a
    sheet of paper does on a desk whatever its edges were made by, and because they are what makes
    a contact shadow visible at all: under the middle the shadow is hidden by the paper making it,
    and at the edges the sheet lifts far enough for the shadow to come out from under.

One square sheet is rendered, and the app nine-slices it. That is honest here and would not be on
a torn edge: the shadow profile along a straight edge is the same everywhere along it, so the four
edge strips of the render may be stretched to any length without inventing anything, and the
corners are corners. `app/lib/material/paper.dart` already has `NineSliced` for the torn edge
light, so the app side is a widget that exists.

Writes, beside the stocks it belongs with:

  assets/paper/cut_edge.png          the lit band along the cut edge, alpha, daylight
  assets/paper/cut_shadow.png        the contact shadow alone, alpha only, daylight
  assets/paper/cut_shadow_dusk.png   the same shadow under the dusk condition
  assets/paper/cut_relief.json       the frame and the constants, for the app and for the packer

Both passes, and not just the shadow, because the shadow on its own does not do the job. Measured
this firing against the committed `10_first_run.png`, by putting the render back around the pad
the way the app would and reading `palette.py`'s own `value_bands`: the contact shadow takes the
mid band from 0.0212 to 0.0274 against a floor of 0.04, and it does not get past 0.0281 even at a
reach of 3.4 mm, which is already more than a sheet of paper has. The reason is geometry rather
than tuning — a pad covers its own shadow, and all that shows is the strip between the top sheet
and the one under it. What does reach the floor is the edge: a band 10 px wide at the pad's rim,
taken to the midpoint between desk and paper, reads 0.0540, and 6 px reads 0.0375. So the mid band
is the lit edge of the paper, with the shadow underneath it, which is exactly the pair every torn
piece in the build already has.
"""
import argparse
import json
import os
import sys

import bpy
import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from rig import common, manifest  # noqa: E402

PAPER = os.path.join(common.repo_root(), "assets", "paper")

# The sheet is rendered at the same 120 mm span as a tear mask, so every number below can be read
# against tear_relief.py's without converting anything.
SPAN_MM = 120.0
THICKNESS_M = 0.00011        # one sheet, as tear_relief.py
SHEETS = 2                   # RegionPad draws one sheet under the top one, so the pad is two thick
CURL_MM = 1.15               # tear_relief.py's, unchanged: paper curls away from a desk at its edges
COCKLE_MM = 0.40             # and waves this much across its width
CURL_FALLOFF_MM = 2.2        # how fast the curl dies away from the edge, as exp(-d / this)
MESH = 340                   # the grid the sheet is meshed on, as tear_relief.py
SHADOW_FRAME = 1.20          # the shadow pass is framed wider than the sheet, because the part of
                             # a contact shadow you can see is the part outside the paper
# How far in from the cut the edge layer reaches before it is gone. tear_relief.py keeps 2.6 mm,
# which is where a torn lip's pulled fibres end. A cut edge has no fibres; what it has is the curl,
# and the curl is what the band has to cover -- `CURL_FALLOFF_MM` 2.2 puts the sheet back within
# 1% of flat by 10 mm, so the band is 10 mm and the ramp inside it is the curl's own shape.
EDGE_BAND_MM = 10.0
SEED = 7                     # the cockle's phase; one sheet, so one seed, and it is written down


def cut_sheet(name, span_mm=SPAN_MM, seed=SEED):
    """A flat rectangular sheet, curled away from the desk at its four cut edges.

    Returns the object and its span in metres. The heights are computed on a grid in millimetres
    and read off it at each vertex, which is how tear_relief.py does it; the difference is that
    the distance driving the curl is the distance to the rectangle's own edge rather than to a
    torn mask's silhouette, so it can be written down in closed form instead of measured off an
    image.
    """
    n = MESH
    span_m = span_mm / 1000.0
    u = np.linspace(0.0, 1.0, n + 1, dtype=np.float32)
    uu, vv = np.meshgrid(u, u, indexing="xy")
    # millimetres from the nearest cut edge
    far = np.minimum(np.minimum(uu, 1.0 - uu), np.minimum(vv, 1.0 - vv)) * span_mm
    curl = CURL_MM * np.exp(-far / CURL_FALLOFF_MM)
    phase = float(seed % 17) * 0.37
    cockle = COCKLE_MM * 0.5 * (np.sin(2 * np.pi * (uu * 1.3) + phase) +
                                np.sin(2 * np.pi * (vv * 0.9) + phase * 1.7))
    # the cockle is a wave across the middle of the sheet, not at the edge where the curl is doing
    # the work — the same weighting tear_relief.py gives it
    z_mm = curl + cockle * (0.4 + 0.6 * np.clip(far / 4.0, 0.0, 1.0))

    bm = bmesh.new()
    verts = {}
    for j in range(n + 1):
        for i in range(n + 1):
            x = (u[i] - 0.5) * span_m
            y = (u[j] - 0.5) * span_m
            z = float(z_mm[j, i]) / 1000.0 + THICKNESS_M * SHEETS
            verts[(i, j)] = bm.verts.new((x, y, z))
    for j in range(n):
        for i in range(n):
            bm.faces.new([verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]])
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uvl].uv = (co.x / span_m + 0.5, co.y / span_m + 0.5)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    solidify = obj.modifiers.new("thickness", "SOLIDIFY")
    solidify.thickness = THICKNESS_M * SHEETS
    solidify.offset = -1.0
    solidify.use_even_offset = True
    return obj, span_m


def keep_edge_band(path, band_mm=EDGE_BAND_MM):
    """Cut the edge render back to the band along the cut.

    The render is of the whole sheet, but only its outer few millimetres are the edge layer's
    business: that is where the sheet curls away from the desk and turns out of the light. Anything
    further in is the stock's own render and must not be painted over -- a sheet whose rules
    disappeared under a second sheet of white is not a sheet. This is tear_relief.py's function
    with the mask taken out: the distance to a rectangle's edge is arithmetic, not an image.
    """
    a = common.load_image_array(path)
    h, w = a.shape[0], a.shape[1]
    span_px = w / SPAN_MM
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / span_px
    # the same shape as the curl that makes the band, rather than a straight ramp
    ramp = np.clip(np.exp(-d / CURL_FALLOFF_MM) - np.exp(-band_mm / CURL_FALLOFF_MM), 0.0, 1.0)
    ramp = ramp / max(float(ramp.max()), 1e-9)
    a[..., 3] = a[..., 3] * ramp
    common.save_image_array(path, a)
    return path


def render_one(out_dir, condition, pass_kind, res, samples):
    scene = common.reset_scene()
    obj, span_m = cut_sheet("cut_sheet")
    obj.data.materials.append(common.paper_material(
        "cut_paper", (0.94, 0.91, 0.85), tooth=1.15, yellowing=0.2, sheen=0.30, fibre_scale=1400.0))
    if pass_kind == "shadow":
        common.add_shadow_catcher(scene, size_m=span_m * 2.2)
        obj.visible_camera = False                  # the sheet casts but is not seen
    frame = SHADOW_FRAME if pass_kind == "shadow" else 1.0
    common.add_top_camera(scene, span_m * frame, span_m * frame, ortho=True, distance=0.6)
    side = int(round(res * frame))
    common.render_settings(scene, side, side, samples=samples, transparent=True, file_format="PNG")
    if condition == "day":
        common.add_daylight(scene)
    else:
        common.add_dusk(scene)
    name = {("shadow", "day"): "cut_shadow.png",
            ("shadow", "dusk"): "cut_shadow_dusk.png",
            ("edge", "day"): "cut_edge.png"}[(pass_kind, condition)]
    path = os.path.join(out_dir, name)
    common.render(scene, path)
    if pass_kind == "shadow":
        common.keep_shadow_only(path)
    else:
        keep_edge_band(path)
    manifest.record(path, "blender/paper/cut_relief.py", {
        "pass": pass_kind, "light": condition, "samples": samples, "resolution": [side, side],
        "span_mm": SPAN_MM, "sheets": SHEETS, "thickness_m": THICKNESS_M,
        "curl_mm": CURL_MM, "curl_falloff_mm": CURL_FALLOFF_MM, "cockle_mm": COCKLE_MM,
        "edge_band_mm": EDGE_BAND_MM, "mesh": MESH, "frame": frame, "seed": SEED,
        "rig": "blender/rig/common.py",
    }, kind=f"cut_{pass_kind}")
    return path


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=PAPER)
    ap.add_argument("--res", type=int, default=1400)
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--conditions", default="day,dusk")
    a = ap.parse_args(argv)
    os.makedirs(a.dir, exist_ok=True)
    import time
    for condition in [c for c in a.conditions.split(",") if c]:
        for pass_kind in ("edge", "shadow"):
            if pass_kind == "edge" and condition != "day":
                continue        # the edge light is baked once, under daylight, as the tears are
            t0 = time.time()
            path = render_one(a.dir, condition, pass_kind, a.res, a.samples)
            print(f"{os.path.basename(path)} in {time.time() - t0:.0f}s", flush=True)
    # What the app has to know to put this back where the render put it. The shadow reaches
    # (frame - 1) / 2 of the sheet's own span past each edge; the app draws it into the gutter it
    # leaves around the pad, and nine-slices it so that a stretch along an edge never stretches
    # the profile across it.
    with open(os.path.join(a.dir, "cut_relief.json"), "w", encoding="utf-8") as f:
        json.dump({
            "frame": SHADOW_FRAME,
            "span_mm": SPAN_MM,
            "overhang_mm": SPAN_MM * (SHADOW_FRAME - 1.0) / 2.0,
            "note": "the shadow image is this many times the cut sheet's box, centred on it; "
                    "the sheet occupies the middle 1/frame of it in both directions",
            "curl_mm": CURL_MM, "curl_falloff_mm": CURL_FALLOFF_MM, "cockle_mm": COCKLE_MM,
            "edge_band_mm": EDGE_BAND_MM,
            "sheets": SHEETS, "thickness_m": THICKNESS_M,
        }, f, indent=1)


if __name__ == "__main__":
    main()
