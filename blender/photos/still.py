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
def light_for(scene, kind):
    """The conditions a phone photograph is actually taken in, all off the one rig.

    Every daylight condition is the shared rig in blender/rig/common.py with its energy and its
    sky changed, so a photograph and the note it will be pinned beside agree about which way the
    light is coming from. The artificial ones are the lamps that are actually in these rooms.
    """
    if kind == "window_left":
        return common.add_daylight(scene)
    if kind == "overcast":
        sun, world_ = common.add_daylight(scene)
        sun.data.energy *= 0.42
        sun.data.angle = math.radians(24)          # a big soft source: cloud, not sun
        world_.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.6
        return sun, world_
    if kind == "hard_sun":
        sun, world_ = common.add_daylight(scene)
        sun.data.energy *= 1.7
        sun.data.angle = math.radians(0.53)        # the sun's actual angular size
        return sun, world_
    if kind == "low_sun":
        sun, world_ = common.add_daylight(scene, elevation=9.0)
        sun.data.energy *= 1.25
        sun.data.color = (1.0, 0.78, 0.52)
        sun.data.angle = math.radians(0.6)
        return sun, world_
    if kind == "fog_dawn":
        sun, world_ = common.add_daylight(scene, elevation=6.0)
        sun.data.energy *= 0.5
        sun.data.angle = math.radians(30)
        world_.node_tree.nodes["Background"].inputs["Strength"].default_value = 2.4
        world.fog(density=0.030, colour=(0.60, 0.62, 0.65))
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
        return common._world(scene, (0.030, 0.034, 0.048), 0.30), None
    if kind == "night_lamp":
        w = common._world(scene, (0.020, 0.024, 0.038), 0.16)
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
        data.energy = 9.0
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


def build(recipe):
    scene = common.reset_scene()
    mode = recipe.get("mode", "tabletop")
    if recipe.get("room", mode == "tabletop"):
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
        if "as_kind" in spec:
            spec["kind"] = spec.pop("as_kind")
        elif kind in TAKES_KIND and "kind" not in spec:
            pass
        made = builder(**spec)
        if lift:
            for obj in (made if isinstance(made, (list, tuple)) else [made]):
                obj.location = (obj.location[0], obj.location[1], obj.location[2] + lift)
    cam = recipe.get("camera", {})
    phone_camera(scene,
                 look_at=tuple(cam.get("look_at", [0, 0, 0])),
                 height=cam.get("height", 0.42),
                 distance=cam.get("distance", 0.30),
                 lean_deg=cam.get("lean_deg", 0.0),
                 mm=cam.get("mm", 26.0))
    light_for(scene, recipe.get("light", "window_left"))
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
    ap.add_argument("--out", default=OUT)
    args = ap.parse_args(argv)

    names = []
    if args.only:
        names = [args.only]
    elif args.all:
        names = [os.path.splitext(f)[0] for f in sorted(os.listdir(RECIPES)) if f.endswith(".json")]
    if not names:
        raise SystemExit("still.py: pass --only <id> or --all")
    os.makedirs(args.out, exist_ok=True)
    for name in names:
        path = os.path.join(args.out, name + ".exr")
        if args.skip_existing and os.path.exists(path):
            print(f"still: {name} already rendered")
            continue
        with open(os.path.join(RECIPES, name + ".json"), encoding="utf-8") as f:
            recipe = json.load(f)
        recipe.setdefault("id", name)
        import time
        t0 = time.time()
        render(recipe, args.res, args.samples, args.out)
        print(f"still: {name} exposed in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
