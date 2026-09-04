#!/usr/bin/env python3
"""Turn `dumpsys gfxinfo <pkg> framestats` into the scroll timings evidence/frames.json carries.

The framework measures its own frames; this only reads them. A frame over 16.7 ms was late, and
the count of them is the number that matters when the thread is a year deep.
"""
import argparse
import json
import pathlib
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    rows = []
    for line in pathlib.Path(args.path).read_text(errors="ignore").splitlines():
        parts = line.strip().split(",")
        if len(parts) < 14 or not parts[0].isdigit():
            continue
        nums = [int(p) for p in parts if p.strip().lstrip("-").isdigit()]
        if len(nums) < 14:
            continue
        # columns are nanosecond timestamps; INTENDED_VSYNC is 1 and FRAME_COMPLETED is the last
        intended, completed = nums[1], nums[-1]
        if completed > intended > 0:
            rows.append((completed - intended) / 1e6)

    if not rows:
        print(json.dumps({"frames": 0, "ok": False, "why": "no framestats rows"}))
        return 1

    rows.sort()
    def pct(p):
        return round(rows[min(len(rows) - 1, int(len(rows) * p))], 2)
    report = {
        "source": "emulator, dumpsys gfxinfo framestats",
        "frames": len(rows),
        "median_ms": pct(0.5),
        "p90_ms": pct(0.9),
        "p99_ms": pct(0.99),
        "worst_ms": round(rows[-1], 2),
        "late_frames": sum(1 for r in rows if r > 16.7),
        "late_fraction": round(sum(1 for r in rows if r > 16.7) / len(rows), 4),
    }
    report["ok"] = report["late_fraction"] < 0.1
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(report, indent=1))
    print(json.dumps(report, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
