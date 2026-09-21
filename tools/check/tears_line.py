#!/usr/bin/env python3
"""One line per still: how many tears it drew and whether any mask is used twice.

`tears.py` answers the question; this says the answer out loud in the capture's own output, for
every still rather than only for 02_chat's notes. It is separate from `tears.py` so that the
answer and the sentence about it are not the same file, and so `capture.sh` stays a shell script
with no Python in it.
"""
import json
import pathlib
import sys


def main():
    if len(sys.argv) < 3:
        return 0
    try:
        d = json.loads(pathlib.Path(sys.argv[2]).read_text())
    except Exception:
        return 0
    if d.get("frame_surfaces") is None:
        return 0
    name = pathlib.PurePosixPath(sys.argv[1]).name.replace(".report.json", "")
    if d.get("frame_ok"):
        print(f"  tears {name}: {d['frame_tear_draws']} draws, all different")
    else:
        print(f"  tears {name}: {d['frame_tear_draws']} draws, "
              f"{d['frame_distinct_tears']} masks — {d.get('frame_why', '')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
