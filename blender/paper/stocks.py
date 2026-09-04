"""blender/paper/stocks.py — every paper stock, rendered as a scan under the one rig.

    bash blender/run.sh blender/paper/stocks.py -- --stock lined --variant 1 --res 600
    bash blender/run.sh blender/paper/stocks.py -- --all --condition both

Each sheet is modelled at real size (metres), given a slight warp so the rules are not perfectly
straight, the fibre/tooth material from rig/common.paper_material with the printed rules from
rules.py multiplied in, a 0.1 mm thickness so the edge catches light, spiral fringe and punched
holes as real geometry, and a lifted bottom edge for sticky notes. The orthographic top camera
frames the sheet with a small margin of desk. Light comes only from rig/common (day or dusk).
Output: assets/paper/<stock>_<NN>.png and <stock>_<NN>_dusk.png, recorded in assets/MANIFEST.json.
"""
import argparse
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))   # blender/
sys.path.insert(0, HERE)                     # blender/paper
from rig import common, manifest             # noqa: E402
import rules                                 # noqa: E402

OUT_DIR = os.path.join(common.repo_root(), "assets", "paper")
MARGIN_MM = 4.0
THICKNESS_M = 0.00010

STOCK_LOOK = {
    # base rgb (linear-ish sRGB values), tooth, fibre scale, sheen, yellowing per variant
    "lined":        dict(rgb=(0.93, 0.90, 0.84), tooth=1.05, fibre=950.0, sheen=0.22, yellow=[0.12, 0.30, 0.48, 0.60]),
    "graph":        dict(rgb=(0.90, 0.92, 0.92), tooth=0.90, fibre=1100.0, sheen=0.20, yellow=[0.05, 0.12, 0.22, 0.30]),
    "spiral":       dict(rgb=(0.93, 0.90, 0.84), tooth=1.10, fibre=900.0, sheen=0.22, yellow=[0.10, 0.28, 0.45, 0.58]),
    "looseleaf":    dict(rgb=(0.94, 0.92, 0.87), tooth=0.95, fibre=1000.0, sheen=0.24, yellow=[0.08, 0.22, 0.38, 0.50]),
    "legal":        dict(rgb=(0.94, 0.88, 0.62), tooth=1.00, fibre=900.0, sheen=0.20, yellow=[0.10, 0.30]),
    "index":        dict(rgb=(0.95, 0.93, 0.88), tooth=0.80, fibre=1300.0, sheen=0.28, yellow=[0.06, 0.20]),
    "sticky_yellow": dict(rgb=(0.94, 0.86, 0.52), tooth=0.75, fibre=1200.0, sheen=0.26, yellow=[0.04, 0.12]),
    "sticky_pink":  dict(rgb=(0.94, 0.74, 0.74), tooth=0.75, fibre=1200.0, sheen=0.26, yellow=[0.04, 0.12]),
    "sticky_blue":  dict(rgb=(0.72, 0.83, 0.90), tooth=0.75, fibre=1200.0, sheen=0.26, yellow=[0.04, 0.12]),
    "receipt":      dict(rgb=(0.95, 0.94, 0.90), tooth=0.55, fibre=1600.0, sheen=0.35, yellow=[0.10]),
}


def _rng(stock, variant, salt=0):
    return np.random.default_rng(int(rules.seed_for(stock, variant)) ^ (0x5EED0 + salt))


def build_sheet(stock, variant, w_mm, h_mm):
    """A subdivided sheet at real size with warp, fringe, holes, curl. Returns the object."""
    rng = _rng(stock, variant, 1)
    w, h = w_mm / 1000.0, h_mm / 1000.0
    nx, ny = max(40, int(w_mm)), max(40, int(h_mm))   # ~1 mm cells
    bm = bmesh.new()
    verts = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = (i / nx - 0.5) * w
            y = (j / ny - 0.5) * h
            verts[(i, j)] = bm.verts.new((x, y, 0.0))
    bm.verts.ensure_lookup_table()
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]))
    bm.faces.ensure_lookup_table()
    # uv 0..1
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x / w) + 0.5, (co.y / h) + 0.5)

    # warp: two sine terms, <= 0.6 mm, plus a very slight cylindrical bow
    a1, a2 = rng.uniform(0.15, 0.35) * 1e-3, rng.uniform(0.10, 0.25) * 1e-3
    p1, p2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    k1, k2 = rng.uniform(0.8, 1.4), rng.uniform(1.2, 2.2)
    bow = rng.uniform(-0.25, 0.25) * 1e-3
    zs = []
    for v in bm.verts:
        u = v.co.x / w + 0.5
        t = v.co.y / h + 0.5
        z = a1 * math.sin(2 * math.pi * k1 * u + p1) + a2 * math.sin(2 * math.pi * k2 * t + p2) + bow * (2 * u - 1) ** 2
        zs.append(z)
    # the sheet rests on the desk: its lowest point (after the thickness below the surface) sits at z = 0
    zmin = min(zs)
    for v, z in zip(bm.verts, zs):
        v.co.z = z - zmin + THICKNESS_M + 0.00002
    # a guillotined edge is never perfectly straight: 0.05 mm of jitter along the outer verts
    for (i, j), v in verts.items():
        if v.is_valid and (i == 0 or i == nx or j == 0 or j == ny):
            v.co.x += rng.uniform(-0.05, 0.05) * 1e-3
            v.co.y += rng.uniform(-0.05, 0.05) * 1e-3

    # spiral: torn fringe along the left edge (the paper pulled out of the coil)
    if stock == "spiral":
        fringe_mm = rng.uniform(4.5, 7.5)
        prof = _fringe_profile(ny + 1, fringe_mm, rng)
        delete = []
        for (i, j), v in verts.items():
            x_mm = (v.co.x + w / 2) * 1000.0
            if x_mm < prof[j]:
                delete.append(v)
        bmesh.ops.delete(bm, geom=delete, context="VERTS")
        # roughen the new edge: small in-plane jitter and a slight upward fibre lift
        for v in bm.verts:
            x_mm = (v.co.x + w / 2) * 1000.0
            if x_mm < fringe_mm + 1.5:
                v.co.x += rng.uniform(-0.25, 0.25) * 1e-3
                v.co.z += rng.uniform(0.0, 0.35) * 1e-3

    # sticky note: bottom edge lifts and curls (the un-gummed end)
    if stock.startswith("sticky"):
        lift = rng.uniform(4.0, 8.0) * 1e-3
        band = rng.uniform(0.35, 0.5)
        for v in bm.verts:
            t = v.co.y / h + 0.5       # 0 bottom .. 1 top
            if t < band:
                s = (band - t) / band
                v.co.z += lift * s * s
                v.co.y += lift * 0.35 * s * s   # the curl pulls the edge in a little

    # receipt: a gentle roll memory
    if stock == "receipt":
        for v in bm.verts:
            t = v.co.y / h + 0.5
            v.co.z += 2.5e-3 * (t ** 3)

    mesh = bpy.data.meshes.new(f"{stock}_{variant}")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    # thickness so the edge is real
    solid = obj.modifiers.new("thickness", "SOLIDIFY")
    solid.thickness = THICKNESS_M
    solid.offset = -1.0
    solid.use_even_offset = True
    return obj


def _fringe_profile(n, fringe_mm, rng):
    """Per-row x threshold (mm) of the torn spiral edge: coil-tooth spikes over a rough baseline."""
    base = np.zeros(n)
    # 1/f-ish roughness
    for k in range(1, 40):
        base += rng.normal(0, 1) / k * np.sin(2 * math.pi * k * np.linspace(0, 1, n) + rng.uniform(0, 6.28))
    base = (base - base.min()) / (base.max() - base.min() + 1e-9)
    prof = fringe_mm * (0.35 + 0.65 * base)
    # spiral pitch teeth: every ~8.5 mm a deeper notch where the wire pulled
    pitch_rows = max(3, int(round(8.5 * (n / 210.0))))
    for r in range(int(rng.uniform(0, pitch_rows)), n, pitch_rows):
        for d in range(-2, 3):
            if 0 <= r + d < n:
                prof[r + d] = max(prof[r + d], fringe_mm * (1.0 - 0.18 * abs(d)))
    return prof


def add_holes(sheet, stock, w_mm, h_mm, variant):
    """Punched holes as boolean cutters (spiral coil holes or two ring-binder holes)."""
    rng = _rng(stock, variant, 2)
    w, h = w_mm / 1000.0, h_mm / 1000.0
    cutters = []
    if stock == "spiral":
        pitch = 8.5e-3
        x = -w / 2 + rng.uniform(9.5, 11.0) * 1e-3
        y = -h / 2 + rng.uniform(4.0, 8.0) * 1e-3
        while y < h / 2 - 3e-3:
            cutters.append((x + rng.uniform(-0.2, 0.2) * 1e-3, y, rng.uniform(1.9, 2.2) * 1e-3))
            y += pitch
    elif stock == "looseleaf":
        for fy in (0.5 - 0.19, 0.5 + 0.19):
            cutters.append((-w / 2 + 8.5e-3, (fy - 0.5) * h, 3.0e-3))
    if not cutters:
        return
    bm = bmesh.new()
    for (cx, cy, r) in cutters:
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=r, radius2=r, depth=0.01,
                              matrix=_translate(cx, cy, 0.0))
    mesh = bpy.data.meshes.new("holes")
    bm.to_mesh(mesh)
    bm.free()
    cutter = bpy.data.objects.new("holes", mesh)
    bpy.context.scene.collection.objects.link(cutter)
    cutter.hide_render = True
    cutter.display_type = "WIRE"
    boolean = sheet.modifiers.new("holes", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.object = cutter


def _translate(x, y, z):
    from mathutils import Matrix
    return Matrix.Translation((x, y, z))


def ensure_rules(stock, variant):
    """The rules image comes from rules.py under the system python (Blender's has no Pillow)."""
    import shutil
    import subprocess
    path = rules.output_path(stock, variant)
    if not os.path.exists(path):
        py = shutil.which("python3") or "python3"
        subprocess.run([py, os.path.join(HERE, "rules.py"), "--stock", stock, "--variant", str(variant)], check=True)
    return path, rules.params_for(stock, variant)


def render_sheet(stock, variant, res_long, condition, samples, out_dir, fmt="WEBP", border=None, threads=0):
    scene = common.reset_scene()
    w_mm, h_mm = rules.SHEETS_MM[stock]
    rules_png, params = ensure_rules(stock, variant)
    look = STOCK_LOOK[stock]
    yellow = look["yellow"][(variant - 1) % len(look["yellow"])]

    sheet = build_sheet(stock, variant, w_mm, h_mm)
    add_holes(sheet, stock, w_mm, h_mm, variant)
    rules_img = common.load_image(rules_png)
    rules_img.colorspace_settings.name = "sRGB"
    mat = common.paper_material(f"paper_{stock}_{variant}", look["rgb"], tooth=look["tooth"], yellowing=yellow,
                                sheen=look["sheen"], rules_image=rules_img, fibre_scale=look["fibre"])
    sheet.data.materials.append(mat)
    common.add_desk(scene, z=0.0)

    fw, fh = (w_mm + 2 * MARGIN_MM) / 1000.0, (h_mm + 2 * MARGIN_MM) / 1000.0
    common.add_top_camera(scene, fw, fh, ortho=True, distance=0.6)
    if fh >= fw:
        rx, ry = int(round(res_long * fw / fh)), res_long
    else:
        rx, ry = res_long, int(round(res_long * fh / fw))
    common.render_settings(scene, rx, ry, samples=samples, transparent=False, file_format=fmt)
    scene.cycles.adaptive_threshold = 0.05
    if threads:
        scene.render.threads_mode = "FIXED"
        scene.render.threads = threads
    if border:
        scene.render.use_border = True
        scene.render.use_crop_to_border = True
        scene.render.border_min_x, scene.render.border_min_y = border[0], border[1]
        scene.render.border_max_x, scene.render.border_max_y = border[2], border[3]
    if condition == "day":
        common.add_daylight(scene)
    else:
        common.add_dusk(scene)
        # the same aperture everything lit at dusk uses; see blender/rig/common.py
        common.stop_down_for_dusk(scene)

    name = f"{stock}_{variant:02d}" + ("" if condition == "day" else "_dusk")
    path = os.path.join(out_dir, name + (".webp" if fmt == "WEBP" else ".png"))
    common.render(scene, path)
    manifest.record(path, "blender/paper/stocks.py", {
        "stock": stock, "variant": variant, "condition": condition, "resolution": [rx, ry],
        "sheet_mm": [w_mm, h_mm], "samples": samples, "seed": int(rules.seed_for(stock, variant)),
        "look": {k: v for k, v in look.items() if k != "yellow"}, "yellowing": yellow,
        "rules": params, "rig": "blender/rig/common.py", "light": condition, "format": fmt,
        "px_per_mm": round(ry / max(w_mm, h_mm), 2),
    }, kind="paper_stock")
    return path


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--stock", choices=rules.STOCKS)
    ap.add_argument("--variant", type=int, default=1)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--res", type=int, default=3000, help="long side in px")
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--condition", choices=["day", "dusk", "both"], default="day")
    ap.add_argument("--out", default=OUT_DIR)
    ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--format", choices=["WEBP", "PNG"], default="WEBP")
    ap.add_argument("--threads", type=int, default=0, help="render threads (0 = all)")
    ap.add_argument("--border", type=float, nargs=4, metavar=("X0", "Y0", "X1", "Y1"),
                    help="render only this fraction of the frame (fast full-resolution tests)")
    a = ap.parse_args(argv)
    conds = ["day", "dusk"] if a.condition == "both" else [a.condition]
    jobs = []
    if a.all:
        for s in rules.STOCKS:
            for v in range(1, rules.VARIANTS[s] + 1):
                for c in conds:
                    jobs.append((s, v, c))
    elif a.stock:
        for c in conds:
            jobs.append((a.stock, a.variant, c))
    else:
        ap.error("--stock or --all")
    os.makedirs(a.out, exist_ok=True)
    for (s, v, c) in jobs:
        name = f"{s}_{v:02d}" + ("" if c == "day" else "_dusk")
        target = os.path.join(a.out, name + (".webp" if a.format == "WEBP" else ".png"))
        if a.skip_existing and os.path.exists(target):
            print(f"skip {name}")
            continue
        import time
        t0 = time.time()
        path = render_sheet(s, v, a.res, c, a.samples, a.out, fmt=a.format, border=a.border, threads=a.threads)
        print(f"rendered {path} in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
