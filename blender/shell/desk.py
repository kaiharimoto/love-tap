"""blender/shell/desk.py — the desk the paper lies on.

    bash blender/run.sh blender/shell/desk.py -- --res 1400
    bash blender/run.sh blender/shell/desk.py -- --res 1400 --condition dusk

Everything in this app sits on one surface, so the surface has to be a real one. This is a wooden
top modelled as three planks with a chamfer at each join, a wax finish with a little wear in the
middle where forearms have been, and a grain cut into the geometry as displacement rather than
painted on. It is rendered from directly overhead under rig/common's one light, so the shading on
the desk agrees with the shading on every note laid on it.

The strip tiles vertically: the grain is built out of sinusoids whose periods divide the strip's
length exactly, so the top edge meets the bottom edge with no seam and a year-deep scroll never
shows a repeat line.
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from rig import common, manifest  # noqa: E402

OUT = os.path.join(common.repo_root(), "assets", "shell")

WIDTH_M = 0.42          # what is framed across the screen
HEIGHT_M = 0.84         # twice as tall, so the strip tiles
PLANKS = 3
JOIN_MM = 1.1           # the gap between two planks
GRAIN_MM = 0.38         # how deep the grain is cut
MESH_X, MESH_Y = 420, 840


def grain_height(u, v, seed):
    """Height in millimetres. Periodic in v so the strip tiles top to bottom.

    Wood grain runs along the plank, so the field varies fast across the plank (u) and slowly
    along it (v). Rings are the fast axis; the slow drift along v is what stops the rings looking
    like corduroy.
    """
    r = np.random.default_rng(seed)
    drift = np.zeros_like(u)
    for k, amp in ((1, 0.55), (2, 0.28), (3, 0.17)):
        drift += amp * np.sin(2 * np.pi * k * v + r.uniform(0, 2 * np.pi))
    rings = np.zeros_like(u)
    for k, amp in ((11, 0.5), (19, 0.3), (31, 0.14), (53, 0.06)):
        rings += amp * np.sin(2 * np.pi * (k * u + 0.22 * drift) + r.uniform(0, 2 * np.pi))
    # the rings are not sinusoidal in real wood: the late wood is a narrow dark band
    rings = np.sign(rings) * np.abs(rings) ** 1.7
    fine = np.zeros_like(u)
    for k in (7, 13):
        fine += 0.05 * np.sin(2 * np.pi * (k * v) + r.uniform(0, 2 * np.pi))
    return GRAIN_MM * (0.72 * rings + 0.18 * drift + fine)


def build_top(seed):
    u = np.linspace(0.0, 1.0, MESH_X + 1)
    v = np.linspace(0.0, 1.0, MESH_Y + 1)
    U, V = np.meshgrid(u, v)
    z = grain_height(U, V, seed)

    # the joins between planks: a chamfer down to the gap
    plank_u = (U * PLANKS) % 1.0
    edge = np.minimum(plank_u, 1.0 - plank_u)
    join = np.clip(1.0 - edge / (JOIN_MM / (WIDTH_M * 1000.0 / PLANKS)), 0.0, 1.0)
    z = z - join ** 2 * 1.6

    # a shallow dish worn into the middle, where arms have rested for years
    wear = np.exp(-(((U - 0.5) / 0.42) ** 2 + ((V - 0.5) / 0.9) ** 2))
    z = z - 0.22 * wear

    bm = bmesh.new()
    verts = np.empty((MESH_Y + 1, MESH_X + 1), dtype=object)
    for j in range(MESH_Y + 1):
        for i in range(MESH_X + 1):
            x = (u[i] - 0.5) * WIDTH_M
            y = (0.5 - v[j]) * HEIGHT_M
            verts[j, i] = bm.verts.new((x, y, float(z[j, i]) / 1000.0))
    for j in range(MESH_Y):
        for i in range(MESH_X):
            bm.faces.new((verts[j, i], verts[j, i + 1], verts[j + 1, i + 1], verts[j + 1, i]))
    mesh = bpy.data.meshes.new("desk_top")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("desk_top", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def wood_material():
    """Waxed oak: warm, mid-dark, glossier along the grain than across it."""
    mat = bpy.data.materials.new("desk_wood")
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.126, 0.088, 0.062, 1.0)
    b.inputs["Roughness"].default_value = 0.44
    b.inputs["Specular IOR Level"].default_value = 0.42
    b.inputs["Coat Weight"].default_value = 0.22
    b.inputs["Coat Roughness"].default_value = 0.30
    # The late wood — the narrow band laid down at the end of a growing season — is denser, darker
    # and stands a little proud. The geometry already carries that as height, so the colour is
    # taken from the height rather than painted separately: the dark line and the ridge are the
    # same fact about the plank. Height is in metres and a colour ramp reads 0 to 1, so it is
    # mapped across the grain's own depth first.
    geom = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    span = nt.nodes.new("ShaderNodeMapRange")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(geom.outputs["Position"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], span.inputs["Value"])
    span.inputs["From Min"].default_value = -GRAIN_MM / 1000.0
    span.inputs["From Max"].default_value = GRAIN_MM / 1000.0
    span.clamp = True
    nt.links.new(span.outputs["Result"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.055, 0.036, 0.024, 1.0)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.180, 0.130, 0.090, 1.0)
    mid = ramp.color_ramp.elements.new(0.62)
    mid.color = (0.126, 0.088, 0.062, 1.0)
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    # and the same height drives a fine roughness break, so the light does not sit on it evenly
    rough = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(span.outputs["Result"], rough.inputs["Value"])
    rough.inputs["To Min"].default_value = 0.52
    rough.inputs["To Max"].default_value = 0.34
    nt.links.new(rough.outputs["Result"], b.inputs["Roughness"])
    return mat


def render(res, condition, out_dir, samples, seed):
    scene = common.reset_scene()
    top = build_top(seed)
    top.data.materials.append(wood_material())
    ry = int(round(res * HEIGHT_M / WIDTH_M))
    common.add_top_camera(scene, WIDTH_M, HEIGHT_M, ortho=True, distance=0.9)
    common.render_settings(scene, res, ry, samples=samples, transparent=False, file_format="PNG")
    if condition == "day":
        common.add_daylight(scene)
    else:
        common.add_dusk(scene)
    name = "desk" if condition == "day" else "desk_dusk"
    path = os.path.join(out_dir, name + ".png")
    common.render(scene, path)
    manifest.record(path, "blender/shell/desk.py", {
        "width_m": WIDTH_M, "height_m": HEIGHT_M, "planks": PLANKS, "join_mm": JOIN_MM,
        "grain_mm": GRAIN_MM, "mesh": [MESH_X, MESH_Y], "res": [res, ry], "samples": samples,
        "condition": condition, "seed": seed, "tiles": "vertically, by construction",
        "rig": "blender/rig/common.py",
    }, kind="shell")
    return path


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--res", type=int, default=1400)
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--condition", default="both", choices=["day", "dusk", "both"])
    ap.add_argument("--seed", type=int, default=20260903)
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    conditions = ["day", "dusk"] if args.condition == "both" else [args.condition]
    for c in conditions:
        print("desk:", render(args.res, c, args.out, args.samples, args.seed))


if __name__ == "__main__":
    main()
