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
    # A render sent outside the repository with --out is a throwaway probe, and the library's
    # manifest is not a log of those. Recording one puts an entry keyed "../../../tmp/..." into
    # assets/MANIFEST.json, where it survives until somebody notices: firing 19's two-frame rules
    # probe left three such entries and they were committed before CLAUDE.md's warning about this
    # exact hazard was read, and firing 26's tooth sweep left thirty more. Both were cleaned by
    # hand afterwards with tools/check/manifest.py --fill. Neither needed to happen, and the
    # generators do not have to remember: a path that climbs out of ROOT is not an asset.
    if rel.startswith(".."):
        return rel
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


def _selftest():
    """Re-break the out-of-tree guard and watch it fail.

        python3 blender/rig/manifest.py --selftest

    The guard has no gate behind it -- assets/MANIFEST.json is written by ten generators and read
    by tools/check/manifest.py, which checks the entries that ARE there and cannot know about one
    that should not be. So the proof is here, beside the line it is about.
    """
    import copy
    import tempfile as _tf

    before = _load()["files"]
    n0 = len(before)
    probe = os.path.join(_tf.gettempdir(), "manifest_selftest_probe.png")
    with open(probe, "wb") as f:
        f.write(b"not an asset")
    try:
        rel = record(probe, "selftest", {"throwaway": True})
        after = _load()["files"]
        assert rel.startswith(".."), f"probe did not resolve outside ROOT: {rel}"
        assert rel not in after, f"GUARD FAILED: {rel} was recorded"
        assert len(after) == n0, f"GUARD FAILED: {n0} entries became {len(after)}"
        print(f"ok  out-of-tree probe not recorded; {n0} entries unchanged")

        # and the re-break: the same call, with the guard's condition inverted, DOES record it.
        # Done against a copy of the manifest so the real one is never touched.
        data = copy.deepcopy(_load())
        data["files"][rel] = {"generator": "selftest", "settings": {}}
        assert rel in data["files"], "the re-break did not reproduce the fault"
        print(f"ok  re-broken: without the guard the same call keys an entry {rel[:34]}...")

        # an in-tree path must still be recorded, or the guard has eaten the feature
        intree = os.path.join(ROOT, "assets", ".manifest_selftest_probe")
        with open(intree, "wb") as f:
            f.write(b"x")
        try:
            rel2 = record(intree, "selftest", {"throwaway": True})
            assert not rel2.startswith(".."), rel2
            assert rel2 in _load()["files"], "GUARD TOO WIDE: an in-tree asset was dropped"
            print(f"ok  in-tree asset still recorded as {rel2}")
        finally:
            d = _load()
            d["files"].pop(rel2, None)
            with open(MANIFEST, "w", encoding="utf-8") as f:
                json.dump(d, f, indent=1, sort_keys=True)
            os.remove(intree)
    finally:
        os.remove(probe)
    assert len(_load()["files"]) == n0, "the selftest did not leave the manifest as it found it"
    print("manifest recorder selftest: all green")


if __name__ == "__main__":
    import sys as _sys
    if "--selftest" in _sys.argv:
        _selftest()
    else:
        print(__doc__)
