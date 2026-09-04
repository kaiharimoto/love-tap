#!/usr/bin/env python3
"""tools/check/diff.py — what changed between this capture and the last one.

    python3 tools/check/diff.py                 # write evidence/DIFF.json
    python3 tools/check/diff.py --rotate        # ...and then make this capture the baseline

evidence/.previous/ holds the artifacts as they were at the end of the last capture. This measures
each of this session's artifacts against its counterpart there and writes evidence/DIFF.json.

Two things this is careful about, both of which were wrong before it existed:

  · The baseline has to actually be the previous capture. Every file in .previous was byte-identical
    to its current counterpart, which means nothing had ever rotated it, which means every SSIM in
    the file was unreproducible from the baseline that shipped beside it. Rotation happens here,
    after the measurement, and only when asked.
  · A label has to agree with its number. What this writes is measured — new, gone, unchanged,
    changed — and `judgement` is left null for the coherence critic to fill in with improved or
    regressed, because whether a change is an improvement is not something SSIM knows.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EVIDENCE = os.path.join(ROOT, "evidence")
PREVIOUS = os.path.join(EVIDENCE, ".previous")
FFMPEG = os.path.join(ROOT, "toolchain", "ffmpeg", "ffmpeg")

ARTIFACTS = [
    "01_pulse.png", "02_chat.png", "03_us.png", "04_moments.png", "05_settings.png",
    "06_unfolding.mp4", "07_feeling_landing.mp4", "08_state_propagating.mp4",
    "09_two_devices.png", "10_first_run.png", "11_chat_scroll.mp4", "12_search.png",
    "13_messenger_states.png", "14_media_viewer.png", "15_authored_feeling.mp4",
    "16_setup_android.png", "17_setup_pwa.png",
]

UNCHANGED_AT = 0.9990      # at or above this, nothing a person would see has moved


def grey(path, size=None):
    im = Image.open(path).convert("L")
    if size and im.size != size:
        im = im.resize(size, Image.LANCZOS)
    return np.asarray(im, dtype=np.float64) / 255.0


def ssim(a, b, window=8):
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    h = a.shape[0] // window * window
    w = a.shape[1] // window * window
    a = a[:h, :w].reshape(h // window, window, w // window, window).transpose(0, 2, 1, 3)
    b = b[:h, :w].reshape(h // window, window, w // window, window).transpose(0, 2, 1, 3)
    a = a.reshape(-1, window * window)
    b = b.reshape(-1, window * window)
    ma, mb = a.mean(1), b.mean(1)
    va, vb = a.var(1), b.var(1)
    cov = ((a - ma[:, None]) * (b - mb[:, None])).mean(1)
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))
    return float(s.mean())


def middle_frame(path, out):
    """A clip is compared on the frame in the middle of it, extracted the same way both times."""
    try:
        subprocess.run([FFMPEG, "-y", "-v", "error", "-i", path, "-vf",
                        "select=eq(n\\,60)", "-vframes", "1", out], check=True,
                       capture_output=True)
        return out if os.path.exists(out) else None
    except Exception:
        return None


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def compare(name, scratch):
    now = os.path.join(EVIDENCE, name)
    was = os.path.join(PREVIOUS, name)
    here, there = os.path.exists(now), os.path.exists(was)
    if not here and not there:
        return {"artifact": name, "label": "absent", "ssim": None, "judgement": None,
                "why": "not captured in this session or the last"}
    if here and not there:
        return {"artifact": name, "label": "new", "ssim": None, "judgement": None,
                "bytes": os.path.getsize(now), "sha": digest(now),
                "why": "there was no previous capture of this"}
    if there and not here:
        return {"artifact": name, "label": "gone", "ssim": None, "judgement": None,
                "why": "captured last session, missing from this one"}

    if digest(now) == digest(was):
        return {"artifact": name, "label": "unchanged", "ssim": 1.0, "judgement": None,
                "sha": digest(now), "why": "byte for byte the same file"}

    a_path, b_path = now, was
    if name.endswith(".mp4"):
        a_path = middle_frame(now, os.path.join(scratch, name + ".now.png"))
        b_path = middle_frame(was, os.path.join(scratch, name + ".was.png"))
        if not a_path or not b_path:
            return {"artifact": name, "label": "changed", "ssim": None, "judgement": None,
                    "why": "the clips differ; no frame could be pulled to measure how"}
    ga = grey(a_path)
    gb = grey(b_path, size=(ga.shape[1], ga.shape[0]))
    value = round(ssim(ga, gb), 4)
    label = "unchanged" if value >= UNCHANGED_AT else "changed"
    return {"artifact": name, "label": label, "ssim": value, "judgement": None,
            "sha": digest(now), "previous_sha": digest(was),
            "label_basis": f"ssim {value} against {UNCHANGED_AT} — at or above it, nothing a "
                           f"person would see has moved"}


def head():
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True).stdout.strip()
    except Exception:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rotate", action="store_true",
                    help="after measuring, make this capture the baseline for the next one")
    ap.add_argument("--out", default=os.path.join(EVIDENCE, "DIFF.json"))
    args = ap.parse_args()

    scratch = os.path.join(EVIDENCE, ".diffscratch")
    os.makedirs(scratch, exist_ok=True)
    rows = [compare(name, scratch) for name in ARTIFACTS]
    shutil.rmtree(scratch, ignore_errors=True)

    baseline_at = None
    stamp = os.path.join(PREVIOUS, "CAPTURED_AT")
    if os.path.exists(stamp):
        with open(stamp, encoding="utf-8") as f:
            baseline_at = f.read().strip()

    out = {
        "commit": head(),
        "baseline": {"dir": "evidence/.previous", "captured_at": baseline_at},
        "unchanged_at": UNCHANGED_AT,
        "labels": "new, gone, unchanged, changed — measured. `judgement` (improved or regressed) "
                  "is the coherence critic's to fill in; SSIM does not know whether a change is "
                  "an improvement.",
        "artifacts": rows,
        "counts": {k: sum(1 for r in rows if r["label"] == k)
                   for k in ("new", "gone", "unchanged", "changed", "absent")},
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    print(f"diff: {out['counts']}")

    if args.rotate:
        os.makedirs(PREVIOUS, exist_ok=True)
        for name in ARTIFACTS:
            src = os.path.join(EVIDENCE, name)
            dst = os.path.join(PREVIOUS, name)
            if os.path.exists(src):
                shutil.copy2(src, dst)
            elif os.path.exists(dst):
                os.unlink(dst)
        import datetime
        with open(stamp, "w", encoding="utf-8") as f:
            f.write(datetime.datetime.now(datetime.timezone.utc).isoformat() + "\n")
        print(f"diff: this capture is the baseline for the next one")
    return 0


if __name__ == "__main__":
    sys.exit(main())
