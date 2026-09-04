"""blender/videos/cut.py — the negatives from a take, developed and cut into the file.

    python3 blender/videos/cut.py --all
    python3 blender/videos/cut.py --only 2026-08_rain_canal

blender/videos/clip.py exposes a take: one scene-linear negative per frame, and a sidecar saying
whose phone held it and what the light was. This runs every frame through the same sensor the
photographs go through (blender/photos/camera.py), so a video and a photograph taken by the same
person on the same day have the same grain, the same vignette, the same colour — and then hands
the sequence to ffmpeg.

The sensor's noise seed moves frame to frame. Grain that holds still across a clip is the single
clearest tell that a video is a still with something wiggling on top of it.

Out of it come the two files the seed loader asks for: <id>.mp4 and <id>.poster.jpg. The clip's
real length goes back into seed/videos/index.*.json, so the thread cannot say seven seconds over
a file that runs two.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "blender", "photos"))

import camera            # noqa: E402
from develop import read_exr  # noqa: E402

TAKES = os.path.join(ROOT, "scratch", "clips")
POSTERS = os.path.join(ROOT, "scratch", "posters")
OUT = os.path.join(ROOT, "seed", "videos")
FFMPEG = os.path.join(ROOT, "toolchain", "ffmpeg", "ffmpeg")


def develop_take(take_dir, work):
    with open(os.path.join(take_dir, "take.json"), encoding="utf-8") as f:
        take = json.load(f)
    negatives = sorted(glob.glob(os.path.join(take_dir, "[0-9]" * 4 + ".exr")))
    if not negatives:
        raise SystemExit(f"cut.py: no negatives in {take_dir}")
    os.makedirs(work, exist_ok=True)
    for i, path in enumerate(negatives):
        rgb = camera.develop(
            read_exr(path),
            by=take.get("by", "noor"),
            light=take.get("light", "window_left"),
            # the sensor is the same one; the noise on it is not the same noise twice
            seed=int(take.get("seed", 1)) * 1000 + i,
            handheld=float(take.get("handheld", 0.0)),
        )
        Image.fromarray(rgb, "RGB").save(os.path.join(work, f"{i + 1:04d}.png"))
    return take, len(negatives)


def encode(work, take, out_dir):
    fps = int(take.get("fps", 12))
    mp4 = os.path.join(out_dir, take["id"] + ".mp4")
    poster = os.path.join(out_dir, take["id"] + ".poster.jpg")
    subprocess.run([
        FFMPEG, "-v", "error", "-y",
        "-framerate", str(fps), "-i", os.path.join(work, "%04d.png"),
        # a phone writes h264 in a container a browser and an Android view will both open
        "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
        "-crf", "24", "-preset", "slow",
        "-movflags", "+faststart",
        # play it back at the rate it was shot rather than at the rate it was rendered
        "-r", str(fps),
        mp4,
    ], check=True)
    # The poster is the frame the thread shows before anybody plays anything, so it is the part
    # of a video most likely to be looked at closely — and a clip has to be small to render at
    # all. Where the same scene has been exposed as a still at a proper size, that is the poster;
    # otherwise it is a frame out of the clip, a little way in.
    shot = os.path.join(POSTERS, take["id"] + ".jpg")
    if os.path.exists(shot):
        shutil.copy2(shot, poster)
    else:
        at = max(1, int(take.get("frames", 1) * 0.18))
        Image.open(os.path.join(work, f"{at:04d}.png")).save(poster, "JPEG", quality=84,
                                                             subsampling=2, optimize=True)
    return mp4, poster


def write_back_duration(video_id, seconds):
    """The note in the thread says how long the file is, so the file decides."""
    for path in sorted(glob.glob(os.path.join(OUT, "index.*.json"))):
        with open(path, encoding="utf-8") as f:
            entries = json.load(f)
        touched = False
        for e in entries:
            if e["id"] == video_id and e.get("duration_ms") != round(seconds * 1000):
                e["duration_ms"] = round(seconds * 1000)
                touched = True
        if touched:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(entries, f, indent=1)
            return True
    return False


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--takes", default=TAKES)
    ap.add_argument("--keep-frames", action="store_true")
    a = ap.parse_args(argv)

    names = []
    if a.only:
        names = [a.only]
    elif a.all:
        names = sorted(d for d in os.listdir(a.takes)
                       if os.path.exists(os.path.join(a.takes, d, "take.json")))
    if not names:
        raise SystemExit("cut.py: pass --only <id> or --all")
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        take_dir = os.path.join(a.takes, name)
        work = os.path.join(take_dir, "developed")
        take, n = develop_take(take_dir, work)
        mp4, poster = encode(work, take, OUT)
        secs = n / int(take.get("fps", 12))
        write_back_duration(name, secs)
        size = os.path.getsize(mp4) / 1e6
        print(f"cut: {name} {n} frames, {secs:.1f}s, {size:.2f} MB"
              f"{'  moving: ' + ', '.join(take['moving']) if take.get('moving') else '  (still)'}",
              flush=True)
        if not a.keep_frames:
            shutil.rmtree(work, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
