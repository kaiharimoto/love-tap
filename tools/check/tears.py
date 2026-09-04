#!/usr/bin/env python3
"""The standard 02_chat.png carries: at least eight notes on screen and no tear used twice.

This reads the capture report the app itself wrote at the moment of the shot, which lists the
event ids that were on screen and the tear mask each one was torn with. The masks come out of the
same assignment the renderer used, so this is checking the frame rather than trusting a note.
"""
import argparse
import json
import pathlib
import sys
from collections import Counter


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--min-notes", type=int, default=8)
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    r = json.loads(pathlib.Path(args.report).read_text())
    tears = {k: v for k, v in (r.get("tears") or {}).items() if v}
    counts = Counter(tears.values())
    repeats = {t: n for t, n in counts.items() if n > 1}
    out = {
        "report": args.report,
        "visible": len(r.get("visible") or []),
        "notes_with_tears": len(tears),
        "distinct_tears": len(counts),
        "repeats": repeats,
        "pool": r.get("masks_in_pool"),
        "scroll": r.get("scroll"),
        "driven_ms": r.get("driven_ms"),
        "seed": r.get("seed"),
        "ok": len(tears) >= args.min_notes and not repeats,
    }
    if not out["ok"]:
        out["why"] = "a tear is used twice" if repeats else f"only {len(tears)} notes on screen"
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(out, indent=1))
    print(json.dumps(out, indent=1))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
