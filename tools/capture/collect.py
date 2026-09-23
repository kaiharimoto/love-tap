#!/usr/bin/env python3
"""Gather what capture.sh produced into the three files the evidence set is read through.

  evidence/frames.json   what every clip actually is: frame count, rate, dropped frames, and the
                         scroll timings, with the device they came off
  evidence/MANIFEST.json every artifact, its size, and — for the ones that are missing — why

evidence/DIFF.json is NOT written here, and neither is evidence/.previous rotated here. Both were,
and both had to stop. capture.sh runs `tools/check/diff.py --rotate` first — which measures this
capture against the baseline and only then makes this capture the new baseline — and this file then
ran second, recomputed SSIM against the baseline that had just been rotated to hold this very
capture, and overwrote the correct file with a column of 1.0s. Every still in every DIFF.json this
build ever shipped read `ssim: 1.0, unchanged` because each one was compared with itself, so the
brief's rule that a regression be caught and rolled back before the next cycle has never once run.
There is exactly one writer of DIFF.json and one rotator of .previous, and tools/check/diff_selftest.py
holds that to be true.

Nothing is invented here. An artifact that was not captured is listed as missing with the reason
capture.sh gave, and the previous session's copy is left where it is rather than being passed off
as this session's.
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
# How far before the run stamp a file may have been written and still count as this run's. The
# scenes start within a second or two of the stamp and a filesystem mtime is not the same clock,
# so a small slack is the difference between "written just before the stamp was taken" and
# "left here by an earlier session". It is named once because it is now asked twice -- of an
# artifact nothing reported on, and of an artifact a scene refused.
FRESH_TOLERANCE_S = 5
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
    ap.add_argument("--failed", default="",
                    help="`name|why` lines for checks that ran on an artifact that IS present and "
                         "failed. They go under `failed_checks`, never under `missing`: a still "
                         "whose chrome repeats a tear is a still that was measured and failed, not "
                         "a still that is not there.")
    ap.add_argument("--browser", default="webkit")
    ap.add_argument("--evidence", default=str(EVIDENCE),
                    help="where the artifacts are and where MANIFEST.json is written. Only the "
                         "selftest passes it; capture.sh uses the default. It exists because a "
                         "gate nothing can drive against a throwaway directory is a gate nothing "
                         "can re-break, and this one has now stated something false twice.")
    args = ap.parse_args()

    reasons = {}
    if args.missing and pathlib.Path(args.missing).exists():
        for line in pathlib.Path(args.missing).read_text().splitlines():
            if "|" in line:
                name, why = line.split("|", 1)
                reasons[name.strip()] = why.strip()

    evidence = pathlib.Path(args.evidence)
    logs = evidence / "logs"
    manifest = {"captured_at": args.stamp, "browser": args.browser, "artifacts": {}, "missing": {}}

    stamp_s = None
    try:
        import datetime as _dt
        stamp_s = _dt.datetime.strptime(args.stamp, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=_dt.timezone.utc).timestamp()
    except Exception:
        pass

    # A reason may arrive under either of two keys and they are not interchangeable. capture.sh's
    # run_scene calls note_missing with the BARE scene name -- `13_messenger_states` -- while
    # STILLS and CLIPS hold filenames. Both spellings have to resolve to the same artifact, in
    # both directions, or the manifest grows an entry for an artifact that does not exist.
    stems = {n.rsplit(".", 1)[0] for n in STILLS + CLIPS}

    for name in STILLS + CLIPS:
        path = evidence / name
        key = name.rsplit(".", 1)[0]
        # `or` was the bug, not a shorthand for it. A reason that is the EMPTY STRING is falsy, so
        # `reasons.get(name) or reasons.get(key)` fell through to None and the artifact was booked
        # as present and complete -- which is what 13_messenger_states did at firing 30, because
        # scene.js handed capture.sh an empty sentence and capture.sh wrote `13_messenger_states|`
        # into the missing file. A scene that refused an artifact and then said nothing about why
        # is a worse fault than one that refused it loudly, and it must not read as success.
        why = reasons.get(name)
        if why is None:
            why = reasons.get(key)
        if why is not None and not why.strip():
            why = ("the scene refused this artifact and reported no reason; see "
                   f"evidence/logs/{key}.json for the problems it collected")
        # A scene that failed is a missing artifact, whatever is on disk. This is the whole reason
        # the file exists: 13_messenger_states failed four runs in a row and the manifest listed it
        # as captured every time, because a copy of it from five hours earlier was still sitting
        # there. That is not evidence of anything this session did — it is exactly the substitution
        # the brief forbids, made by accident.
        if why:
            manifest["missing"][name] = why
            if path.exists():
                # Whose file it is, decided by the clock rather than assumed.
                #
                # This branch used to append "a copy from an earlier run is still on disk ... it
                # is not this session's" to EVERY refused artifact whose file existed, without
                # comparing the time it printed to anything -- while the branch immediately below
                # made exactly that comparison to decide staleness, and was never reached because
                # this one returns first. So MANIFEST.json said of 02_chat.png that it was "not
                # this session's": it was written at 10:20:05Z and the capture began at 10:06:21Z,
                # fourteen minutes INTO the run. Firing 31's visual-design critic read that
                # sentence and recorded a provenance caveat against a good artifact.
                #
                # A refused artifact written during the run is a real thing and not a rare one:
                # scene.js writes its PNG and only then sets exitCode 1 if it collected problems,
                # so the file is this session's and the scene still refused it. Both facts are
                # true at once and the manifest has to say both, because "it is not counted" is
                # the part that matters and "it is not yours" is the part that was false.
                if stamp_s is not None and path.stat().st_mtime < stamp_s - FRESH_TOLERANCE_S:
                    manifest["missing"][name] += (
                        f" (a copy from an earlier run is still on disk, written "
                        f"{_stamp_of(path)}; it is not this session's and is not counted)")
                else:
                    manifest["missing"][name] += (
                        f" (this session wrote {name} at {_stamp_of(path)} and then refused it, "
                        f"so the file on disk is this run's and is still not counted)")
            continue
        if not path.exists():
            manifest["missing"][name] = reasons.get("__default__") or "not captured this session"
            continue
        entry = {"bytes": path.stat().st_size, "written": _stamp_of(path)}
        # and one that nothing reported on, but which predates this run, is stale rather than fresh
        if stamp_s is not None and path.stat().st_mtime < stamp_s - FRESH_TOLERANCE_S:
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
        log = logs / f"{name.rsplit('.', 1)[0]}.frames.json"
        if log.exists():
            frames["clips"][name] = json.loads(log.read_text())
    scroll_log = logs / "11_chat_scroll.json"
    if scroll_log.exists():
        s = json.loads(scroll_log.read_text())
        frames["scroll"] = {
            "source": args.browser,
            "viewport": s.get("viewport"),
            "cold_ms": s.get("cold_ms"),
            "steps": s.get("steps"),
        }
    emulator = logs / "scroll_emulator.json"
    if emulator.exists():
        frames["scroll_emulator"] = json.loads(emulator.read_text())
    else:
        frames["scroll_emulator"] = {"missing": reasons.get("frames.json") or "no Android device was up in this session"}

    # Anything capture.sh reported that is not one of the seventeen artifacts -- a derived file, a
    # gate that failed -- still has to appear. It was being read into `reasons` and then dropped on
    # the floor, so a note_missing on DIFF.json or a selftest would have printed once to a console
    # nobody reads and left MANIFEST.json saying everything was fine.
    # The stems belong here as well as the filenames. Without them a reason keyed
    # `13_messenger_states` is not recognised as being about a known artifact, survives this
    # filter, and is added to `missing` under a name nothing else in the file uses -- which is
    # exactly why firing 30's manifest read 14 present plus 4 missing against a set of 17.
    said = set(STILLS) | set(CLIPS) | stems | {"__default__"}
    for name, why in reasons.items():
        if name not in said and name not in manifest["missing"]:
            manifest["missing"][name] = why

    failed = {}
    if args.failed and pathlib.Path(args.failed).exists():
        for line in pathlib.Path(args.failed).read_text().splitlines():
            if "|" in line:
                name, why = line.split("|", 1)
                failed[name.strip()] = why.strip()
    manifest["failed_checks"] = failed

    (evidence / "frames.json").write_text(json.dumps(frames, indent=1) + "\n")
    (evidence / "MANIFEST.json").write_text(json.dumps(manifest, indent=1) + "\n")

    have = len(manifest["artifacts"])
    print(f"· {have} of {len(STILLS) + len(CLIPS)} artifacts present")
    for name, why in sorted(manifest["missing"].items()):
        print(f"    {name}: {why}")
    if failed:
        print(f"· {len(failed)} check(s) failed on artifacts that are present")
        for name, why in sorted(failed.items()):
            print(f"    {name}: {why}")


if __name__ == "__main__":
    main()
