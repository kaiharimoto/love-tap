"""blender/shell/desk.py — the desk the paper lies on.

    bash blender/run.sh blender/shell/desk.py -- --res 1400
    bash blender/run.sh blender/shell/desk.py -- --res 1400 --condition dusk

Everything in this app sits on one surface, so the surface has to be a real one: three boards of
waxed oak, each cut from a different part of a different tree, with the joins between them, the
knots, the ring stains where mugs have stood, and the scratches of whatever has been dragged
across it.

The grain is computed at the full resolution of the render as an image and handed to the shader,
rather than being carried by the mesh. The version before this one cut the grain into a mesh of
four hundred divisions and rendered it at eleven hundred pixels, so every ring was interpolated
across three pixels of triangle and the whole desk came out as a flat brown field with a seam in
it. Height still displaces the mesh, because the light has to catch the relief for the wax to
read as wax, but what you see is the picture.

Every field is built from sinusoids whose periods divide the strip exactly, so the strip tiles
top to bottom with no seam, and the stains and scratches are placed away from the edges.
"""
import argparse
import math
import os
import sys
import tempfile

import bpy
import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from rig import common, manifest  # noqa: E402

OUT = os.path.join(common.repo_root(), "assets", "shell")

WIDTH_M = 0.42          # what is framed across the screen
HEIGHT_M = 0.92         # the strip is taller than the tallest screen, and tiles anyway
PLANKS = 3
JOIN_MM = 2.2           # the gap between two boards, and the chamfer either side of it
GRAIN_MM = 0.16         # the relief a wax finish leaves standing: small, and the light finds it
MESH_X, MESH_Y = 300, 660

# Waxed oak, in linear light. Earlywood is the pale open part of a ring, latewood the narrow dark
# band laid down as the season closed; the ratio between them is what makes oak read as oak.
EARLY = np.array([0.163, 0.100, 0.053])
LATE = np.array([0.049, 0.026, 0.013])
RAY = np.array([0.205, 0.138, 0.080])     # the medullary flecks, paler than either


def _periodic(shape, freqs, seed, axis=0):
    """A field made of whole-numbered sinusoids, so it meets itself at the edge."""
    h, w = shape
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, h, endpoint=False)[:, None]
    u = np.linspace(0, 1, w, endpoint=False)[None, :]
    t = v if axis == 0 else u
    out = np.zeros((h, w))
    for k, amp in freqs:
        out = out + amp * np.sin(2 * np.pi * k * t + rng.uniform(0, 2 * np.pi))
    return out


def board_grain(h, w, seed, rings=17.0, cant=0.10):
    """One board, seen face on.

    A flat-sawn board shows the growth rings opened out: they run the length of the board, they
    wander, and where the cut passes near the middle of the log they arch into the cathedral
    figure everyone recognises as wood. Latewood is a narrow dark band, not half of a sine wave,
    so the ring profile is pushed hard toward its dark end.
    """
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, h, endpoint=False)[:, None]      # along the board
    u = np.linspace(0, 1, w, endpoint=False)[None, :]      # across it

    # the wander of the rings along the board, periodic so the strip tiles
    drift = _periodic((h, w), [(1, 0.85), (2, 0.45), (3, 0.22), (5, 0.10)], seed + 1, axis=0)
    # the cathedral: where the saw passed near the middle of the log the rings arch into it, and
    # it happens once or twice down a board rather than repeating like wallpaper
    arch = (np.cos(2 * np.pi * (v * 1 + 0.3)) * cant
            + np.cos(2 * np.pi * (v * 2 + 0.61)) * cant * 0.45)

    across = u + 0.075 * drift + arch
    # Growth rings are not evenly spaced. A tree puts on a wide ring in a good year and a narrow
    # one in a bad year, and the run of good and bad years is what a ring count is read for. Even
    # spacing is corduroy, which is what the first version of this looked like.
    seasons = _periodic((h, w), [(2, 0.5), (3, 0.3), (5, 0.2)], seed + 11, axis=1)
    phase = across * rings + 0.9 * seasons + 0.5 * drift
    ring = 0.5 + 0.5 * np.sin(2 * np.pi * phase)
    # narrow dark bands: most of the face is earlywood
    late = np.clip((ring - 0.66) / 0.34, 0, 1) ** 0.5

    # medullary rays: short pale flecks lying across the rings, the tell of quarter-sawn oak
    fleck = _periodic((h, w), [(37, 0.5), (61, 0.3), (89, 0.2)], seed + 2, axis=1)
    fleck = fleck * _periodic((h, w), [(23, 0.6), (41, 0.4)], seed + 3, axis=0)
    fleck = np.clip(fleck * 1.6 - 0.85, 0, 1)

    # the fibre itself, far finer than a ring
    fibre = _periodic((h, w), [(211, 0.5), (307, 0.3), (419, 0.2)], seed + 4, axis=1) * 0.5
    fibre = fibre * (0.6 + 0.4 * _periodic((h, w), [(7, 1.0)], seed + 5, axis=0))
    return late, fleck, fibre


def knot(h, w, cx, cy, r, seed):
    """A knot is where a branch left the trunk, cut across at an angle.

    It is an ellipse rather than a circle, it leans, and the grain of the board does not stop at
    it: the rings are pushed aside and swept past it on both sides. Concentric circles on their
    own are a target, not a knot.
    """
    rng = np.random.default_rng(seed)
    lean = float(rng.uniform(0, math.pi))
    squash = float(rng.uniform(1.6, 3.0))
    v = np.linspace(0, 1, h, endpoint=False)[:, None]
    u = np.linspace(0, 1, w, endpoint=False)[None, :]
    dy = (v - cy) * (h / w)
    dx = u - cx
    ax = dx * math.cos(lean) + dy * math.sin(lean)
    ay = -dx * math.sin(lean) + dy * math.cos(lean)
    d = np.sqrt((ax * squash) ** 2 + ay ** 2) / r
    core = np.clip(1.0 - d, 0, 1) ** 0.7
    whorl = 0.5 + 0.5 * np.sin(2 * np.pi * (d * float(rng.uniform(4.0, 7.5))
                                            + np.arctan2(ay, ax * squash) * 0.28))
    # how far the surrounding grain is pushed aside, which is what makes it sit in the board
    sweep = np.exp(-((d - 1.0) / 1.4) ** 2) * np.sign(ay) * r * 0.55
    return core, np.clip(core * 1.25, 0, 1) * whorl, sweep


def marks(h, w, seed):
    """What has been done to it: mugs, a compass point, whatever was dragged across."""
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, h, endpoint=False)[:, None]
    u = np.linspace(0, 1, w, endpoint=False)[None, :]
    stain = np.zeros((h, w))
    for _ in range(3):
        cx, cy = rng.uniform(0.12, 0.88), rng.uniform(0.08, 0.92)
        r = rng.uniform(0.055, 0.085)
        d = np.sqrt((u - cx) ** 2 + ((v - cy) * (h / w)) ** 2)
        # a ring stain is a ring, darkest where the drip ran round the base of the mug
        band = np.exp(-((d - r) / (r * 0.10)) ** 2)
        gap = 0.55 + 0.45 * np.sin(np.arctan2(v - cy, u - cx) * 3 + rng.uniform(0, 6))
        stain += band * gap * rng.uniform(0.5, 1.0)
    # Most marks on a desk are almost invisible and a couple are not. Twenty of them at equal
    # strength, evenly spread, read as a pattern of sticks rather than as wear.
    scratch = np.zeros((h, w))
    for _ in range(26):
        x0, y0 = rng.uniform(0.05, 0.95), rng.uniform(0.05, 0.95)
        ang = rng.uniform(0, math.pi)
        length = float(rng.uniform(0.012, 0.10)) ** 1.4 * 2.2
        width = rng.uniform(0.0009, 0.0022)
        strength = float(rng.uniform(0.05, 1.0)) ** 2.2
        along = (u - x0) * math.cos(ang) + (v - y0) * math.sin(ang) * (h / w)
        across = -(u - x0) * math.sin(ang) + (v - y0) * math.cos(ang) * (h / w)
        # a scratch tails off at both ends rather than stopping dead
        taper = np.clip(1.0 - (np.abs(along) / length) ** 2, 0, 1)
        scratch += np.exp(-(across / width) ** 2) * taper * strength
    return np.clip(stain, 0, 1.4), np.clip(scratch, 0, 1)


def desk_maps(w, h, seed):
    """The albedo and the height of the whole top, at the resolution it will be rendered at."""
    albedo = np.zeros((h, w, 3))
    height = np.zeros((h, w))
    rng = np.random.default_rng(seed)
    edges = np.linspace(0, w, PLANKS + 1).astype(int)
    for p in range(PLANKS):
        a, b = edges[p], edges[p + 1]
        bw = b - a
        late, fleck, fibre = board_grain(h, bw, seed + p * 101,
                                         rings=float(rng.uniform(12, 23)),
                                         cant=float(rng.uniform(0.05, 0.16)))
        # each board is off a different tree and has taken the wax differently
        warmth = float(rng.uniform(0.88, 1.14))
        early = EARLY * warmth
        col = early[None, None, :] * (1 - late[..., None]) + LATE[None, None, :] * late[..., None]
        col = col * (1 + 0.10 * fibre[..., None])
        col = col * (1 - 0.55 * fleck[..., None]) + RAY[None, None, :] * 0.55 * fleck[..., None]
        hgt = late * -0.55 + fibre * 0.25 + fleck * 0.1

        for j in range(int(rng.integers(0, 3))):
            core, whorl, _sweep = knot(h, bw, float(rng.uniform(0.2, 0.8)),
                                       float(rng.uniform(0.05, 0.95)),
                                       float(rng.uniform(0.09, 0.20)),
                                       seed + p * 31 + j * 7)
            k = np.clip(core * 0.9 + whorl * 0.5, 0, 1)
            col = col * (1 - k[..., None]) + (LATE * 0.75)[None, None, :] * k[..., None]
            hgt = hgt - k * 0.6
        albedo[:, a:b] = col
        height[:, a:b] = hgt

    # the joins: a dark gap with the arris of each board chamfered down into it
    u = np.linspace(0, 1, w, endpoint=False)[None, :]
    plank_u = (u * PLANKS) % 1.0
    edge = np.minimum(plank_u, 1.0 - plank_u)
    gap_u = (JOIN_MM / 1000.0) / (WIDTH_M / PLANKS)
    join = np.clip(1.0 - edge / gap_u, 0.0, 1.0)
    # each board took the finish differently and one of them is a shade off the others
    for p in range(PLANKS):
        a, b = edges[p], edges[p + 1]
        albedo[:, a:b] *= float(np.random.default_rng(seed + 900 + p).uniform(0.86, 1.12))
    albedo = albedo * (1 - join[..., None] ** 1.2 * 0.92)
    # the chamfer either side of the gap: a couple of millimetres of arris that catches the light
    chamfer = np.clip(1.0 - edge / (gap_u * 2.6), 0.0, 1.0)
    albedo = albedo * (1 - chamfer[..., None] ** 2 * 0.22)
    # A trench five times deeper than the grain, normalised into the same map, leaves the grain
    # in two per cent of the range and no relief on the desk at all. The join is a line; it does
    # not need to be a canyon.
    height = height - join ** 2 * 1.1 - chamfer ** 2 * 0.35

    # the finish has not aged evenly: broad patches a shade darker, larger than any ring
    blotch = (_periodic((h, w), [(1, 0.6), (2, 0.35), (3, 0.2)], seed + 51, axis=0)
              * _periodic((h, w), [(1, 0.7), (2, 0.4)], seed + 52, axis=1))
    albedo = albedo * (1 + 0.10 * blotch[..., None])

    stain, scratch = marks(h, w, seed + 7)
    albedo = albedo * (1 - 0.46 * stain[..., None])
    # a scratch cuts through the wax into raw wood, so it is paler than what is round it
    albedo = albedo * (1 - 0.34 * scratch[..., None]) + 0.62 * scratch[..., None] * RAY
    height = height + scratch * -1.2

    # the dish worn into the middle where forearms have been for years: it takes the light
    # differently rather than being a different colour
    v = np.linspace(0, 1, h, endpoint=False)[:, None]
    wear = np.exp(-(((u - 0.5) / 0.44) ** 2 + ((v - 0.5) / 0.95) ** 2))
    gloss = 0.30 + 0.34 * (1 - wear) + 0.18 * stain + 0.25 * scratch
    return np.clip(albedo, 0, 1), height, np.clip(gloss, 0.10, 0.85)


def _write_png(path, arr):
    """Sixteen-bit through Blender's own writer, which is the only one in this interpreter."""
    h, w = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, axis=2)
    img = bpy.data.images.new(os.path.basename(path), width=w, height=h, alpha=False,
                              float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    flat = np.ones((h, w, 4), dtype=np.float32)
    flat[..., :3] = arr[::-1].astype(np.float32)
    img.pixels.foreach_set(flat.ravel())
    img.filepath_raw = path
    img.file_format = "OPEN_EXR"
    img.save()
    return img


def build_top(seed, w, h, tmp):
    albedo, height, gloss = desk_maps(w, h, seed)
    a_img = _write_png(os.path.join(tmp, "desk_albedo.exr"), albedo)
    # normalised on percentiles, so one deep join does not squash the grain into nothing
    lo, hi = np.percentile(height, 0.5), np.percentile(height, 99.5)
    h_img = _write_png(os.path.join(tmp, "desk_height.exr"),
                       np.clip((height - lo) / (hi - lo + 1e-9), 0.0, 1.0))
    g_img = _write_png(os.path.join(tmp, "desk_gloss.exr"), gloss)

    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=MESH_X, y_segments=MESH_Y, size=0.5)
    mesh = bpy.data.meshes.new("desk_top")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("desk_top", mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.scale = (WIDTH_M, HEIGHT_M, 1.0)
    bpy.context.view_layer.objects.active = obj
    # Selected, not merely active. transform_apply acts on selected_editable_objects, and an object
    # made with bpy.data.objects.new() and linked into a collection is active and *not* selected —
    # so the operator returned {'CANCELLED'}, the scale stayed on the object, and the vertices below
    # were still the unit grid's +/-0.5 rather than metres. Dividing +/-0.5 by 0.42 gave a u span of
    # 2.381 against a texture set to REPEAT, so the whole three-plank desk was tiled two and a third
    # times across its own top: a tiled repeating texture, which the brief names as a failure of the
    # entire visual concept. The generator was always right; one unselected object undid it.
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for p in mesh.polygons:
        p.use_smooth = True
    mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers[0]
    us, vs = [], []
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        u, v = co.x / WIDTH_M + 0.5, co.y / HEIGHT_M + 0.5
        uv.data[loop.index].uv = (u, v)
        us.append(u)
        vs.append(v)
    # The desk covers its own map exactly once, in both directions, or it is tiled. Checked here
    # rather than found later in a photograph of it.
    for name, vals in (("u", us), ("v", vs)):
        span = max(vals) - min(vals)
        if abs(span - 1.0) > 1e-6:
            raise SystemExit(
                f"desk.py: the {name} span is {span:.4f}, not 1.0 — the top is tiled "
                f"{span:.3f} times across itself rather than mapped once"
            )

    mat = bpy.data.materials.new("desk_wood")
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    for img, socket, non_colour in ((a_img, "Base Color", False), (g_img, "Roughness", True)):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Cubic"
        tex.extension = "REPEAT"
        if non_colour:
            img.colorspace_settings.name = "Non-Color"
        nt.links.new(tex.outputs["Color"], b.inputs[socket])
    bump_tex = nt.nodes.new("ShaderNodeTexImage")
    bump_tex.image = h_img
    bump_tex.interpolation = "Cubic"
    h_img.colorspace_settings.name = "Non-Color"
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = GRAIN_MM / 1000.0
    nt.links.new(bump_tex.outputs["Color"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Specular IOR Level"].default_value = 0.45
    b.inputs["Coat Weight"].default_value = 0.20
    b.inputs["Coat Roughness"].default_value = 0.26
    obj.data.materials.append(mat)

    # the relief, as geometry rather than a normal, so the joins actually cast into each other
    disp_tex = bpy.data.textures.new("desk_disp", type="IMAGE")
    disp_tex.image = h_img
    disp_tex.extension = "REPEAT"
    mod = obj.modifiers.new("relief", "DISPLACE")
    mod.texture = disp_tex
    mod.texture_coords = "UV"
    mod.strength = 3.0 * GRAIN_MM / 1000.0
    mod.mid_level = 0.5
    return obj


def render(res, condition, out_dir, samples, seed):
    scene = common.reset_scene()
    ry = int(round(res * HEIGHT_M / WIDTH_M))
    tmp = tempfile.mkdtemp(prefix="desk-")
    build_top(seed, res, ry, tmp)
    common.add_top_camera(scene, WIDTH_M, HEIGHT_M, ortho=True, distance=0.9)
    common.render_settings(scene, res, ry, samples=samples, transparent=False, file_format="PNG")
    if condition == "day":
        common.add_daylight(scene)
    else:
        common.add_dusk(scene)
        # The desk did not stop down and the paper did, so the dusk desk came out brighter than
        # the daylight desk with the paper on it dimmer than both — wood glowing under dim notes,
        # in one picture, which is the first thing anyone looking for faked material checks.
        common.stop_down_for_dusk(scene)
    name = "desk" if condition == "day" else "desk_dusk"
    path = os.path.join(out_dir, name + ".png")
    common.render(scene, path)
    manifest.record(path, "blender/shell/desk.py", {
        "width_m": WIDTH_M, "height_m": HEIGHT_M, "planks": PLANKS, "join_mm": JOIN_MM,
        "grain_mm": GRAIN_MM, "mesh": [MESH_X, MESH_Y], "res": [res, ry], "samples": samples,
        "condition": condition, "seed": seed,
        "grain": "computed at render resolution as albedo, height and gloss maps, not carried "
                 "by the mesh",
        "marks": "three ring stains, nine scratches, up to two knots a board",
        "tiles": "vertically, by construction: every field is whole-numbered sinusoids",
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
