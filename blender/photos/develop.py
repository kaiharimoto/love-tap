"""blender/photos/develop.py — turn the negatives into the photographs.

    python3 blender/photos/develop.py --all
    python3 blender/photos/develop.py --only 2026-08_bread_loaf

still.py renders a sixteen-bit negative and a sidecar saying whose phone took it and what the
light was. This applies blender/photos/camera.py to it and writes the JPEG the seed loader reads.
Splitting it out is what makes the camera itself judgeable: a change to the sensor is a second's
work over a hundred and fifteen negatives rather than four hours of re-rendering.
"""
import argparse
import glob
import json
import os
import re
import sys

import subprocess

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import camera            # noqa: E402
from rig import manifest  # noqa: E402

OUT = os.path.join(ROOT, "seed", "photos")
FFMPEG = os.path.join(ROOT, "toolchain", "ffmpeg", "ffmpeg")


def read_exr(path):
    """Scene-linear float from the negative.

    Pillow cannot read a sixteen-bit-per-channel image without quietly truncating it to eight,
    and eight bits of a linear image is banding in every gradient, so the decode goes through
    ffmpeg into raw planar float instead.
    """
    probe = subprocess.run([FFMPEG, "-i", path], capture_output=True, text=True)
    m = re.search(r"(\d{2,5})x(\d{2,5})", probe.stderr)
    if not m:
        raise SystemExit("develop.py: could not read the size of " + path)
    w, h = int(m.group(1)), int(m.group(2))
    out = subprocess.run([FFMPEG, "-v", "error", "-i", path, "-f", "rawvideo",
                          "-pix_fmt", "gbrpf32le", "-"], capture_output=True, check=True)
    planes = np.frombuffer(out.stdout, dtype="<f4")
    if planes.size != w * h * 3:
        raise SystemExit(f"develop.py: {path} decoded to {planes.size} samples, not {w*h*3}")
    g, b, r = (planes[i * w * h:(i + 1) * w * h].reshape(h, w) for i in range(3))
    return np.stack([r, g, b], axis=-1).astype(np.float64)


# What a photograph has to have in it before it is one. These are measured on the negative, which
# is scene-linear, so they are exposure and structure rather than taste.
FLOOR_MEDIAN = 0.004      # below this the frame is dark enough that development is guesswork
FLOOR_P99 = 0.020         # nothing in the frame is lit at all
FLOOR_RANGE = 0.010       # p99 minus p1: a frame this flat is one colour, not a picture


def look_at_the_negative(a):
    """Whether this is a photograph, said in one sentence, or None if it is.

    A sealed room lit by a sun outside it renders black, and a camera aimed into the sky over an
    empty plane renders a flat grey field. Both develop without complaint into a file of the right
    size with the right name, and the only way anyone finds out is by opening a hundred and
    fifteen of them. So the negative is looked at before it is developed.
    """
    med = float(np.median(a))
    p1, p99 = (float(x) for x in np.percentile(a, [1, 99]))
    if med < FLOOR_MEDIAN and p99 < FLOOR_P99:
        return (f"the frame is empty: median {med:.5f}, brightest percentile {p99:.5f}. "
                f"Nothing in this scene is lit — check that the light can reach it.")
    if p99 - p1 < FLOOR_RANGE:
        return (f"the frame is one flat value: the 1st and 99th percentiles are {p1:.4f} and "
                f"{p99:.4f}. There is nothing in shot.")
    return None


# And what the photograph has to have in it once the sensor has been applied. Three frames passed
# the check on the negative and developed to a flat dark rectangle anyway: the linear range was
# there, and the tone curve put all of it inside four grey levels.
FLOOR_DEVELOPED_STD = 6.0


def look_at_the_photograph(rgb):
    """Whether a developed frame is a picture, said in one sentence, or None if it is."""
    grey = np.asarray(rgb, dtype=np.float64) @ (0.2126, 0.7152, 0.0722)
    std = float(grey.std())
    if std < FLOOR_DEVELOPED_STD:
        return (f"it developed flat: {std:.1f} grey levels of variation across the whole frame, "
                f"mean {grey.mean():.0f}. There is a picture in the negative and none in this.")
    return None


def develop_one(raw_path, out_path, shot, strict=True):
    a = read_exr(raw_path)
    wrong = look_at_the_negative(a)
    if wrong:
        if strict:
            raise ValueError(wrong)
        print(f"develop: {os.path.basename(raw_path)} — {wrong}", flush=True)
    rgb = camera.develop(a, by=shot.get("by", "noor"), light=shot.get("light", "window_left"),
                         seed=shot.get("seed", 1), handheld=shot.get("handheld", 0.0))
    flat = look_at_the_photograph(rgb)
    if flat:
        if strict:
            raise ValueError(flat)
        print(f"develop: {os.path.basename(raw_path)} — {flat}", flush=True)
    Image.fromarray(rgb, "RGB").save(out_path, "JPEG", quality=shot.get("quality", 86),
                                     subsampling=1, optimize=True)
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--dir", default=OUT)
    ap.add_argument("--out", default="")
    ap.add_argument("--keep-negatives", action="store_true")
    ap.add_argument("--anyway", action="store_true",
                    help="develop a negative that has nothing in it, and say so, rather than stop")
    args = ap.parse_args()
    out_dir = args.out or args.dir
    os.makedirs(out_dir, exist_ok=True)

    raws = sorted(glob.glob(os.path.join(args.dir, "*.exr")))
    if args.only:
        raws = [r for r in raws if os.path.basename(r).startswith(args.only + ".")]
    if not raws:
        raise SystemExit("develop.py: no negatives found in " + args.dir)
    empty = []
    for raw in raws:
        name = os.path.basename(raw)[:-len(".exr")]
        side = os.path.join(args.dir, name + ".shot.json")
        shot = {}
        if os.path.exists(side):
            with open(side, encoding="utf-8") as f:
                shot = json.load(f)
        out = os.path.join(out_dir, name + ".jpg")
        try:
            develop_one(raw, out, shot, strict=not args.anyway)
        except ValueError as e:
            empty.append(f"{name}: {e}")
            continue
        manifest.record(out, "blender/photos/still.py + blender/photos/develop.py", {
            "recipe": name, "light": shot.get("light"), "surface": shot.get("surface"),
            "objects": shot.get("objects"), "camera": shot.get("camera"),
            "sensor": "blender/photos/camera.py, " + str(shot.get("by")) + "'s phone",
            "res": shot.get("res"), "samples": shot.get("samples"),
            "rig": "blender/rig/common.py",
        }, kind="photo")
        print(f"develop: {name}  {os.path.getsize(out)//1024}kB", flush=True)
        if not args.keep_negatives:
            os.unlink(raw)
    if empty:
        # the negatives stay on disk: whatever is wrong is in the scene, and it is quicker to look
        # at the one that failed than to render it again to find out
        print(f"\ndevelop: {len(empty)} negatives had nothing in them, and were not developed:")
        for line in empty:
            print("  " + line)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
