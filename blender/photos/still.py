"""blender/photos/still.py — the photographs in the thread, taken the way the two of them take them.

    bash blender/run.sh blender/photos/still.py -- --only 2026-08_soup_pan --res 900
    bash blender/run.sh blender/photos/still.py -- --all --res 1200 --samples 64

A recipe (blender/photos/recipes/*.json) names a surface, a light, where the camera is held, and
what is on the table. Everything it names is built by kit.py at real size and lit by the same rig
as the paper, so a photograph and the note it is pinned beside agree about where the light is.

The camera is a phone: a perspective lens around 26 mm equivalent, held at the height and lean a
person actually holds one at. That is why these do not read as product shots — nobody photographs
their own boiler from a tripod.

This writes the negative: seed/photos/<id>.exr, scene-linear and unclipped. Running
blender/photos/develop.py turns the negatives into the JPEGs the seed loader reads.
"""
import argparse
import inspect
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from rig import common, manifest  # noqa: E402
sys.path.insert(0, HERE)
import kit  # noqa: E402
import world  # noqa: E402

RECIPES = os.path.join(HERE, "recipes")
OUT = os.path.join(common.repo_root(), "seed", "photos")
SEED_INDEX = os.path.join(common.repo_root(), "seed", "photos")


# ------------------------------------------------------------------ light
def daylight_through_the_window(scene, sky=(0.62, 0.70, 0.86), strength=60.0):
    """The window itself, as light.

    A sun outside a room reaches the table through the opening in one wall, and nothing else does.
    Left at that, the frame is a hard shaft on the floor and everything out of it is black, and
    Cycles has to find a small bright rectangle by chance from every shaded point, which is noise.
    So the opening is also a light: a rectangle of sky, the size of the hole, facing into the room.
    That is what a window is — the sun is what makes the shaft across the table, the sky is what
    makes the rest of the room visible.
    """
    w = kit.WINDOW
    data = bpy.data.lights.new("window", "AREA")
    data.shape = "RECTANGLE"
    data.size = w["y1"] - w["y0"]
    data.size_y = w["z1"] - w["z0"]
    data.energy = strength
    data.color = sky
    lamp = bpy.data.objects.new("window", data)
    scene.collection.objects.link(lamp)
    lamp.location = (w["x"] + 0.01, (w["y0"] + w["y1"]) / 2.0, (w["z0"] + w["z1"]) / 2.0)
    # an area light emits along its local -Z, so this turns that to +X: into the room, not out of it
    lamp.rotation_euler = (0.0, math.radians(-90), 0.0)
    return lamp


def lamp_in_the_room(scene, energy=18.0, colour=(1.0, 0.80, 0.55), at=(0.40, 0.16, 0.30)):
    """A lamp that is in the room rather than down the road.

    night_lamp is a streetlamp: a point source at (-4.5, 9, 5.5) with sixty watts in it, which is
    right for a towpath and useless for a kitchen table, because the room has walls and the lamp
    is outside them. Eighteen of the hundred and fifteen photographs are night scenes and every
    one of them came back with nothing in it. A kitchen at night is not dark; it is lit by
    whatever happens to be on.
    """
    data = bpy.data.lights.new("room_lamp", "AREA")
    data.energy = energy
    data.color = colour
    data.size = 0.11
    lamp = bpy.data.objects.new("room_lamp", data)
    scene.collection.objects.link(lamp)
    lamp.location = at
    common._aim(lamp, (-at[0], -at[1], -at[2] * 0.7))
    return lamp


def light_for(scene, kind, indoors=False, enclosed=False):
    """The conditions a phone photograph is actually taken in, all off the one rig.

    Every daylight condition is the shared rig in blender/rig/common.py with its energy and its
    sky changed, so a photograph and the note it will be pinned beside agree about which way the
    light is coming from. The artificial ones are the lamps that are actually in these rooms.

    Indoors, every daylight condition also lights the window it is coming through; see
    daylight_through_the_window.
    """
    if kind == "window_left":
        sun, world_ = common.add_daylight(scene)
        if enclosed:
            daylight_through_the_window(scene, strength=62.0)
        return sun, world_
    if kind == "overcast":
        sun, world_ = common.add_daylight(scene)
        sun.data.energy *= 0.42
        sun.data.angle = math.radians(24)          # a big soft source: cloud, not sun
        world_.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.6
        if enclosed:
            daylight_through_the_window(scene, sky=(0.74, 0.77, 0.82), strength=78.0)
        return sun, world_
    if kind == "hard_sun":
        sun, world_ = common.add_daylight(scene)
        sun.data.energy *= 1.7
        sun.data.angle = math.radians(0.53)        # the sun's actual angular size
        if enclosed:
            daylight_through_the_window(scene, strength=48.0)
        return sun, world_
    if kind == "low_sun":
        sun, world_ = common.add_daylight(scene, elevation=9.0)
        sun.data.energy *= 1.25
        sun.data.color = (1.0, 0.78, 0.52)
        sun.data.angle = math.radians(0.6)
        if enclosed:
            daylight_through_the_window(scene, sky=(0.86, 0.66, 0.44), strength=44.0)
        return sun, world_
    if kind == "fog_dawn":
        sun, world_ = common.add_daylight(scene, elevation=6.0)
        sun.data.energy *= 0.5
        sun.data.angle = math.radians(30)
        world_.node_tree.nodes["Background"].inputs["Strength"].default_value = 2.4
        world.fog(density=0.030, colour=(0.60, 0.62, 0.65))
        if enclosed:
            daylight_through_the_window(scene, sky=(0.72, 0.74, 0.78), strength=40.0)
        return sun, world_
    if kind == "kitchen_bulb":
        # one warm bulb directly overhead, which is why the shadow under a loaf is so hard
        data = bpy.data.lights.new("bulb", "POINT")
        data.energy = 26.0
        data.color = (1.0, 0.86, 0.68)
        data.shadow_soft_size = 0.03
        lamp = bpy.data.objects.new("bulb", data)
        scene.collection.objects.link(lamp)
        lamp.location = (0.05, -0.02, 0.72)
        return common._world(scene, (0.30, 0.26, 0.22), 0.12), lamp
    if kind == "lamp":
        # a lamp off to one side at desk height: long shadows across the table, warm
        data = bpy.data.lights.new("lamp", "AREA")
        data.energy = 14.0
        data.color = (1.0, 0.82, 0.58)
        data.size = 0.09
        lamp = bpy.data.objects.new("lamp", data)
        scene.collection.objects.link(lamp)
        lamp.location = (0.42, 0.12, 0.34)
        common._aim(lamp, (-0.42, -0.12, -0.22))
        return common._world(scene, (0.20, 0.18, 0.16), 0.09), lamp
    if kind == "night":
        # a town at night: no key light at all, only what the sky and the streetlights leave
        w = common._world(scene, (0.030, 0.034, 0.048), 0.30)
        if indoors:
            # Indoors at night the sky leaves nothing at all, and a photograph of a kitchen at
            # night is not a photograph of nothing: it is whatever was on. One lamp, low and
            # warm, and the street outside the window.
            lamp_in_the_room(scene, energy=2.6, colour=(1.0, 0.83, 0.62))
            if enclosed:
                daylight_through_the_window(scene, sky=(0.42, 0.40, 0.52), strength=1.8)
        return w, None
    if kind == "night_lamp":
        w = common._world(scene, (0.020, 0.024, 0.038), 0.16)
        if indoors:
            # the lamp the sentence means is the one in the room, not the one down the road
            lamp = lamp_in_the_room(scene, energy=4.5)
            if enclosed:
                daylight_through_the_window(scene, sky=(0.46, 0.40, 0.44), strength=2.2)
            return w, lamp
        data = bpy.data.lights.new("streetlamp", "POINT")
        data.energy = 60.0
        data.color = (1.0, 0.70, 0.38)
        data.shadow_soft_size = 0.25
        lamp = bpy.data.objects.new("streetlamp", data)
        scene.collection.objects.link(lamp)
        lamp.location = (-4.5, 9.0, 5.5)
        return w, lamp
    if kind == "torch":
        # a phone torch held in the other hand: hard, close, and from one side only
        data = bpy.data.lights.new("torch", "SPOT")
        # a phone torch thirty centimetres from a pressure gauge is bright; nine watts in a room
        # whose walls reflect five per cent developed to 5.6 grey levels across the whole frame
        data.energy = 42.0
        data.color = (0.98, 0.97, 0.94)
        data.spot_size = math.radians(48)
        data.spot_blend = 0.35
        data.shadow_soft_size = 0.012
        lamp = bpy.data.objects.new("torch", data)
        scene.collection.objects.link(lamp)
        lamp.location = (-0.26, -0.30, 0.30)
        common._aim(lamp, (0.26, 0.30, -0.10))
        return common._world(scene, (0.10, 0.10, 0.11), 0.05), lamp
    if kind == "strip":
        # institutional: a long tube overhead, flat and slightly green
        data = bpy.data.lights.new("strip", "AREA")
        data.energy = 260.0
        data.color = (0.94, 1.0, 0.96)
        data.shape = "RECTANGLE"
        data.size = 1.5
        data.size_y = 0.10
        lamp = bpy.data.objects.new("strip", data)
        scene.collection.objects.link(lamp)
        lamp.location = (0.0, 2.0, 2.7)
        common._aim(lamp, (0, 0, -1))
        return common._world(scene, (0.32, 0.34, 0.33), 0.30), lamp
    return common.add_daylight(scene)


def phone_camera(scene, look_at=(0, 0, 0), height=0.42, distance=0.30, lean_deg=0.0, mm=26.0):
    """Where a phone is when someone takes this: above and in front, leaning in, hand-held."""
    data = bpy.data.cameras.new("phone")
    data.lens = mm
    data.sensor_width = 36.0
    cam = bpy.data.objects.new("phone", data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (look_at[0] + math.sin(math.radians(lean_deg)) * distance,
                    look_at[1] - math.cos(math.radians(lean_deg)) * distance,
                    look_at[2] + height)
    common._aim(cam, (look_at[0] - cam.location[0], look_at[1] - cam.location[1],
                      look_at[2] - cam.location[2]))
    # A phone held thirty centimetres from a loaf does not hold the whole table in focus, and a
    # picture where everything is equally sharp is the other loud way a render says it is one.
    data.dof.use_dof = True
    data.dof.focus_distance = math.dist(cam.location, look_at)
    data.dof.aperture_fstop = 2.2
    return cam


# ------------------------------------------------------------------ building a recipe
BUILDERS = {
    "sheet": kit.sheet,
    "mug": kit.mug,
    "pan": kit.pan,
    "loaf": kit.loaf,
    "gauge": kit.gauge,
    "pipe": kit.pipe,
    "tray": kit.tray,
    "panel": kit.panel,
    "crate": kit.crate,
    "spoon": kit.spoon,
    "knife": kit.knife,
    "crumbs": kit.crumbs,
    "wall": kit.wall,
    "board": kit.board,
    "slab": kit.slab,
    "bowl": kit.bowl,
    "tin": kit.tin,
    "jar": kit.jar,
    "pen": kit.pen,
    "folded": kit.folded,
    "card": kit.card,
    "envelope": kit.envelope,
    "book": kit.book,
    "stack": kit.stack,
    "cloth": kit.cloth,
    "bag": kit.bag,
    "ladle": kit.ladle,
    "hob_ring": kit.hob_ring,
    "plate": kit.plate,
    "cake": kit.cake,
    "flask": kit.flask,
    "bench": kit.bench,
    "cone": kit.cone,
    "car": kit.car,
    "rope": kit.rope,
    "coat": kit.coat,
    # the world beyond a table top
    "ground": world.ground,
    "bays": world.bays,
    "water": world.water,
    "trunk": world.trunk,
    "limbs": world.limbs,
    "canopy": world.canopy,
    "undergrowth": world.undergrowth,
    "post": world.post,
    "railing": world.railing,
    "barrier": world.barrier,
    "block": world.block,
    "chair": world.chair,
    "table": world.table,
    "shelf_rack": world.shelf_rack,
    "window_light": world.window_light,
    "string_lights": world.string_lights,
    "wood": world.wood,
}
# builders whose own first argument is called `kind`; a recipe says `as_kind` so that the
# argument cannot overwrite the key that decides which builder to call in the first place
TAKES_KIND = {"wall", "post", "ground", "pen", "bag"}


def _fit_position(builder, at):
    """`at` in the shape this builder asks for: two numbers, three, or none at all."""
    if at is None:
        return None
    try:
        default = inspect.signature(builder).parameters["at"].default
    except (KeyError, ValueError, TypeError):
        return at
    if not isinstance(default, (tuple, list)):
        return at
    at = tuple(at)
    if len(at) >= len(default):
        # more than the builder's own default is not an error: a builder that can be told a height
        # reads it defensively, and truncating here would quietly drop it
        return at
    return at + tuple(default[len(at):])


def _cut_the_channel(recipe):
    """Where there is water, take the ground out from under it.

    world.water lays its surface ten centimetres below zero, on the assumption that something has
    dug a channel for it. Nothing had: the ground was one flat plane over the top, so every canal,
    every river and every stretch of open water in the year was buried under it and the picture
    came back as an empty field. This digs the channel — a flat bottom under the water and a bank
    that slopes up to the towpath — so the water has somewhere to be and an edge to have.
    """
    waters = [o for o in recipe.get("objects", []) if o.get("kind") == "water"]
    if not waters:
        return
    ground = next((o for o in bpy.data.objects
                   if o.type == "MESH" and o.name.startswith("ground_")), None)
    if ground is None:
        return
    beds = []
    for spec in waters:
        at = spec.get("at", [0.0, 4.0])
        w = float(spec.get("w", 14.0)) / 2.0
        d = float(spec.get("d", 9.0)) / 2.0
        beds.append((float(at[0]), float(at[1]), w, d, float(spec.get("z", -0.10))))
    bank = 0.9                      # how far the bank takes to fall away, in metres
    for v in ground.data.vertices:
        drop = 0.0
        for cx, cy, w, d, z in beds:
            # how far outside the water's footprint this vertex is, along each axis
            ox = max(0.0, abs(v.co.x - cx) - w)
            oy = max(0.0, abs(v.co.y - cy) - d)
            out = math.hypot(ox, oy)
            if out < bank:
                t = 1.0 - (out / bank)
                # a bank is a curve, not a ramp
                drop = min(drop, (z - 0.06) * (t * t * (3 - 2 * t)))
        if drop:
            v.co.z += drop
    ground.data.update()


def build(recipe):
    scene = common.reset_scene()
    mode = recipe.get("mode", "tabletop")
    indoors = recipe.get("room", mode == "tabletop")
    if indoors:
        # a still life is photographed in a room, and a table floating in a void is the single
        # loudest way a render says it is a render
        kit.room(dark=tuple(recipe.get("room_colour", [0.10, 0.09, 0.085])))
    if recipe.get("surface"):
        kit.surface(recipe["surface"], size=recipe.get("surface_size", 1.2),
                    seed=recipe.get("seed", 1))
    if recipe.get("ground"):
        world.ground(recipe["ground"], size=260.0 if mode == "outdoor" else 12.0,
                     seed=recipe.get("seed", 1))
    if mode == "outdoor":
        # Air is not empty. Even on a clear day the far side of a car park is a little paler and
        # a little bluer than the near side, and without that everything sits on one flat plane
        # at the same distance. A photograph of a wood is mostly this.
        world.fog(density=float(recipe.get("fog", 0.006)), size=300.0,
                  colour=(0.55, 0.60, 0.68) if recipe.get("light") != "night_lamp"
                  else (0.10, 0.11, 0.16))
    elif recipe.get("fog"):
        world.fog(density=float(recipe["fog"]))
    if mode == "room" and not recipe.get("ground"):
        # a room seen from across it is not enclosed by kit.room, so the sky still reaches it and
        # it is not lit through a window
        world.ground("carpet", size=12.0, seed=recipe.get("seed", 1))
    for spec in recipe.get("objects", []):
        spec = dict(spec)
        kind = spec.pop("kind")
        # things stand on other things, and a board is twenty-one millimetres thick, so a recipe
        # says how high off the table a piece starts rather than every builder growing a z
        lift = spec.pop("on", 0.0)
        builder = BUILDERS.get(kind)
        if builder is None:
            raise SystemExit(f"still.py: nothing in the kit called {kind!r}")
        # json gives lists; the kit wants tuples
        for key, value in list(spec.items()):
            if isinstance(value, list):
                spec[key] = tuple(value)
        # A recipe says where a thing stands as two numbers, because almost everything in the kit
        # stands on something. A few things hang in the air — a pressure gauge on a wall, a panel
        # over a worktop — and take a height as well. Rather than every recipe having to know
        # which is which, the height the builder itself defaults to is used when the recipe does
        # not give one. Without this a gauge in a recipe was two numbers into a three-number slot,
        # which is a ValueError a hundred and five photographs into a run.
        spec["at"] = _fit_position(builder, spec.get("at"))
        if spec["at"] is None:
            del spec["at"]
        if "as_kind" in spec:
            spec["kind"] = spec.pop("as_kind")
        elif kind in TAKES_KIND and "kind" not in spec:
            pass
        made = builder(**spec)
        if lift:
            for obj in (made if isinstance(made, (list, tuple)) else [made]):
                obj.location = (obj.location[0], obj.location[1], obj.location[2] + lift)
    _cut_the_channel(recipe)
    cam = recipe.get("camera", {})
    phone_camera(scene,
                 look_at=tuple(cam.get("look_at", [0, 0, 0])),
                 height=cam.get("height", 0.42),
                 distance=cam.get("distance", 0.30),
                 lean_deg=cam.get("lean_deg", 0.0),
                 mm=cam.get("mm", 26.0))
    light_for(scene, recipe.get("light", "window_left"),
              indoors=mode != "outdoor", enclosed=bool(indoors))
    if mode == "outdoor" and recipe.get("sky", True) and recipe.get("light") not in ("night",
                                                                                     "night_lamp"):
        world.sky(scene, turbidity=6.0 if recipe.get("light") == "overcast" else 3.0,
                  elevation_deg={"low_sun": 9.0, "fog_dawn": 6.0}.get(recipe.get("light")),
                  strength=1.0 if recipe.get("light") != "overcast" else 1.5)
    return scene


def render(recipe, res, samples, out_dir):
    """Render the scene to a scene-linear negative and stop there.

    The negative is half-float OpenEXR, so nothing above white is thrown away before the
    highlight rolloff has had a chance to roll it off. What a camera does to light on its way to
    a JPEG is a separate step, in blender/photos/develop.py, run by plain Python afterwards.
    Keeping the two apart means the sensor can be re-judged and re-run over the whole set in a
    minute rather than re-rendering four hours of geometry.
    """
    scene = build(recipe)
    w, h = recipe.get("size", [1200, 1600])
    if max(w, h) != res:
        s = res / max(w, h)
        w, h = max(1, round(w * s)), max(1, round(h * s))
    common.render_settings(scene, w, h, samples=samples, transparent=False,
                           file_format="OPEN_EXR")
    scene.render.image_settings.color_depth = "16"      # half float
    scene.render.image_settings.exr_codec = "ZIP"
    scene.view_settings.view_transform = "Raw"          # scene-linear, unbounded, nothing clipped
    scene.view_settings.exposure = 0.0
    raw = os.path.join(out_dir, recipe["id"] + ".exr")
    common.render(scene, raw)
    with open(os.path.join(out_dir, recipe["id"] + ".shot.json"), "w", encoding="utf-8") as f:
        json.dump({
            "id": recipe["id"], "by": recipe.get("by", "noor"),
            "light": recipe.get("light", "window_left"),
            "seed": recipe.get("seed", 1), "handheld": recipe.get("handheld", 0.0),
            "quality": recipe.get("quality", 86),
            "surface": recipe.get("surface"),
            "objects": [o["kind"] for o in recipe.get("objects", [])],
            "camera": recipe.get("camera"), "res": [w, h], "samples": samples,
        }, f, indent=1)
    return raw


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--res", type=int, default=1200)
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--build-only", action="store_true",
                    help="build every scene and render none of them, so a recipe that cannot be "
                         "built is a minute rather than a hundred photographs into a run")
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--recipes", default=RECIPES,
                    help="where the recipes are; the video shots are the same shape")
    args = ap.parse_args(argv)

    names = []
    if args.only:
        names = [args.only]
    elif args.all:
        names = [os.path.splitext(f)[0] for f in sorted(os.listdir(args.recipes)) if f.endswith(".json")]
    if not names:
        raise SystemExit("still.py: pass --only <id> or --all")
    os.makedirs(args.out, exist_ok=True)
    if args.build_only:
        broken = []
        for name in names:
            with open(os.path.join(args.recipes, name + ".json"), encoding="utf-8") as f:
                recipe = json.load(f)
            recipe.setdefault("id", name)
            try:
                build(recipe)
            except Exception as e:                       # noqa: BLE001 — any failure is the point
                broken.append(f"{name}: {type(e).__name__}: {e}")
                print(f"still: {name} CANNOT BE BUILT — {type(e).__name__}: {e}", flush=True)
        print(f"still: {len(names) - len(broken)} of {len(names)} scenes build", flush=True)
        raise SystemExit(1 if broken else 0)
    for name in names:
        path = os.path.join(args.out, name + ".exr")
        # develop.py deletes the negative once it has developed it, so a negative on disk means a
        # render in flight and a photograph on disk means one that is finished. Looking only for
        # the negative made --skip-existing skip nothing at all after the first develop pass, and
        # re-exposing a hundred and fifteen photographs to get at eighteen is two and a half hours
        done = os.path.join(args.out, name + ".jpg")
        if args.skip_existing and (os.path.exists(path) or os.path.exists(done)):
            print(f"still: {name} already rendered")
            continue
        with open(os.path.join(args.recipes, name + ".json"), encoding="utf-8") as f:
            recipe = json.load(f)
        recipe.setdefault("id", name)
        import time
        t0 = time.time()
        render(recipe, args.res, args.samples, args.out)
        print(f"still: {name} exposed in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
