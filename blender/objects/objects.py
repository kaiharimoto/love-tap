"""blender/objects/objects.py — the feeling objects, as things rather than icons.

    bash blender/run.sh blender/objects/objects.py -- --only obj_crane --res 400
    bash blender/run.sh blender/objects/objects.py -- --all --res 1200

Every feeling in docs/FEELINGS.md that is a physical object is modelled here and rendered under
rig/common: a paper crane, a boat, a folded heart, a paper plane, a fortune teller, a crown, a
crumpled ball, a torn corner, a blanket fold; a foil star, hole-punch confetti, a curled ribbon,
a rubber band, a chain of staples, a spitball; a stone, a candle, a mug, a snapped pencil, a knot
of thread, a loop of string, a cinema ticket, a plaster, a pressed clover, a coffee ring on a card.

Each is rendered twice at the same camera: the object with alpha (film transparent) and its contact
shadow alone from a shadow catcher, so the app composites object over shadow and the shadow comes
from the same light as the object. Nothing is a drop shadow. Dusk versions of the shadow are baked
for the night appearance.
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

OUT = os.path.join(common.repo_root(), "assets", "objects")
PAPER_T = 0.00012


# ------------------------------------------------------------------ materials
def paper_mat(name, rgb=(0.94, 0.91, 0.85), tooth=0.9):
    return common.paper_material(name, rgb, tooth=tooth, yellowing=0.18, sheen=0.26, fibre_scale=1600.0)


def simple_mat(name, rgb, roughness=0.5, metallic=0.0, transmission=0.0, ior=1.45):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Metallic"].default_value = metallic
    b.inputs["IOR"].default_value = ior
    if transmission:
        b.inputs["Transmission Weight"].default_value = transmission
    return mat


# ------------------------------------------------------------------ helpers
def new_mesh(bm, name, mat=None, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True
    if mat:
        obj.data.materials.append(mat)
    return obj


def sheet(w, h, nx=40, ny=40, warp=None):
    """A flat sheet in the xy plane; warp(u, v) -> z in metres."""
    bm = bmesh.new()
    verts = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            z = warp(u, v) if warp else 0.0
            verts[(i, j)] = bm.verts.new(((u - 0.5) * w, (v - 0.5) * h, z))
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]))
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            loop[uv].uv = (c.x / w + 0.5, c.y / h + 0.5)
    return bm


def solidify(obj, t=PAPER_T):
    m = obj.modifiers.new("thickness", "SOLIDIFY")
    m.thickness = t
    m.offset = 0.0
    return obj


def tube(points, radius, sections=12, name="tube", mat=None, taper=None):
    """A tube along a polyline (thread, string, ribbon core, staple wire)."""
    bm = bmesh.new()
    pts = [np.array(p, float) for p in points]
    rings = []
    for k, p in enumerate(pts):
        if k == 0:
            d = pts[1] - pts[0]
        elif k == len(pts) - 1:
            d = pts[-1] - pts[-2]
        else:
            d = pts[k + 1] - pts[k - 1]
        d /= (np.linalg.norm(d) + 1e-9)
        a = np.array([0.0, 0.0, 1.0])
        if abs(np.dot(a, d)) > 0.9:
            a = np.array([1.0, 0.0, 0.0])
        u = np.cross(d, a)
        u /= (np.linalg.norm(u) + 1e-9)
        v = np.cross(d, u)
        r = radius * (taper(k / max(1, len(pts) - 1)) if taper else 1.0)
        ring = [bm.verts.new(tuple(p + (math.cos(2 * math.pi * s / sections) * u +
                                        math.sin(2 * math.pi * s / sections) * v) * r))
                for s in range(sections)]
        rings.append(ring)
    for k in range(len(rings) - 1):
        for s in range(sections):
            s2 = (s + 1) % sections
            bm.faces.new((rings[k][s], rings[k][s2], rings[k + 1][s2], rings[k + 1][s]))
    return new_mesh(bm, name, mat)


# ------------------------------------------------------------------ the objects
def obj_pinch(rng):
    """A squeeze: a strip of paper taken between finger and thumb and pressed.

    This replaces an origami heart. A heart is a glyph whatever it is modelled out of — a filled
    white one on a warm ground is the emoji whether or not it was folded — and the anti-goal is
    about what a thing reads as, not how it was made. A squeeze is a gesture, so the object is the
    mark that gesture leaves: the strip pleats at the pinch, stands up either side of it, and the
    two ends drop back down to the desk.
    """
    L, W = 0.052, 0.017
    def warp(u, v):
        # u runs along the strip. The pinch is at the middle: two creases about four millimetres
        # apart, with the paper standing between them and settling away either side.
        d = abs(u - 0.5)
        peak = math.exp(-(d / 0.055) ** 2)
        pleat = 0.0028 * math.cos((v - 0.5) * math.pi * 3.0) * peak
        settle = 0.0011 * math.exp(-((d - 0.22) / 0.13) ** 2)
        return 0.0075 * peak + pleat + settle
    bm = sheet(L, W, 90, 34, warp)
    # the strip is torn off, not cut: its two ends are ragged
    for v in bm.verts:
        u = v.co.x / L + 0.5
        if u < 0.03 or u > 0.97:
            v.co.y += 0.0006 * math.sin(v.co.y * 900.0 + u * 60.0)
            v.co.z += 0.0004 * math.sin(v.co.y * 1400.0)
    obj = solidify(new_mesh(bm, "pinch", paper_mat("pinch_paper", (0.93, 0.90, 0.84), tooth=1.0)))
    obj.rotation_euler = (0.0, 0.0, math.radians(float(rng.uniform(-16, 16))))
    return obj


def _poly(points, name, mat, t=PAPER_T):
    """One flat folded facet from a list of 3D points (a crease-bounded panel of the model)."""
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(p)) for p in points]
    bm.faces.new(vs)
    return solidify(new_mesh(bm, name, mat, smooth=False), t)


def obj_crane(rng):
    """A folded paper bird seen from a shallow angle: a diamond body creased down the middle, two
    wide wings with a little dihedral, a beak and a tail. Every panel is planar (three points, or
    four that lie in one plane) so the creases are real edges rather than a smoothed blob."""
    mat = paper_mat("crane_paper", (0.95, 0.93, 0.88))
    parts = []
    # body: two triangles meeting along the keel, nose at +x, tail at -x
    nose, tail_pt, ridge = (0.019, 0.0, 0.007), (-0.020, 0.0, 0.009), (0.0, 0.0, 0.011)
    for sign in (1, -1):
        parts.append(_poly([nose, ridge, (0.001, 0.009 * sign, 0.001)], f"body_f{sign}", mat))
        parts.append(_poly([ridge, tail_pt, (-0.006, 0.008 * sign, 0.001)], f"body_b{sign}", mat))
        parts.append(_poly([(0.001, 0.009 * sign, 0.001), ridge, (-0.006, 0.008 * sign, 0.001)],
                           f"body_s{sign}", mat))
    # wings: wide triangles from the ridge out to a tip, lifted a little at the tip
    for sign in (1, -1):
        parts.append(_poly([(0.008, 0.002 * sign, 0.009), (-0.010, 0.002 * sign, 0.010),
                            (-0.002, 0.027 * sign, 0.014)], f"wing{sign}", mat))
    # beak and tail: narrow folded points
    parts.append(_poly([(0.019, 0.0015, 0.007), (0.019, -0.0015, 0.007), (0.031, 0.0, 0.013)], "beak", mat))
    parts.append(_poly([(-0.020, 0.0018, 0.009), (-0.020, -0.0018, 0.009), (-0.033, 0.0, 0.017)], "tail", mat))
    return parts


def obj_boat(rng):
    mat = paper_mat("boat_paper", (0.94, 0.92, 0.86))
    hull = sheet(0.034, 0.016, 26, 14, lambda u, v: 0.006 * (abs(v - 0.5) * 2) ** 1.5 + 0.004 * (abs(u - 0.5) * 2) ** 2)
    parts = [solidify(new_mesh(hull, "boat_hull", mat))]
    sail = sheet(0.020, 0.020, 16, 16, lambda u, v: 0.0)
    s = solidify(new_mesh(sail, "boat_sail", mat))
    s.rotation_euler = (math.radians(78), 0.0, math.radians(8))
    s.location = (0.0, 0.0, 0.010)
    parts.append(s)
    return parts


def obj_plane(rng):
    mat = paper_mat("plane_paper", (0.95, 0.94, 0.90))
    parts = []
    for sign in (1, -1):
        w = sheet(0.040, 0.016, 26, 12, lambda u, v: 0.003 * (1 - v))
        o = solidify(new_mesh(w, f"wing{sign}", mat))
        o.rotation_euler = (math.radians(12 * sign), 0.0, 0.0)
        o.location = (0.0, 0.008 * sign, 0.002)
        parts.append(o)
    keel = sheet(0.040, 0.010, 26, 8, lambda u, v: 0.0)
    k = solidify(new_mesh(keel, "keel", mat))
    k.rotation_euler = (math.radians(90), 0.0, 0.0)
    k.location = (0.0, 0.0, 0.004)
    parts.append(k)
    return parts


def obj_fortune_teller(rng):
    mat = paper_mat("ft_paper", (0.95, 0.93, 0.88))
    parts = []
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        p = sheet(0.020, 0.020, 16, 16, lambda u, v: 0.008 * (1 - u) * (1 - v))
        o = solidify(new_mesh(p, f"ft{k}", mat))
        o.rotation_euler = (math.radians(26), 0.0, a)
        o.location = (0.011 * math.cos(a), 0.011 * math.sin(a), 0.004)
        parts.append(o)
    return parts


def obj_crown(rng):
    """A paper crown, cut from a strip and taped into a ring, lying over on its side.

    Stood upright and seen from above it is a ring of triangles, which is a graphic. Tipped over
    the way one actually ends up on a table, it is a band of paper with points on it, and you can
    see the thickness of the card at every cut edge and where the two ends overlap at the join.
    """
    mat = paper_mat("crown_paper", (0.95, 0.92, 0.72))
    bm = bmesh.new()
    n = 7
    r = 0.019
    ring, top = [], []
    for k in range(n * 2):
        a = 2 * math.pi * k / (n * 2)
        rr = r if k % 2 == 0 else r * 0.88
        # the band is not a true circle: it has been squashed by being sat on
        squash = 1.0 - 0.22 * abs(math.sin(a))
        ring.append((rr * math.cos(a) * squash, rr * math.sin(a), 0.0))
        h = 0.015 if k % 2 == 0 else 0.005
        top.append((rr * math.cos(a) * squash * 1.03, rr * math.sin(a) * 1.03, h))
    vb = [bm.verts.new(p) for p in ring]
    vt = [bm.verts.new(p) for p in top]
    for k in range(len(vb)):
        k2 = (k + 1) % len(vb)
        bm.faces.new((vb[k], vb[k2], vt[k2], vt[k]))
    obj = solidify(new_mesh(bm, "crown", mat, smooth=False), t=0.00035)
    # tipped over onto the desk, resting on its rim
    obj.rotation_euler = (math.radians(76.0), 0.0, math.radians(float(rng.uniform(-20, 20))))
    obj.location = (0.0, 0.0, r * 0.94)
    return obj


def obj_blanket_fold(rng):
    mat = paper_mat("blanket_paper", (0.93, 0.91, 0.87), tooth=1.2)
    bm = sheet(0.034, 0.026, 40, 32, lambda u, v: 0.004 * math.sin(v * 6.0) + 0.002 * math.sin(u * 9.0))
    return solidify(new_mesh(bm, "blanket", mat), t=0.0004)


def obj_crumple_ball(rng):
    """Paper crushed into a ball: a facetted sphere whose panels are flat, so every crease is a
    hard edge and the light breaks across it the way it does on a crumpled note."""
    mat = paper_mat("crumple_paper", (0.93, 0.90, 0.84), tooth=1.3)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.013)
    r = np.random.default_rng(17)
    planes = [(r.normal(size=3), r.uniform(-0.006, 0.006), r.uniform(0.0012, 0.0032)) for _ in range(16)]
    for v in bm.verts:
        p = np.array(v.co, float)
        d = 0.0
        for n, off, amp in planes:
            n = n / (np.linalg.norm(n) + 1e-9)
            s_ = float(np.dot(p, n)) - off
            # a crease: the surface is pushed in on one side of each plane and stands proud on the
            # other, sharply near the plane itself
            d += amp * math.tanh(s_ / 0.0022)
        v.co = tuple(p * (1.0 + d / 0.013 * 0.55))
    return new_mesh(bm, "crumple_ball", mat, smooth=False)


def obj_torn_corner(rng):
    mat = paper_mat("corner_paper", (0.94, 0.91, 0.85))
    bm = sheet(0.026, 0.026, 30, 30, lambda u, v: 0.0012 * math.sin(u * 5) + 0.0018 * v ** 2)
    kill = [v for v in bm.verts if (v.co.x / 0.026 + 0.5) + (v.co.y / 0.026 + 0.5) > 1.25 + 0.06 * math.sin(v.co.x * 300)]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    return solidify(new_mesh(bm, "torn_corner", mat))


def obj_ticket(rng):
    mat = paper_mat("ticket_paper", (0.94, 0.90, 0.80), tooth=0.6)
    bm = sheet(0.030, 0.014, 26, 12, lambda u, v: 0.0008 * math.sin(u * 8))
    return solidify(new_mesh(bm, "ticket", mat))


def obj_plaster(rng):
    pad = simple_mat("gauze", (0.93, 0.92, 0.89), roughness=0.85)
    tape = simple_mat("plaster", (0.86, 0.72, 0.60), roughness=0.6)
    bm = sheet(0.034, 0.012, 26, 10, lambda u, v: 0.0006 * math.sin(u * 6))
    parts = [solidify(new_mesh(bm, "plaster", tape), t=0.0003)]
    bm2 = sheet(0.012, 0.009, 10, 8, lambda u, v: 0.0)
    p = solidify(new_mesh(bm2, "gauze_pad", pad), t=0.0006)
    p.location = (0.0, 0.0, 0.0006)
    parts.append(p)
    return parts


def obj_gold_star(rng):
    """A foil star, stuck on a scrap of paper with one point lifting off it.

    A five-pointed star lying flat and dead-on is a glyph. What makes it a sticker is that it is
    stuck to something, that it is not quite flat, and that the foil throws a hard highlight in
    one place while the paper under it does not.
    """
    parts = []
    backing = sheet(0.026, 0.024, 20, 20, lambda u, v: 0.0003 * math.sin(u * 5 + v * 3))
    parts.append(solidify(new_mesh(backing, "star_backing",
                                   paper_mat("star_backing", (0.90, 0.87, 0.80))), t=0.00016))

    mat = simple_mat("foil", (0.86, 0.68, 0.24), roughness=0.14, metallic=1.0)
    bm = bmesh.new()
    lift_at = int(rng.integers(0, 5)) * 2
    pts = []
    for k in range(10):
        a = math.pi / 2 + 2 * math.pi * k / 10
        r = 0.011 if k % 2 == 0 else 0.0048
        # one point has been picked at and stands off the paper, curling as it goes
        z = 0.0009 + (0.0042 if k == lift_at else 0.0)
        pts.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
    centre = bm.verts.new((0.0, 0.0, 0.0009))
    for k in range(10):
        bm.faces.new((centre, pts[k], pts[(k + 1) % 10]))
    star = solidify(new_mesh(bm, "gold_star", mat, smooth=False), t=0.00022)
    star.rotation_euler = (0.0, 0.0, math.radians(float(rng.uniform(-25, 25))))
    parts.append(star)
    return parts


def obj_confetti(rng):
    mat_a = paper_mat("conf_a", (0.95, 0.78, 0.80))
    mat_b = paper_mat("conf_b", (0.90, 0.92, 0.72))
    parts = []
    r = np.random.default_rng(41)
    for k in range(14):
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=True, segments=16, radius=0.0022)
        o = solidify(new_mesh(bm, f"conf{k}", mat_a if k % 2 else mat_b), t=0.00012)
        o.location = (float(r.uniform(-0.016, 0.016)), float(r.uniform(-0.014, 0.014)), float(r.uniform(0, 0.0004)))
        o.rotation_euler = (float(r.uniform(-0.4, 0.4)), float(r.uniform(-0.4, 0.4)), float(r.uniform(0, 3.14)))
        parts.append(o)
    return parts


def obj_ribbon(rng):
    mat = simple_mat("ribbon", (0.92, 0.62, 0.72), roughness=0.35)
    pts = []
    for k in range(90):
        t = k / 89
        a = t * 4.4 * math.pi
        r = 0.012 * (1 - 0.55 * t)
        pts.append((r * math.cos(a), r * math.sin(a) * 0.8, 0.0016 + 0.010 * t))
    return tube(pts, 0.0016, 8, "ribbon", mat, taper=lambda t: 1.0 - 0.35 * t)


def obj_string_loop(rng):
    mat = simple_mat("string", (0.80, 0.72, 0.56), roughness=0.9)
    pts = [(0.016 * math.cos(2 * math.pi * k / 60), 0.011 * math.sin(2 * math.pi * k / 60),
            0.0009 + 0.0016 * math.sin(4 * math.pi * k / 60)) for k in range(61)]
    return tube(pts, 0.0008, 8, "string_loop", mat)


def obj_knot(rng):
    mat = simple_mat("thread", (0.62, 0.52, 0.36), roughness=0.9)
    pts = []
    for k in range(160):
        t = k / 159 * 2 * math.pi
        pts.append((0.010 * math.sin(2 * t), 0.010 * math.cos(3 * t) * 0.8, 0.0018 + 0.004 * math.sin(3 * t)))
    return tube(pts, 0.0007, 8, "knot", mat)


def obj_rubber_band(rng):
    mat = simple_mat("rubber", (0.82, 0.56, 0.36), roughness=0.75)
    pts = [(0.018 * math.cos(2 * math.pi * k / 70), 0.009 * math.sin(2 * math.pi * k / 70), 0.0008) for k in range(71)]
    return tube(pts, 0.0009, 8, "rubber_band", mat)


def obj_staple_chain(rng):
    mat = simple_mat("steel", (0.62, 0.63, 0.66), roughness=0.28, metallic=1.0)
    parts = []
    r = np.random.default_rng(9)
    for k in range(6):
        x = -0.016 + k * 0.0065
        pts = [(x, -0.004, 0.0007), (x, 0.004, 0.0007), (x + 0.0035, 0.004, 0.0007), (x + 0.0035, -0.004, 0.0007)]
        o = tube(pts, 0.00055, 6, f"staple{k}", mat)
        o.rotation_euler = (0.0, 0.0, float(r.uniform(-0.25, 0.25)))
        parts.append(o)
    return parts


def obj_spitball(rng):
    mat = paper_mat("spit_paper", (0.92, 0.90, 0.85), tooth=1.4)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.006)
    r = np.random.default_rng(3)
    for v in bm.verts:
        p = np.array(v.co)
        v.co = tuple(p * (1 + r.uniform(-0.18, 0.18)))
    return new_mesh(bm, "spitball", mat)


def obj_stone(rng):
    mat = simple_mat("stone", (0.42, 0.42, 0.44), roughness=0.55)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=0.012)
    r = np.random.default_rng(5)
    for v in bm.verts:
        p = np.array(v.co)
        p[2] *= 0.55
        v.co = tuple(p * (1 + r.uniform(-0.06, 0.06)))
    return new_mesh(bm, "stone", mat)


def obj_candle(rng):
    wax = simple_mat("wax", (0.92, 0.86, 0.68), roughness=0.45, transmission=0.25)
    wick = simple_mat("wick", (0.15, 0.13, 0.12), roughness=0.9)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=28, radius1=0.010, radius2=0.0095, depth=0.020)
    body = new_mesh(bm, "candle", wax, smooth=False)
    body.location = (0.0, 0.0, 0.010)
    w = tube([(0.0, 0.0, 0.020), (0.0006, 0.0, 0.024)], 0.0006, 6, "wick", wick)
    return [body, w]


def obj_mug(rng):
    mat = simple_mat("mug", (0.78, 0.74, 0.70), roughness=0.35)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.013, radius2=0.014, depth=0.022)
    body = new_mesh(bm, "mug", mat, smooth=False)
    body.location = (0.0, 0.0, 0.011)
    handle = tube([(0.014, 0.0, 0.008), (0.021, 0.0, 0.011), (0.021, 0.0, 0.016), (0.014, 0.0, 0.018)], 0.0016, 8, "handle", mat)
    tea = simple_mat("tea", (0.30, 0.18, 0.10), roughness=0.15)
    bm2 = bmesh.new()
    bmesh.ops.create_circle(bm2, cap_ends=True, segments=32, radius=0.0122)
    surf = new_mesh(bm2, "tea", tea, smooth=False)
    surf.location = (0.0, 0.0, 0.019)
    return [body, handle, surf]


def obj_snapped_pencil(rng):
    wood = simple_mat("wood", (0.78, 0.62, 0.32), roughness=0.6)
    lead = simple_mat("graphite", (0.20, 0.20, 0.22), roughness=0.35)
    parts = []
    for k, (x, ang) in enumerate(((-0.011, -0.10), (0.013, 0.22))):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.0032, radius2=0.0032, depth=0.020)
        o = new_mesh(bm, f"pencil{k}", wood, smooth=False)
        o.rotation_euler = (0.0, math.radians(90), ang)
        o.location = (x, 0.001 * k, 0.0032)
        parts.append(o)
    tip = tube([(0.003, 0.0006, 0.0032), (0.0075, 0.0012, 0.0032)], 0.0009, 6, "lead", lead)
    parts.append(tip)
    return parts


def obj_clover(rng):
    """A clover, picked rather than drawn: three leaves that each dish and tilt their own way, on
    a stem that bends where it was pinched off. Light comes through a leaf, so it has thickness
    and scatter rather than being a flat green shape."""
    mat = simple_mat("clover", (0.20, 0.34, 0.14), roughness=0.62)
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Subsurface Weight"].default_value = 0.45
    b.inputs["Subsurface Radius"].default_value = (0.0016, 0.0034, 0.0012)
    b.inputs["Sheen Weight"].default_value = 0.25
    parts = []
    for k in range(3):
        a = 2 * math.pi * k / 3 + float(rng.uniform(-0.25, 0.25))
        dish = float(rng.uniform(0.0016, 0.0032))
        bm = sheet(0.011, 0.013, 18, 18,
                   lambda u, v, d=dish: d * (((u - 0.5) * 2) ** 2 + ((v - 0.35) * 1.6) ** 2))
        kill = [v for v in bm.verts
                if ((v.co.x / 0.011) ** 2 + ((v.co.y / 0.013) - 0.15) ** 2) > 0.26]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        # the crease down the middle of a leaf, and the notch at its tip
        for v in bm.verts:
            v.co.z += 0.0009 * math.exp(-((v.co.x / 0.0016) ** 2))
            if v.co.y > 0.0045 and abs(v.co.x) < 0.0011:
                v.co.y -= 0.0012 * (1 - abs(v.co.x) / 0.0011)
        o = solidify(new_mesh(bm, f"leaf{k}", mat), t=0.00010)
        o.rotation_euler = (float(rng.uniform(-0.30, -0.10)), float(rng.uniform(-0.15, 0.15)), a)
        o.location = (0.006 * math.cos(a), 0.006 * math.sin(a), 0.0004)
        parts.append(o)
    stem = tube([(0.0, 0.0, 0.0004), (-0.002, -0.007, 0.0012), (-0.005, -0.014, 0.0004)],
                0.00042, 7, "stem", mat)
    parts.append(stem)
    return parts


def obj_coffee_ring(rng):
    card = paper_mat("ring_card", (0.94, 0.92, 0.87))
    bm = sheet(0.040, 0.030, 30, 24, lambda u, v: 0.0006 * math.sin(u * 5 + v * 3))
    base = solidify(new_mesh(bm, "ring_card", card))
    stain = simple_mat("stain", (0.52, 0.36, 0.22), roughness=0.7)
    bm2 = bmesh.new()
    bmesh.ops.create_circle(bm2, cap_ends=False, segments=48, radius=0.011)
    ring = tube([(0.011 * math.cos(2 * math.pi * k / 48), 0.011 * math.sin(2 * math.pi * k / 48), 0.00016) for k in range(49)],
                0.0009, 6, "ring", stain)
    bm2.free()
    return [base, ring]


OBJECTS = {
    "obj_pinch": obj_pinch, "obj_crane": obj_crane, "obj_boat": obj_boat, "obj_plane": obj_plane,
    "obj_fortune_teller": obj_fortune_teller, "obj_crown": obj_crown, "obj_blanket_fold": obj_blanket_fold,
    "obj_crumple_ball": obj_crumple_ball, "obj_torn_corner": obj_torn_corner, "obj_ticket": obj_ticket,
    "obj_plaster": obj_plaster, "obj_gold_star": obj_gold_star, "obj_confetti": obj_confetti,
    "obj_ribbon": obj_ribbon, "obj_string_loop": obj_string_loop, "obj_knot": obj_knot,
    "obj_rubber_band": obj_rubber_band, "obj_staple_chain": obj_staple_chain, "obj_spitball": obj_spitball,
    "obj_stone": obj_stone, "obj_candle": obj_candle, "obj_mug": obj_mug,
    "obj_snapped_pencil": obj_snapped_pencil, "obj_clover": obj_clover, "obj_coffee_ring": obj_coffee_ring,
}


def render_object(name, res, samples, out_dir, conditions=("day", "dusk")):
    rng = np.random.default_rng(20260903 + abs(hash(name)) % 997)
    written = []
    for condition in conditions:
        for pass_kind in ("object", "shadow"):
            if pass_kind == "object" and condition != "day":
                continue
            scene = common.reset_scene()
            made = OBJECTS[name](rng)
            objs = made if isinstance(made, list) else [made]
            if pass_kind == "shadow":
                common.add_shadow_catcher(scene, size_m=0.20)
                for o in objs:
                    o.visible_camera = False
            # a shallow angle, the way a note lies on a desk in front of you: an object seen from
            # straight above reads as a silhouette, and these have to read as things
            cam = common.add_top_camera(scene, 0.075, 0.075, ortho=True, tilt_deg=26.0, distance=0.42)
            cam.location = (0.0, -0.42 * math.sin(math.radians(26.0)), 0.42 * math.cos(math.radians(26.0)))
            common.render_settings(scene, res, res, samples=samples, transparent=True, file_format="PNG")
            if condition == "day":
                common.add_daylight(scene)
            else:
                common.add_dusk(scene)
            suffix = {"object": "", "shadow": "_shadow" if condition == "day" else "_shadow_dusk"}[pass_kind]
            path = os.path.join(out_dir, name + suffix + ".png")
            common.render(scene, path)
            if pass_kind == "shadow":
                common.keep_shadow_only(path)
            manifest.record(path, "blender/objects/objects.py", {
                "object": name, "pass": pass_kind, "light": condition, "samples": samples,
                "resolution": [res, res], "frame_mm": 60, "rig": "blender/rig/common.py",
            }, kind=f"feeling_{pass_kind}")
            written.append(path)
    return written


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--res", type=int, default=1200)
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--conditions", default="day,dusk")
    ap.add_argument("--skip-existing", action="store_true")
    a = ap.parse_args(argv)
    names = list(OBJECTS) if a.all else (a.only or [])
    if not names:
        ap.error("--only or --all")
    os.makedirs(a.out, exist_ok=True)
    conditions = [c for c in a.conditions.split(",") if c]
    import time
    for n in names:
        if a.skip_existing and os.path.exists(os.path.join(a.out, n + ".png")):
            print(f"skip {n}")
            continue
        t0 = time.time()
        render_object(n, a.res, a.samples, a.out, conditions)
        print(f"{n} in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
