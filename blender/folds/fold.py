"""blender/folds/fold.py — the fold, unfold and crumple sequences, as rendered geometry.

    bash blender/run.sh blender/folds/fold.py -- --seq unfold_thirds --frames 240
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

# The stock a note in the thread is torn from, and which variant of it.
#
# Every other piece of paper in this build is a render of a printed stock: blender/paper/stocks.py
# passes `rules_image` to `common.paper_material` for all fifty-four of them. The fold did not, so
# for four cycles the one sheet the material row is judged on was the only blank sheet in the
# library -- a flat cream rectangle with a procedural tooth, square-cut, which is the archetype
# docs/BRIEF.md names as a failure of the whole visual concept. Firing 19 measured it: a 300x120
# interior patch of frame 0 reads L_std 1.795 over 16 luminance levels against 9.783 over 95 for
# the stock it is meant to be made of, and the artifact it freezes into reads 1.317 against 36.896
# for the ruled note 200 px below it in the same frame.
RULES_STOCK = "lined"
RULES_VARIANT = 1
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


# A flap folded back on itself never reaches a full half turn: the paper it is folded against is
# in the way. Folding to exactly pi put the flap's surface in the same plane as the third it lies
# on, and Cycles cannot choose between two coincident surfaces — frame 0000 came out as grey
# interference banding instead of paper, sixty-three levels darker than frame 0001, and that first
# frame is the one every unopened note in the thread shows. Two degrees of paper is what stops it.
FLAT = math.pi - 0.035


def apply_thirds(verts_co, h, t, rng):
    """A letter folded in thirds opening: the top flap first, then the bottom, then a settle."""
    y1, y2 = h / 6.0, -h / 6.0
    # phase 1: top flap 0 -> 1.6 s, phase 2: bottom flap 1.4 -> 3.2 s, settle to 4 s
    a_top = FLAT * (1.0 - ease(min(1.0, t / 0.40)))
    a_bot = FLAT * (1.0 - ease(min(1.0, max(0.0, (t - 0.35) / 0.45))))
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
    a = FLAT * (1.0 - ease(min(1.0, t / 0.7)))
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


def rules_for_a_note():
    """The printed rules of the stock this note is torn from, and where on the stock it is torn.

    Two things have to be right or the rules are worse than none. The image comes from
    blender/paper/rules.py under the SYSTEM python, because Blender's bundled python has numpy and
    no Pillow -- the same dance blender/paper/stocks.py:203 does and for the same reason. And the
    pitch has to survive the change of sheet: rules.py prints a `lined` sheet at 148 x 210 mm with
    8 mm feint rules and a red margin 32 mm in, while this sheet is A6 at 148 x 105 mm, and the
    rules image is sampled by raw UV. Stretched, 8 mm rules would print at 4 mm and the note would
    be ruled like nothing that exists. So the sheet samples the fraction of the image it actually
    covers -- 105/210 in v, 148/148 in u -- and takes it from the middle of the stock rather than
    the top, because the top of a lined sheet is its header margin and a note torn out of the
    middle of a pad is what the thread is made of.
    """
    import shutil
    import subprocess
    sys.path.insert(0, os.path.join(os.path.dirname(HERE), "paper"))
    import rules as rules_mod  # noqa: E402
    path = rules_mod.output_path(RULES_STOCK, RULES_VARIANT)
    if not os.path.exists(path):
        py = shutil.which("python3") or "python3"
        subprocess.run([py, os.path.join(os.path.dirname(HERE), "paper", "rules.py"),
                        "--stock", RULES_STOCK, "--variant", str(RULES_VARIANT)], check=True)
    stock_w_mm, stock_h_mm = rules_mod.SHEETS_MM[RULES_STOCK]
    scale = (SHEET_MM[0] / stock_w_mm, SHEET_MM[1] / stock_h_mm)
    offset = ((1.0 - scale[0]) / 2.0, (1.0 - scale[1]) / 2.0)
    return path, scale, offset


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
    # The path once; the datablock per frame, because reset_scene empties bpy.data.
    rules_png, rules_scale, rules_offset = rules_for_a_note()
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
        rules_img = common.load_image(rules_png)
        rules_img.colorspace_settings.name = "sRGB"
        mat = common.paper_material(f"{name}_paper", (0.94, 0.91, 0.85), tooth=1.05, yellowing=0.25,
                                    sheen=0.24, fibre_scale=1100.0,
                                    rules_image=rules_img, rules_uv_scale=rules_scale,
                                    rules_uv_offset=rules_offset)
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
    settings = {
        "sequence": name, "frames": frames, "resolution": res, "samples": samples,
        "sheet_mm": list(SHEET_MM), "crease_mm": CREASE_MM, "light": condition,
        "rules_stock": RULES_STOCK, "rules_variant": RULES_VARIANT,
        "rig": "blender/rig/common.py",
    }
    # The brief's rule is that every file in assets/ names its generator, so each frame gets its
    # own entry rather than the directory getting one. They share the sequence's settings and add
    # the frame number, which is the only thing that differs between them.
    manifest.record(out_dir, "blender/folds/fold.py", settings, kind="fold_sequence")
    # Only the frames this call actually rendered. Listing the directory instead records every
    # frame that happens to be sitting in it under THIS call's settings, so a chunked run --
    # which is the only way 240 frames get committed as they land rather than in one three-hour
    # lump -- writes "resolution: 1440" over frames still on disk at 540. The manifest is the
    # provenance of the library and it has to be true of a half-finished one too.
    for frame in range(start, end):
        frame_path = os.path.join(out_dir, f"{frame:04d}.png")
        if os.path.exists(frame_path):
            manifest.record(frame_path, "blender/folds/fold.py",
                            dict(settings, frame=frame), kind="fold_frame")


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--seq", choices=list(SEQUENCES))
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--frames", type=int)
    # Rendered at 1440 and packed down to 540, because 540 is below what the fibre needs.
    #
    # 94 of the 240 frames of unfold_thirds read below tools/check/surfaces.py's 1.2 floor for
    # paper, 0.912 to 1.197, and the whole of that is render resolution. Measured at firing 10, one
    # variable at a time, as surfaces.py's own patch_std. "packed" is the frame put through
    # pack_assets.convert at the size the app ships it, which is the number the default gate reads.
    #
    #                                          frame 0000        frame 0150
    #   committed, old lamp, 540/16                 1.096             1.354
    #   new lamp, 540/16                            0.831              --
    #   new lamp, 540/64                            0.864             1.098    samples are not it
    #   new lamp, 540/16, fibre 1100 -> 669         0.822             1.073    worse, not better
    #   new lamp, 540/16, exposure -0.30            1.027             1.296    see the note below
    #   new lamp, 1080/16            source         1.677             1.944
    #                                packed         1.179             1.371    still short
    #   new lamp, 1440/16            source         2.047             2.084
    #                                packed         1.489             1.607
    #
    # And on the two worst frames in the whole set, which is what the floor has to clear:
    #
    #                                          frame 0235        frame 0238
    #   committed, old lamp, 540/16                 0.912             0.924
    #   new lamp, 1440/16            source         1.946             1.925
    #                                packed         1.384             1.399
    #   new lamp, 1440/64            source         2.047              --
    #                                packed         1.396              --
    #
    # So 1440/16. The last pair is what says 16 samples is converged: quadrupling them moves the
    # packed frame by 0.012, which is not worth three times the render. Two checks that this is
    # texture and not render noise, because a patch-variance floor is met by noise as happily as by
    # tooth -- a 2.67x downsample cuts white noise by about 2.67, so 2.047 would land at 0.77 and it
    # lands at 1.489; and 16 samples against 64 agree to 0.012, which undenoised noise would not.
    #
    # THE OBVIOUS READING OF "the tooth the stocks carry" IS REFUTED. paper_material's noise scales
    # are in UV, a stock's UV spans 210 mm and the fold's spans 148, so the same number is a 1.64x
    # finer fibre on the fold than on the paper it is meant to be made of. Matching the stocks in
    # millimetres made every frame worse, at both resolutions. The fold's fibre was never too fine
    # for the paper; it was too fine for 540 pixels.
    #
    # The exposure row is NOT taken. It is the day aperture, it is a rig-level quantity, and it is
    # filed as the-corrected-lamp-pins-the-red-channel for ADDRESS to rank. A fold-only day aperture
    # is precisely the mistake DUSK_STOPS exists to stop: everything lit by one lamp has to agree
    # about the aperture.
    ap.add_argument("--res", type=int, default=1440)
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
