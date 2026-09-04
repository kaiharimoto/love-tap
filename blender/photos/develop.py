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


def develop_one(raw_path, out_path, shot):
    a = read_exr(raw_path)
    rgb = camera.develop(a, by=shot.get("by", "noor"), light=shot.get("light", "window_left"),
                         seed=shot.get("seed", 1), handheld=shot.get("handheld", 0.0))
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
    args = ap.parse_args()
    out_dir = args.out or args.dir
    os.makedirs(out_dir, exist_ok=True)

    raws = sorted(glob.glob(os.path.join(args.dir, "*.exr")))
    if args.only:
        raws = [r for r in raws if os.path.basename(r).startswith(args.only + ".")]
    if not raws:
        raise SystemExit("develop.py: no negatives found in " + args.dir)
    for raw in raws:
        name = os.path.basename(raw)[:-len(".exr")]
        side = os.path.join(args.dir, name + ".shot.json")
        shot = {}
        if os.path.exists(side):
            with open(side, encoding="utf-8") as f:
                shot = json.load(f)
        out = os.path.join(out_dir, name + ".jpg")
        develop_one(raw, out, shot)
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


if __name__ == "__main__":
    main()
