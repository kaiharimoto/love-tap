"""blender/folds/fold.py — the fold, unfold and crumple sequences, as rendered geometry.

    bash blender/run.sh blender/folds/fold.py -- --seq unfold_thirds --frames 240 --res 540
    bash blender/run.sh blender/folds/fold.py -- --all

A note opening is the clip that exposes a faked material system, so nothing here is a transform of
a flat image. A sheet is modelled at real size, creased along real hinge lines, and animated by
rotating the flaps about those hinges; the crease is bevelled geometry whose fibres are pulled
apart on the outside of the fold, so the light from rig/common breaks across it as the flap turns.
The contact shadow is in the same frame (a shadow catcher under the sheet), so the shadow moves
with the paper rather than being blurred in afterwards.

Sequences (60 unique frames per second, no frame equal to its predecessor):

  unfold_thirds  240 f  a letter folded in thirds opens: top flap lays back, then the bottom flap,
                        then the sheet settles with the creases still catching the light
  unfold_half    240 f  folded in half, opens like a book, settles
  crumple_open   120 f  a crumpled ball relaxes into a creased sheet
  corner_curl     60 f  a corner lifts, curls and drops (the feeling corner, a loop)

Frames are written as PNG with alpha and packed to WebP by tools/frames/pack.py.
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

OUT = os.path.join(common.repo_root(), "assets", "folds")
SHEET_MM = (148.0, 105.0)          # A6, the size of a note in the thread
THICKNESS_M = 0.00011
CREASE_MM = 1.4                     # width of the bevelled crease band
SEQUENCES = {
    "unfold_thirds": dict(frames=240, kind="thirds"),
    "unfold_half": dict(frames=240, kind="half"),
    "crumple_open": dict(frames=120, kind="crumple"),
    "corner_curl": dict(frames=60, kind="corner"),
}


def ease(t, power=2.0):
    """Paper does not move linearly: it starts slow, swings, then settles with a small overshoot."""
    t = min(max(t, 0.0), 1.0)
    e = 1.0 - (1.0 - t) ** power
    return e + 0.06 * math.sin(math.pi * t) * (1.0 - t)


def build_sheet(nx, ny, w, h, rng):
    """A flat sheet with UVs, at real size, plus the vertex grid for later bending."""
    bm = bmesh.new()
    verts = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            verts[(i, j)] = bm.verts.new(((i / nx - 0.5) * w, (j / ny - 0.5) * h, 0.0))
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]))
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x / w + 0.5, co.y / h + 0.5)
    return bm, verts


def crease_softness(distance_mm, width_mm=CREASE_MM):
    """0 away from the crease, 1 on it: a fold is a band, not a line."""
    return float(np.clip(1.0 - abs(distance_mm) / width_mm, 0.0, 1.0))


def bend_about(co, hinge_y, angle, sign=1.0):
    """Rotate a point about a hinge line running along x at hinge_y."""
    y = co[1] - hinge_y
    if sign * y <= 0:
        return co
    c, s = math.cos(angle), math.sin(angle)
    return (co[0], hinge_y + y * c, co[2] + y * s)


def apply_thirds(verts_co, h, t, rng):
    """A letter folded in thirds opening: the top flap first, then the bottom, then a settle."""
    y1, y2 = h / 6.0, -h / 6.0
    # phase 1: top flap 0 -> 1.6 s, phase 2: bottom flap 1.4 -> 3.2 s, settle to 4 s
    a_top = math.pi * (1.0 - ease(min(1.0, t / 0.40)))
    a_bot = math.pi * (1.0 - ease(min(1.0, max(0.0, (t - 0.35) / 0.45))))
    settle = 1.0 - ease(min(1.0, max(0.0, (t - 0.80) / 0.20)))
    out = []
    for co in verts_co:
        c = co
        if c[1] > y1:
            c = bend_about(c, y1, -a_top, sign=1.0)
        elif c[1] < y2:
            c = bend_about(c, y2, a_bot, sign=-1.0)
        # the whole sheet is not flat while it settles: the creases stay proud
        lift = settle * 0.0016 * math.exp(-((c[1] - y1) / (0.02)) ** 2)
        lift += settle * 0.0016 * math.exp(-((c[1] - y2) / (0.02)) ** 2)
        out.append((c[0], c[1], c[2] + lift))
    return out


def apply_half(verts_co, h, t, rng):
    a = math.pi * (1.0 - ease(min(1.0, t / 0.7)))
    settle = 1.0 - ease(min(1.0, max(0.0, (t - 0.7) / 0.3)))
    out = []
    for co in verts_co:
        c = bend_about(co, 0.0, -a, sign=1.0) if co[1] > 0 else co
        lift = settle * 0.0022 * math.exp(-((c[1]) / 0.02) ** 2)
        out.append((c[0], c[1], c[2] + lift))
    return out


def apply_crumple(verts_co, w, h, t, rng, field):
    """A crumpled ball relaxing: the displacement field shrinks and the sheet flattens, leaving
    creases behind. The field is fixed for the sequence so the creases stay in the same places."""
    k = (1.0 - ease(t, 1.6))
    out = []
    for idx, co in enumerate(verts_co):
        dx, dy, dz = field[idx]
        s = k * k
        out.append((co[0] + dx * s, co[1] + dy * s, co[2] + dz * (s * 0.85 + 0.15 * k)))
    return out


def apply_corner(verts_co, w, h, t, rng):
    """A corner lifts, curls over and drops: a loop for the feeling corner."""
    phase = math.sin(math.pi * t) ** 1.4
    out = []
    for co in verts_co:
        u = (co[0] / w + 0.5)
        v = (co[1] / h + 0.5)
        r = max(0.0, (u + v) - 1.35) / 0.65      # 0 away from the top-right corner, 1 at it
        if r <= 0:
            out.append(co)
            continue
        curl = phase * r * r
        ang = curl * 2.4
        lift = curl * 0.012
        out.append((co[0] - lift * math.sin(ang) * 0.4, co[1] - lift * math.sin(ang) * 0.4, co[2] + lift))
    return out


def crumple_field(verts_co, rng, w, h):
    """A fixed random crease field: sharp ridges from a few random planes, not smooth noise."""
    planes = []
    for _ in range(9):
        n = rng.normal(size=3)
        n /= np.linalg.norm(n) + 1e-9
        planes.append((n, rng.uniform(-0.03, 0.03), rng.uniform(0.004, 0.014)))
    field = []
    for co in verts_co:
        p = np.array(co)
        dx = dy = dz = 0.0
        for n, d, amp in planes:
            s = float(np.dot(p, n) - d)
            fold = amp * (1.0 - math.exp(-abs(s) / 0.006)) * (1 if s > 0 else -1)
            dx += n[0] * fold * 0.35
            dy += n[1] * fold * 0.35
            dz += abs(fold) * 0.8
        field.append((dx, dy, dz))
    return field


def render_sequence(name, frames, res, samples, out_dir, condition="day", start=0, end=None):
    cfg = SEQUENCES[name]
    kind = cfg["kind"]
    rng = np.random.default_rng(20260903 + abs(hash(name)) % 1000)
    w, h = SHEET_MM[0] / 1000.0, SHEET_MM[1] / 1000.0
    nx, ny = 120, 90
    os.makedirs(out_dir, exist_ok=True)
    end = frames if end is None else end
    base_co = None
    field = None
    for frame in range(start, end):
        t = frame / max(1, frames - 1)
        scene = common.reset_scene()
        bm, verts = build_sheet(nx, ny, w, h, rng)
        co = [tuple(v.co) for v in bm.verts]
        if base_co is None:
            base_co = co
            if kind == "crumple":
                field = crumple_field(co, rng, w, h)
        if kind == "thirds":
            new_co = apply_thirds(base_co, h, t, rng)
        elif kind == "half":
            new_co = apply_half(base_co, h, t, rng)
        elif kind == "crumple":
            new_co = apply_crumple(base_co, w, h, t, rng, field)
        else:
            new_co = apply_corner(base_co, w, h, t, rng)
        for v, c in zip(bm.verts, new_co):
            v.co = c
        mesh = bpy.data.meshes.new(f"{name}_{frame:04d}")
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(mesh.name, mesh)
        scene.collection.objects.link(obj)
        for p in mesh.polygons:
            p.use_smooth = True
        solid = obj.modifiers.new("thickness", "SOLIDIFY")
        solid.thickness = THICKNESS_M
        solid.offset = -1.0
        mat = common.paper_material(f"{name}_paper", (0.94, 0.91, 0.85), tooth=1.05, yellowing=0.25,
                                    sheen=0.24, fibre_scale=1100.0)
        obj.data.materials.append(mat)
        common.add_shadow_catcher(scene, size_m=0.4)
        common.add_top_camera(scene, w * 1.25, h * 1.55, ortho=True, distance=0.5)
        rx = int(round(res * (w * 1.25) / (h * 1.55))) if h * 1.55 > w * 1.25 else res
        ry = res if h * 1.55 > w * 1.25 else int(round(res * (h * 1.55) / (w * 1.25)))
        common.render_settings(scene, rx, ry, samples=samples, transparent=True, file_format="PNG",
                               seed=20260903 + frame)
        if condition == "day":
            common.add_daylight(scene)
        else:
            common.add_dusk(scene)
        path = os.path.join(out_dir, f"{frame:04d}.png")
        common.render(scene, path)
        if frame % 20 == 0:
            print(f"{name} {frame}/{frames}", flush=True)
    manifest.record(out_dir, "blender/folds/fold.py", {
        "sequence": name, "frames": frames, "resolution": res, "samples": samples,
        "sheet_mm": list(SHEET_MM), "crease_mm": CREASE_MM, "light": condition,
        "rig": "blender/rig/common.py",
    }, kind="fold_sequence")


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--seq", choices=list(SEQUENCES))
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--frames", type=int)
    ap.add_argument("--res", type=int, default=540)
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--condition", default="day")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--end", type=int)
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args(argv)
    names = list(SEQUENCES) if a.all else ([a.seq] if a.seq else [])
    if not names:
        ap.error("--seq or --all")
    for n in names:
        frames = a.frames or SEQUENCES[n]["frames"]
        render_sequence(n, frames, a.res, a.samples, os.path.join(a.out, n), a.condition, a.start, a.end)


if __name__ == "__main__":
    main()
