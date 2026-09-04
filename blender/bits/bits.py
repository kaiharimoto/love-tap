"""blender/bits/bits.py — the things that hold paper to paper.

    bash blender/run.sh blender/bits/bits.py -- --only tape_01 --res 700
    bash blender/run.sh blender/bits/bits.py -- --all --res 700 --samples 24

Tape, staples, paperclips, pins and a smear of glue. They are laid over a note in the thread where
a note is holding something else down, and they are the reason a reply reads as pinned to the note
it answers rather than as a nested box.

Every bit is modelled and rendered under rig/common's one light, with its own contact shadow baked
from a shadow catcher in the same frame. A strip of tape is not a translucent rectangle: it is a
sheet with thickness and a rough torn end whose edges gather light, laid slightly off-square, with
the paper's own tone showing through its transmission.
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

OUT = os.path.join(common.repo_root(), "assets", "bits")

# name -> (kind, frame width in metres, seed)
BITS = {
    "tape_01": ("tape", 0.052, 11),
    "tape_02": ("tape", 0.044, 23),
    "tape_03": ("tape", 0.061, 37),
    "tape_04": ("tape", 0.038, 53),
    "staple_01": ("staple", 0.016, 7),
    "staple_02": ("staple", 0.016, 19),
    "clip_01": ("clip", 0.030, 5),
    "clip_02": ("clip", 0.030, 29),
    "pin_01": ("pin", 0.020, 13),
    "pin_02": ("pin", 0.020, 41),
    "glue_01": ("glue", 0.034, 17),
}


def rng(seed):
    return np.random.default_rng(20260903 + seed)


# ------------------------------------------------------------------ materials
def tape_material():
    """Matte office tape: mostly transmissive, slightly cloudy, with a low sheen."""
    mat = bpy.data.materials.new("tape")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.96, 0.95, 0.92, 1.0)
    b.inputs["Roughness"].default_value = 0.42
    b.inputs["Transmission Weight"].default_value = 0.86
    b.inputs["IOR"].default_value = 1.47
    return mat


def metal_material(name, rgb, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Metallic"].default_value = 1.0
    b.inputs["Roughness"].default_value = roughness
    return mat


def glue_material():
    mat = bpy.data.materials.new("glue")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.93, 0.91, 0.86, 1.0)
    b.inputs["Roughness"].default_value = 0.22
    b.inputs["Transmission Weight"].default_value = 0.65
    b.inputs["IOR"].default_value = 1.42
    return mat


# ------------------------------------------------------------------ shapes
def link_mesh(bm, name, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def torn_end(r, width, n=9):
    """The profile of a tape end pulled off the roll: a ragged run, not a cut."""
    xs = np.linspace(-width / 2, width / 2, n)
    ys = r.normal(0, width * 0.055, n)
    ys[0] = ys[-1] = 0.0
    # smooth it once so the tear is a run rather than noise
    ys = np.convolve(np.pad(ys, 1, mode="edge"), [0.25, 0.5, 0.25], "valid")
    return xs, ys


def build_tape(name, width, seed):
    r = rng(seed)
    length = width
    tape_w = width * 0.30
    thickness = 0.00006
    bm = bmesh.new()
    xs, y0 = torn_end(r, tape_w)
    _, y1 = torn_end(r, tape_w)
    rows = []
    for t, ys in ((-length / 2, y0), (length / 2, y1)):
        row = []
        for x, dy in zip(xs, ys):
            row.append(bm.verts.new((t + math.copysign(dy, t), x, 0.0)))
        rows.append(row)
    bm.verts.ensure_lookup_table()
    for i in range(len(xs) - 1):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=thickness)
    obj = link_mesh(bm, name, tape_material())
    # tape is never laid square, and it lifts a little where it was pressed down badly
    obj.rotation_euler = (0.0, 0.0, float(r.uniform(-0.22, 0.22)))
    obj.location = (0, 0, thickness * 0.5)
    return obj


def build_staple(name, width, seed):
    r = rng(seed)
    w = width * 0.62
    leg = width * 0.16
    wire = 0.00035
    path = [(-w / 2, 0, leg), (-w / 2, 0, 0), (w / 2, 0, 0), (w / 2, 0, leg)]
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in path]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=6, use_grid_fill=False)
    obj = link_mesh(bm, name, metal_material("staple", (0.62, 0.63, 0.65), 0.28))
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    for v in obj.data.skin_vertices[0].data:
        v.radius = (wire, wire)
    obj.modifiers.new("sub", "SUBSURF").levels = 2
    obj.rotation_euler = (0.0, 0.0, float(r.uniform(-0.5, 0.5)))
    return obj


def build_clip(name, width, seed):
    """A paperclip: one wire bent back on itself twice, lying flat with a slight lift."""
    r = rng(seed)
    w = width * 0.36
    h = width
    wire = 0.00042
    pts = []
    # outer loop
    pts += [(-w * 0.5, 0, h * 0.42), (-w * 0.5, 0, -h * 0.40)]
    pts += [(w * 0.5, 0, -h * 0.46), (w * 0.5, 0, h * 0.30)]
    # inner return
    pts += [(-w * 0.16, 0, h * 0.30), (-w * 0.16, 0, -h * 0.22), (w * 0.20, 0, -h * 0.26)]
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in pts]
    for a, b in zip(verts, verts[1:]):
        bm.edges.new((a, b))
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=8, use_grid_fill=False)
    for v in bm.verts:
        v.co.y += float(r.normal(0, wire * 0.6))
    obj = link_mesh(bm, name, metal_material("clip", (0.66, 0.67, 0.69), 0.34))
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    for v in obj.data.skin_vertices[0].data:
        v.radius = (wire, wire)
    obj.modifiers.new("sub", "SUBSURF").levels = 2
    obj.rotation_euler = (math.radians(90), 0.0, float(r.uniform(-0.35, 0.35)))
    obj.location = (0, 0, wire)
    return obj


def build_pin(name, width, seed):
    """A drawing pin seen from above and slightly off: a domed head and a shadow under its rim."""
    r = rng(seed)
    head = width * 0.30
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=head)
    bmesh.ops.scale(bm, vec=(1.0, 1.0, 0.42), verts=list(bm.verts))
    for v in list(bm.verts):
        if v.co.z < 0:
            v.co.z *= 0.12
    obj = link_mesh(bm, name, metal_material("pin", (0.55, 0.24, 0.22), 0.30))
    obj.location = (0, 0, head * 0.16)
    obj.rotation_euler = (0.0, float(r.uniform(-0.06, 0.06)), 0.0)
    return obj


def build_glue(name, width, seed):
    """A dried smear: a low ridge with a bright edge where it pulled away as it set."""
    r = rng(seed)
    n = 48
    bm = bmesh.new()
    grid = {}
    for i in range(n):
        for j in range(n):
            u = (i / (n - 1) - 0.5) * 2
            v = (j / (n - 1) - 0.5) * 2
            d = math.hypot(u, v * 1.7)
            fall = max(0.0, 1.0 - d) ** 1.6
            z = fall * width * 0.045 * (1.0 + 0.35 * float(r.normal(0, 1)) * fall)
            grid[(i, j)] = bm.verts.new((u * width * 0.5, v * width * 0.32, max(z, 0.0)))
    for i in range(n - 1):
        for j in range(n - 1):
            bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
    obj = link_mesh(bm, name, glue_material())
    obj.rotation_euler = (0.0, 0.0, float(r.uniform(-0.4, 0.4)))
    return obj


BUILDERS = {"tape": build_tape, "staple": build_staple, "clip": build_clip, "pin": build_pin, "glue": build_glue}


def render_bit(name, res, samples, out_dir, conditions=("day", "dusk")):
    kind, width, seed = BITS[name]
    made = []
    for condition in conditions:
        for pass_name in ("", "_shadow"):
            scene = common.reset_scene()
            if pass_name:
                common.add_shadow_catcher(scene, size_m=0.20)
            else:
                common.add_desk(scene, size_m=0.20)
                scene.collection.objects[0].hide_render = True
            BUILDERS[kind](name, width, seed)
            frame = width * 1.5
            common.add_top_camera(scene, frame, frame, ortho=True, tilt_deg=18.0, distance=0.40)
            common.render_settings(scene, res, res, samples=samples, transparent=True, file_format="PNG")
            if condition == "day":
                common.add_daylight(scene)
            else:
                common.add_dusk(scene)
            suffix = "" if condition == "day" else "_dusk"
            path = os.path.join(out_dir, f"{name}{suffix}{pass_name}.png")
            common.render(scene, path)
            if pass_name:
                common.keep_shadow_only(path)
            manifest.record(
                path, "blender/bits/bits.py",
                {"kind": kind, "width_m": width, "seed": seed, "res": res, "samples": samples,
                 "condition": condition, "pass": pass_name.strip("_") or "colour"},
                kind="bit",
            )
            made.append(path)
    return made


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--res", type=int, default=700)
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args(argv)

    names = [args.only] if args.only else (list(BITS) if args.all else [])
    if not names:
        raise SystemExit("bits.py: pass --only <name> or --all")
    os.makedirs(args.out, exist_ok=True)
    for name in names:
        if args.skip_existing and os.path.exists(os.path.join(args.out, f"{name}.png")):
            print(f"bits: {name} already rendered")
            continue
        render_bit(name, args.res, args.samples, args.out)
        print(f"bits: {name}")


if __name__ == "__main__":
    main()
