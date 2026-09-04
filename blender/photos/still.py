"""blender/photos/still.py — the photographs in the thread, taken the way the two of them take them.

    bash blender/run.sh blender/photos/still.py -- --only 2026-08_soup_pan --res 900
    bash blender/run.sh blender/photos/still.py -- --all --res 1200 --samples 64

A recipe (blender/photos/recipes/*.json) names a surface, a light, where the camera is held, and
what is on the table. Everything it names is built by kit.py at real size and lit by the same rig
as the paper, so a photograph and the note it is pinned beside agree about where the light is.

The camera is a phone: a perspective lens around 26 mm equivalent, held at the height and lean a
person actually holds one at. That is why these do not read as product shots — nobody photographs
their own boiler from a tripod.

Output goes to seed/photos/<id>.jpg at the dimensions the month's index declares, because the seed
loader reads the size off the file and the thread lays the row out from it.
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

RECIPES = os.path.join(HERE, "recipes")
OUT = os.path.join(common.repo_root(), "seed", "photos")
SEED_INDEX = os.path.join(common.repo_root(), "seed", "photos")


# ------------------------------------------------------------------ light
def light_for(scene, kind):
    """The conditions a phone photograph is actually taken in, all off the one rig."""
    if kind == "window_left":
        return common.add_daylight(scene)
    if kind == "overcast":
        sun, world = common.add_daylight(scene)
        sun.data.energy *= 0.55
        world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.1
        return sun, world
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
        data.energy = 32.0
        data.color = (0.94, 1.0, 0.96)
        data.shape = "RECTANGLE"
        data.size = 1.2
        data.size_y = 0.08
        lamp = bpy.data.objects.new("strip", data)
        scene.collection.objects.link(lamp)
        lamp.location = (0.0, 0.10, 1.9)
        common._aim(lamp, (0, 0, -1))
        return common._world(scene, (0.62, 0.66, 0.64), 0.35), lamp
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
}


def build(recipe):
    scene = common.reset_scene()
    if recipe.get("surface"):
        kit.surface(recipe["surface"], size=recipe.get("surface_size", 1.2),
                    seed=recipe.get("seed", 1))
    for spec in recipe.get("objects", []):
        spec = dict(spec)
        kind = spec.pop("kind")
        builder = BUILDERS.get(kind)
        if builder is None:
            raise SystemExit(f"still.py: nothing in the kit called {kind!r}")
        # json gives lists; the kit wants tuples
        for key, value in list(spec.items()):
            if isinstance(value, list):
                spec[key] = tuple(value)
        builder(**spec)
    cam = recipe.get("camera", {})
    phone_camera(scene,
                 look_at=tuple(cam.get("look_at", [0, 0, 0])),
                 height=cam.get("height", 0.42),
                 distance=cam.get("distance", 0.30),
                 lean_deg=cam.get("lean_deg", 0.0),
                 mm=cam.get("mm", 26.0))
    light_for(scene, recipe.get("light", "window_left"))
    return scene


def render(recipe, res, samples, out_dir):
    scene = build(recipe)
    w, h = recipe.get("size", [1200, 1600])
    if max(w, h) != res:
        s = res / max(w, h)
        w, h = max(1, round(w * s)), max(1, round(h * s))
    common.render_settings(scene, w, h, samples=samples, transparent=False, file_format="JPEG")
    scene.render.image_settings.quality = 90
    path = os.path.join(out_dir, recipe["id"] + ".jpg")
    common.render(scene, path)
    manifest.record(path, "blender/photos/still.py", {
        "recipe": recipe["id"], "light": recipe.get("light"), "surface": recipe.get("surface"),
        "objects": [o["kind"] for o in recipe.get("objects", [])],
        "camera": recipe.get("camera"), "res": [w, h], "samples": samples,
        "rig": "blender/rig/common.py",
    }, kind="photo")
    return path


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
        path = os.path.join(args.out, name + ".jpg")
        if args.skip_existing and os.path.exists(path):
            print(f"still: {name} already rendered")
            continue
        with open(os.path.join(RECIPES, name + ".json"), encoding="utf-8") as f:
            recipe = json.load(f)
        recipe.setdefault("id", name)
        import time
        t0 = time.time()
        render(recipe, args.res, args.samples, args.out)
        print(f"still: {name} in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
