"""blender/rig/manifest.py — every asset records its generator and settings.

Usage from any generator (Blender or plain Python):

    from manifest import record
    record("assets/paper/lined_01.png", "blender/paper/stocks.py", {"stock": "lined", "variant": 1, ...})

Entries are keyed by the asset path relative to the repository root and merged into
assets/MANIFEST.json atomically. `tools/manifest.py --check` verifies coverage.
"""
import json
import os
import tempfile
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(_HERE, "..", ".."))
MANIFEST = os.path.join(ROOT, "assets", "MANIFEST.json")


def _load():
    if os.path.exists(MANIFEST):
        with open(MANIFEST, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"version": 1, "light": "DIRECTION.md: daylight from upper-left, azimuth 315, elevation 50",
            "files": {}}


def record(path, generator, settings, kind=None):
    rel = os.path.relpath(os.path.abspath(path), ROOT).replace(os.sep, "/")
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    for _ in range(20):
        try:
            data = _load()
            break
        except json.JSONDecodeError:
            time.sleep(0.05)
    else:
        data = {"version": 1, "files": {}}
    entry = {"generator": generator, "settings": settings}
    if kind:
        entry["kind"] = kind
    if os.path.exists(path):
        entry["bytes"] = os.path.getsize(path)
    data["files"][rel] = entry
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(MANIFEST), prefix=".manifest.", suffix=".json")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, sort_keys=True)
    os.replace(tmp, MANIFEST)
    return rel
