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

Pixel-identity turned out to be the wrong instrument for that rule. The gate was a mean absolute
difference below 1e-4 over the whole frame, which is a fortieth of one grey level averaged over
seven and a half million subpixels: a pair passes as moving if 2.55 per cent of them shift by a
single code value. Nothing dithers the frames on purpose — the sub-threshold motion is the fold
sequence's own ease-out, which brings the sheet to rest asymptotically and then stops changing its
height entirely while the source frames keep ticking. So a clip could end on fifty frames that a
reader sees as frozen and still be recorded as never repeating.

A held frame is now defined on what an eye can see, in grey levels of luma, and all three have to
be true at once:

  (a) mean absolute change over the whole frame     < 0.5
  (b) share of pixels changing by more than 2       < 0.15 per cent
  (c) the busiest 32x32 tile's mean absolute change < 2.0

(b) is the perceptual core — how much of the screen actually moved by a visible step. (c) is what
separates a frozen frame from genuinely slow motion: slow motion concentrates its change on a
moving edge, so some tile carries it, while a frozen frame spreads a few code values thinly over
everything. Global SSIM was measured against the same clips and does not separate the two classes
at all — the frozen tail of 06 scores higher on it than the fastest clip in the set.

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


def luma(rgb):
    """Rec.601 luma in grey levels, from the 0..1 RGB `load` returns."""
    return (0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]) * 255.0


def tile_max(d, tile=32):
    """The busiest tile's mean absolute change: what tells slow motion from a frozen frame."""
    h, w = d.shape
    hh, ww = (h // tile) * tile, (w // tile) * tile
    if hh == 0 or ww == 0:
        return float(d.mean())
    t = d[:hh, :ww].reshape(hh // tile, tile, ww // tile, tile)
    return float(t.mean(axis=(1, 3)).max())


# A held frame, in grey levels of luma. All three must be true at once; see the module docstring
# for where the numbers come from and why global SSIM is not one of them.
HELD_MEAN = 0.5
HELD_VISIBLE = 0.0015
HELD_TILE = 2.0


def held_frame(mean_delta, visible_share, busiest_tile):
    return mean_delta < HELD_MEAN and visible_share < HELD_VISIBLE and busiest_tile < HELD_TILE


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

    # Full resolution: at a quarter scale a sheet turning by half a pixel averaged to the same
    # image, and a clip that never stopped moving was failed for standing still.
    prev = load(paths[0], 1.0)
    prev_l = luma(prev)
    deltas = []          # mean absolute change per frame, in grey levels
    visible = []         # share of pixels that changed by more than two grey levels
    busiest = []         # the busiest 32x32 tile's mean absolute change
    means = []
    for p in paths[1:]:
        cur = load(p, 1.0)
        cur_l = luma(cur)
        d = np.abs(cur_l - prev_l)
        deltas.append(float(d.mean()))
        visible.append(float((d > 2.0).mean()))
        busiest.append(tile_max(d))
        means.append(float(cur.mean()))
        prev, prev_l = cur, cur_l

    seconds = len(paths) / args.fps
    # A frame identical to the one before it is a frame the app did not draw. Some of those are
    # honest — a note that has finished moving is still, and a clip that holds on it for a moment
    # is a clip, not a fault — so what matters is that the motion itself has no gaps in it and that
    # most of the clip is moving.
    held = [held_frame(deltas[i], visible[i], busiest[i]) for i in range(len(deltas))]
    still = [i for i, h in enumerate(held) if h]
    moved = float(np.mean(deltas)) if deltas else 0.0
    runs = []
    run = 0
    for i, h in enumerate(held):
        if h:
            run += 1
        else:
            if run:
                runs.append(run)
            run = 0
    if run:
        runs.append(run)
    longest_still = max(runs) if runs else 0
    mv = [i for i, h in enumerate(held) if not h]
    mv_mean = [deltas[i] for i in mv]
    mv_vis = [visible[i] for i in mv]
    mv_tile = [busiest[i] for i in mv]
    still_fraction = len(still) / max(1, len(deltas))
    # the light must not swing about mid-motion: overall brightness may drift, not jump
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

    # The first frame of a take is not the next frame of the one before it. A clip is shot in
    # runs — the thread, then Settings, then the thread again — and between two runs the app was
    # taken somewhere else on purpose. The light changing there is that cut, and the rule about
    # the light not changing is about the light not changing *while something is moving*. Every
    # other jump still fails, and a repeat at a boundary fails wherever it is: a cut that lands on
    # the same picture is not a cut.
    # means[i] is the mean of frame i+1, so the change between the last frame of one run and the
    # first of the next shows up one index earlier than the frame number.
    cuts = set()
    at = 0
    for run in steps_ms[:-1] if steps_ms else []:
        at += int(run["frames"])
        cuts.add(at - 1)
    jumps = [i for i in range(1, len(means))
             if abs(means[i] - means[i - 1]) > 0.06 and i not in cuts]

    report = {
        "dir": args.dir,
        "frames": len(paths),
        "fps": args.fps,
        "seconds": round(seconds, 2),
        "clock": "driven",
        "timebase": "app time: each frame is one step of the app's own clock, grabbed one at a "
                    "time; wall-clock time between grabs is not in the clip",
        "runs": steps_ms,
        "cuts_between_runs": sorted(cuts),
        "app_seconds": None if app_ms is None else round(app_ms / 1000.0, 2),
        "playback_over_app_time": None if not app_ms else round((seconds * 1000.0) / app_ms, 3),
        "mean_change_per_frame": round(moved, 5),
        "held_frame_test": {
            "unit": "grey levels of Rec.601 luma at full resolution",
            "all_three_must_hold": {
                "mean_abs_change_below": HELD_MEAN,
                "share_of_pixels_changing_more_than_two_below": HELD_VISIBLE,
                "busiest_32px_tile_mean_change_below": HELD_TILE,
            },
            # the least-moving frame that still counts as motion: how close the clip came
            "worst_moving_frame": {
                "mean": round(min(mv_mean), 4) if mv_mean else None,
                "visible_share": round(min(mv_vis), 6) if mv_vis else None,
                "busiest_tile": round(min(mv_tile), 4) if mv_tile else None,
            },
        },
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
