#!/usr/bin/env python3
"""Gather what capture.sh produced into the three files the evidence set is read through.

  evidence/frames.json   what every clip actually is: frame count, rate, dropped frames, and the
                         scroll timings, with the device they came off
  evidence/MANIFEST.json every artifact, its size, and — for the ones that are missing — why

Nothing is invented here. An artifact that was not captured is listed as missing with the reason
capture.sh gave, and the previous session's copy is left where it is rather than being passed off
as this session's.

DIFF.json and the baseline under evidence/.previous/ are not written here. tools/check/diff.py
owns both: it measures each artifact against the baseline and, when asked, rotates the baseline
afterwards. This used to do both as well, after diff.py had already rotated, which is how every
SSIM in DIFF.json came to be a file compared with itself.
"""
import argparse
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "evidence"
LOGS = EVIDENCE / "logs"

STILLS = [
    "01_pulse.png", "02_chat.png", "03_us.png", "04_moments.png", "05_settings.png",
    "09_two_devices.png", "10_first_run.png", "12_search.png", "13_messenger_states.png",
    "14_media_viewer.png", "16_setup_android.png", "17_setup_pwa.png",
]
CLIPS = [
    "06_unfolding.mp4", "07_feeling_landing.mp4", "08_state_propagating.mp4",
    "11_chat_scroll.mp4", "15_authored_feeling.mp4",
]
MINIMUMS = {
    "01_pulse.png": (1440, 3120), "02_chat.png": (1440, 3120), "03_us.png": (1440, 3120),
    "04_moments.png": (1440, 3120), "05_settings.png": (1440, 3120),
    "09_two_devices.png": (3840, 2160), "10_first_run.png": (1440, 3120),
    "12_search.png": (1440, 3120), "13_messenger_states.png": (1440, 3120),
    "14_media_viewer.png": (1440, 3120), "16_setup_android.png": (1440, 3120),
    "17_setup_pwa.png": (1440, 3120),
    "06_unfolding.mp4": (1080, 2340), "07_feeling_landing.mp4": (1080, 2340),
    "08_state_propagating.mp4": (1080, 2340), "11_chat_scroll.mp4": (1080, 2340),
    "15_authored_feeling.mp4": (1080, 2340),
}
MIN_SECONDS = {
    "06_unfolding.mp4": 4, "07_feeling_landing.mp4": 6, "08_state_propagating.mp4": 8,
    "11_chat_scroll.mp4": 4, "15_authored_feeling.mp4": 4,
}


def _stamp_of(path):
    import datetime as dt
    return dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ")


def png_size(path):
    from PIL import Image
    with Image.open(path) as im:
        return list(im.size)


def probe(path):
    ffprobe = ROOT / "toolchain" / "ffmpeg" / "ffprobe"
    out = subprocess.run(
        [str(ffprobe), "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height,nb_frames,r_frame_rate,duration", "-of", "json", str(path)],
        capture_output=True, text=True,
    )
    try:
        s = json.loads(out.stdout)["streams"][0]
    except Exception:
        return {}
    num, _, den = s.get("r_frame_rate", "0/1").partition("/")
    fps = float(num) / float(den or 1) if float(den or 1) else 0.0
    return {
        "size": [int(s.get("width", 0)), int(s.get("height", 0))],
        "frames": int(s.get("nb_frames", 0) or 0),
        "fps": round(fps, 2),
        "seconds": round(float(s.get("duration", 0) or 0), 2),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stamp", required=True)
    ap.add_argument("--missing", default="")
    ap.add_argument("--browser", default="webkit")
    args = ap.parse_args()

    reasons = {}
    if args.missing and pathlib.Path(args.missing).exists():
        for line in pathlib.Path(args.missing).read_text().splitlines():
            if "|" in line:
                name, why = line.split("|", 1)
                reasons[name.strip()] = why.strip()

    manifest = {"captured_at": args.stamp, "browser": args.browser, "artifacts": {}, "missing": {}}

    stamp_s = None
    try:
        import datetime as _dt
        stamp_s = _dt.datetime.strptime(args.stamp, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=_dt.timezone.utc).timestamp()
    except Exception:
        pass

    for name in STILLS + CLIPS:
        path = EVIDENCE / name
        key = name.rsplit(".", 1)[0]
        why = reasons.get(name) or reasons.get(key)
        # A scene that failed is a missing artifact, whatever is on disk. This is the whole reason
        # the file exists: 13_messenger_states failed four runs in a row and the manifest listed it
        # as captured every time, because a copy of it from five hours earlier was still sitting
        # there. That is not evidence of anything this session did — it is exactly the substitution
        # the brief forbids, made by accident.
        if why:
            manifest["missing"][name] = why
            if path.exists():
                manifest["missing"][name] += (
                    f" (a copy from an earlier run is still on disk, written "
                    f"{_stamp_of(path)}; it is not this session's and is not counted)")
            continue
        if not path.exists():
            manifest["missing"][name] = reasons.get("__default__") or "not captured this session"
            continue
        entry = {"bytes": path.stat().st_size, "written": _stamp_of(path)}
        # and one that nothing reported on, but which predates this run, is stale rather than fresh
        if stamp_s is not None and path.stat().st_mtime < stamp_s - 5:
            entry["from_this_run"] = False
            manifest.setdefault("stale", {})[name] = (
                f"on disk from {_stamp_of(path)}, before this capture began at {args.stamp}")
        else:
            entry["from_this_run"] = True
        if name.endswith(".png"):
            entry["size"] = png_size(path)
        else:
            entry.update(probe(path))
        want = MINIMUMS.get(name)
        if want and entry.get("size"):
            entry["meets_minimum"] = entry["size"][0] >= want[0] and entry["size"][1] >= want[1]
            entry["minimum"] = list(want)
        if name in MIN_SECONDS:
            entry["minimum_seconds"] = MIN_SECONDS[name]
            entry["long_enough"] = entry.get("seconds", 0) >= MIN_SECONDS[name]
        manifest["artifacts"][name] = entry


    # frames.json: what every clip is made of, and where the frames came from
    frames = {"captured_at": args.stamp, "source": args.browser, "clips": {}, "scroll": {}}
    for name in CLIPS:
        log = LOGS / f"{name.rsplit('.', 1)[0]}.frames.json"
        if log.exists():
            frames["clips"][name] = json.loads(log.read_text())
    scroll_log = LOGS / "11_chat_scroll.json"
    if scroll_log.exists():
        s = json.loads(scroll_log.read_text())
        frames["scroll"] = {
            "source": args.browser,
            "viewport": s.get("viewport"),
            "cold_ms": s.get("cold_ms"),
            "steps": s.get("steps"),
        }
    emulator = LOGS / "scroll_emulator.json"
    if emulator.exists():
        frames["scroll_emulator"] = json.loads(emulator.read_text())
    else:
        frames["scroll_emulator"] = {"missing": reasons.get("frames.json") or "no Android device was up in this session"}

    (EVIDENCE / "frames.json").write_text(json.dumps(frames, indent=1) + "\n")
    (EVIDENCE / "MANIFEST.json").write_text(json.dumps(manifest, indent=1) + "\n")

    have = len(manifest["artifacts"])
    print(f"· {have} of {len(STILLS) + len(CLIPS)} artifacts present")
    for name, why in sorted(manifest["missing"].items()):
        print(f"    {name}: {why}")


if __name__ == "__main__":
    main()
