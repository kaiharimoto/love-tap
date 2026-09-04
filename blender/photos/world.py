"""blender/photos/world.py — the places the photographs are taken, beyond a table top.

The seeded year has two people photographing a canal lock at night, a beech wood full of
bluebells, a hospital car park in fog, and a dental waiting room, as well as the kitchen tables
that kit.py already builds. None of those is a still life, and none of them can be assembled from
a loaf and a mug.

What is here is deliberately coarse. A photograph in a message thread is looked at for about a
second and a half, mostly at the width of a thumb, and what decides whether it reads is the
silhouette, the light and the depth — not whether the bark has lenticels. So a tree is a tapering
trunk with a few limbs and a cloud of leaf cards; a car park is tarmac, painted bays and three
posts fading into a volume of fog. Everything is built at real size and lit by the same rig as
the paper, so a photograph and the note pinned beside it agree about where the light is.
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
from rig import common  # noqa: E402
import kit  # noqa: E402


# ------------------------------------------------------------------ ground
GROUNDS = {
    "tarmac": ((0.030, 0.030, 0.032), 0.78, 900.0),
    "wet_tarmac": ((0.022, 0.023, 0.026), 0.22, 900.0),
    "gravel": ((0.115, 0.100, 0.082), 0.88, 320.0),
    "cobbles": ((0.055, 0.050, 0.046), 0.55, 26.0),
    "paving": ((0.150, 0.145, 0.135), 0.80, 9.0),
    "grass": ((0.035, 0.075, 0.022), 0.90, 700.0),
    "leaf_litter": ((0.105, 0.070, 0.036), 0.92, 180.0),
    "carpet": ((0.115, 0.100, 0.090), 0.96, 900.0),
    "lino": ((0.150, 0.148, 0.140), 0.55, 500.0),
    "tiles": ((0.185, 0.180, 0.170), 0.34, 11.0),
    "earth": ((0.075, 0.055, 0.038), 0.93, 260.0),
    "snow": ((0.640, 0.660, 0.700), 0.72, 400.0),
    "sand": ((0.230, 0.190, 0.140), 0.88, 500.0),
}


def _speckled(name, rgb, rough, scale, contrast=0.45, bump=0.5, seed=1):
    """A ground is never one colour: it is a great many small things of slightly different ones."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = 9.0
    tex.inputs["Roughness"].default_value = 0.62
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
    lo = tuple(c * (1 - contrast) for c in rgb)
    hi = tuple(min(1.0, c * (1 + contrast)) for c in rgb)
    ramp.color_ramp.elements[0].color = (*lo, 1.0)
    ramp.color_ramp.elements[1].color = (*hi, 1.0)
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if bump:
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        bp.inputs["Distance"].default_value = 0.004
        nt.links.new(tex.outputs["Fac"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    return mat


def ground(kind="tarmac", size=40.0, z=0.0, seed=1):
    rgb, rough, scale = GROUNDS.get(kind, GROUNDS["tarmac"])
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=90, y_segments=90, size=size / 2)
    obj = kit.link(bm, f"ground_{kind}", _speckled(kind, rgb, rough, scale, seed=seed))
    obj.location = (0, 0, z)
    # Ground is never flat, and how un-flat it is depends on how much of it is in shot. A couple
    # of centimetres of roll is right for a ten metre yard and invisible across two hundred and
    # sixty metres of towpath, where the plane went to the horizon like a table.
    soft = 0.03 if kind in ("grass", "earth", "leaf_litter") else 0.012
    kit.rough_up(obj, soft * max(1.0, size / 12.0) * 0.5, seed, scale=0.9)
    return obj


def bays(at=(0, 6.0), rows=2, cols=5, w=2.4, d=4.8, z=0.001, worn=0.6):
    """Painted parking bays: white lines gone chalky, which is what says car park."""
    made = []
    mat = bpy.data.materials.new("bay_paint")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.32 * worn, 0.31 * worn, 0.29 * worn, 1.0)
    b.inputs["Roughness"].default_value = 0.92
    for r in range(rows):
        for c in range(cols + 1):
            bm = bmesh.new()
            bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
            line = kit.link(bm, "bay_line", mat, smooth=False)
            line.scale = (0.10, d, 1)
            line.location = (at[0] + (c - cols / 2) * w, at[1] + (r - (rows - 1) / 2) * (d + 0.6), z)
            bpy.context.view_layer.objects.active = line
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            made.append(line)
    return made


# ------------------------------------------------------------------ water
def water(at=(0, 4.0), w=14.0, d=9.0, z=-0.10, dark=(0.006, 0.008, 0.009), ripple=0.9, seed=2):
    """Still canal water: almost black, almost a mirror, and never quite flat.

    What makes water read as water is that the reflection in it is broken into horizontal
    fragments. That comes out of the surface, so the surface has a long low swell across it
    rather than a bump map.
    """
    n = 160
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 8)
    grid = {}
    for j in range(n + 1):
        for i in range(n + 1):
            u, v = i / n - 0.5, j / n - 0.5
            h = 0.0
            for k, amp in ((3.0, 1.0), (7.0, 0.45), (13.0, 0.22), (29.0, 0.09)):
                h += amp * math.sin(2 * math.pi * k * v + ph[int(k) % 8]) * math.cos(
                    2 * math.pi * k * 0.28 * u + ph[(int(k) + 3) % 8])
            grid[(i, j)] = bm.verts.new((u * w, v * d, h * 0.0018 * ripple))
    for j in range(n):
        for i in range(n):
            bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
    mat = bpy.data.materials.new("canal_water")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*dark, 1.0)
    b.inputs["Roughness"].default_value = 0.045
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["IOR"].default_value = 1.33
    obj = kit.link(bm, "water", mat)
    obj.location = (at[0], at[1], z)
    return obj


# ------------------------------------------------------------------ growing things
def bark_material(name="bark", pale=False, seed=3, tone=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 14.0
    tex.inputs["Detail"].default_value = 10.0
    stretch = nt.nodes.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (9.0, 9.0, 0.22)   # fissures run up the trunk
    coord = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(coord.outputs["Object"], stretch.inputs["Vector"])
    nt.links.new(stretch.outputs["Vector"], tex.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
    # beech is grey but it is not concrete: it is grey-green on the north side, warmer where the
    # light has been on it, and no two trees in a wood are the same value
    base = (0.088, 0.086, 0.072) if pale else (0.050, 0.040, 0.030)
    base = tuple(c * tone for c in base)
    ramp.color_ramp.elements[0].color = (*[c * 0.35 for c in base], 1.0)
    ramp.color_ramp.elements[1].color = (*[min(1.0, c * 1.6) for c in base], 1.0)
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.94
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.9
    bp.inputs["Distance"].default_value = 0.012
    nt.links.new(tex.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    return mat


def wood(at=(0, 10.0), count=11, spread=(9.0, 22.0), height=8.0, radius=0.22, pale=True,
         seed=3, canopy_above=True, close_horizon=True, leaf=(0.055, 0.115, 0.030)):
    """A wood, rather than one tree on a plain.

    Three things make it one: the trunks stack up and get closer together going back; there is
    more wood behind them than you can see through, so the horizon is closed; and there is a
    canopy over the top of the camera, which is what turns the light green and puts the shadows
    on the ground. Leave any of the three out and it is a field with poles in it.
    """
    made = []
    rng = np.random.default_rng(seed)
    for k in range(count):
        d = float(rng.uniform(3.0, spread[1]))
        x = at[0] + float(rng.uniform(-spread[0], spread[0])) * (0.4 + d / spread[1])
        y = at[1] + d - spread[1] * 0.45
        h = height * float(rng.uniform(0.72, 1.28))
        r = radius * float(rng.uniform(0.6, 1.5))
        made.append(trunk(at=(x, y), height=h, radius=r, taper=float(rng.uniform(0.35, 0.62)),
                          lean=float(rng.uniform(-0.06, 0.06)), pale=pale,
                          tone=float(rng.uniform(0.7, 1.4)), seed=seed + k * 13))
        if rng.random() < 0.55:
            made += limbs(at=(x, y), from_h=h * float(rng.uniform(0.45, 0.75)),
                          count=int(rng.integers(3, 6)), length=h * 0.22,
                          radius=r * 0.30, seed=seed + k * 7)
    if close_horizon:
        # the wood you cannot see through: far trunks, thin and close together, which is what
        # stops the eye at forty metres instead of at the edge of the ground plane
        for k in range(46):
            a = float(rng.uniform(-0.9, 0.9))
            d = float(rng.uniform(spread[1] * 1.1, spread[1] * 3.2))
            made.append(trunk(at=(at[0] + math.sin(a) * d, at[1] + d),
                              height=height * float(rng.uniform(0.8, 1.3)),
                              radius=radius * float(rng.uniform(0.7, 1.2)),
                              taper=0.5, pale=pale, tone=float(rng.uniform(0.8, 1.3)),
                              seed=seed + 500 + k, rings=9, segs=8))
    if canopy_above:
        # over the camera, not beside it, and dense enough to be a ceiling rather than a
        # handful of dark flecks in the top of the frame
        for k in range(9):
            made.append(canopy(at=(at[0] + float(rng.uniform(-9, 9)),
                                   at[1] + float(rng.uniform(-6, 18))),
                               centre_h=height * float(rng.uniform(0.72, 1.05)),
                               radius=float(rng.uniform(4.5, 7.5)), count=2400,
                               leaf=0.17, colour=leaf, seed=seed + 90 + k,
                               spread=(1.0, 1.0, 0.30)))
    return made


def trunk(at=(0, 6.0), height=7.0, radius=0.20, lean=0.0, taper=0.42, pale=False, seed=3,
          tone=1.0, rings=14, segs=18):
    """A trunk: tapering, leaning a little, and not round in section."""
    bm = bmesh.new()
    rng = np.random.default_rng(seed)
    wob = rng.uniform(-0.12, 0.12, segs)
    grid = []
    for j in range(rings + 1):
        t = j / rings
        r = radius * (1 - taper * t)
        z = height * t
        sway = math.sin(t * 2.1 + seed) * height * 0.035
        row = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            rr = r * (1 + wob[i] * (1 - 0.4 * t))
            row.append(bm.verts.new((rr * math.cos(a) + lean * z + sway,
                                     rr * math.sin(a), z)))
        grid.append(row)
    for j in range(rings):
        for i in range(segs):
            k = (i + 1) % segs
            bm.faces.new((grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]))
    obj = kit.link(bm, "trunk", bark_material("bark", pale, seed, tone))
    obj.location = (at[0], at[1], 0)
    return obj


def limbs(at=(0, 6.0), from_h=3.2, count=7, length=2.6, radius=0.055, spread=1.1, seed=4):
    """A few limbs going up and out, which is most of what a bare tree's silhouette is."""
    made = []
    rng = np.random.default_rng(seed)
    mat = bark_material("limb_bark", seed=seed)
    for k in range(count):
        a = 2 * math.pi * k / count + float(rng.uniform(-0.4, 0.4))
        rise = float(rng.uniform(0.5, 1.5))
        L = length * float(rng.uniform(0.6, 1.35))
        z0 = from_h + float(rng.uniform(-0.5, 1.6))
        bm = bmesh.new()
        v1 = bm.verts.new((at[0], at[1], z0))
        mid = bm.verts.new((at[0] + math.cos(a) * L * 0.5 * spread,
                            at[1] + math.sin(a) * L * 0.5 * spread, z0 + rise * L * 0.42))
        v2 = bm.verts.new((at[0] + math.cos(a) * L * spread,
                           at[1] + math.sin(a) * L * spread, z0 + rise * L))
        bm.edges.new((v1, mid))
        bm.edges.new((mid, v2))
        obj = kit.link(bm, "limb", mat)
        skin = obj.modifiers.new("skin", "SKIN")
        skin.use_smooth_shade = True
        radii = (radius, radius * 0.6, radius * 0.22)
        for v, r in zip(obj.data.skin_vertices[0].data, radii):
            v.radius = (r, r)
        obj.modifiers.new("sub", "SUBSURF").levels = 1
        made.append(obj)
    return made


def canopy(at=(0, 6.0), centre_h=5.4, radius=2.6, count=260, leaf=0.075,
           colour=(0.055, 0.115, 0.030), seed=5, spread=(1.0, 1.0, 0.7)):
    """Foliage as a cloud of small cards. At the size a photograph is looked at, a cloud of
    cards catching light from one side is a canopy; a sphere with a leaf texture is a bush."""
    rng = np.random.default_rng(seed)
    mat = bpy.data.materials.new("leaf")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*colour, 1.0)
    b.inputs["Roughness"].default_value = 0.62
    b.inputs["Subsurface Weight"].default_value = 0.35
    b.inputs["Subsurface Radius"].default_value = (0.004, 0.006, 0.002)
    bm = bmesh.new()
    for _ in range(count):
        d = rng.normal(0, 0.42, 3) * np.array(spread) * radius
        if np.linalg.norm(d / (np.array(spread) * radius)) > 1.35:
            continue
        cx, cy, cz = at[0] + d[0], at[1] + d[1], centre_h + d[2]
        a, tilt = rng.uniform(0, 6.28), rng.uniform(-1.0, 1.0)
        s = leaf * rng.uniform(0.65, 1.4)
        ca, sa = math.cos(a), math.sin(a)
        pts = [(-s, -s * 0.55), (s, -s * 0.35), (s * 0.8, s * 0.6), (-s * 0.9, s * 0.4)]
        verts = [bm.verts.new((cx + px * ca - py * sa, cy + px * sa + py * ca,
                               cz + (px + py) * tilt * 0.4)) for px, py in pts]
        bm.faces.new(verts)
    return kit.link(bm, "canopy", mat, smooth=False)


def undergrowth(at=(0, 6.0), w=9.0, d=9.0, count=1400, height=0.22,
                colour=(0.075, 0.055, 0.30), stem=(0.045, 0.085, 0.030), seed=6):
    """A drift of something small and flowering, running away between the trunks."""
    rng = np.random.default_rng(seed)
    flower = bpy.data.materials.new("flower")
    flower.use_nodes = True
    fb = flower.node_tree.nodes.get("Principled BSDF")
    fb.inputs["Base Color"].default_value = (*colour, 1.0)
    fb.inputs["Roughness"].default_value = 0.70
    fb.inputs["Subsurface Weight"].default_value = 0.30
    bm = bmesh.new()
    for _ in range(count):
        x = at[0] + float(rng.uniform(-w / 2, w / 2))
        y = at[1] + float(rng.uniform(-d / 2, d / 2))
        h = height * float(rng.uniform(0.6, 1.35))
        lean = float(rng.uniform(-0.35, 0.35))
        # a nodding head on a stem: three little cards hanging off the top
        for k in range(3):
            a = 2 * math.pi * k / 3 + float(rng.uniform(0, 1))
            s = h * 0.16
            top = (x + lean * h, y, h)
            verts = [bm.verts.new((top[0] + math.cos(a) * s, top[1] + math.sin(a) * s, top[2])),
                     bm.verts.new((top[0] + math.cos(a) * s * 1.6, top[1] + math.sin(a) * s * 1.6,
                                   top[2] - s * 1.5)),
                     bm.verts.new((top[0], top[1], top[2] - s * 1.9))]
            bm.faces.new(verts)
    return kit.link(bm, "undergrowth", flower, smooth=False)


# ------------------------------------------------------------------ things that stand up
def post(at=(0, 8.0), height=6.0, radius=0.075, kind="lamp", seed=7):
    """A lamp post, a bollard, a signpost: the vertical that gives a flat place its depth."""
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16,
                          radius1=radius, radius2=radius * 0.65, depth=height)
    mat = kit.metal("post", (0.045, 0.048, 0.050), 0.55)
    p = kit.link(bm, kind + "_post", mat)
    p.location = (at[0], at[1], height / 2)
    made.append(p)
    if kind == "lamp":
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        head = kit.link(bm, "lamp_head", kit.matte("lamp_glass", (0.7, 0.62, 0.42), 0.35),
                        smooth=False)
        head.scale = (0.30, 0.62, 0.10)
        head.location = (at[0], at[1] + 0.18, height)
        made.append(head)
    elif kind == "bollard":
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius * 1.4)
        cap = kit.link(bm, "bollard_cap", mat)
        cap.location = (at[0], at[1], height)
        made.append(cap)
    return made


def railing(at=(0, 3.0), length=6.0, height=0.95, posts=7, rot=0.0, seed=8):
    """Low iron railing: two rails and a row of uprights."""
    made = []
    mat = kit.metal("iron", (0.030, 0.030, 0.032), 0.62)
    for k in range(posts):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10,
                              radius1=0.018, radius2=0.016, depth=height)
        u = (k / (posts - 1) - 0.5) * length
        p = kit.link(bm, "railing_post", mat)
        p.location = (at[0] + u * math.cos(math.radians(rot)),
                      at[1] + u * math.sin(math.radians(rot)), height / 2)
        made.append(p)
    for z in (height * 0.98, height * 0.45):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10,
                              radius1=0.016, radius2=0.016, depth=length)
        r = kit.link(bm, "railing_rail", mat)
        r.rotation_euler = (math.radians(90), 0, math.radians(rot + 90))
        r.location = (at[0], at[1], z)
        made.append(r)
    return made


def barrier(at=(0, 7.0), length=3.4, height=0.95, angle=0.0, seed=9):
    """A car park barrier arm, chevron striped, and the box it swings out of."""
    made = []
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    box = kit.link(bm, "barrier_box", kit.matte("barrier_box", (0.180, 0.145, 0.030), 0.72),
                   smooth=False)
    box.scale = (0.22, 0.20, height)
    box.location = (at[0], at[1], height / 2)
    made.append(box)
    stripes = bpy.data.materials.new("chevron")
    stripes.use_nodes = True
    nt = stripes.node_tree
    b = nt.nodes.get("Principled BSDF")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.wave_profile = "SAW"
    wave.inputs["Scale"].default_value = 8.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].color = (0.62, 0.60, 0.56, 1.0)
    ramp.color_ramp.elements[1].position = 0.5
    ramp.color_ramp.elements[1].color = (0.30, 0.045, 0.030, 1.0)
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.60
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    arm = kit.link(bm, "barrier_arm", stripes, smooth=False)
    arm.scale = (length, 0.055, 0.085)
    arm.location = (at[0] + length / 2 * math.cos(math.radians(angle)),
                    at[1] + length / 2 * math.sin(math.radians(angle)), height * 0.92)
    arm.rotation_euler = (0, math.radians(-angle * 0.6), math.radians(angle))
    made.append(arm)
    return made


# ------------------------------------------------------------------ walls and rooms
def brick_material(name="brick", tone=(0.130, 0.062, 0.042), seed=10):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexBrick")
    tex.inputs["Scale"].default_value = 5.5
    tex.offset = 0.5
    tex.squash = 1.0
    tex.inputs["Mortar Size"].default_value = 0.022
    tex.inputs["Mortar Smooth"].default_value = 0.15
    tex.inputs["Bias"].default_value = 0.0
    tex.inputs["Brick Width"].default_value = 0.52
    tex.inputs["Row Height"].default_value = 0.22
    tex.inputs["Color1"].default_value = (*tone, 1.0)
    tex.inputs["Color2"].default_value = (*[c * 0.68 for c in tone], 1.0)
    tex.inputs["Mortar"].default_value = (0.230, 0.220, 0.205, 1.0)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.92
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.55
    bp.inputs["Distance"].default_value = 0.006
    nt.links.new(tex.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    return mat


def wall(kind="painted", at=(0, 3.0), w=8.0, h=2.6, rot=0.0, tone=None, seed=11):
    if kind == "brick":
        mat = brick_material("brick", tone or (0.130, 0.062, 0.042), seed)
    elif kind == "tiled":
        mat = _speckled("tile_wall", tone or (0.30, 0.31, 0.29), 0.20, 8.0, 0.10, 0.2, seed)
    else:
        mat = _speckled("painted_wall", tone or (0.320, 0.310, 0.290), 0.90, 60.0, 0.08, 0.15, seed)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=24, y_segments=12, size=0.5)
    obj = kit.link(bm, f"wall_{kind}", mat, smooth=False)
    obj.scale = (w, h, 1)
    obj.rotation_euler = (math.radians(90), 0, math.radians(rot))
    obj.location = (at[0], at[1], h / 2)
    return obj


def window_light(at=(0, 3.4), w=1.1, h=1.5, energy=180.0, colour=(0.72, 0.80, 1.0), rot=0.0):
    """A window, as the thing that lights the room and as the bright rectangle in the frame."""
    made = []
    data = bpy.data.lights.new("window", "AREA")
    data.energy = energy
    data.color = colour
    data.shape = "RECTANGLE"
    data.size = w
    data.size_y = h
    lamp = bpy.data.objects.new("window_light", data)
    bpy.context.scene.collection.objects.link(lamp)
    lamp.location = (at[0], at[1] - 0.05, at[2] if len(at) > 2 else 1.4)
    common._aim(lamp, (0, -1, -0.25))
    made.append(lamp)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
    mat = bpy.data.materials.new("sky_through_glass")
    mat.use_nodes = True
    nt = mat.node_tree
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1.0)
    em.inputs["Strength"].default_value = 3.0
    nt.links.new(em.outputs["Emission"], nt.nodes["Material Output"].inputs["Surface"])
    pane = kit.link(bm, "window_pane", mat, smooth=False)
    pane.scale = (w, h, 1)
    pane.rotation_euler = (math.radians(90), 0, math.radians(rot))
    pane.location = (at[0], at[1], at[2] if len(at) > 2 else 1.4)
    made.append(pane)
    return made


def block(at=(0, 0), w=0.5, d=0.5, h=0.75, rot=0.0, tone=(0.10, 0.10, 0.10), rough=0.8,
          bevel=0.006, z=0.0, seed=12):
    """Furniture, coarsely: a chair is a seat and a back, a table is a top and four legs, and at
    the far end of a waiting room both are a box with its edges knocked off."""
    return kit.slab("block", w, d, h, kit.matte(f"block_{seed}", tone, rough), at=at, rot=rot,
                    z=z, bevel=bevel, seed=seed)


def chair(at=(0, 0), rot=0.0, tone=(0.09, 0.10, 0.11), seed=13):
    made = [block(at=at, w=0.44, d=0.44, h=0.045, rot=rot, tone=tone, z=0.43, seed=seed)]
    back = block(at=(at[0] - math.sin(math.radians(rot)) * 0.20,
                     at[1] + math.cos(math.radians(rot)) * 0.20),
                 w=0.42, d=0.05, h=0.42, rot=rot, tone=tone, z=0.47, seed=seed + 1)
    made.append(back)
    for dx, dy in ((-0.18, -0.18), (0.18, -0.18), (-0.18, 0.18), (0.18, 0.18)):
        made.append(block(at=(at[0] + dx, at[1] + dy), w=0.022, d=0.022, h=0.43,
                          tone=(0.06, 0.06, 0.065), seed=seed + 2))
    return made


def table(at=(0, 0), w=1.1, d=0.7, h=0.73, rot=0.0, tone=None, wood=True, seed=14):
    made = []
    if wood:
        mat = kit.wood_material("table_wood", tone or (0.36, 0.24, 0.14), 40.0, 0.5, seed)
    else:
        mat = kit.laminate_material("table_top", tone or (0.30, 0.30, 0.28), seed)
    made.append(kit.slab("table_top", w, d, 0.026, mat, at=at, rot=rot, z=h - 0.026, seed=seed))
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        made.append(block(at=(at[0] + dx * (w / 2 - 0.06), at[1] + dy * (d / 2 - 0.06)),
                          w=0.045, d=0.045, h=h - 0.026, tone=(0.10, 0.07, 0.045), seed=seed + 3))
    return made


def shelf_rack(at=(0, 2.0), w=0.5, h=0.7, rows=5, rot=0.0, tone=(0.24, 0.23, 0.21), seed=15):
    """A rack of folded leaflets on a wall: a grid of small bright rectangles, which is all it is
    at the far side of a waiting room."""
    made = [block(at=at, w=w, d=0.06, h=h, rot=rot, tone=tone, z=1.0, seed=seed)]
    for r in range(rows):
        for c in range(2):
            made.append(block(at=(at[0] + (c - 0.5) * w * 0.46, at[1] - 0.045),
                              w=w * 0.40, d=0.012, h=h / rows * 0.62, rot=rot,
                              tone=(0.44, 0.42, 0.38), z=1.0 + (r + 0.2) * h / rows, seed=seed + r))
    return made


# ------------------------------------------------------------------ air
def sky(scene, turbidity=3.0, elevation_deg=None, strength=1.0):
    """A real sky rather than a flat grey card.

    The horizon of a physical sky is much brighter and much warmer than the zenith, and that
    gradient is most of what tells you a photograph was taken outdoors. The sun in the rig still
    does the lighting; this is the environment it stands in.
    """
    from rig import common as _c
    world = scene.world or bpy.data.worlds.new("sky")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_WORLD":
            nt.nodes.remove(n)
    tex = nt.nodes.new("ShaderNodeTexSky")
    tex.sky_type = "NISHITA"
    tex.turbidity = turbidity
    tex.sun_disc = False
    el = math.radians(_c.DAY_ELEVATION_DEG if elevation_deg is None else elevation_deg)
    tex.sun_elevation = el
    tex.sun_rotation = math.radians(_c.DAY_AZIMUTH_DEG)
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    nt.links.new(tex.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], nt.nodes["World Output"].inputs["Surface"])
    return world


def fog(density=0.02, colour=(0.62, 0.64, 0.66), size=60.0):
    """A volume over the whole scene. Fog is what makes three lamp posts into a distance."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=size)
    mat = bpy.data.materials.new("fog")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    scatter = nt.nodes.new("ShaderNodeVolumeScatter")
    scatter.inputs["Color"].default_value = (*colour, 1.0)
    scatter.inputs["Density"].default_value = density
    scatter.inputs["Anisotropy"].default_value = 0.35
    nt.links.new(scatter.outputs["Volume"], nt.nodes["Material Output"].inputs["Volume"])
    obj = kit.link(bm, "fog", mat, smooth=False)
    obj.location = (0, 0, size / 2 - 0.5)
    return obj


def string_lights(along=((-2.0, 6.0, 3.0), (2.0, 6.5, 4.2)), count=14, energy=0.22,
                  colour=(1.0, 0.68, 0.35), sag=0.5, seed=16):
    """Small warm lights wound through branches: point lights, and a small bright bead at each
    so the camera sees the source and not only what it lights."""
    made = []
    rng = np.random.default_rng(seed)
    a, b = np.array(along[0], dtype=float), np.array(along[1], dtype=float)
    mat = bpy.data.materials.new("bulb_bead")
    mat.use_nodes = True
    nt = mat.node_tree
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1.0)
    em.inputs["Strength"].default_value = 22.0
    nt.links.new(em.outputs["Emission"], nt.nodes["Material Output"].inputs["Surface"])
    for k in range(count):
        t = k / max(count - 1, 1)
        p = a + (b - a) * t
        p[2] -= sag * math.sin(math.pi * t)
        p += rng.normal(0, 0.10, 3)
        data = bpy.data.lights.new(f"bead_{k}", "POINT")
        data.energy = energy
        data.color = colour
        data.shadow_soft_size = 0.01
        lamp = bpy.data.objects.new(f"bead_{k}", data)
        bpy.context.scene.collection.objects.link(lamp)
        lamp.location = tuple(p)
        made.append(lamp)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.011)
        bead = kit.link(bm, f"bead_glass_{k}", mat)
        bead.location = tuple(p)
        made.append(bead)
    return made
