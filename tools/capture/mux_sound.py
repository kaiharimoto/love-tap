#!/usr/bin/env python3
"""Put the feeling's own sound into a clip, where the feeling arrived.

    python3 tools/capture/mux_sound.py evidence/07_feeling_landing.mp4 evidence/logs/07_feeling_landing.json \
        --haptics evidence/logs/haptics.json --fps 60

The scene log records, for every arrival the harness waited for, the far phone's instruction (which
names the feeling) and the frame of the clip at which the arrival began. The feeling's sound is the
asset the app plays (assets/sound/<sound>.ogg, named in the registry the app dumped to haptics.json),
placed at that frame's time and mixed over silence. The pixels are copied, not re-encoded: nothing
about the picture changes.
"""
import argparse
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
FFMPEG = ROOT / "toolchain" / "ffmpeg" / "ffmpeg"
FFPROBE = ROOT / "toolchain" / "ffmpeg" / "ffprobe"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("clip")
    ap.add_argument("log")
    ap.add_argument("--haptics", default=str(ROOT / "evidence" / "logs" / "haptics.json"))
    ap.add_argument("--fps", type=float, default=60.0)
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    log = json.loads(pathlib.Path(a.log).read_text())
    haptics = json.loads(pathlib.Path(a.haptics).read_text()) if os.path.exists(a.haptics) else {}
    sounds = {f["id"]: f["sound"] for f in haptics.get("feelings", [])}
    placed = []
    for arr in log.get("arrivals", []):
        parts = (arr.get("line") or "").split()
        if len(parts) < 2 or parts[0] != "feeling":
            continue
        snd = sounds.get(parts[1])
        path = ROOT / "assets" / "sound" / f"{snd}.ogg" if snd else None
        if path is None or not path.exists():
            continue
        placed.append({"feeling": parts[1], "sound": str(path.relative_to(ROOT)),
                       "at_frame": arr["at_frame"], "at_seconds": round(arr["at_frame"] / a.fps, 3)})
    report = {"clip": a.clip, "placed": placed}
    if not placed:
        report["why"] = "no arrival of a feeling in the scene log, so no sound belongs in this clip"
        print(json.dumps(report))
        return 0
    probe = subprocess.run([str(FFPROBE), "-v", "error", "-show_entries", "format=duration", "-of",
                            "default=nw=1:nk=1", a.clip], capture_output=True, text=True)
    duration = float(probe.stdout.strip() or 0)
    inputs = ["-i", a.clip]
    filters = []
    labels = []
    for i, p in enumerate(placed):
        inputs += ["-i", str(ROOT / p["sound"])]
        delay = int(p["at_seconds"] * 1000)
        filters.append(f"[{i + 1}:a]adelay={delay}|{delay},apad[a{i}]")
        labels.append(f"[a{i}]")
    filters.append("".join(labels) + f"amix=inputs={len(placed)}:normalize=0,atrim=0:{duration:.3f}[mix]")
    out = a.out or a.clip + ".withsound.mp4"
    cmd = [str(FFMPEG), "-y", "-loglevel", "error", *inputs, "-filter_complex", ";".join(filters),
           "-map", "0:v", "-map", "[mix]", "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
           "-movflags", "+faststart", out]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        report["error"] = r.stderr.strip()[-400:]
        print(json.dumps(report))
        return 1
    if not a.out:
        os.replace(out, a.clip)
    report["audio"] = "aac 128k, the feeling's own ogg placed at its arrival, video stream copied"
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
