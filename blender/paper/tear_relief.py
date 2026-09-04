"""blender/paper/tear_relief.py — the torn edge lit by the rig, and its contact shadow.

    bash blender/run.sh blender/paper/tear_relief.py -- --ids 001 --res 512
    bash blender/run.sh blender/paper/tear_relief.py -- --all --res 1400

A mask from tools/tears/ is only the silhouette. What makes a torn edge read as paper rather than
as a cut-out is the light on the broken fibres: the edge is thicker, softer and brighter than the
face of the sheet, and it throws a small contact shadow that is darkest where the paper touches
the desk and opens out where the piece lifts.

So each mask becomes geometry: a thin sheet whose outline is the mask, with the fibre band along
the break displaced upward (torn paper flares where it broke) and roughened, laid on the desk with
a slight lift at one corner. It is rendered three times under rig/common:

  tear_NNN_edge.png        the lit piece with alpha (film transparent), daylight
  tear_NNN_shadow.png      the contact shadow alone, alpha only, daylight
  tear_NNN_shadow_dusk.png the same shadow under the dusk condition

The app composites stock x mask, then the edge light on top, over the shadow. Nothing is blurred
into a drop shadow: the shadow comes out of the same render as the light.
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

TEARS = os.path.join(common.repo_root(), "assets", "tears")
PX_PER_MM = 2048 / 120.0
THICKNESS_M = 0.00011
FIBRE_BAND_MM = 1.4          # how far the flared fibre band reaches in from the break
FLARE_MM = 0.42              # how far the broken fibres stand up out of the sheet
LIFT_MM = 2.4                # how far one corner of the piece lifts off the desk
CURL_MM = 1.15               # torn paper curls up along its edges; this is how far
COCKLE_MM = 0.40             # and waves this much across its width
MESH = 340                   # the outline is quantised to this grid, so it decides the shadow
SHADOW_FRAME = 1.20          # the shadow pass is framed wider than the piece, because the part of
                             # a contact shadow you can see is the part outside the paper


def load_mask(path, max_side=1024):
    """The mask as a float array, box-downsampled for meshing (the render keeps the full alpha)."""
    a = common.load_image_array(path)[..., 0]
    step = max(1, a.shape[0] // max_side)
    if step > 1:
        h = (a.shape[0] // step) * step
        w = (a.shape[1] // step) * step
        a = a[:h, :w].reshape(h // step, step, w // step, step).mean(axis=(1, 3))
    return a.astype(np.float32)


def sheet_from_mask(mask, meta, name):
    """A thin sheet whose outline follows the mask, with the fibre band raised along the break."""
    h, w = mask.shape
    px_mm = w / 120.0
    solid = mask > 0.5
    band = FIBRE_BAND_MM
    d_in = common.distance_inside(solid, int(band * px_mm) + 2) / px_mm   # mm inside the piece
    # the break flares: the fibre band lifts and thickens toward the edge
    flare = np.clip(1.0 - d_in / band, 0.0, 1.0) ** 1.6
    # torn edges only: a cut edge is flat. Distance to the nearest cut edge is large inside.
    grain = common.blur(np.random.default_rng(meta.get("seed", 1)).normal(0, 1, mask.shape).astype(np.float32), 1.4)
    grain /= (np.abs(grain).max() + 1e-9)
    z_mm = flare * (FLARE_MM * (0.7 + 0.3 * grain))         # the break stands proud of the face
    # The sheet does not lie dead flat, and that is the whole reason a contact shadow exists: it
    # rides a little off the desk everywhere, cockles across its width, and lifts at one corner.
    # The gap is what lets the sky get underneath, which is what makes the shadow soft near the
    # edges and dark where the paper actually touches.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xx / max(1.0, w - 1.0)
    v = yy / max(1.0, h - 1.0)
    corner = (u * 0.6 + (1.0 - v) * 0.4)
    phase = float(meta.get("seed", 1) % 17) * 0.37
    cockle = COCKLE_MM * 0.5 * (np.sin(2 * np.pi * (u * 1.3) + phase) + np.sin(2 * np.pi * (v * 0.9) + phase * 1.7))
    # Paper lying on a desk touches it in the middle and curls away at the edges, and that curl
    # is the whole reason a contact shadow can be seen at all: under the middle the shadow is
    # hidden by the paper making it, and at the edges the sheet lifts far enough for the shadow to
    # come out from under and open into a soft gradient on the desk.
    far = common.distance_inside(solid, int(6.0 * px_mm) + 2) / px_mm
    curl = CURL_MM * np.exp(-far / 2.2)
    z_mm = z_mm + curl + cockle * (0.4 + 0.6 * np.clip(far / 4.0, 0, 1)) + LIFT_MM * (corner ** 3)

    nx, ny = MESH, MESH                                     # mesh resolution over the mask
    bm = bmesh.new()
    verts = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            px, py = min(w - 1, int(u * (w - 1))), min(h - 1, int((1 - v) * (h - 1)))
            if not solid[py, px]:
                continue
            x = (u - 0.5) * (w / px_mm) / 1000.0
            y = (v - 0.5) * (h / px_mm) / 1000.0
            z = float(z_mm[py, px]) / 1000.0 + THICKNESS_M
            verts[(i, j)] = bm.verts.new((x, y, z))
    for j in range(ny):
        for i in range(nx):
            quad = [verts.get((i, j)), verts.get((i + 1, j)), verts.get((i + 1, j + 1)), verts.get((i, j + 1))]
            if all(q is not None for q in quad):
                bm.faces.new(quad)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    uv = bm.loops.layers.uv.new("UVMap")
    span_x = (w / px_mm) / 1000.0
    span_y = (h / px_mm) / 1000.0
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x / span_x + 0.5, co.y / span_y + 0.5)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    solidify = obj.modifiers.new("thickness", "SOLIDIFY")
    solidify.thickness = THICKNESS_M
    solidify.offset = -1.0
    solidify.use_even_offset = True
    return obj, span_x, span_y


def render_one(mask_path, meta, out_dir, res, samples, conditions):
    name = os.path.splitext(os.path.basename(mask_path))[0]
    mask = load_mask(mask_path)
    written = []
    for condition in conditions:
        for pass_kind in ("edge", "shadow"):
            if pass_kind == "edge" and condition != "day":
                continue          # the edge light is baked once, under daylight
            scene = common.reset_scene()
            obj, span_x, span_y = sheet_from_mask(mask, meta, name)
            mat = common.paper_material(f"{name}_paper", (0.94, 0.91, 0.85), tooth=1.15, yellowing=0.2,
                                        sheen=0.30, fibre_scale=1400.0)
            obj.data.materials.append(mat)
            if pass_kind == "shadow":
                catcher = common.add_shadow_catcher(scene, size_m=max(span_x, span_y) * 2.2)
                obj.visible_camera = False          # the piece casts but is not seen
            frame = SHADOW_FRAME if pass_kind == "shadow" else 1.0
            common.add_top_camera(scene, span_x * frame, span_y * frame, ortho=True, distance=0.6)
            rx = res if span_x >= span_y else int(round(res * span_x / span_y))
            ry = res if span_y > span_x else int(round(res * span_y / span_x))
            rx, ry = int(round(rx * frame)), int(round(ry * frame))
            common.render_settings(scene, rx, ry, samples=samples, transparent=True, file_format="PNG")
            if condition == "day":
                common.add_daylight(scene)
            else:
                common.add_dusk(scene)
            suffix = {"edge": "_edge", "shadow": "_shadow" if condition == "day" else "_shadow_dusk"}[pass_kind]
            path = os.path.join(out_dir, name + suffix + ".png")
            common.render(scene, path)
            if pass_kind == "shadow":
                # the catcher render carries the shadow in its alpha; keep only that
                common.keep_shadow_only(path)
            manifest.record(path, "blender/paper/tear_relief.py", {
                "mask": os.path.relpath(mask_path, common.repo_root()).replace(os.sep, "/"),
                "pass": pass_kind, "light": condition, "samples": samples, "resolution": [rx, ry],
                "fibre_band_mm": FIBRE_BAND_MM, "lift_mm": LIFT_MM, "thickness_m": THICKNESS_M,
                    "curl_mm": CURL_MM, "cockle_mm": COCKLE_MM, "mesh": MESH,
                "frame": frame,
                "rig": "blender/rig/common.py",
            }, kind=f"tear_{pass_kind}")
            written.append(path)
    return written


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", nargs="*", help="mask numbers, e.g. 001 002")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--dir", default=TEARS)
    ap.add_argument("--res", type=int, default=1400)
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--conditions", default="day,dusk")
    ap.add_argument("--skip-existing", action="store_true")
    a = ap.parse_args(argv)
    index_path = os.path.join(a.dir, "tears.json")
    metas = {}
    if os.path.exists(index_path):
        with open(index_path, encoding="utf-8") as f:
            metas = {m["id"]: m for m in json.load(f)["masks"]}
    ids = sorted(metas) if a.all else [f"tear_{i}" for i in (a.ids or [])]
    conditions = [c for c in a.conditions.split(",") if c]
    for mid in ids:
        path = os.path.join(a.dir, mid + ".png")
        if not os.path.exists(path):
            print(f"missing {path}")
            continue
        if a.skip_existing and os.path.exists(os.path.join(a.dir, mid + "_edge.png")):
            print(f"skip {mid}")
            continue
        import time
        t0 = time.time()
        render_one(path, metas.get(mid, {}), a.dir, a.res, a.samples, conditions)
        print(f"{mid} in {time.time() - t0:.0f}s", flush=True)

    # what the app needs to lay the three layers on top of each other correctly
    with open(os.path.join(a.dir, "relief.json"), "w", encoding="utf-8") as f:
        json.dump({
            "shadow_frame": SHADOW_FRAME,
            "note": "the shadow image is this many times the piece's box, centred on it; "
                    "the edge image is exactly the piece's box",
            "curl_mm": CURL_MM, "cockle_mm": COCKLE_MM, "lift_mm": LIFT_MM,
            "fibre_band_mm": FIBRE_BAND_MM, "flare_mm": FLARE_MM,
        }, f, indent=1)


if __name__ == "__main__":
    main()
