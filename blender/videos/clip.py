"""blender/videos/clip.py — the fourteen videos the year refers to, rendered as moving pictures.

    bash blender/run.sh blender/videos/clip.py -- --only 2026-08_rain_canal --res 480 --fps 12
    bash blender/run.sh blender/videos/clip.py -- --all --res 480 --samples 20 --fps 12

A video in the thread is not a photograph that plays. Every one of these fourteen sentences is a
fixed shot of something that will not hold still — rain running down glass, a sheet snapping on a
line, a canal pocked with rings, soup at a slow simmer — so the thing that moves has to actually
move, in the same room, under the same light, in front of the same camera the photographs use.

So a clip is composed exactly like a still (blender/photos/compose.py reads its sentence into the
same recipe), built exactly like a still (still.build), and then the sentence is read a second
time for what is moving in it. The motions are modifiers and keyframes on what the kit already
built: a wave across the water, a wave through the cloth, a needle turning, a sponge rising, a
boat crossing. Nothing is composited, nothing is a loop of one frame, and the camera is held by a
hand for the whole take like the photographs are.

Frames come out as scene-linear negatives and go through blender/photos/camera.py one at a time,
with the sensor's noise seed moving between them, because grain that does not move is not grain.
ffmpeg puts them together. The clip's true length is written back into seed/videos/index.*.json,
so the note in the thread says how long the file it is holding actually is.
"""
import argparse
import json
import math
import os
import subprocess
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "photos"))

from rig import common  # noqa: E402
import still            # noqa: E402

ROOT = common.repo_root()
SHOTS = os.path.join(HERE, "shots")
INDEX = os.path.join(ROOT, "seed", "videos")
OUT = os.path.join(ROOT, "seed", "videos")
FFMPEG = os.path.join(ROOT, "toolchain", "ffmpeg", "ffmpeg")


# ---- what is moving ---------------------------------------------------------------------------
def moving_in(text, kinds):
    """What the sentence says will not hold still, as motions this file knows how to make.

    The sentence is the same one the composer read for what is in the shot; this reads it for what
    that thing is doing. A motion is only returned when something in the scene can carry it —
    there is no point animating water in a shot that has none.
    """
    t = text.lower()
    out = []

    def has(*words):
        return any(w in t for w in words)

    if "water" in kinds:
        if has("rain", "sleet", "shower", "rings", "pocked", "drops"):
            out.append({"do": "ripple", "on": "water", "scale": 0.055, "height": 0.010, "speed": 0.9})
        elif has("wake", "churn", "boil", "propeller"):
            out.append({"do": "ripple", "on": "water", "scale": 0.14, "height": 0.030, "speed": 1.6})
        else:
            out.append({"do": "ripple", "on": "water", "scale": 0.30, "height": 0.012, "speed": 0.35})
    if has("snapping", "gusts", "wind", "flapping", "billow", "fills"):
        for k in ("cloth", "sheet", "rope", "wood"):
            if k in kinds:
                out.append({"do": "flutter", "on": k, "height": 0.022, "speed": 1.5})
                break
    if has("simmer", "bubbl", "boiling"):
        for k in ("pan", "bowl", "mug"):
            if k in kinds:
                out.append({"do": "ripple", "on": k, "scale": 0.020, "height": 0.0022, "speed": 1.1})
                break
    if has("rising", "rises", "prov"):
        for k in ("cake", "loaf"):
            if k in kinds:
                out.append({"do": "rise", "on": k, "by": 0.22})
                break
    if has("needle", "gauge", "dial", "pressure"):
        if "gauge" in kinds:
            out.append({"do": "tremble", "on": "gauge", "degrees": 3.2, "speed": 2.6})
    if has("passing", "passes", "crossing", "going past", "pass each other"):
        for k in ("car", "crate", "post"):
            if k in kinds:
                out.append({"do": "cross", "on": k, "metres": 2.4})
                break
    if has("strip", "ribbon", "streamer", "knotted"):
        for k in ("sheet", "cloth"):
            if k in kinds:
                out.append({"do": "flutter", "on": k, "height": 0.014, "speed": 3.4})
                break
    return out


def _targets(name_hint):
    """The objects the kit made for one recipe entry, found by the name it gave them."""
    hit = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if obj.name.lower().startswith(name_hint) or name_hint in obj.name.lower():
            hit.append(obj)
    return hit


def apply_motion(spec, frames, fps):
    """One motion, as a modifier or a pair of keyframes on what the kit built."""
    kind = spec["do"]
    objs = _targets(spec["on"])
    if not objs:
        return False
    obj = max(objs, key=lambda o: len(o.data.vertices))

    if kind in ("ripple", "flutter"):
        # A wave modifier is driven by the scene frame itself, so the surface is genuinely a
        # different shape in every frame rather than one shape shifted sideways.
        if len(obj.data.vertices) < 400:
            # a four-vertex plane has nothing to displace; give it a grid first
            sub = obj.modifiers.new("grid", "SUBSURF")
            sub.subdivision_type = "SIMPLE"
            sub.levels = sub.render_levels = 5
        w = obj.modifiers.new(kind, "WAVE")
        w.use_normal = True
        w.height = float(spec.get("height", 0.01))
        w.width = float(spec.get("scale", 0.1))
        w.narrowness = 1.6
        w.speed = float(spec.get("speed", 1.0)) * 0.02
        w.start_position_x = float(np.random.default_rng(len(obj.name)).uniform(-0.4, 0.4))
        w.time_offset = 0
        if kind == "flutter":
            w.use_cyclic = True
            w.use_x, w.use_y = True, False
        return True

    if kind == "rise":
        by = float(spec.get("by", 0.2))
        obj.scale = (obj.scale[0], obj.scale[1], obj.scale[2])
        obj.keyframe_insert("scale", frame=1)
        obj.scale = (obj.scale[0], obj.scale[1], obj.scale[2] * (1.0 + by))
        obj.keyframe_insert("scale", frame=frames)
        return True

    if kind == "tremble":
        deg = math.radians(float(spec.get("degrees", 3.0)))
        speed = float(spec.get("speed", 2.5))
        rng = np.random.default_rng(7)
        base = obj.rotation_euler[2]
        for f in range(1, frames + 1):
            t = (f - 1) / fps
            obj.rotation_euler[2] = base + deg * (
                math.sin(t * speed * 2 * math.pi) * 0.6
                + math.sin(t * speed * 5.3 * math.pi + 1.1) * 0.4
            ) + deg * 0.2 * float(rng.normal())
            obj.keyframe_insert("rotation_euler", index=2, frame=f)
        return True

    if kind == "cross":
        d = float(spec.get("metres", 2.0))
        x, y, z = obj.location
        obj.location = (x - d * 0.5, y, z)
        obj.keyframe_insert("location", frame=1)
        obj.location = (x + d * 0.5, y, z)
        obj.keyframe_insert("location", frame=frames)
        return True
    return False


def hold_by_hand(scene, frames, fps, amount, seed):
    """The camera, held rather than mounted, for the length of the take.

    Two frequencies: a slow wander nobody notices and a small tremor everybody does. The still
    camera gets the same treatment as a blur in development; a video has to have it in the
    geometry, because between two frames it is parallax rather than softness.
    """
    cam = scene.camera
    rng = np.random.default_rng(seed)
    base_loc = tuple(cam.location)
    base_rot = tuple(cam.rotation_euler)
    drift = rng.normal(size=3) * 0.5
    tremor_hz = rng.uniform(1.6, 2.6, size=3)
    phase = rng.uniform(0, 2 * math.pi, size=3)
    slow_hz = rng.uniform(0.10, 0.22, size=3)
    slow_phase = rng.uniform(0, 2 * math.pi, size=3)
    a = 0.0032 * (0.6 + amount)
    for f in range(1, frames + 1):
        t = (f - 1) / fps
        off = [
            a * (math.sin(2 * math.pi * slow_hz[i] * t + slow_phase[i]) * 2.2
                 + math.sin(2 * math.pi * tremor_hz[i] * t + phase[i]) * 0.5
                 + drift[i] * t * 0.10)
            for i in range(3)
        ]
        cam.location = tuple(base_loc[i] + off[i] for i in range(3))
        cam.rotation_euler = tuple(base_rot[i] + off[i] * 0.55 for i in range(3))
        cam.keyframe_insert("location", frame=f)
        cam.keyframe_insert("rotation_euler", frame=f)


# ---- the take ----------------------------------------------------------------------------------
def shoot(recipe, entry, res, samples, fps, out_dir, frames_dir):
    seconds = float(entry["duration_ms"]) / 1000.0
    frames = max(2, int(round(seconds * fps)))
    scene = still.build(recipe)
    kinds = {o["kind"] for o in recipe.get("objects", [])}
    motions = moving_in(entry["scene"], kinds)
    made = [m for m in motions if apply_motion(m, frames, fps)]
    hold_by_hand(scene, frames, fps, float(recipe.get("handheld", 0.3)), recipe.get("seed", 1))

    w, h = recipe.get("size", [1600, 900])
    if max(w, h) != res:
        s = res / max(w, h)
        w, h = max(2, round(w * s)), max(2, round(h * s))
    w, h = w - (w % 2), h - (h % 2)          # h264 wants even sides
    common.render_settings(scene, w, h, samples=samples, transparent=False,
                           file_format="OPEN_EXR")
    scene.render.image_settings.color_depth = "16"
    scene.render.image_settings.exr_codec = "ZIP"
    scene.view_settings.view_transform = "Raw"
    scene.view_settings.exposure = 0.0
    scene.frame_start, scene.frame_end = 1, frames

    os.makedirs(frames_dir, exist_ok=True)
    for f in range(1, frames + 1):
        scene.frame_set(f)
        common.render(scene, os.path.join(frames_dir, f"{f:04d}.exr"))
    with open(os.path.join(frames_dir, "take.json"), "w", encoding="utf-8") as fh:
        json.dump({
            "id": entry["id"], "by": entry.get("by", "noor"),
            "light": recipe.get("light", "window_left"),
            "seed": recipe.get("seed", 1), "handheld": recipe.get("handheld", 0.0),
            "res": [w, h], "fps": fps, "frames": frames, "samples": samples,
            "seconds": round(frames / fps, 3),
            "moving": [m["do"] + " the " + m["on"] for m in made],
            "asked_for": [m["do"] + " the " + m["on"] for m in motions],
            "from_scene": entry["scene"],
        }, fh, indent=1)
    return frames


def main():
    argv = common.argv()
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--res", type=int, default=480)
    ap.add_argument("--samples", type=int, default=20)
    ap.add_argument("--fps", type=int, default=12)
    ap.add_argument("--skip-existing", action="store_true")
    ap.add_argument("--frames-dir", default=os.path.join(ROOT, "scratch", "clips"))
    args = ap.parse_args(argv)

    entries = []
    import glob as _glob
    for f in sorted(_glob.glob(os.path.join(INDEX, "index.*.json"))):
        with open(f, encoding="utf-8") as fh:
            entries.extend(json.load(fh))
    if args.only:
        entries = [e for e in entries if e["id"] == args.only]
    elif not args.all:
        raise SystemExit("clip.py: pass --only <id> or --all")

    import time
    for entry in entries:
        frames_dir = os.path.join(args.frames_dir, entry["id"])
        if args.skip_existing and os.path.exists(os.path.join(frames_dir, "take.json")):
            print(f"clip: {entry['id']} already shot", flush=True)
            continue
        with open(os.path.join(SHOTS, entry["id"] + ".json"), encoding="utf-8") as fh:
            recipe = json.load(fh)
        recipe.setdefault("id", entry["id"])
        t0 = time.time()
        n = shoot(recipe, entry, args.res, args.samples, args.fps, OUT, frames_dir)
        print(f"clip: {entry['id']} {n} frames in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
