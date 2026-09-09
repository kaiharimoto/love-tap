"""blender/folds/fold.py — the fold, unfold and crumple sequences, as rendered geometry.

    bash blender/run.sh blender/folds/fold.py -- --seq unfold_thirds --frames 240 --res 600
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

Frames are written as PNG with alpha and packed to WebP by tools/pack_assets.py.

Density. A stock is rendered at about 8.7 px/mm; a fold frame at 600 px across a 185 mm field is
3.24 px/mm, so the paper material's fibre layers — sized for the stocks — fall under one pixel
here and Cycles averages them away: the sequence this replaces measured 94 of 240 frames below the
paper floor with the very material the stocks pass with. The material is therefore told the
ratio (mottle_scale, fibre_scale), so a fibre in a fold frame is the same fraction of a pixel it
is in a stock, and the frame is rendered at 48 samples with the denoiser's albedo pass keeping
the texture it would otherwise smooth.
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
CREASE_RIDGE_M = 0.00036            # how far the crease stands off the sheet: pulled fibres, not a line
HINGE_M = 0.0022                    # the radius band a fold turns through: paper bends, it does not hinge
BOW_RAD = 0.20                      # how much further a standing flap curls over its own length
# How far off the vertical the camera sits. A flap standing at a right angle projects sin(tilt) of
# its length into the frame — at twenty degrees a 35 mm flap is 12 mm of the picture, which reads
# as a flap; below about fifteen it reads as a thick edge, and above about thirty the settled sheet
# is foreshortened enough to argue with the note it becomes. Every fold frame is shot from here.
TILT_DEG = 20.0
# What the material is told about the density it is rendered at. The stocks are 8.7 px/mm; the
# ratio below is (frame px/mm) / 8.7 at the default --res, so a fibre is the same fraction of a
# pixel here as it is on a stock. Recomputed from --res in render_sequence.
STOCK_PX_PER_MM = 8.7
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


# How deep the torn edge bites into the sheet, and the two wavelengths it bites at. A tear is not
# a wobble: it is fibre giving way along the grain, so it wants a long run and a short one at once.
TEAR_DEEP_M = 0.0032
TEAR_LONG_MM = 12.0
TEAR_SHORT_MM = 2.2
# How far the sheet lies off flat where nothing is bending it, and over what distance. Paper that
# has been folded and opened does not lie flat: it cockles. Under the crease ridge (0.36 mm) so
# the crease stays the sharpest thing on the sheet.
COCKLE_M = 0.00045
COCKLE_LONG_MM = 34.0
COCKLE_SHORT_MM = 17.0


def _tear_bite(u_mm, rng_phase, deep_m=TEAR_DEEP_M):
    """How far the torn edge has eaten into the sheet at [u_mm] along it, in metres, never out.

    Two runs at once — one about a finger's width, one about a fibre bundle's — raised to a
    power so most of the edge is nearly whole and the bites are occasional, which is what a tear
    looks like and what a sine wave does not.
    """
    a, b = rng_phase
    d = (0.62 * (0.5 + 0.5 * math.sin(2.0 * math.pi * u_mm / TEAR_LONG_MM + a))
         + 0.38 * (0.5 + 0.5 * math.sin(2.0 * math.pi * u_mm / TEAR_SHORT_MM + b)))
    return (d ** 1.4) * deep_m


def _cockle(x, y, phases):
    """The undulation of a sheet that has been folded and opened, in metres, never below zero.

    Never below, because the shadow catcher is a real plane 0.2 mm under the sheet and a shadow
    catcher is invisible to the camera: where the paper dipped under it the render came back
    transparent, and the settled sheet was a grid of twenty black holes in the cockle's own
    pattern. Paper resting on a desk cockles upward from where it touches, which is what this is.
    """
    p1, p2, p3 = phases
    xm, ym = x * 1000.0, y * 1000.0
    wave = (0.6 * math.sin(2.0 * math.pi * xm / COCKLE_LONG_MM + p1)
            * math.cos(2.0 * math.pi * ym / (COCKLE_LONG_MM * 1.2) + p2)
            + 0.4 * math.sin(2.0 * math.pi * xm / COCKLE_SHORT_MM + p3))
    return COCKLE_M * (1.0 + wave)


def build_sheet(nx, ny, w, h, rng):
    """A torn sheet with UVs, at real size, plus the vertex grid for later bending.

    Torn, not cut. The sheet used to be a rectangle to the last decimal, and it is the one thing in
    the app whose silhouette a critic could measure without any judgement in it: the left edge of
    the arriving sheet occupied a single column over ninety rows, standard deviation 0.00 px, while
    the notes lying beside it in the same frame wandered 22 to 35. Every note in the thread is torn;
    the one that arrives folded was not.

    Cockled, not flat. Away from the hinges the sheet was a plane, so its shading was a
    one-dimensional gradient: the per-row standard deviation across its 580-pixel width measured
    1.50 grey levels, which is a ramp rather than a surface. Paper that has been folded and opened
    does not lie flat.
    """
    # one phase pair per edge, one triple for the cockle, so no two sheets tear or lie alike
    ph = [(rng.random() * 6.28, rng.random() * 6.28) for _ in range(4)]
    cph = (rng.random() * 6.28, rng.random() * 6.28, rng.random() * 6.28)
    bm = bmesh.new()
    verts = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = (i / nx - 0.5) * w
            y = (j / ny - 0.5) * h
            # the two edges this vertex is on, if any, bite inward
            if i == 0:
                x += _tear_bite(y * 1000.0, ph[0])
            elif i == nx:
                x -= _tear_bite(y * 1000.0, ph[1])
            if j == 0:
                y += _tear_bite(x * 1000.0, ph[2])
            elif j == ny:
                y -= _tear_bite(x * 1000.0, ph[3])
            verts[(i, j)] = bm.verts.new((x, y, _cockle(x, y, cph)))
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


def _arc(length, turn, a0):
    """Walk `length` of inextensible paper whose tangent turns by `turn`, starting at angle a0.

    Returns (along, up, ending angle). A constant turn rate over a length is a circular arc, which
    is what paper does: it has no hinges in it, only radii.
    """
    a1 = a0 + turn
    if abs(turn) < 1e-9:
        return length * math.cos(a0), length * math.sin(a0), a1
    r = length / turn
    return r * (math.sin(a1) - math.sin(a0)), -r * (math.cos(a1) - math.cos(a0)), a1


def bend_about(co, hinge_y, angle, sign=1.0, flap_m=None):
    """Bend a point about a hinge line running along x at hinge_y.

    This used to be a rigid rotation, and a rigidly rotated flap is a plane. A plane under one
    light is one tone, so the fold frames came out as two flat fills meeting at a step: measured
    over 46 frames and 59 panels, the end-to-end ramp inside a panel was 11.3 grey levels against
    a crease step of 24.2, and the thirty rows nearest a crease were 0.37 levels *darker* than the
    thirty farthest — no highlight on the ridge, no valley beside it. That is a picture being
    transformed, which is the one thing the fold render exists not to be.

    Paper has no corners. The bend runs over a band HINGE_M wide, so the surface through the fold
    is an arc of radius HINGE_M/angle: the light climbs it on the outside and is occluded on the
    inside, both of them shading rather than drawing. Past the band the flap keeps turning, very
    slowly, over its own length — a raised flap sags under its own weight, and a sheet that has
    been folded and opened keeps some of the fold — so the panel is a shallow cylinder and its
    tone ramps across it instead of sitting flat.
    """
    y = co[1] - hinge_y
    if sign * y <= 0:
        return co
    d = abs(y)
    sy = 1.0 if y >= 0 else -1.0
    band = HINGE_M
    p, q, a1 = _arc(min(d, band), angle * min(1.0, d / band), 0.0)
    if d > band:
        run = max((flap_m or band) - band, 1e-6)
        # the tail's curvature, in radians over the whole flap: nothing when the flap lies flat,
        # most when it stands up
        bow = BOW_RAD * math.sin(min(abs(angle), math.pi)) * (1.0 if angle >= 0 else -1.0)
        dp, dq, _ = _arc(d - band, bow * (d - band) / run, a1)
        p += dp
        q += dq
    return (co[0], hinge_y + sy * p, co[2] + sy * q)


# A flap folded back on itself never reaches a full half turn: the paper it is folded against is
# in the way. Folding to exactly pi put the flap's surface in the same plane as the third it lies
# on, and Cycles cannot choose between two coincident surfaces — frame 0000 came out as grey
# interference banding instead of paper, sixty-three levels darker than frame 0001, and that first
# frame is the one every unopened note in the thread shows. Two degrees of paper is what stops it.
FLAT = math.pi - 0.035


def apply_thirds(verts_co, h, t, rng):
    """A letter folded in thirds opening: the top flap first, then the bottom, then a settle.

    The signs on the two bends matter and were both wrong. A flap rotated with the angle negated
    swings *under* the sheet: at a quarter of the way open it points into the desk, and when it is
    folded shut it lies a tenth of a millimetre below the third it is folded against instead of on
    top of it. Filmed from directly overhead that is invisible — the outline is the same whichever
    side of the plane the flap is on — so it survived a render, a packing and three review cycles.
    The tilted camera is what shows it.
    """
    y1, y2 = h / 6.0, -h / 6.0
    # phase 1: top flap 0 -> 1.6 s, phase 2: bottom flap 1.4 -> 3.2 s, settle to 4 s
    a_top = FLAT * (1.0 - ease(min(1.0, t / 0.40)))
    a_bot = FLAT * (1.0 - ease(min(1.0, max(0.0, (t - 0.35) / 0.45))))
    settle = 1.0 - ease(min(1.0, max(0.0, (t - 0.80) / 0.20)))
    out = []
    for co in verts_co:
        c = co
        if c[1] > y1:
            c = bend_about(c, y1, a_top, sign=1.0, flap_m=h / 3.0)
        elif c[1] < y2:
            c = bend_about(c, y2, -a_bot, sign=-1.0, flap_m=h / 3.0)
        # the whole sheet is not flat while it settles: the creases stay proud
        lift = settle * 0.0016 * math.exp(-((c[1] - y1) / (0.02)) ** 2)
        lift += settle * 0.0016 * math.exp(-((c[1] - y2) / (0.02)) ** 2)
        # and a fold leaves a crease: a ridge of pulled fibres along the hinge, there from the
        # first frame to the last, so the light breaks across it whichever way the flap lies
        lift += CREASE_RIDGE_M * (crease_softness((c[1] - y1) * 1000.0)
                                  + crease_softness((c[1] - y2) * 1000.0))
        out.append((c[0], c[1], c[2] + lift))
    return out


def apply_half(verts_co, h, t, rng):
    a = FLAT * (1.0 - ease(min(1.0, t / 0.7)))
    settle = 1.0 - ease(min(1.0, max(0.0, (t - 0.7) / 0.3)))
    out = []
    for co in verts_co:
        c = bend_about(co, 0.0, a, sign=1.0, flap_m=h / 2.0) if co[1] > 0 else co  # over, not under
        lift = settle * 0.0022 * math.exp(-((c[1]) / 0.02) ** 2)
        lift += CREASE_RIDGE_M * crease_softness(c[1] * 1000.0)
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


# How much of the rendered shadow is kept. A shadow catcher's alpha is the fraction of the light
# the sheet blocks, and here that is 0.70: the sun is most of the light in this rig. Composited as
# black at 0.70 over the app's own desk it comes out at 30 grey levels against a desk at 80, which
# a critic measured as "a hard slab, not a contact shadow" — and it is not a shadow, it is a hole.
# The app's own baked tear shadows are drawn between 0.16 and 0.42 for the same reason: the desk a
# note lies on is lit by more than the sun this rig models. Scaled to land at the same ceiling.
SHADOW_KEEP = 0.6


def _soften_shadow(path):
    """Scale the shadow's alpha in a rendered frame, leaving the sheet's own alpha alone."""
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    shadow = px[:, 3] < 0.995
    px[shadow, 3] *= SHADOW_KEEP
    img.pixels = px.reshape(-1).tolist()
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render_sequence(name, frames, res, samples, out_dir, condition="day", start=0, end=None):
    cfg = SEQUENCES[name]
    kind = cfg["kind"]
    rng = np.random.default_rng(20260903 + abs(hash(name)) % 1000)
    w, h = SHEET_MM[0] / 1000.0, SHEET_MM[1] / 1000.0
    # rows of 0.29 mm, so the 2.2 mm the fold turns through is an arc seven or eight rows long
    # rather than three. At 180 rows the bend was four quads and read as a chamfer; the light has
    # to climb it, and it cannot climb what it can count.
    nx, ny = 160, 360
    os.makedirs(out_dir, exist_ok=True)
    end = frames if end is None else end
    base_co = None
    field = None
    # the frame is res pixels across w*1.25 metres (see add_top_camera below), so this is the
    # density the material has to be told about
    px_per_mm = res / (w * 1.25 * 1000.0)
    density = px_per_mm / STOCK_PX_PER_MM
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
        mat = common.paper_material(f"{name}_paper", (0.94, 0.91, 0.85), tooth=1.55, yellowing=0.25,
                                    sheen=0.24, fibre_scale=1100.0 * density,
                                    mottle_scale=density)
        obj.data.materials.append(mat)
        common.add_shadow_catcher(scene, size_m=0.4)
        # A bounce plane under the sheet, as the object queue got. Without one nothing lights the
        # underside of the shadow: it fell 247.8 -> 30.0 grey levels across four rows and then held
        # flat at 30-37 for sixty pixels, which is a slab with a sheet on it rather than paper
        # resting on a desk. Two millimetres under the lowest point the sheet reaches, so a flap
        # standing on its crease is not buried in its own bounce.
        common.add_desk(scene, size_m=0.30,
                        z=common.lowest_z([obj]) - 0.002).visible_camera = False
        # Orthographic, tilted off the vertical. Straight down was geometrically honest and it did
        # not look like paper: a flap rotating about its crease foreshortens to nothing from
        # directly overhead, so a letter opening filmed as a cream rectangle getting taller, which
        # is what the material critic measured for three cycles. From TILT_DEG the flap stands in
        # the frame and its shadow crosses the third below it.
        #
        # The field is shortened by cos(tilt) so the settled sheet ends the sequence at the same
        # size in frame as it had from overhead. Without that the note would shrink by a tenth at
        # the moment the app crossfades the last frame into the real widget, and the crossfade is
        # the one place a viewer is looking straight at both.
        vfield = h * 1.55 * math.cos(math.radians(TILT_DEG))
        common.add_top_camera(scene, w * 1.25, vfield, ortho=True, tilt_deg=TILT_DEG, distance=0.5)
        rx = int(round(res * (w * 1.25) / vfield)) if vfield > w * 1.25 else res
        ry = res if vfield > w * 1.25 else int(round(res * vfield / (w * 1.25)))
        common.render_settings(scene, rx, ry, samples=samples, transparent=True, file_format="PNG",
                               seed=20260903 + frame)
        if condition == "day":
            # Lighting this from twenty-two degrees rather than fifty was tried: the crease reads
            # a little better and the paper goes cooler than every other stock in the library,
            # which is worse. It was never the light.
            common.add_daylight(scene)
        else:
            common.add_dusk(scene)
        path = os.path.join(out_dir, f"{frame:04d}.png")
        common.render(scene, path)
        _soften_shadow(path)
        if frame % 20 == 0:
            print(f"{name} {frame}/{frames}", flush=True)
    settings = {
        "sequence": name, "frames": frames, "resolution": res, "samples": samples,
        "sheet_mm": list(SHEET_MM), "crease_mm": CREASE_MM, "crease_ridge_mm": CREASE_RIDGE_M * 1000.0,
        "light": condition, "rig": "blender/rig/common.py", "camera_tilt_deg": TILT_DEG,
        "px_per_mm": round(px_per_mm, 3), "density_vs_stock": round(density, 3),
        "look": {"rgb": [0.94, 0.91, 0.85], "tooth": 1.55, "yellowing": 0.25, "sheen": 0.24,
                 "fibre": round(1100.0 * density, 1), "mottle_scale": round(density, 3)},
        "grid": [nx, ny],
        "tear_mm": {"deep": TEAR_DEEP_M * 1000.0, "long": TEAR_LONG_MM, "short": TEAR_SHORT_MM},
        "cockle_mm": {"amplitude": COCKLE_M * 1000.0, "long": COCKLE_LONG_MM,
                      "short": COCKLE_SHORT_MM},
        "bounce_plane": "an invisible desk 2 mm under the sheet's lowest point",
        "shadow_keep": SHADOW_KEEP,
    }
    # The brief's rule is that every file in assets/ names its generator, so each frame gets its
    # own entry and the directory gets none: a directory entry is an entry without a file, which
    # tools/check/manifest.py rightly lists as stale, and a critic read as the asset being missing.
    for frame_file in sorted(os.listdir(out_dir)):
        if frame_file.endswith((".png", ".webp")):
            manifest.record(os.path.join(out_dir, frame_file), "blender/folds/fold.py",
                            dict(settings, frame=int(os.path.splitext(frame_file)[0])),
                            kind="fold_frame")


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--seq", choices=list(SEQUENCES))
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--frames", type=int)
    ap.add_argument("--res", type=int, default=600)
    ap.add_argument("--samples", type=int, default=48)
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
