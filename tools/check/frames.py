#!/usr/bin/env python3
"""Checks and derivations over a captured frame sequence.

Every clip in the evidence set is a directory of PNGs taken one at a time with the app's driven
clock stepped between them. That makes three things checkable that a screen recording cannot
prove: that no frame was dropped (a dropped frame shows up as two identical neighbours), that the
motion actually moves (a still clip is a failure), and that the light never changes direction
mid-motion.

The rule on repeated frames is the brief's, word for word: a clip in which any frame is
pixel-identical to its predecessor is a failure. It used to be a tolerance — up to a third of a
clip could be frames the app did not draw — and every clip in the set leaned on it: twenty held
frames before a note opened, a hundred after a feeling had landed. A held frame is not a dropped
frame, but a reader cannot tell the two apart, so the scenes are cut to the motion instead and
this refuses the first still it finds.

  python3 tools/check/frames.py evidence/frames/06_unfolding --strip evidence/crops/06_strip.png \
      --log evidence/logs/06_unfolding.json

With --log, the scene's own log is read for the size of each clock step, so the report says what
one frame of the clip is worth in the app's time: these are app-time recordings, not wall-clock
ones, and a critic who reads them as real time is wrong by the ratio recorded here.
"""
import argparse
import json
import pathlib
import sys

import numpy as np
from PIL import Image


def load(path, scale=0.25):
    im = Image.open(path).convert("RGB")
    if scale != 1.0:
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.BILINEAR)
    return np.asarray(im, dtype=np.float32) / 255.0


def strip(paths, out, count=6, height=320):
    """A row of evenly spaced frames: what a critic looks at instead of the whole clip."""
    picks = [paths[round(i * (len(paths) - 1) / (count - 1))] for i in range(count)]
    ims = []
    for p in picks:
        im = Image.open(p).convert("RGB")
        w = round(im.width * height / im.height)
        ims.append(im.resize((w, height), Image.LANCZOS))
    total = sum(i.width for i in ims) + 4 * (len(ims) - 1)
    sheet = Image.new("RGB", (total, height), (28, 24, 20))
    x = 0
    for im in ims:
        sheet.paste(im, (x, 0))
        x += im.width + 4
    out = pathlib.Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    return [str(p) for p in picks]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--strip", default="")
    ap.add_argument("--fps", type=float, default=60.0)
    ap.add_argument("--out", default="")
    ap.add_argument("--min-seconds", type=float, default=0.0)
    ap.add_argument("--log", default="", help="the scene log, for the clock step behind each run")
    args = ap.parse_args()

    paths = sorted(pathlib.Path(args.dir).glob("*.png"))
    if not paths:
        print(json.dumps({"dir": args.dir, "frames": 0, "ok": False, "why": "no frames"}))
        return 1

    prev = load(paths[0])
    deltas = []
    means = []
    for p in paths[1:]:
        cur = load(p)
        deltas.append(float(np.abs(cur - prev).mean()))
        means.append(float(cur.mean()))
        prev = cur

    seconds = len(paths) / args.fps
    # A frame identical to the one before it is a frame the app did not draw. Some of those are
    # honest — a note that has finished moving is still, and a clip that holds on it for a moment
    # is a clip, not a fault — so what matters is that the motion itself has no gaps in it and that
    # most of the clip is moving.
    still = [i for i, d in enumerate(deltas) if d < 1e-4]
    moved = float(np.mean(deltas)) if deltas else 0.0
    runs = []
    run = 0
    for i, d in enumerate(deltas):
        if d < 1e-4:
            run += 1
        else:
            if run:
                runs.append(run)
            run = 0
    if run:
        runs.append(run)
    longest_still = max(runs) if runs else 0
    still_fraction = len(still) / max(1, len(deltas))
    # the light must not swing about mid-motion: overall brightness may drift, not jump
    jumps = [i for i in range(1, len(means)) if abs(means[i] - means[i - 1]) > 0.06]

    # What one frame is worth in the app's time, from the scene log: every `frames` run records
    # how many milliseconds the driven clock was stepped between two grabs.
    steps_ms = []
    app_ms = None
    if args.log and pathlib.Path(args.log).exists():
        try:
            scene_log = json.loads(pathlib.Path(args.log).read_text())
            for shot in scene_log.get("shots", []):
                if "frames" in shot:
                    steps_ms.append({"frames": shot["frames"], "step_ms": shot.get("ms"),
                                     "dir": shot.get("dir")})
            app_ms = sum(int(s["frames"]) * int(s["step_ms"] or 0) for s in steps_ms)
        except Exception:
            steps_ms = []

    report = {
        "dir": args.dir,
        "frames": len(paths),
        "fps": args.fps,
        "seconds": round(seconds, 2),
        "clock": "driven",
        "timebase": "app time: each frame is one step of the app's own clock, grabbed one at a "
                    "time; wall-clock time between grabs is not in the clip",
        "runs": steps_ms,
        "app_seconds": None if app_ms is None else round(app_ms / 1000.0, 2),
        "playback_over_app_time": None if not app_ms else round((seconds * 1000.0) / app_ms, 3),
        "mean_change_per_frame": round(moved, 5),
        "repeated_frames": len(still),
        "repeated_fraction": round(still_fraction, 3),
        "longest_still_run": longest_still,
        "repeated_at": still,
        "brightness_jumps": len(jumps),
        "ok": (moved > 1e-4 and not jumps and seconds >= args.min_seconds and not still),
    }
    if not report["ok"]:
        why = []
        if moved <= 1e-4:
            why.append("nothing moves in it at all")
        if jumps:
            why.append(f"the light jumps {len(jumps)} times")
        if seconds < args.min_seconds:
            why.append(f"{seconds:.1f}s is short of {args.min_seconds}s")
        if still:
            why.append(f"{len(still)} frame(s) identical to the one before (first at {still[0]}); "
                       f"the brief allows none")
        report["why"] = "; ".join(why)
    if args.strip:
        report["strip"] = args.strip
        report["strip_frames"] = strip(paths, args.strip)
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(report, indent=1))
    print(json.dumps(report, indent=1))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
