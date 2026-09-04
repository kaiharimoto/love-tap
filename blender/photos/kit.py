"""blender/photos/kit.py — the things that appear in the photographs the two of them take.

The seeded year references a hundred and eighty photographs, videos and voice notes, and until they
exist the loader drops every one of those events, so the thread has no pictures in it at all. These
are not illustrations of the app: they are the photographs, taken by two people on their phones, of
a boiler gauge and a pan of soup and a lift panel.

Everything here is modelled at real size and lit by the same rig as the paper, then photographed
with a perspective camera at a phone's focal length and a plausible height. Nothing is a texture
pulled from anywhere; the kit is deliberately small and each piece is written to be recognisable
rather than detailed, because a photograph in a thread is looked at for a second and a half.

Distances are metres. Every builder returns the object it made so a recipe can move it.
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from rig import common  # noqa: E402


# ------------------------------------------------------------------ materials
def matte(name, rgb, roughness=0.72):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = roughness
    return mat


def metal(name, rgb=(0.62, 0.63, 0.65), roughness=0.34, brushed=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Metallic"].default_value = 1.0
    b.inputs["Roughness"].default_value = roughness
    if brushed:
        b.inputs["Anisotropic"].default_value = brushed
    return mat


def glazed(name, rgb, roughness=0.18):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Coat Weight"].default_value = 0.35
    return mat


def glassy(name, roughness=0.05):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Transmission Weight"].default_value = 1.0
    b.inputs["IOR"].default_value = 1.5
    return mat


def liquid(name, rgb, roughness=0.22):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Subsurface Weight"].default_value = 0.22
    b.inputs["Subsurface Radius"].default_value = (0.004, 0.002, 0.001)
    return mat


# ------------------------------------------------------------------ helpers
def link(bm, name, mat=None, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    return obj


def rough_up(obj, amount, seed, scale=40.0):
    """Nothing in a kitchen is machined. Push every vertex about by a smooth field."""
    rng = np.random.default_rng(seed)
    phases = rng.uniform(0, 2 * math.pi, 6)
    for v in obj.data.vertices:
        x, y, z = v.co
        d = (math.sin(scale * x + phases[0]) * math.sin(scale * y + phases[1])
             + 0.5 * math.sin(2 * scale * y + phases[2]) * math.sin(2 * scale * z + phases[3])
             + 0.25 * math.sin(4 * scale * z + phases[4]) * math.sin(4 * scale * x + phases[5]))
        n = v.normal
        v.co = (x + n.x * d * amount, y + n.y * d * amount, z + n.z * d * amount)


# ------------------------------------------------------------------ surfaces
SURFACES = {
    "desk": ((0.126, 0.088, 0.062), 0.44),
    "melamine": ((0.66, 0.63, 0.58), 0.36),
    "trestle": ((0.30, 0.24, 0.17), 0.68),
    "lino": ((0.20, 0.20, 0.19), 0.52),
    "hob": ((0.10, 0.10, 0.11), 0.30),
    "board": ((0.42, 0.32, 0.20), 0.58),
    "wall": ((0.72, 0.70, 0.66), 0.85),
    "steel": ((0.55, 0.56, 0.58), 0.28),
}


def room(dark=(0.10, 0.09, 0.085), size=4.0):
    """What is behind the thing being photographed.

    The first version of this had a table floating in a void, which is the single loudest way a
    render says it is a render. A kitchen at night has walls, and they are out of focus and nearly
    black, but they are there and they bounce a little light back.
    """
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=size)
    obj = link(bm, "room", matte("room", dark, 0.92), smooth=False)
    obj.location = (0, 0, size / 2 - 0.02)
    # seen from inside
    for p in obj.data.polygons:
        p.flip()
    obj.data.update()
    return obj


def surface(kind="desk", size=2.4, z=0.0, wear=0.0006, seed=1):
    rgb, rough = SURFACES.get(kind, SURFACES["desk"])
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=60, y_segments=60, size=size / 2)
    mat = metal("steel_top", rgb, rough, brushed=0.6) if kind in ("steel", "hob") else matte(kind, rgb, rough)
    obj = link(bm, f"surface_{kind}", mat)
    obj.location = (0, 0, z)
    if wear:
        rough_up(obj, wear, seed, scale=9.0)
    return obj


def wall(kind="wall", w=1.2, h=1.2, y=0.35):
    rgb, rough = SURFACES.get(kind, SURFACES["wall"])
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=20, y_segments=20, size=0.5)
    obj = link(bm, "wall", matte(f"{kind}_wall", rgb, rough))
    obj.scale = (w, h, 1)
    obj.rotation_euler = (math.radians(90), 0, 0)
    obj.location = (0, y, h / 2)
    return obj


# ------------------------------------------------------------------ things
def sheet(w=0.21, h=0.297, at=(0, 0), rot=0.0, colour=(0.93, 0.91, 0.86), curl=0.004, seed=3):
    """A piece of paper lying down: never flat, always a little bowed at one edge."""
    n = 40
    bm = bmesh.new()
    grid = {}
    rng = np.random.default_rng(seed)
    tilt = rng.uniform(0, 2 * math.pi)
    for j in range(n + 1):
        for i in range(n + 1):
            u, v = i / n - 0.5, j / n - 0.5
            z = curl * ((abs(u) * 2) ** 3 * math.cos(tilt) + (abs(v) * 2) ** 3 * math.sin(tilt))
            grid[(i, j)] = bm.verts.new((u * w, v * h, z + 0.00008))
    for j in range(n):
        for i in range(n):
            bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
    obj = link(bm, "sheet", common.paper_material("photo_paper", colour, tooth=0.9, yellowing=0.1))
    obj.location = (at[0], at[1], 0)
    obj.rotation_euler = (0, 0, math.radians(rot))
    return obj


def mug(at=(0, 0), r=0.041, h=0.095, colour=(0.86, 0.84, 0.79), rot=0.0, full=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=48,
                          radius1=r * 0.86, radius2=r, depth=h)
    body = link(bm, "mug", glazed("mug", colour))
    body.location = (at[0], at[1], h / 2)
    body.rotation_euler = (0, 0, math.radians(rot))
    solid = body.modifiers.new("wall", "SOLIDIFY")
    solid.thickness = 0.004
    handle_bm = bmesh.new()
    bmesh.ops.create_cone(handle_bm, cap_ends=True, cap_tris=False, segments=18,
                          radius1=0.0045, radius2=0.0045, depth=0.001)
    handle = link(handle_bm, "handle", glazed("mug", colour))
    handle.location = (at[0] + r * 0.98, at[1], h * 0.56)
    handle.rotation_euler = (0, 0, math.radians(rot))
    # a mug handle is a piece of the same clay bent round: a torus, flattened, standing off the side
    screw = handle.modifiers.new("bend", "SCREW")
    screw.axis = "Z"
    screw.angle = math.radians(340)
    screw.steps = 32
    screw.render_steps = 32
    screw.screw_offset = 0.0
    screw.use_merge_vertices = True
    handle.scale = (1.0, 0.55, 1.0)
    made = [body, handle]
    if full > 0:
        bm2 = bmesh.new()
        bmesh.ops.create_circle(bm2, cap_ends=True, segments=48, radius=r * 0.90)
        top = link(bm2, "mug_liquid", liquid("tea", (0.20, 0.11, 0.05)))
        top.location = (at[0], at[1], h * full)
        made.append(top)
    return made


def pan(at=(0, 0), r=0.11, h=0.085, soup=(0.86, 0.72, 0.44), level=0.72):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=64, radius1=r * 0.92, radius2=r, depth=h)
    body = link(bm, "pan", metal("pan_steel", (0.58, 0.59, 0.61), 0.30))
    body.location = (at[0], at[1], h / 2)
    body.modifiers.new("wall", "SOLIDIFY").thickness = 0.0025
    bm2 = bmesh.new()
    bmesh.ops.create_circle(bm2, cap_ends=True, segments=64, radius=r * 0.90)
    top = link(bm2, "soup", liquid("soup", soup, roughness=0.30))
    top.location = (at[0], at[1], h * level)
    rough_up(top, 0.0014, 11, scale=90.0)
    return [body, top]


def crust_material(seed=7):
    """A crust is not a colour. It is blistered, floured in patches, and darker where it caught."""
    mat = bpy.data.materials.new("crust")
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = 0.88
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 26.0
    tex.inputs["Detail"].default_value = 9.0
    tex.inputs["Roughness"].default_value = 0.72
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.30
    ramp.color_ramp.elements[0].color = (0.16, 0.085, 0.040, 1.0)   # where it caught
    ramp.color_ramp.elements[1].position = 0.72
    ramp.color_ramp.elements[1].color = (0.52, 0.36, 0.20, 1.0)     # floured
    mid = ramp.color_ramp.elements.new(0.52)
    mid.color = (0.30, 0.18, 0.088, 1.0)
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    # the blisters, as real relief rather than a painted highlight
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.55
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 180.0
    fine.inputs["Detail"].default_value = 6.0
    nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return mat


def loaf(at=(0, 0), length=0.24, width=0.12, height=0.085, rot=12.0, cut=0.35, seed=7):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=96, v_segments=56, radius=0.5)
    obj = link(bm, "loaf", crust_material(seed))
    obj.scale = (length * (1 - cut * 0.5), width, height)
    obj.location = (at[0], at[1], height * 0.48)
    obj.rotation_euler = (0, 0, math.radians(rot))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # A loaf slumps a little and sits flat where it touched the tray. Clamping coordinates
    # outright collapses the silhouette into a dome, so this eases them instead.
    half = length * (1 - cut * 0.5) * 0.5
    for v in obj.data.vertices:
        t = v.co.z / height + 0.5
        v.co.x *= 1.0 + 0.08 * (1 - t)
        v.co.y *= 1.0 + 0.12 * (1 - t)
        if v.co.z < -height * 0.40:
            v.co.z = -height * 0.40 - (v.co.z + height * 0.40) * 0.25
        # the end already eaten: the last tenth is drawn in toward a square cut, not chopped
        over = (v.co.x - half * 0.80) / (half * 0.20)
        if over > 0:
            v.co.x = half * 0.80 + half * 0.20 * (1 - (1 - min(over, 1.0)) ** 2) * 0.55
    rough_up(obj, 0.0032, seed, scale=42.0)
    # the slash across the top, opened where it sprang in the oven
    for v in obj.data.vertices:
        d = abs(v.co.y - v.co.x * 0.35)
        if v.co.z > height * 0.10 and d < width * 0.09:
            v.co.z -= 0.006 * math.cos(d / (width * 0.09) * math.pi / 2)
    return obj


def gauge(at=(0, 0, 0.9), r=0.028, needle_deg=-38.0):
    """A round pressure gauge on a wall: a dial, a green band, a red band, a needle, glass."""
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=48, radius1=r, radius2=r, depth=0.014)
    case = link(bm, "gauge_case", metal("gauge_case", (0.42, 0.43, 0.45), 0.42))
    case.rotation_euler = (math.radians(90), 0, 0)
    case.location = at
    made.append(case)

    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=48, radius=r * 0.88)
    face = link(bm, "gauge_face", matte("dial", (0.90, 0.89, 0.85), 0.62))
    face.rotation_euler = (math.radians(90), 0, 0)
    face.location = (at[0], at[1] - 0.006, at[2])
    made.append(face)

    for colour, start, span in (((0.24, 0.42, 0.22), -60, 70), ((0.55, 0.16, 0.13), 20, 45)):
        bm = bmesh.new()
        steps = 24
        verts = []
        for k in range(steps + 1):
            a = math.radians(start + span * k / steps)
            for rr in (r * 0.62, r * 0.76):
                verts.append(bm.verts.new((rr * math.cos(a), 0, rr * math.sin(a))))
        for k in range(steps):
            bm.faces.new((verts[2 * k], verts[2 * k + 1], verts[2 * k + 3], verts[2 * k + 2]))
        band = link(bm, "gauge_band", matte("band", colour, 0.60))
        band.location = (at[0], at[1] - 0.0065, at[2])
        made.append(band)

    bm = bmesh.new()
    a = math.radians(needle_deg)
    tip = (r * 0.70 * math.cos(a), 0, r * 0.70 * math.sin(a))
    w = 0.0011
    v = [bm.verts.new(p) for p in
         ((-w, 0, -w), (w, 0, w), tip, (0, 0, 0))]
    bm.faces.new((v[0], v[1], v[2]))
    needle = link(bm, "gauge_needle", matte("needle", (0.06, 0.06, 0.07), 0.42), smooth=False)
    needle.location = (at[0], at[1] - 0.0072, at[2])
    made.append(needle)

    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=48, radius=r * 0.86)
    glass = link(bm, "gauge_glass", glassy("gauge_glass", 0.08))
    glass.rotation_euler = (math.radians(90), 0, 0)
    glass.location = (at[0], at[1] - 0.0080, at[2])
    made.append(glass)
    return made


def pipe(a, b, r=0.008, mat=None):
    bm = bmesh.new()
    v1 = bm.verts.new(a)
    v2 = bm.verts.new(b)
    bm.edges.new((v1, v2))
    obj = link(bm, "pipe", mat or metal("copper", (0.72, 0.42, 0.24), 0.36))
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    for v in obj.data.skin_vertices[0].data:
        v.radius = (r, r)
    obj.modifiers.new("sub", "SUBSURF").levels = 2
    return obj


def tray(at=(0, 0), rows=5, cols=6, cell=0.045, rot=0.0, seed=5):
    """A fibre egg tray, and eggs of unmatched sizes sitting in it."""
    rng = np.random.default_rng(seed)
    made = []
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=cols * 6, y_segments=rows * 6, size=0.5)
    base = link(bm, "tray", matte("fibre", (0.58, 0.50, 0.40), 0.94))
    base.scale = (cols * cell, rows * cell, 1)
    base.location = (at[0], at[1], 0.004)
    base.rotation_euler = (0, 0, math.radians(rot))
    bpy.context.view_layer.objects.active = base
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # press a dimple under every egg
    for v in base.data.vertices:
        u = (v.co.x / (cols * cell) + 0.5) * cols
        w = (v.co.y / (rows * cell) + 0.5) * rows
        du = (u % 1.0) - 0.5
        dw = (w % 1.0) - 0.5
        v.co.z -= 0.016 * math.exp(-((du * 2.4) ** 2 + (dw * 2.4) ** 2))
    made.append(base)
    for j in range(rows):
        for i in range(cols):
            if rng.random() < 0.04:
                continue                      # one or two gaps: nobody sells a full tray
            r = float(rng.uniform(0.0205, 0.0245))
            shade = float(rng.uniform(0.34, 0.62))
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=r)
            egg = link(bm, "egg", matte("shell", (shade, shade * 0.78, shade * 0.58), 0.82))
            egg.scale = (1.0, 1.0, 1.33)
            egg.rotation_euler = (float(rng.uniform(-0.3, 0.3)), float(rng.uniform(-0.3, 0.3)),
                                  float(rng.uniform(0, 3.14)))
            egg.location = (at[0] + (i - (cols - 1) / 2) * cell,
                            at[1] + (j - (rows - 1) / 2) * cell,
                            r * 0.92)
            made.append(egg)
    return made


def panel(at=(0, 0, 1.05), w=0.11, h=0.34, buttons=8, worn=0.6, seed=13):
    """A lift's button panel: brushed steel, numbers worn to ghosts, one alarm bell scratched round."""
    rng = np.random.default_rng(seed)
    made = []
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=6, y_segments=20, size=0.5)
    plate = link(bm, "panel", metal("brushed", (0.60, 0.61, 0.63), 0.30, brushed=0.75))
    plate.scale = (w, h, 1)
    plate.rotation_euler = (math.radians(90), 0, 0)
    plate.location = at
    made.append(plate)
    for k in range(buttons):
        y = at[2] + h * (0.5 - (k + 0.7) / (buttons + 1))
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=32,
                              radius1=0.011, radius2=0.0115, depth=0.004)
        b = link(bm, "button", metal("button", (0.68, 0.68, 0.70), 0.22 + 0.3 * float(rng.random())))
        b.rotation_euler = (math.radians(90), 0, 0)
        b.location = (at[0], at[1] - 0.003, y)
        made.append(b)
    return made


def crate(at=(0, 0), w=0.30, d=0.22, h=0.11, rot=0.0, colour=(0.42, 0.26, 0.16)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    obj = link(bm, "crate", matte("crate", colour, 0.80), smooth=False)
    obj.scale = (w, d, h)
    obj.location = (at[0], at[1], h / 2)
    obj.rotation_euler = (0, 0, math.radians(rot))
    return obj


def spoon(at=(0, 0), length=0.28, rot=30.0, z=0.0):
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16,
                          radius1=0.006, radius2=0.009, depth=length * 0.78)
    handle = link(bm, "spoon", matte("beech", (0.60, 0.46, 0.29), 0.66))
    handle.rotation_euler = (0, math.radians(90), math.radians(rot))
    handle.location = (at[0], at[1], z + 0.006)
    made.append(handle)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=0.021)
    bowl = link(bm, "spoon_bowl", matte("beech", (0.60, 0.46, 0.29), 0.66))
    bowl.scale = (1.4, 1.0, 0.34)
    bowl.location = (at[0] + math.cos(math.radians(rot)) * length * 0.44,
                     at[1] + math.sin(math.radians(rot)) * length * 0.44, z + 0.008)
    bowl.rotation_euler = (0, 0, math.radians(rot))
    made.append(bowl)
    return made


def knife(at=(0, 0), length=0.21, rot=-24.0):
    """A bread knife lying on its side: a spine, a bevel down to an edge, a serrated line."""
    made = []
    l, w = length * 0.62, 0.021
    bm = bmesh.new()
    # seen from above it is a long wedge; the bevel is what catches the light along one side
    pts = [(-l / 2, w * 0.5, 0.0018), (l / 2 - 0.012, w * 0.5, 0.0018), (l / 2, w * 0.1, 0.0012),
           (l / 2, -w * 0.45, 0.0003), (-l / 2, -w * 0.5, 0.0003)]
    verts = [bm.verts.new(p) for p in pts]
    bm.faces.new(verts)
    top = link(bm, "blade", metal("blade", (0.76, 0.77, 0.79), 0.14), smooth=False)
    solid = top.modifiers.new("thick", "SOLIDIFY")
    solid.thickness = 0.0016
    top.location = (at[0], at[1], 0.0004)
    top.rotation_euler = (0, 0, math.radians(rot))
    made.append(top)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    grip = link(bm, "grip", matte("grip", (0.10, 0.09, 0.09), 0.52), smooth=False)
    grip.scale = (length * 0.30, 0.013, 0.006)
    grip.location = (at[0] - math.cos(math.radians(rot)) * length * 0.52,
                     at[1] - math.sin(math.radians(rot)) * length * 0.52, 0.006)
    grip.rotation_euler = (0, 0, math.radians(rot))
    made.append(grip)
    return made


def crumbs(at=(0, 0), spread=0.09, count=90, seed=9):
    rng = np.random.default_rng(seed)
    made = []
    for _ in range(count):
        r = float(rng.uniform(0.0004, 0.0018))
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
        shade = float(rng.uniform(0.34, 0.62))
        c = link(bm, "crumb", matte("crumb", (shade, shade * 0.76, shade * 0.50), 0.92), smooth=False)
        # a crumb is a flake off a crust, not a ball bearing
        c.scale = (float(rng.uniform(0.8, 2.2)), float(rng.uniform(0.8, 1.8)), float(rng.uniform(0.22, 0.5)))
        c.rotation_euler = (0, 0, float(rng.uniform(0, 3.14)))
        c.location = (at[0] + float(rng.normal(0, spread)), at[1] + float(rng.normal(0, spread)),
                      r * 0.35)
        made.append(c)
    return made
