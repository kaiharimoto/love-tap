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
def paper_mat(name, rgb=(0.94, 0.91, 0.85), tooth=0.9, span_mm=40.0):
    """Paper for a thing that is a few centimetres across, not a sheet that is twenty-one.

    The material's grain is written in UV cycles, and an object's UV spans its own width. A stock
    sheet is 210 mm across, so its 120-cycle mottle is a feature every 1.75 mm; the same number on
    a 40 mm card is a feature every third of a millimetre, and its relief — fibre_scale/3 — is a
    fourteenth of one, which is under a pixel at any density this is rendered at. Measured on a
    plain card in the object rig, 40 px windows of its own surface: 0.91 grey levels of local
    standard deviation, against 2.56 and 4.24 for the two unruled card stocks measured the same
    way, and 0.97 for thermal receipt paper, which is the one deliberately smooth stock in the
    build. Four critics and this builder have read that as a flat slab with a drop shadow, which is
    the brief's own words for a failure of the whole visual concept.

    So the grain is written in millimetres here and converted: an object's paper has the same
    feature size as a sheet's. Measured the same way, that alone takes the card from 0.91 to 1.77,
    and the amplitude — which is a separate knob now, because raising `tooth` also raises a relief
    that is already sub-pixel — takes it to 2.42 at two and a half. That is inside the band the
    unruled stocks measure, which is the only number worth aiming at.
    """
    span = max(8.0, float(span_mm))
    ratio = span / 210.0
    return common.paper_material(name, rgb, tooth=tooth, yellowing=0.18, sheen=0.26,
                                 fibre_scale=1600.0 * ratio,
                                 mottle_scale=ratio,
                                 mottle_amount=2.5)


def simple_mat(name, rgb, roughness=0.5, metallic=0.0, transmission=0.0, ior=1.45, grain=1.0):
    """A material for a small object on a desk.

    Nothing on a desk is one colour. These were flat Principled fills — a patch inside the candle
    measured 0.44 grey levels of variation against 6 for the paper it stands on, which is what
    makes a rendered object read as a CG prop dropped into a photograph. The colour is broken up
    by a fine noise and the roughness by a coarser one, so the light finds something to sit on:
    a wax cylinder is not polished, and a cork is not a smooth brown pill.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    b = tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Metallic"].default_value = metallic
    b.inputs["IOR"].default_value = ior
    if transmission:
        b.inputs["Transmission Weight"].default_value = transmission
    if grain > 0:
        coords = tree.nodes.new("ShaderNodeTexCoord")
        # the colour: a fine mottle, a few per cent either way
        fine = tree.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 420.0 * grain
        fine.inputs["Detail"].default_value = 6.0
        fine.inputs["Roughness"].default_value = 0.55
        tree.links.new(coords.outputs["Object"], fine.inputs["Vector"])
        mix = tree.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["Factor"].default_value = 0.26 * grain
        mix.inputs[6].default_value = (*rgb, 1.0)
        dark = tuple(max(0.0, c * 0.70) for c in rgb)
        mix.inputs[7].default_value = (*dark, 1.0)
        tree.links.new(fine.outputs["Fac"], mix.inputs["Factor"])
        tree.links.new(mix.outputs[2], b.inputs["Base Color"])
        # the surface: a coarser noise on the roughness, so the highlight is not a clean sweep
        coarse = tree.nodes.new("ShaderNodeTexNoise")
        coarse.inputs["Scale"].default_value = 90.0 * grain
        coarse.inputs["Detail"].default_value = 3.0
        tree.links.new(coords.outputs["Object"], coarse.inputs["Vector"])
        rough = tree.nodes.new("ShaderNodeMapRange")
        rough.inputs["From Min"].default_value = 0.0
        rough.inputs["From Max"].default_value = 1.0
        rough.inputs["To Min"].default_value = max(0.05, roughness - 0.24)
        rough.inputs["To Max"].default_value = min(1.0, roughness + 0.24)
        tree.links.new(coarse.outputs["Fac"], rough.inputs["Value"])
        tree.links.new(rough.outputs["Result"], b.inputs["Roughness"])
        # and a hair of relief, so an edge is not a mathematical edge
        bump = tree.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.22 * grain
        bump.inputs["Distance"].default_value = 0.0004
        tree.links.new(fine.outputs["Fac"], bump.inputs["Height"])
        tree.links.new(bump.outputs["Normal"], b.inputs["Normal"])
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

    def peak_at(u):
        return math.exp(-(abs(u - 0.5) / 0.10) ** 2)

    def warp(u, v):
        # u runs along the strip. The pinch is at the middle: the paper stands between the two
        # creases and settles away either side. It used to be a 7.5 mm bump over 4 mm of a 52 mm
        # strip — four millimetres of gesture on a slab — so it is wider and deeper now, and the
        # ends lift off the desk the way a pinched strip does.
        d = abs(u - 0.5)
        peak = peak_at(u)
        pleat = 0.0034 * math.cos((v - 0.5) * math.pi * 3.0) * peak
        settle = 0.0013 * math.exp(-((d - 0.24) / 0.12) ** 2)
        ends = 0.0022 * max(0.0, (d - 0.34) / 0.16) ** 2
        return 0.0105 * peak + pleat + settle + ends
    bm = sheet(L, W, 90, 34, warp)
    # and the strip necks in where the fingers were: the two creases converge in plan, so the
    # waist is in the silhouette and not only in the shading. A left-to-right measurement of a
    # strip with a bump on it reads a slab; a waisted one reads a pinch.
    for v in bm.verts:
        u = v.co.x / L + 0.5
        v.co.y *= 1.0 - 0.42 * peak_at(u)
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
    """Here: a folded paper boat, and what makes it one is its plan silhouette — pointed at the
    prow and at the stern, flaring out amidships. It used to be a rectangular dish with a square
    card standing in it called a sail, which a critic read, correctly, as a grey open box: box IoU
    0.902 against its own minimum-area rectangle, and a folded paper boat has no sail. The hull is
    double-ended now and the two gunwales are the folded triangles that stand up from it."""
    mat = paper_mat("boat_paper", (0.94, 0.92, 0.86))
    parts = []
    L, B = 0.038, 0.019
    # the hull, narrowing to a point at each end: the half-width is a smooth function of x
    def plan(u):
        return (math.sin(math.pi * u) ** 0.7)

    bm = bmesh.new()
    nx, ny = 30, 12
    verts = {}
    for i in range(nx + 1):
        u = i / nx
        half = B * 0.5 * plan(u)
        for j in range(ny + 1):
            v = j / ny
            y = (v - 0.5) * 2 * half
            # A folded paper boat is two peaks with a hollow between them: the prow and the stern
            # rise to a point and the middle sits low and open. The sides come up as gunwales.
            z = (0.0045 * (abs(v - 0.5) * 2) ** 1.6
                 + 0.0130 * (abs(u - 0.5) * 2) ** 3.0
                 - 0.0018 * math.sin(math.pi * u) ** 2)
            verts[(i, j)] = bm.verts.new(((u - 0.5) * L, y, z))
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]))
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            c = loop.vert.co
            loop[uv].uv = (c.x / L + 0.5, c.y / B + 0.5)
    parts.append(solidify(new_mesh(bm, "boat_hull", mat)))
    # and the folded flap that runs along each side, turned down over the gunwale — the crease
    # that is the whole of how a paper boat is made
    for sign in (1, -1):
        parts.append(_poly([
            (-L * 0.34, B * 0.28 * sign, 0.0072),
            (0.0, B * 0.47 * sign, 0.0040),
            (L * 0.34, B * 0.28 * sign, 0.0072),
            (0.0, B * 0.30 * sign, 0.0068),
        ], f"boat_flap{sign}", mat))
    return parts


def obj_plane(rng):
    """Catch: a paper dart. What makes it one is the planform — a point at the nose and a trailing
    edge swept back to two tips — and it had none: two constant-chord rectangular wings at
    y = +/-8 mm, whose union in plan is a 40 by 31 mm rectangle. It measured a silhouette IoU of
    0.995 against its own minimum-area rectangle, the highest number in the library and half a per
    cent off a literal rectangle. Every panel here is planar, so the creases are real edges."""
    mat = paper_mat("plane_paper", (0.95, 0.94, 0.90))
    parts = []
    nose, tail = 0.024, -0.018
    # the keel: the fold down the middle, standing up, nose to tail
    parts.append(_poly([
        (nose, 0.0, 0.0015),
        (tail, 0.0, 0.0015),
        (tail, 0.0, 0.0085),
        (nose * 0.35, 0.0, 0.0075),
    ], "plane_keel", mat))
    for sign in (1, -1):
        # the wing: a swept triangle from the nose back to a tip, with the trailing edge raked
        parts.append(_poly([
            (nose, 0.0, 0.0035),
            (tail, 0.0125 * sign, 0.0015),
            (tail * 0.55, 0.0035 * sign, 0.0030),
        ], f"plane_wing{sign}", mat))
        # and the winglet the fold leaves standing at the tip
        parts.append(_poly([
            (tail, 0.0125 * sign, 0.0015),
            (tail * 0.35, 0.0072 * sign, 0.0026),
            (tail, 0.0110 * sign, 0.0062),
        ], f"plane_tip{sign}", mat))
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


def obj_confetti(rng):
    """Delight: paper punched and cut, lying where it fell.

    It was fourteen discs of one size in two colours, and a critic read them as sugared almonds —
    round, pastel, all alike, and flat enough that no light gets into them. Confetti off a desk is
    what a hole punch and a pair of scissors leave: circles, squares, and thin strips, in the
    colours of whatever paper was to hand, and half of it lands curled rather than flat, which is
    the half the light finds.
    """
    stocks = [
        paper_mat("conf_a", (0.90, 0.58, 0.62)),
        paper_mat("conf_b", (0.78, 0.85, 0.55)),
        paper_mat("conf_c", (0.58, 0.74, 0.86)),
        paper_mat("conf_d", (0.94, 0.82, 0.44)),
        paper_mat("conf_e", (0.90, 0.87, 0.82)),
    ]
    parts = []
    r = np.random.default_rng(41)
    for k in range(17):
        mat = stocks[k % len(stocks)]
        shape = k % 3
        curl = float(r.uniform(0.0, 1.0)) < 0.45
        if shape == 0:
            # punched out of a page
            bm = bmesh.new()
            bmesh.ops.create_circle(bm, cap_ends=True, segments=14, radius=float(r.uniform(0.0016, 0.0024)))
            o = solidify(new_mesh(bm, f"conf{k}", mat, smooth=False), t=0.00010)
        else:
            # cut with scissors: a square, or a strip off the edge
            w = float(r.uniform(0.0026, 0.0042)) if shape == 1 else float(r.uniform(0.0060, 0.0090))
            h = float(r.uniform(0.0024, 0.0038)) if shape == 1 else float(r.uniform(0.0012, 0.0018))
            bend = float(r.uniform(0.0006, 0.0013)) if curl else 0.0
            o = solidify(
                new_mesh(
                    sheet(w, h, 10, 6, lambda u, v, b=bend: b * math.sin(u * math.pi) * (1.0 - 0.4 * v)),
                    f"conf{k}", mat, smooth=False),
                t=0.00010)
        o.location = (
            float(r.uniform(-0.013, 0.013)),
            float(r.uniform(-0.011, 0.011)),
            float(r.uniform(0.0, 0.0006)),
        )
        # a piece that landed on an edge stands a little off the desk; a flat one lies down
        tip = float(r.uniform(0.5, 1.1)) if curl else float(r.uniform(-0.25, 0.25))
        o.rotation_euler = (tip, float(r.uniform(-0.3, 0.3)), float(r.uniform(0, 3.14)))
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
    """Hold: a candle stub that has been burning. It was a twenty-millimetre untapered cylinder
    with a speck on top — an ellipse IoU of 0.948 and a mean saturation of 0.113, which is to say
    a grey cylinder the caption had to rescue. What makes a stub a stub is what the flame did to
    it: a melted rim that has run down one side, a hollow round the wick, and the burnt ring.

    Its wax also carried 25 per cent transmission, which washed the body from behind and took more
    than half of what little gradient it had; wax that thick is not translucent, and the light on
    it should come off its surface."""
    wax = simple_mat("wax", (0.93, 0.88, 0.72), roughness=0.42)
    wick = simple_mat("wick", (0.10, 0.09, 0.08), roughness=0.95)
    R, H = 0.0102, 0.019
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=40, radius1=R, radius2=R * 0.94, depth=H)
    r = np.random.default_rng(21)
    lip = r.uniform(0, 2 * math.pi)
    for v in bm.verts:
        x, y, z = v.co
        rr = math.hypot(x, y)
        if z < H * 0.4:
            continue
        a = math.atan2(y, x)
        # the rim has melted: it dips on the side the flame leaned, and scallops all the way round
        dip = 0.0042 * (0.5 + 0.5 * math.cos(a - lip)) ** 1.6
        scallop = 0.0007 * math.sin(3.7 * a + 1.1) + 0.0005 * math.sin(6.3 * a)
        # and the middle of the top is hollow, burnt down round the wick
        hollow = 0.0034 * max(0.0, 1.0 - (rr / (R * 0.66)) ** 2) if rr < R * 0.66 else 0.0
        v.co = (x, y, z - (dip + scallop + hollow) * (z / (H * 0.5)))
    # flat-shaded: the scallops the flame left are facets, and smoothing them turned the
    # stub into an egg
    body = new_mesh(bm, "candle", wax, smooth=False)
    body.location = (0.0, 0.0, H * 0.5)
    parts = [body]
    # the runnel the wax made coming down the low side
    run = tube([
        (R * 0.97 * math.cos(lip), R * 0.97 * math.sin(lip), H - 0.0045),
        (R * 1.00 * math.cos(lip), R * 1.00 * math.sin(lip), H * 0.55),
        (R * 0.96 * math.cos(lip), R * 0.96 * math.sin(lip), H * 0.24),
    ], 0.0013, 8, "runnel", wax)
    parts.append(run)
    # the burnt ring in the wax, and the wick leaning out of it
    ring = bmesh.new()
    bmesh.ops.create_cone(ring, cap_ends=True, segments=24, radius1=0.0028, radius2=0.0026,
                          depth=0.0006)
    burnt = new_mesh(ring, "burnt", wick, smooth=False)
    burnt.location = (0.0, 0.0, H - 0.0038)
    parts.append(burnt)
    parts.append(tube([(0.0, 0.0, H - 0.0028), (0.0011, 0.0004, H + 0.0032)], 0.0006, 6,
                      "wick", wick))
    return parts


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


# ------------------------------------------------------------------ things, not symbols
# The five below replace marks that read as the standard emoji set to a fresh eye — a sun with rays,
# a crescent moon, a tongue-out face, rain, a firework — and two that read as prizes: a gold star
# and a crown. Drawing an emoji by hand does not stop it being the emoji, and a badge is a badge
# whatever it is made of. Each of these is a thing that would be on a desk between two people.


def obj_bookmark(rng):
    """Thinking of you: a strip torn for a bookmark, one end folded over on itself, lying where it
    fell out of the book. The fold is the sign somebody's thumb was on it."""
    mat = paper_mat("bookmark_paper", (0.93, 0.89, 0.78), tooth=1.1)
    L, W = 0.058, 0.016
    parts = []
    # Two pieces with a rounded spine between them, not one smoothed sheet. Folding it as a single
    # warped grid made a flat ramp and took the fold away entirely — 2.3 grey levels of internal
    # contrast against 4.3 for the two slabs it replaced, which is the wrong direction. What a fold
    # actually is, is a step with a spine on it.
    # It has to be curled, not laid flat. Under the day rig — soft light from one window, an
    # orthographic camera — a plane has one normal and therefore one value, and this was two plates
    # 0.4 mm proud of each other: patch_std 0.913 against a floor of 2.0, the flattest thing in the
    # library. A strip that has been in a book and fallen out of it is bowed, and the end that is
    # not weighed down by the fold is the end that lifts. Three millimetres over fifty-eight is a
    # curl a hand would not remark on and a light rakes right across.
    def bow(u, v):
        lift = 0.0030 * (1.0 - u) ** 2.2                    # the torn head, off the desk
        trough = 0.0005 * (1.0 - math.cos((v - 0.5) * 2.6))  # and the strip cupped across itself
        return lift + trough + 0.00025 * math.sin(u * 9.0)
    body = sheet(L * 0.66, W, 48, 18, bow)
    # and the head it was torn from the sheet at: ragged, which is the one silhouette a bookmark
    # has, and it was a clean rectangle
    for v in body.verts:
        u = v.co.x / (L * 0.66) + 0.5
        if u < 0.05:
            v.co.x -= 0.0012 * abs(math.sin(v.co.y * 900.0)) + 0.0006 * abs(math.sin(v.co.y * 2400.0))
            v.co.z += 0.00025 * math.sin(v.co.y * 1500.0)
    b = solidify(new_mesh(body, "bookmark", mat))
    b.location = (-L * 0.17, 0.0, 0.0)
    parts.append(b)
    # the folded end: a second piece hinged at the body's end, laid back over it, thickness apart
    flap = sheet(L * 0.34, W * 0.96, 24, 12, lambda u, v: 0.0)
    f = solidify(new_mesh(flap, "bookmark_flap", mat))
    f.location = (L * 0.16, 0.0, PAPER_T * 2.2)
    f.rotation_euler = (0.0, math.radians(-3.5), math.radians(float(rng.uniform(-2.5, 2.5))))
    parts.append(f)
    # the spine of the crease: a half-round running across the strip where the paper turns back,
    # so the fold catches a highlight instead of ending in a butt edge
    spine = tube([(L * 0.335, -W * 0.48, PAPER_T * 1.1), (L * 0.335, W * 0.48, PAPER_T * 1.1)],
                 PAPER_T * 1.15, 8, "bookmark_spine", mat)
    parts.append(spine)
    for part in parts:
        part.rotation_euler[2] += math.radians(float(rng.uniform(-14, 14)))
    return parts


def obj_dog_ear(rng):
    """Goodnight: a card with its corner turned down — the way a page is marked where you stopped
    reading for the night. Nothing on it; the fold is the whole object."""
    mat = paper_mat("dogear_card", (0.95, 0.93, 0.87), tooth=0.95)
    W, H = 0.040, 0.030
    card = sheet(W, H, 40, 30, lambda u, v: 0.0003 * math.sin(u * 3 + v * 2))
    # A page, not a blank. Four per cent of the object carried all of its identity and the other
    # ninety-six was a rectangle of the same near-white paper — box IoU 0.946. The left edge is the
    # edge it was torn from the book at, which is the one silhouette feature a page has.
    for v in card.verts:
        u = v.co.x / W + 0.5
        if u < 0.04:
            v.co.x += 0.0013 * math.sin(v.co.y * 900.0) + 0.0007 * math.sin(v.co.y * 2400.0)
            v.co.z += 0.00025 * math.sin(v.co.y * 1500.0)
    parts = [solidify(new_mesh(card, "dogear_card", mat), t=0.00024)]
    # the corner: a triangle folded down over the card, its free tip lifted a millimetre off it so
    # it throws a triangle of its own shadow — which is the cue that says turned down rather than
    # printed on
    bm = bmesh.new()
    d = 0.013
    vs = [bm.verts.new((W / 2 - d, H / 2, PAPER_T * 2.4)),
          bm.verts.new((W / 2, H / 2 - d, PAPER_T * 2.4)),
          bm.verts.new((W / 2 - d * 0.92, H / 2 - d * 0.92, PAPER_T * 2.4 + 0.0016))]
    bm.faces.new(vs)
    ear = solidify(new_mesh(bm, "dogear_flap", mat, smooth=False), t=0.00024)
    parts.append(ear)
    for part in parts:
        part.rotation_euler = (0.0, 0.0, math.radians(float(rng.uniform(-18, 18))))
    return parts


def obj_wrapper(rng):
    """Nyeh: a sweet in its wrapper, wrung at both ends, of the kind that is unwrapped very slowly
    in front of somebody who wants one.

    Two goes at this. It was a tapered tube — fat in the middle, pinched at the ends, glossy — and
    a critic read it as a stuck-out tongue, which it was. The first rebuild flattened it and put
    creases round it, and the render came back a pale pink blob: 16 per cent of a 6 mm radius is a
    ripple a millimetre deep under a soft light, which is nothing, and the ends still closed to a
    rounded point rather than a twist.

    What actually says wrapper is the shape of the ends. The paper is gathered and wrung, so each
    end is a narrow throat that flares open again into a little fan, and the creases run out of the
    body into that throat and turn with it. So: a pouch in the middle with deep folds down it, a
    wrung throat at each end, and a fan beyond it. The empty version — the paper on the desk after
    the sweet is gone — is flatter and reads better as rubbish than as a thing one of them would
    send the other, so this one still has the sweet in it.
    """
    mat = simple_mat("wrapper", (0.90, 0.55, 0.60), roughness=0.50, transmission=0.10, ior=1.35)
    nu, nv = 84, 26
    length = 0.050
    bm = bmesh.new()
    verts = {}
    for j in range(nv):
        for i in range(nu + 1):
            u = i / nu
            th0 = 2.0 * math.pi * j / nv
            # how far into the body we are: 1 in the middle, 0 at the throats
            d = abs(u - 0.5) * 2.0            # 0 at the centre, 1 at the ends
            body = max(0.0, 1.0 - (d / 0.62) ** 2.2)
            # the fan past the throat: it opens again in the last twelfth
            fan = max(0.0, (d - 0.80) / 0.20) ** 1.4
            rad = 0.00055 + 0.0070 * body + 0.0032 * fan
            # the folds: deep in the body, deeper still where the paper is gathered
            gather = 1.0 - body
            crease = (1.0
                      + (0.34 + 0.34 * gather) * math.sin(th0 * 6.0)
                      + 0.13 * math.sin(th0 * 3.0 + 1.1)
                      + 0.10 * math.sin(th0 * 13.0 + u * 4.0)
                      + 0.06 * math.sin(u * 17.0))
            rad *= max(0.25, crease)
            # the wring: the folds turn as they leave the body, a couple of turns into each throat
            th = th0 + 5.0 * (u - 0.5) * gather
            x = (u - 0.5) * length
            y = rad * math.cos(th)
            # flattened, because there is nothing inside it any more
            z = 0.0010 + rad * 0.42 * math.sin(th) + 0.0008 * math.sin(u * math.pi * 3.0)
            verts[(i, j)] = bm.verts.new((x, y, z))
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((
                verts[(i, j)], verts[(i + 1, j)],
                verts[(i + 1, (j + 1) % nv)], verts[(i, (j + 1) % nv)],
            ))
    obj = solidify(new_mesh(bm, "wrapper", mat, smooth=True), t=0.00008)
    obj.rotation_euler = (0.0, 0.0, math.radians(float(rng.uniform(-25, 25))))
    return [obj]


def obj_pencil_smudge(rng):
    """Grey: a graphite smudge on a scrap — the side of a hand dragged through pencil, which is
    what a grey day leaves on the page."""
    card = paper_mat("smudge_card", (0.92, 0.91, 0.87), tooth=1.0)
    parts = [solidify(new_mesh(sheet(0.036, 0.028, 30, 24, lambda u, v: 0.0003 * math.sin(u * 4 + v * 3)),
                                "smudge_card", card))]
    graphite = simple_mat("graphite_smear", (0.30, 0.30, 0.31), roughness=0.55, metallic=0.25)
    # the smear: a soft-edged streak, thicker where the hand came down and fading where it left
    bm = bmesh.new()
    verts = {}
    nx, ny = 30, 10
    for j in range(ny + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x = (u - 0.5) * 0.026 + 0.004 * math.sin(v * 3.1)
            y = (v - 0.5) * 0.007 * (0.5 + 0.5 * math.sin(u * math.pi)) - 0.002
            verts[(i, j)] = bm.verts.new((x, y, PAPER_T * 1.6))
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]))
    smear = new_mesh(bm, "smear", graphite)
    parts.append(smear)
    for part in parts:
        part.rotation_euler = (0.0, 0.0, math.radians(float(rng.uniform(-12, 12))))
    return parts


def obj_bunting(rng):
    """Yes: three triangles of bunting on a length of thread, the string sagging between them,
    left on the desk from something worth putting up for."""
    thread = simple_mat("bunting_thread", (0.55, 0.50, 0.42), roughness=0.9)
    colours = [(0.94, 0.66, 0.72), (0.74, 0.85, 0.90), (0.95, 0.88, 0.55)]
    pts = [((t - 0.5) * 0.062, 0.006 * math.sin(t * math.pi * 1.0) - 0.003, 0.0007 + 0.001 * math.sin(t * math.pi))
           for t in [k / 24 for k in range(25)]]
    parts = [tube(pts, 0.00035, 6, "bunting_thread", thread)]
    for k in range(3):
        t = 0.2 + 0.3 * k
        cx = (t - 0.5) * 0.062
        cy = 0.006 * math.sin(t * math.pi) - 0.003
        mat = paper_mat(f"bunting_{k}", colours[k], tooth=0.9)
        bm = bmesh.new()
        w, h = 0.012, 0.015
        lean = float(rng.uniform(-0.004, 0.004))
        vs = [bm.verts.new((cx - w / 2, cy, 0.0005)), bm.verts.new((cx + w / 2, cy, 0.0005)),
              bm.verts.new((cx + lean, cy - h, 0.0002))]
        bm.faces.new(vs)
        parts.append(solidify(new_mesh(bm, f"bunting_flag_{k}", mat, smooth=False), t=0.00018))
    return parts


def obj_cork(rng):
    """Did it: a cork, out of the bottle and on its side, with the pull-marks of the corkscrew in
    its top. Not a prize: the thing left over from having opened something."""
    mat = simple_mat("cork", (0.76, 0.62, 0.42), roughness=0.92)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=28, radius1=0.0098, radius2=0.0105, depth=0.040)
    for v in bm.verts:
        # a cork is not a lathe part: it is a little dented and a little out of round
        a = math.atan2(v.co.y, v.co.x)
        r = 1.0 + 0.03 * math.sin(a * 3 + v.co.z * 90) + 0.02 * math.sin(a * 7)
        v.co.x *= r
        v.co.y *= r
    cork = new_mesh(bm, "cork", mat)
    cork.rotation_euler = (math.radians(90.0), 0.0, math.radians(float(rng.uniform(-30, 30))))
    cork.location = (0.0, 0.0, 0.0102)
    # the corkscrew's hole, a dark pit in the end
    pit = simple_mat("cork_pit", (0.28, 0.20, 0.12), roughness=0.95)
    bm2 = bmesh.new()
    bmesh.ops.create_cone(bm2, cap_ends=True, segments=12, radius1=0.0016, radius2=0.0024, depth=0.006)
    hole = new_mesh(bm2, "cork_pit", pit)
    hole.rotation_euler = (math.radians(90.0), 0.0, cork.rotation_euler[2])
    dx = 0.0195 * math.cos(cork.rotation_euler[2] + math.pi / 2)
    dy = 0.0195 * math.sin(cork.rotation_euler[2] + math.pi / 2)
    hole.location = (dx, dy, 0.0102)
    return [cork, hole]


def obj_party_hat(rng):
    """A paper hat out of a cracker, lying on its side: the tissue crown nobody wears for more
    than a minute. A cone of thin paper with a torn seam, not a ring of points."""
    mat = paper_mat("party_hat", (0.92, 0.72, 0.36), tooth=0.8)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=36, radius1=0.019, radius2=0.0012, depth=0.036)
    for v in bm.verts:
        # crumpled a little from being in the cracker
        v.co.x *= 1.0 + 0.02 * math.sin(v.co.z * 400 + v.co.y * 300)
        v.co.y *= 1.0 + 0.02 * math.cos(v.co.z * 350)
    hat = solidify(new_mesh(bm, "party_hat", mat), t=0.00012)
    hat.rotation_euler = (math.radians(80.0), 0.0, math.radians(float(rng.uniform(-40, 40))))
    hat.location = (0.0, 0.0, 0.0112)
    return [hat]


def obj_user_soup(rng):
    """tuesday soup, the feeling Teo made: the ring a bowl left on the recipe card, with a drip
    where it was put down too fast. The same idea as the coffee ring, in soup."""
    card = paper_mat("soup_card", (0.95, 0.92, 0.84))
    bm = sheet(0.044, 0.034, 30, 24, lambda u, v: 0.0005 * math.sin(u * 4 + v * 3))
    base = solidify(new_mesh(bm, "soup_card", card))
    # a stain is flat and dull: the first render had the ring as a glossy tube standing off the
    # card, and it read as a rubber ring lying on it rather than as something that had dried there
    stain = simple_mat("soup_stain", (0.60, 0.31, 0.11), roughness=0.9)
    ring = tube([(0.0135 * math.cos(2 * math.pi * k / 56) * 1.05, 0.0135 * math.sin(2 * math.pi * k / 56), 0.00012)
                 for k in range(57)], 0.0013, 6, "soup_ring", stain)
    ring.scale = (1.0, 1.0, 0.12)
    drip = tube([(0.0135 * 1.05 + 0.0005 * k, -0.002 - 0.0016 * k, 0.00012) for k in range(5)],
                0.0010, 6, "soup_drip", stain, taper=lambda t: 1.0 - 0.6 * t)
    drip.scale = (1.0, 1.0, 0.12)
    return [base, ring, drip]


OBJECTS = {
    "obj_pinch": obj_pinch, "obj_crane": obj_crane, "obj_boat": obj_boat, "obj_plane": obj_plane,
    "obj_fortune_teller": obj_fortune_teller, "obj_blanket_fold": obj_blanket_fold,
    "obj_crumple_ball": obj_crumple_ball, "obj_torn_corner": obj_torn_corner, "obj_ticket": obj_ticket,
    "obj_plaster": obj_plaster, "obj_confetti": obj_confetti,
    "obj_ribbon": obj_ribbon, "obj_string_loop": obj_string_loop, "obj_knot": obj_knot,
    "obj_rubber_band": obj_rubber_band, "obj_staple_chain": obj_staple_chain, "obj_spitball": obj_spitball,
    "obj_stone": obj_stone, "obj_candle": obj_candle, "obj_mug": obj_mug,
    "obj_snapped_pencil": obj_snapped_pencil, "obj_clover": obj_clover, "obj_coffee_ring": obj_coffee_ring,
    "obj_bookmark": obj_bookmark, "obj_dog_ear": obj_dog_ear, "obj_wrapper": obj_wrapper,
    "obj_pencil_smudge": obj_pencil_smudge, "obj_bunting": obj_bunting, "obj_cork": obj_cork,
    "obj_party_hat": obj_party_hat, "obj_user_soup": obj_user_soup,
}


def render_object(name, res, samples, out_dir, conditions=("day", "dusk")):
    rng = np.random.default_rng(20260903 + abs(hash(name)) % 997)
    written = []
    for condition in conditions:
        for pass_kind in ("object", "shadow"):
            scene = common.reset_scene()
            made = OBJECTS[name](rng)
            objs = made if isinstance(made, list) else [made]
            if pass_kind == "shadow":
                common.add_shadow_catcher(scene, size_m=0.20)
                for o in objs:
                    o.visible_camera = False
            else:
                # The object is on a desk, so the desk has to be in the beauty pass — invisible to
                # the camera, so the cut-out and its alpha are unchanged, but present to the light.
                # Without it the object was rendered in an empty scene, which is the one place a
                # thing on a desk never is.
                #
                # It goes under the object rather than at z=0. These objects are modelled centred
                # on the origin rather than seated on it: twenty-five of the thirty-three have
                # geometry below zero, crumple_ball by 22.1 mm, so a plane at z=0 buries their lower
                # half in its own shadow and rules a hard horizontal line across them — which a
                # left-to-right measurement reads as a gradient, and which would have been the worst
                # kind of fix: one that moves the number by breaking the picture. Two millimetres
                # under the lowest vertex the object actually has, measured after modifiers.
                #
                # Measured, on a 20 mm diffuse cylinder at this tilt, quarters of the camera-facing
                # wall, left to right: no ground +6.7 grey levels of swing, this desk +12.6, the
                # white shadow catcher +17.4. It roughly doubles a small gradient; it does not
                # create one. And most of what it buys is not bounce — splitting the passes, the
                # sky-only term stays flat and only dims, so the ground is mostly occluding the
                # lower half of a constant sky and taking the flat wash off. The sun is about a
                # fifth of that wall's light and all of its gradient. Halving DAY_SKY_STRENGTH
                # would buy the same +9.3 with no ground at all — but that changes every family in
                # the library at once, and this does not.
                #
                # What it cannot do is put a gradient on a plane: a flat-lying ticket or a
                # coffee ring has one normal, and one normal under a distant sun and an
                # orthographic camera has one value. Those read flat because of their geometry.
                common.add_desk(scene, size_m=0.20,
                                z=common.lowest_z(objs) - 0.002).visible_camera = False
            # a shallow angle, the way a note lies on a desk in front of you: an object seen from
            # straight above reads as a silhouette, and these have to read as things
            cam = common.add_top_camera(scene, 0.075, 0.075, ortho=True, tilt_deg=26.0, distance=0.42)
            cam.location = (0.0, -0.42 * math.sin(math.radians(26.0)), 0.42 * math.cos(math.radians(26.0)))
            common.render_settings(scene, res, res, samples=samples, transparent=True, file_format="PNG")
            if condition == "day":
                common.add_daylight(scene)
            else:
                common.add_dusk(scene)
                # the same aperture everything else lit at dusk is shot at, or the object is the
                # one thing on the desk that did not stop down
                common.stop_down_for_dusk(scene)
            # The object used to be rendered under daylight only, and drawn under both. A
            # completeness pass measured it: under the dusk light the paper beside it shifts
            # thirty to forty levels and warms, and the object shifts eight and does not warm at
            # all — a pre-lit sprite sitting on a photograph. It has its own dusk render now.
            suffix = {
                ("object", "day"): "",
                ("object", "dusk"): "_dusk",
                ("shadow", "day"): "_shadow",
                ("shadow", "dusk"): "_shadow_dusk",
            }[(pass_kind, condition)]
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
