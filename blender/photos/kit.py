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



# ------------------------------------------------------------------ real materials
def wood_material(name, base=(0.40, 0.26, 0.15), lines_per_m=45.0, wear=0.35, seed=3,
                  along="x"):
    """Wood is grain, and grain is a set of nearly parallel lines that wander.

    A board is a slice cut along a trunk, so what shows on its face is the growth rings opened
    out into long wavering stripes running the length of the board — not the concentric rings you
    get on the end grain, which is what the first version of this used and why it came out as
    brown blotches. The stripes are dark where the tree grew slowly and pale where it grew fast,
    they are a few tenths of a millimetre proud of each other, and the pores between them are
    what a raking light finds.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")

    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    # squash across the grain and stretch along it: one wave becomes a long stripe
    if along == "x":
        mapping.inputs["Scale"].default_value = (0.22, 1.0, 0.55)
    else:
        mapping.inputs["Scale"].default_value = (1.0, 0.22, 0.55)
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])

    grain = nt.nodes.new("ShaderNodeTexWave")
    grain.wave_type = "BANDS"
    grain.bands_direction = "Y" if along == "x" else "X"
    grain.wave_profile = "SIN"
    grain.inputs["Scale"].default_value = lines_per_m / 12.0
    # a lot of distortion: grain that runs dead straight is a barcode, and a barcode is what the
    # first pass of this produced
    grain.inputs["Distortion"].default_value = 22.0
    grain.inputs["Detail"].default_value = 8.0
    grain.inputs["Detail Scale"].default_value = 3.2
    grain.inputs["Detail Roughness"].default_value = 0.72
    grain.inputs["Phase Offset"].default_value = float(seed % 97)
    nt.links.new(mapping.outputs["Vector"], grain.inputs["Vector"])

    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(grain.outputs["Fac"], ramp.inputs["Fac"])
    # earlywood to latewood is a difference of a stop at most, not black to cream
    dark = tuple(c * 0.66 for c in base)
    mid = base
    light = tuple(min(1.0, c * 1.26) for c in base)
    ramp.color_ramp.elements[0].position = 0.08
    ramp.color_ramp.elements[0].color = (*dark, 1.0)
    ramp.color_ramp.elements[1].position = 0.92
    ramp.color_ramp.elements[1].color = (*light, 1.0)
    e = ramp.color_ramp.elements.new(0.46)
    e.color = (*mid, 1.0)

    # the pores: short dashes lying along the grain, much finer than the rings
    pores = nt.nodes.new("ShaderNodeTexNoise")
    pores.inputs["Scale"].default_value = 12.0
    pores.inputs["Detail"].default_value = 6.0
    pores.inputs["Roughness"].default_value = 0.7
    pore_map = nt.nodes.new("ShaderNodeMapping")
    pore_map.inputs["Scale"].default_value = ((3.0, 90.0, 20.0) if along == "x"
                                              else (90.0, 3.0, 20.0))
    nt.links.new(coord.outputs["Object"], pore_map.inputs["Vector"])
    nt.links.new(pore_map.outputs["Vector"], pores.inputs["Vector"])

    darken = nt.nodes.new("ShaderNodeMix")
    darken.data_type = "RGBA"
    darken.blend_type = "MULTIPLY"
    darken.inputs["Factor"].default_value = 0.30
    nt.links.new(ramp.outputs["Color"], darken.inputs[6])
    pore_ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(pores.outputs["Fac"], pore_ramp.inputs["Fac"])
    pore_ramp.color_ramp.elements[0].position = 0.42
    pore_ramp.color_ramp.elements[0].color = (0.72, 0.70, 0.68, 1.0)
    pore_ramp.color_ramp.elements[1].position = 0.58
    pore_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    nt.links.new(pore_ramp.outputs["Color"], darken.inputs[7])
    nt.links.new(darken.outputs[2], b.inputs["Base Color"])

    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22 + 0.30 * wear
    bump.inputs["Distance"].default_value = 0.0004
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    add.inputs[1].default_value = 0.4
    nt.links.new(grain.outputs["Fac"], add.inputs[0])
    nt.links.new(pores.outputs["Fac"], add.inputs[2])
    nt.links.new(add.outputs["Value"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])

    rough = nt.nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.38
    rough.inputs["To Max"].default_value = 0.74
    nt.links.new(pores.outputs["Fac"], rough.inputs["Value"])
    nt.links.new(rough.outputs["Result"], b.inputs["Roughness"])
    return mat


def laminate_material(name, base=(0.72, 0.70, 0.66), seed=5):
    """A kitchen worktop: printed, sealed, and scuffed to a dull sheen where things get put."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 460.0
    tex.inputs["Detail"].default_value = 8.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color = (*[c * 0.80 for c in base], 1.0)
    ramp.color_ramp.elements[1].color = (*[min(1.0, c * 1.10) for c in base], 1.0)
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    scuff = nt.nodes.new("ShaderNodeTexNoise")
    scuff.inputs["Scale"].default_value = 18.0
    scuff.inputs["Detail"].default_value = 5.0
    r = nt.nodes.new("ShaderNodeMapRange")
    r.inputs["To Min"].default_value = 0.16
    r.inputs["To Max"].default_value = 0.44
    nt.links.new(scuff.outputs["Fac"], r.inputs["Value"])
    nt.links.new(r.outputs["Result"], b.inputs["Roughness"])
    b.inputs["Coat Weight"].default_value = 0.18
    return mat


def slab(name, w, d, thick, mat, at=(0, 0), rot=0.0, z=0.0, bevel=0.0022, seed=1, warp=0.0):
    """A real object with a top, four sides and an edge you can see, rather than a plane.

    A photograph taken thirty centimetres above a table almost always has the table's edge in it
    somewhere, and an infinite tinted plane running off to the horizon is the single clearest
    signal that a picture was made rather than taken.
    """
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    obj = link(bm, name, mat, smooth=False)
    obj.scale = (w, d, thick)
    obj.location = (at[0], at[1], z + thick / 2)
    obj.rotation_euler = (0, 0, math.radians(rot))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    sub = obj.modifiers.new("dice", "SUBSURF")
    sub.subdivision_type = "SIMPLE"
    sub.levels = sub.render_levels = 4
    bev = obj.modifiers.new("edge", "BEVEL")
    bev.width = bevel
    bev.segments = 3
    bev.limit_method = "ANGLE"
    if warp:
        rough_up(obj, warp, seed, scale=6.0)
    return obj


def board(at=(0, 0), w=0.36, d=0.24, thick=0.020, rot=0.0, scars=14, seed=7, tone=(0.44, 0.30, 0.17)):
    """A chopping board: end grain, a bevel, and the marks of everything cut on it."""
    obj = slab("board", w, d, thick, wood_material("board_wood", tone, 60.0, 0.6, seed),
               at=at, rot=rot, bevel=0.0030, seed=seed)
    rng = np.random.default_rng(seed)
    mesh = obj.data
    top = thick - 1e-5
    cuts = [(float(rng.uniform(-w / 2 * 0.8, w / 2 * 0.8)),
             float(rng.uniform(-d / 2 * 0.8, d / 2 * 0.8)),
             float(rng.uniform(0, math.pi)),
             float(rng.uniform(0.02, 0.11))) for _ in range(scars)]
    for v in mesh.vertices:
        if v.co.z < top * 0.9:
            continue
        for (cx, cy, ang, half) in cuts:
            dx, dy = v.co.x - cx, v.co.y - cy
            along = dx * math.cos(ang) + dy * math.sin(ang)
            across = -dx * math.sin(ang) + dy * math.cos(ang)
            if abs(along) < half and abs(across) < 0.0009:
                v.co.z -= 0.00035 * (1 - abs(across) / 0.0009)
    return obj


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


WOOD_TONES = {"desk": (0.30, 0.19, 0.11), "trestle": (0.36, 0.27, 0.18),
              "board": (0.44, 0.30, 0.17), "table": (0.38, 0.25, 0.14)}


def surface(kind="desk", size=2.4, z=0.0, wear=0.0006, seed=1, depth=0.9, thick=0.028):
    """Whatever the thing being photographed is standing on, as an object with an edge."""
    rgb, rough = SURFACES.get(kind, SURFACES["desk"])
    if kind in WOOD_TONES:
        mat = wood_material(f"{kind}_wood", WOOD_TONES[kind], 34.0, 0.5, seed)
    elif kind in ("melamine", "worktop"):
        mat = laminate_material("worktop", rgb, seed)
    elif kind in ("steel", "hob"):
        mat = metal("steel_top", rgb, rough, brushed=0.6)
    else:
        mat = matte(kind, rgb, rough)
    obj = slab(f"surface_{kind}", size, depth, thick, mat, z=z - thick, seed=seed,
               warp=wear * 1.5 if wear else 0.0)
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


def mug(at=(0, 0), r=0.041, h=0.095, colour=(0.86, 0.84, 0.79), rot=0.0, full=0.0, seed=2):
    """A mug: a slightly tapered cylinder with a rim and a real handle standing off one side.

    The handle is built as a swept ellipse rather than a modifier stack, because the modifier
    version produced a mug with a bump on it, and a mug with a bump on it is a plastic tub.
    """
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=56,
                          radius1=r * 0.83, radius2=r, depth=h)
    body = link(bm, "mug", glazed("mug", colour))
    body.location = (at[0], at[1], h / 2)
    body.rotation_euler = (0, 0, math.radians(rot))
    solid = body.modifiers.new("wall", "SOLIDIFY")
    solid.thickness = 0.0042
    solid.offset = 1.0
    made.append(body)

    # the handle: an open loop of oval section, its two ends buried in the wall
    bm = bmesh.new()
    ring, tube = 26, 10
    ra, rb = 0.026, 0.020          # how far out and how tall the loop is
    sec_a, sec_b = 0.0055, 0.0032  # the strap's own section
    grid = []
    for i in range(ring + 1):
        t = -0.46 + 0.92 * i / ring          # a little under a full half-turn each way
        ang = t * math.pi * 2 * 0.5
        cx = ra * math.cos(ang) * 1.0
        cz = rb * math.sin(ang) * 1.25
        # the strap leans out at the top and tucks back in at the bottom, as a thrown handle does
        tx, tz = -math.sin(ang), math.cos(ang)
        row = []
        for j in range(tube):
            p = 2 * math.pi * j / tube
            ox = math.cos(p) * sec_a
            oz = math.sin(p) * sec_b
            row.append(bm.verts.new((cx + tx * ox * 0.2 + ox, oz * 0.35, cz + oz)))
        grid.append(row)
    for i in range(ring):
        for j in range(tube):
            k = (j + 1) % tube
            bm.faces.new((grid[i][j], grid[i][k], grid[i + 1][k], grid[i + 1][j]))
    handle = link(bm, "mug_handle", glazed("mug", colour))
    handle.location = (at[0] + math.cos(math.radians(rot)) * (r * 0.93),
                       at[1] + math.sin(math.radians(rot)) * (r * 0.93), h * 0.54)
    handle.rotation_euler = (0, 0, math.radians(rot))
    made.append(handle)

    if full > 0:
        bm2 = bmesh.new()
        bmesh.ops.create_circle(bm2, cap_ends=True, segments=56, radius=r * 0.92)
        top = link(bm2, "mug_liquid", liquid("tea", (0.20, 0.11, 0.05)))
        top.location = (at[0], at[1], h * full)
        rough_up(top, 0.00025, seed, scale=160.0)
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


def loaf(at=(0, 0), length=0.24, width=0.12, height=0.085, rot=12.0, cut=0.35, seed=7,
         flour=0.5):
    """A loaf that has been in an oven and then been cut into.

    Three things make bread read as bread and not as a stone: the slash across the top sprang
    open and the crust either side of it is paler and stands proud; the end that has been cut is
    a flat face of open crumb rather than more crust; and the flour it went into the oven under
    is still on it in patches.
    """
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=112, v_segments=64, radius=0.5)
    obj = link(bm, "loaf", crust_material(seed))
    obj.scale = (length * (1 - cut * 0.5), width, height)
    obj.location = (at[0], at[1], height * 0.48)
    obj.rotation_euler = (0, 0, math.radians(rot))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    half = length * (1 - cut * 0.5) * 0.5
    for v in obj.data.vertices:
        t = v.co.z / height + 0.5
        v.co.x *= 1.0 + 0.08 * (1 - t)
        v.co.y *= 1.0 + 0.12 * (1 - t)
        if v.co.z < -height * 0.40:
            v.co.z = -height * 0.40 - (v.co.z + height * 0.40) * 0.25
    rough_up(obj, 0.0030, seed, scale=42.0)

    # the cut face: everything past the cut plane is pulled flat onto it, so the end of the loaf
    # is a face rather than a rounded stump
    face_x = half * 0.86
    for v in obj.data.vertices:
        if v.co.x > face_x:
            v.co.x = face_x

    # the slash: it was cut before baking and sprang open, so the crust lifts either side of a
    # trough and the trough itself is paler
    for v in obj.data.vertices:
        if v.co.x >= face_x - 0.0005:
            continue
        d = abs(v.co.y - v.co.x * 0.22)
        if v.co.z > height * 0.02:
            if d < width * 0.07:
                v.co.z -= 0.0075 * math.cos(d / (width * 0.07) * math.pi / 2)
            elif d < width * 0.20:
                lift = (1 - abs(d - width * 0.135) / (width * 0.065))
                v.co.z += 0.0042 * max(lift, 0.0)
    obj.data.update()

    made = [obj]
    # the crumb, showing at the cut: a paler, softer, open interior filling the face
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=26, radius=0.5)
    crumb = link(bm, "crumb_face", crumb_material(seed + 1))
    crumb.scale = (length * (1 - cut * 0.5) * 0.86, width * 0.93, height * 0.90)
    bpy.context.view_layer.objects.active = crumb
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    crumb.location = (at[0] + math.cos(math.radians(rot)) * 0.0018,
                      at[1] + math.sin(math.radians(rot)) * 0.0018, height * 0.48)
    crumb.rotation_euler = (0, 0, math.radians(rot))
    made.append(crumb)

    if flour:
        made.append(_flour(obj, at, length, width, height, rot, seed, flour))
    return made


def crumb_material(seed=8):
    """Open crumb: pale, matte, and full of holes of very unequal size."""
    mat = bpy.data.materials.new("crumb")
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = 0.95
    b.inputs["Subsurface Weight"].default_value = 0.20
    b.inputs["Subsurface Radius"].default_value = (0.004, 0.003, 0.002)
    holes = nt.nodes.new("ShaderNodeTexVoronoi")
    holes.feature = "F1"
    holes.inputs["Scale"].default_value = 220.0
    holes.inputs["Randomness"].default_value = 1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(holes.outputs["Distance"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.03
    ramp.color_ramp.elements[0].color = (0.22, 0.17, 0.12, 1.0)
    ramp.color_ramp.elements[1].position = 0.20
    ramp.color_ramp.elements[1].color = (0.80, 0.72, 0.56, 1.0)
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.85
    bump.inputs["Distance"].default_value = 0.0018
    nt.links.new(holes.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return mat


def _flour(loaf_obj, at, length, width, height, rot, seed, amount):
    """The dusting it went into the oven under, still on the top in patches."""
    mat = bpy.data.materials.new("flour")
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.94, 0.92, 0.88, 1.0)
    b.inputs["Roughness"].default_value = 0.98
    patches = nt.nodes.new("ShaderNodeTexNoise")
    patches.inputs["Scale"].default_value = 34.0
    patches.inputs["Detail"].default_value = 8.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(patches.outputs["Fac"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.42 + 0.22 * (1 - amount)
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.62 + 0.22 * (1 - amount)
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    trans = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes["Material Output"]
    nt.links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    nt.links.new(trans.outputs["BSDF"], mix.inputs[1])
    nt.links.new(b.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else mat.blend_method

    dusting = loaf_obj.copy()
    dusting.data = loaf_obj.data.copy()
    dusting.data.materials.clear()
    dusting.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(dusting)
    dusting.name = "flour"
    for v in dusting.data.vertices:
        v.co *= 1.0035
    return dusting


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


# ------------------------------------------------------------------ the rest of the kitchen
def bowl(at=(0, 0), r=0.105, h=0.055, wall=0.005, colour=(0.86, 0.85, 0.82), fill=None,
         level=0.62, rot=0.0, seed=17, enamel=True):
    """A wide shallow bowl. What is in it is a separate surface a few millimetres down, because
    the meniscus climbing the wall is most of what says there is something in it."""
    made = []
    n = 56
    bm = bmesh.new()
    grid = []
    for j in range(13):
        t = j / 12
        # a bowl's section is a curve, not a cone: shallow in the middle, turning up at the rim
        rr = r * (0.10 + 0.90 * t ** 0.62)
        z = h * (t ** 1.9)
        row = [bm.verts.new((rr * math.cos(2 * math.pi * i / n),
                             rr * math.sin(2 * math.pi * i / n), z)) for i in range(n)]
        grid.append(row)
    for j in range(12):
        for i in range(n):
            k = (i + 1) % n
            bm.faces.new((grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]))
    mat = glazed("bowl", colour, 0.14 if enamel else 0.24)
    body = link(bm, "bowl", mat)
    body.location = (at[0], at[1], 0)
    body.rotation_euler = (0, 0, math.radians(rot))
    solid = body.modifiers.new("wall", "SOLIDIFY")
    solid.thickness = wall
    made.append(body)
    if fill:
        bm2 = bmesh.new()
        rr = r * (0.10 + 0.90 * level ** 0.62) - wall
        bmesh.ops.create_circle(bm2, cap_ends=True, segments=n, radius=rr)
        top = link(bm2, "bowl_fill", liquid("in_the_bowl", tuple(fill), roughness=0.42))
        top.location = (at[0], at[1], h * (level ** 1.9))
        rough_up(top, 0.0006, seed, scale=120.0)
        made.append(top)
    return made


def tin(at=(0, 0), r=0.085, h=0.075, rot=0.0, lid="beside", colour=(0.24, 0.20, 0.10)):
    """A biscuit tin, its lid either on it or lying next to it."""
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=48,
                          radius1=r, radius2=r, depth=h)
    body = link(bm, "tin", metal("tin", colour, 0.36))
    body.location = (at[0], at[1], h / 2)
    body.rotation_euler = (0, 0, math.radians(rot))
    body.modifiers.new("wall", "SOLIDIFY").thickness = 0.0008
    made.append(body)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=48,
                          radius1=r * 1.03, radius2=r * 1.03, depth=0.012)
    cap = link(bm, "tin_lid", metal("tin", colour, 0.30))
    if lid == "on":
        cap.location = (at[0], at[1], h + 0.004)
    else:
        cap.location = (at[0] + r * 2.1, at[1] - r * 0.7, 0.006)
    made.append(cap)
    return made


def jar(at=(0, 0), r=0.042, h=0.115, holds=0, seed=18):
    """A glass jar, usually with brushes standing in it."""
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=40,
                          radius1=r * 0.96, radius2=r, depth=h)
    g = link(bm, "jar", glassy("jar_glass", 0.03))
    g.location = (at[0], at[1], h / 2)
    g.modifiers.new("wall", "SOLIDIFY").thickness = 0.0025
    made.append(g)
    rng = np.random.default_rng(seed)
    for k in range(holds):
        a = 2 * math.pi * k / max(holds, 1)
        lean = float(rng.uniform(0.05, 0.30))
        made += pen(at=(at[0] + math.cos(a) * r * 0.45, at[1] + math.sin(a) * r * 0.45),
                    length=float(rng.uniform(0.16, 0.24)), kind="brush",
                    rot=math.degrees(a), pitch=90 - math.degrees(lean), z=h * 0.35,
                    seed=seed + k)
    return made


def pen(at=(0, 0), length=0.145, rot=0.0, kind="pen", z=0.0, pitch=0.0, seed=19):
    """A pen, a pencil or a brush, lying down or standing in something."""
    made = []
    rng = np.random.default_rng(seed)
    if kind == "pencil":
        body_r, body_c, rough = 0.0038, (0.34, 0.24, 0.10), 0.72
    elif kind == "brush":
        body_r, body_c, rough = 0.0042, (0.30, 0.22, 0.12), 0.70
    else:
        body_r, body_c, rough = 0.0045, (0.28, 0.045, 0.035), 0.38
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=(kind != "pencil"),
                          segments=6 if kind == "pencil" else 20,
                          radius1=body_r, radius2=body_r * 0.92, depth=length)
    body = link(bm, kind, matte(kind, body_c, rough), smooth=(kind != "pencil"))
    body.rotation_euler = (math.radians(90 - pitch), 0, math.radians(rot))
    body.location = (at[0], at[1], z + (body_r if pitch == 0 else 0))
    made.append(body)
    tip_c = (0.06, 0.055, 0.05) if kind != "brush" else (0.30, 0.20, 0.08)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=14,
                          radius1=body_r * 1.05, radius2=0.0004, depth=length * 0.10)
    tip = link(bm, kind + "_tip", matte(kind + "_tip", tip_c, 0.55))
    dx = math.cos(math.radians(rot)) * length * 0.55
    dy = math.sin(math.radians(rot)) * length * 0.55
    tip.rotation_euler = (math.radians(-90 + pitch), 0, math.radians(rot))
    tip.location = (at[0] + dx, at[1] + dy, z + (body_r if pitch == 0 else -length * 0.5))
    made.append(tip)
    return made


def folded(at=(0, 0), w=0.21, h=0.297, folds=3, rot=0.0, rise=0.0035, colour=(0.90, 0.88, 0.83),
           seed=20, printed=0.0):
    """A sheet folded into thirds and flattened out again: it never lies flat afterwards, and the
    two creases across it are the whole reason to photograph it."""
    n = 90
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    grid = {}
    for j in range(n + 1):
        for i in range(n + 1):
            u, v = i / n - 0.5, j / n - 0.5
            t = (v + 0.5) * folds
            near = min(abs(t - k) for k in range(folds + 1))
            # it stands up along each crease and settles between them
            z = rise * math.exp(-(near / 0.30) ** 2) + rise * 0.35 * math.cos(2 * math.pi * (v + 0.5) * folds)
            z += rise * 0.25 * u * math.sin(rng.uniform(0, 3.0) + v * 4.0)
            grid[(i, j)] = bm.verts.new((u * w, v * h, z + 0.00008))
    for j in range(n):
        for i in range(n):
            bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
    mat = (printed_material(colour, printed, seed) if printed
           else common.paper_material("folded_paper", colour, tooth=0.9, yellowing=0.12))
    obj = link(bm, "folded", mat)
    obj.location = (at[0], at[1], 0)
    obj.rotation_euler = (0, 0, math.radians(rot))
    return obj


def printed_material(colour=(0.90, 0.88, 0.83), grid=1.0, seed=21):
    """Paper with something machine-printed on it: a grid of boxes, ruled lines, a form."""
    mat = bpy.data.materials.new("printed")
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = 0.94
    coord = nt.nodes.new("ShaderNodeTexCoord")
    brick = nt.nodes.new("ShaderNodeTexBrick")
    brick.inputs["Scale"].default_value = 7.0 * grid
    brick.offset = 0.0
    brick.squash = 1.0
    brick.inputs["Mortar Size"].default_value = 0.012
    brick.inputs["Brick Width"].default_value = 0.25
    brick.inputs["Row Height"].default_value = 0.16
    brick.inputs["Color1"].default_value = (*colour, 1.0)
    brick.inputs["Color2"].default_value = (*colour, 1.0)
    brick.inputs["Mortar"].default_value = (0.10, 0.11, 0.14, 1.0)
    nt.links.new(coord.outputs["Object"], brick.inputs["Vector"])
    nt.links.new(brick.outputs["Color"], b.inputs["Base Color"])
    return mat


def card(at=(0, 0), w=0.105, h=0.148, thick=0.0009, rot=0.0, colour=(0.88, 0.86, 0.80),
         z=0.0, seed=22):
    """A stiff card: a postcard, a ticket, an insert. It has an edge and it does not drape."""
    return slab("card", w, h, thick, common.paper_material("card", colour, tooth=0.6,
                                                           yellowing=0.06),
                at=at, rot=rot, z=z, bevel=0.00012, seed=seed)


def envelope(at=(0, 0), w=0.24, h=0.165, rot=0.0, torn=True, colour=(0.72, 0.64, 0.50), seed=23):
    """A courier envelope, opened by tearing one end off."""
    made = [slab("envelope", w, h, 0.0016,
                 common.paper_material("envelope", colour, tooth=1.0, yellowing=0.05),
                 at=at, rot=rot, bevel=0.0004, seed=seed)]
    if torn:
        strip = slab("envelope_strip", w * 0.22, h * 0.96, 0.0012,
                     common.paper_material("envelope", colour, tooth=1.0, yellowing=0.05),
                     at=(at[0] + w * 0.72, at[1] - h * 0.22), rot=rot + 14, z=0.0016,
                     bevel=0.0003, seed=seed + 1)
        made.append(strip)
    return made


def book(at=(0, 0), w=0.21, d=0.29, pages=0.018, rot=0.0, open_book=True,
         cover=(0.14, 0.11, 0.09), seed=24):
    """A sketchbook: closed it is a slab, open it is two leaves rising to a spine."""
    made = []
    if not open_book:
        made.append(slab("book", w, d, pages + 0.004, matte("cover", cover, 0.66),
                         at=at, rot=rot, bevel=0.0018, seed=seed))
        return made
    paper = common.paper_material("page", (0.90, 0.885, 0.845), tooth=1.1, yellowing=0.10)
    for side in (-1, 1):
        n = 48
        bm = bmesh.new()
        grid = {}
        for j in range(n + 1):
            for i in range(n + 1):
                u, v = i / n, j / n - 0.5
                # each leaf lifts toward the spine and drops away at the fore-edge
                z = pages * (1 - u) ** 1.7
                x = side * (0.004 + u * w)
                grid[(i, j)] = bm.verts.new((x, v * d, z))
        for j in range(n):
            for i in range(n):
                bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
        leaf = link(bm, "page", paper)
        leaf.location = (at[0], at[1], 0.001)
        leaf.rotation_euler = (0, 0, math.radians(rot))
        made.append(leaf)
    return made


def stack(at=(0, 0), w=0.23, d=0.31, count=9, rot=0.0, lean=7.0, seed=25,
          tones=((0.55, 0.42, 0.22), (0.30, 0.32, 0.36), (0.62, 0.58, 0.44))):
    """A pile of folders and binders, none of them square to any other."""
    made = []
    rng = np.random.default_rng(seed)
    z = 0.0
    for k in range(count):
        t = tones[k % len(tones)]
        thick = float(rng.uniform(0.006, 0.028))
        made.append(slab(f"folder_{k}", w * float(rng.uniform(0.86, 1.06)),
                         d * float(rng.uniform(0.88, 1.04)), thick,
                         matte(f"folder_{k}", tuple(c * float(rng.uniform(0.8, 1.2)) for c in t), 0.86),
                         at=(at[0] + float(rng.normal(0, 0.012)), at[1] + float(rng.normal(0, 0.014))),
                         rot=rot + float(rng.uniform(-lean, lean)), z=z, bevel=0.0012, seed=seed + k))
        z += thick + 0.0008
        if rng.random() < 0.45:
            made.append(slab(f"tab_{k}", w * 0.12, 0.02, 0.0008,
                             common.paper_material("tab", (0.86, 0.72, 0.32), 0.7, 0.05),
                             at=(at[0] + float(rng.uniform(-w * 0.3, w * 0.3)), at[1] + d * 0.52),
                             rot=rot, z=z - 0.001, bevel=0.0002, seed=seed + 50 + k))
    return made


def cloth(at=(0, 0), w=0.34, d=0.22, rot=0.0, rumple=0.012, colour=(0.42, 0.44, 0.40), seed=26):
    """A tea towel, thrown down rather than folded."""
    n = 60
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 6)
    grid = {}
    for j in range(n + 1):
        for i in range(n + 1):
            u, v = i / n - 0.5, j / n - 0.5
            z = rumple * (math.sin(6 * u + ph[0]) * math.cos(4 * v + ph[1])
                          + 0.5 * math.sin(11 * v + ph[2]) * math.cos(9 * u + ph[3]))
            z *= math.exp(-((u * 1.7) ** 4 + (v * 1.7) ** 4))
            grid[(i, j)] = bm.verts.new((u * w, v * d, max(z, 0.0002)))
    for j in range(n):
        for i in range(n):
            bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
    mat = matte("cloth", colour, 0.96)
    obj = link(bm, "cloth", mat)
    obj.location = (at[0], at[1], 0)
    obj.rotation_euler = (0, 0, math.radians(rot))
    return obj


def bag(at=(0, 0), w=0.30, d=0.20, h=0.34, rot=0.0, kind="canvas", seed=27):
    """A bag standing on the floor with things in it, so it slumps rather than being a box."""
    n = 40
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 4)
    grid = []
    for j in range(n + 1):
        t = j / n
        # wide and slumped at the bottom, pulled in and buckled at the mouth
        sx = w / 2 * (1.0 - 0.16 * t ** 2 + 0.10 * math.sin(t * 6 + ph[0]))
        sy = d / 2 * (1.0 - 0.22 * t ** 2 + 0.12 * math.sin(t * 5 + ph[1]))
        row = []
        for i in range(n):
            a = 2 * math.pi * i / n
            buckle = 1.0 + 0.09 * t ** 2 * math.sin(3 * a + ph[2])
            row.append(bm.verts.new((sx * math.cos(a) * buckle, sy * math.sin(a) * buckle, t * h)))
        grid.append(row)
    for j in range(n):
        for i in range(n):
            k = (i + 1) % n
            bm.faces.new((grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]))
    colour = (0.42, 0.38, 0.30) if kind == "canvas" else (0.55, 0.44, 0.28)
    obj = link(bm, "bag", matte("bag", colour, 0.94))
    obj.location = (at[0], at[1], 0)
    obj.rotation_euler = (0, 0, math.radians(rot))
    return obj


def ladle(at=(0, 0), length=0.30, rot=20.0, pitch=72.0, z=0.0):
    """Standing upright in a pan, which is where a ladle usually is."""
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=14,
                          radius1=0.0055, radius2=0.0055, depth=length)
    handle = link(bm, "ladle", metal("ladle", (0.62, 0.63, 0.65), 0.30))
    handle.rotation_euler = (math.radians(90 - pitch), 0, math.radians(rot))
    handle.location = (at[0], at[1], z + math.sin(math.radians(pitch)) * length / 2)
    made.append(handle)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=22, v_segments=14, radius=0.030)
    cup = link(bm, "ladle_cup", metal("ladle", (0.62, 0.63, 0.65), 0.30))
    cup.scale = (1.0, 1.0, 0.72)
    cup.location = (at[0] - math.cos(math.radians(rot)) * 0.02, at[1], z + 0.02)
    made.append(cup)
    return made


def hob_ring(at=(0, 0), r=0.075, z=0.001):
    made = []
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, segments=64, radius=r)
    ring = link(bm, "hob_ring", metal("hob_ring", (0.10, 0.10, 0.11), 0.42))
    ring.location = (at[0], at[1], z)
    sk = ring.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    for v in ring.data.skin_vertices[0].data:
        v.radius = (0.004, 0.004)
    made.append(ring)
    return made


def plate(at=(0, 0), r=0.115, rim=0.018, rot=0.0, chipped=True, colour=(0.90, 0.89, 0.86),
          seed=28):
    """A plate: a well, a rim that lifts, and a chip out of the glaze at the edge."""
    n = 60
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    chip_a = float(rng.uniform(0, 6.28))
    grid = []
    for j in range(11):
        t = j / 10
        rr = r * t
        z = 0.004 * (t ** 3) + (rim * max(0.0, (t - 0.80) / 0.20) ** 1.6)
        row = []
        for i in range(n):
            a = 2 * math.pi * i / n
            bite = 1.0
            if chipped and t > 0.85 and abs(((a - chip_a + math.pi) % (2 * math.pi)) - math.pi) < 0.10:
                bite = 0.965
            row.append(bm.verts.new((rr * math.cos(a) * bite, rr * math.sin(a) * bite, z)))
        grid.append(row)
    for j in range(10):
        for i in range(n):
            k = (i + 1) % n
            bm.faces.new((grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]))
    obj = link(bm, "plate", glazed("plate", colour, 0.10))
    obj.location = (at[0], at[1], 0.001)
    obj.rotation_euler = (0, 0, math.radians(rot))
    obj.modifiers.new("thick", "SOLIDIFY").thickness = 0.004
    return obj


def cake(at=(0, 0), r=0.085, layers=3, layer_h=0.032, lean=6.0, rot=0.0, z=0.0,
         sponge=(0.62, 0.48, 0.28), cream=(0.94, 0.90, 0.78), seed=29):
    """A layer cake that is not level: each layer sits a little off the one below and the
    buttercream is squeezed out on the low side, which is the whole photograph."""
    made = []
    rng = np.random.default_rng(seed)
    drift = 0.0
    for k in range(layers):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=52,
                              radius1=r * float(rng.uniform(0.94, 1.02)),
                              radius2=r * float(rng.uniform(0.95, 1.03)), depth=layer_h)
        s = link(bm, f"sponge_{k}", matte("sponge", sponge, 0.94))
        drift += math.radians(lean) * r * float(rng.uniform(0.5, 1.4))
        s.location = (at[0] + drift, at[1] + drift * 0.4,
                      z + layer_h / 2 + k * (layer_h + 0.008))
        rough_up(s, 0.0012, seed + k, scale=90.0)
        made.append(s)
        if k < layers - 1:
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=52,
                                  radius1=r * 0.99, radius2=r * 1.06, depth=0.008)
            c = link(bm, f"cream_{k}", matte("buttercream", cream, 0.62))
            # squeezed out on the side it is leaning toward
            c.location = (at[0] + drift + r * 0.05, at[1] + drift * 0.4,
                          z + layer_h + k * (layer_h + 0.008) + 0.004)
            rough_up(c, 0.0018, seed + 40 + k, scale=60.0)
            made.append(c)
    return made


def flask(at=(0, 0), r=0.037, h=0.24, rot=0.0, z=0.0, dented=True, seed=30):
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=40,
                          radius1=r, radius2=r * 0.92, depth=h)
    body = link(bm, "flask", metal("flask", (0.44, 0.45, 0.47), 0.36))
    body.location = (at[0], at[1], z + h / 2)
    body.rotation_euler = (0, 0, math.radians(rot))
    if dented:
        rng = np.random.default_rng(seed)
        for _ in range(3):
            cx, cy, cz = rng.normal(0, r, 2).tolist() + [float(rng.uniform(-h / 3, h / 3))]
            for v in body.data.vertices:
                d = math.dist((v.co.x, v.co.y, v.co.z), (cx, cy, cz))
                if d < r * 0.7:
                    f = (1 - d / (r * 0.7)) ** 2 * 0.004
                    v.co = (v.co.x - v.co.x * f / r, v.co.y - v.co.y * f / r, v.co.z)
    made.append(body)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=40,
                          radius1=r * 0.86, radius2=r * 0.86, depth=0.045)
    cup = link(bm, "flask_cup", matte("flask_cup", (0.10, 0.09, 0.08), 0.55))
    cup.location = (at[0], at[1], z + h + 0.022)
    made.append(cup)
    return made


def bench(at=(0, 1.6), length=1.6, depth=0.42, height=0.44, slats=5, rot=0.0, seed=31,
          tone=(0.20, 0.16, 0.11)):
    """A slatted bench: the gaps between the slats are the point of it."""
    made = []
    mat = wood_material("bench_wood", tone, 30.0, 0.8, seed)
    gap = depth / slats
    for k in range(slats):
        y = at[1] + (k - (slats - 1) / 2) * gap
        made.append(slab(f"slat_{k}", length, gap * 0.72, 0.028, mat,
                         at=(at[0], y), rot=rot, z=height, bevel=0.002, seed=seed + k))
    for dx in (-1, 1):
        made.append(slab("bench_leg", 0.06, depth, height,
                         matte("bench_iron", (0.045, 0.045, 0.048), 0.72),
                         at=(at[0] + dx * (length / 2 - 0.14), at[1]), rot=rot, bevel=0.004,
                         seed=seed))
    return made


def cone(at=(0, 3.0), h=0.52, r=0.16, seed=32):
    """A traffic cone, which is how a car park says one space is not available."""
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=24,
                          radius1=r * 0.34, radius2=0.022, depth=h)
    body = link(bm, "cone", matte("cone_plastic", (0.42, 0.075, 0.020), 0.62))
    body.location = (at[0], at[1], h / 2 + 0.01)
    made.append(body)
    made.append(slab("cone_base", r * 2, r * 2, 0.02,
                     matte("cone_plastic", (0.42, 0.075, 0.020), 0.62),
                     at=at, bevel=0.006, seed=seed))
    return made


def car(at=(0, 8.0), length=4.3, width=1.78, height=1.45, rot=0.0, colour=(0.055, 0.058, 0.062),
        seed=33):
    """A car at ten metres: a body, a cabin set back on it, and four dark wheels. At that
    distance and that size in the frame, that is a car."""
    made = []
    paint = bpy.data.materials.new(f"car_paint_{seed}")
    paint.use_nodes = True
    b = paint.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*colour, 1.0)
    b.inputs["Roughness"].default_value = 0.24
    b.inputs["Metallic"].default_value = 0.55
    b.inputs["Coat Weight"].default_value = 0.55
    body = slab("car_body", length, width, height * 0.44, paint, at=at, rot=rot,
                z=0.28, bevel=0.10, seed=seed)
    made.append(body)
    glass = glassy("car_glass", 0.06)
    cabin = slab("car_cabin", length * 0.48, width * 0.90, height * 0.34, glass,
                 at=(at[0] - math.cos(math.radians(rot)) * length * 0.04,
                     at[1] - math.sin(math.radians(rot)) * length * 0.04),
                 rot=rot, z=0.28 + height * 0.44, bevel=0.07, seed=seed + 1)
    made.append(cabin)
    tyre = matte("tyre", (0.020, 0.020, 0.021), 0.88)
    for dx, dy in ((-0.32, -0.5), (0.32, -0.5), (-0.32, 0.5), (0.32, 0.5)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=22,
                              radius1=0.32, radius2=0.32, depth=0.22)
        w = link(bm, "wheel", tyre)
        w.rotation_euler = (math.radians(90), 0, math.radians(rot))
        w.location = (at[0] + dx * length * math.cos(math.radians(rot)) - dy * width * math.sin(math.radians(rot)),
                      at[1] + dx * length * math.sin(math.radians(rot)) + dy * width * math.cos(math.radians(rot)),
                      0.30)
        made.append(w)
    return made


def rope(at=(0, 0), length=0.9, coils=3, r=0.011, rot=0.0, z=0.0, seed=34):
    """A knotted length of rope on a cleat: a loose spiral going nowhere in particular."""
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    n = 90
    verts = []
    for i in range(n + 1):
        t = i / n
        a = 2 * math.pi * coils * t
        rr = length * 0.18 * (1.0 - 0.35 * t) * (1 + 0.18 * math.sin(a * 2.3))
        verts.append(bm.verts.new((at[0] + rr * math.cos(a) + float(rng.normal(0, 0.004)),
                                   at[1] + rr * math.sin(a) * 0.7 + float(rng.normal(0, 0.004)),
                                   z + r + 0.012 * math.sin(a * 1.7) + 0.02 * t)))
    for i in range(n):
        bm.edges.new((verts[i], verts[i + 1]))
    obj = link(bm, "rope", matte("rope", (0.50, 0.44, 0.32), 0.95))
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    for v in obj.data.skin_vertices[0].data:
        v.radius = (r, r)
    obj.modifiers.new("sub", "SUBSURF").levels = 1
    return obj


def coat(at=(0, 0), w=0.44, h=0.75, rot=0.0, z=0.45, colour=(0.030, 0.062, 0.038), seed=35):
    """A wool coat over the back of a chair: it hangs in folds and one sleeve goes lower."""
    n = 46
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 4)
    grid = {}
    for j in range(n + 1):
        for i in range(n + 1):
            u, v = i / n - 0.5, j / n
            fold = 0.016 * math.sin(9 * u + ph[0]) * (0.4 + v)
            drop = -h * v ** 1.15
            grid[(i, j)] = bm.verts.new((u * w + fold * 0.4, fold, drop))
    for j in range(n):
        for i in range(n):
            bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
    obj = link(bm, "coat", matte("wool", colour, 0.98))
    obj.location = (at[0], at[1], z + h * 0.55)
    obj.rotation_euler = (0, 0, math.radians(rot))
    obj.modifiers.new("thick", "SOLIDIFY").thickness = 0.004
    return obj
