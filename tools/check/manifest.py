#!/usr/bin/env python3
"""Every file in assets/ names the thing that made it.

The rule is the brief's, and it is there so that nothing can arrive in the material library from
somewhere unaccounted for — a texture off the internet, a file copied by hand, an experiment left
behind. If a file cannot say which script produced it and with what settings, it does not belong.

    python3 tools/check/manifest.py
    python3 tools/check/manifest.py --json --out evidence/logs/manifest.json
"""
import argparse
import json
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
MANIFEST = ASSETS / "MANIFEST.json"

# the manifest itself, and the small index files the generators write beside their output
EXEMPT = {"MANIFEST.json", "MANIFEST.fonts.json", "MANIFEST.sound.json",
          "tears.json", "relief.json", "INDEX.json"}


def covered(entries):
    """The manifest keys, reduced to paths relative to assets/ however they were recorded."""
    out = set()
    for key in entries:
        k = key.replace(os.sep, "/")
        if "assets/" in k:
            k = k.split("assets/", 1)[1]
        out.add(k.lstrip("./"))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="")
    ap.add_argument("--fill", action="store_true",
                    help="give each file inside a recorded directory its own entry")
    args = ap.parse_args()

    if not MANIFEST.exists():
        print("assets/MANIFEST.json does not exist")
        return 1
    entries = json.loads(MANIFEST.read_text()).get("files", {})
    have = covered(entries)

    on_disk = []
    for path in sorted(ASSETS.rglob("*")):
        if path.is_dir() or path.name in EXEMPT or path.name.startswith("."):
            continue
        on_disk.append(str(path.relative_to(ASSETS)).replace(os.sep, "/"))

    missing = [f for f in on_disk if f not in have]
    # an entry naming a file that is not there any more is also worth knowing about
    stale = sorted(h for h in have if h not in set(on_disk) and not h.startswith("../"))

    if args.fill:
        # Entries pointing outside assets/ are records of smoke tests that were written to a
        # scratch directory. They are not part of the library and never were.
        raw = json.loads(MANIFEST.read_text())
        outside = [k for k in raw["files"] if k.replace(os.sep, "/").startswith("../")]
        for k in outside:
            del raw["files"][k]
        if outside:
            MANIFEST.write_text(json.dumps(raw, indent=1) + "\n")
            print(f"dropped {len(outside)} entries for files written outside assets/")
            entries = raw["files"]
            have = covered(entries)
            missing = [f for f in on_disk if f not in have]

    if args.fill and missing:
        # A generator that recorded the directory it wrote rather than each file in it leaves its
        # output uncovered. Rather than let that pass, each file takes the directory's entry — same
        # generator, same settings — plus the one thing that differs, which is its own name.
        raw = json.loads(MANIFEST.read_text())
        by_dir = {}
        for key, value in raw["files"].items():
            k = key.replace(os.sep, "/")
            k = k.split("assets/", 1)[1] if "assets/" in k else k.lstrip("./")
            by_dir[k] = (key, value)
        filled = 0
        for f in list(missing):
            parent = str(pathlib.PurePosixPath(f).parent)
            if parent in by_dir:
                _, value = by_dir[parent]
                entry = dict(value)
                entry["settings"] = dict(entry.get("settings", {}), file=pathlib.PurePosixPath(f).name)
                entry["kind"] = (entry.get("kind") or "file").replace("_sequence", "_frame")
                entry["bytes"] = (ASSETS / f).stat().st_size
                raw["files"][f"assets/{f}"] = entry
                filled += 1
        MANIFEST.write_text(json.dumps(raw, indent=1) + "\n")
        print(f"filled {filled} entries from the directory each file was written into")
        entries = raw["files"]
        have = covered(entries)
        missing = [f for f in on_disk if f not in have]

    report = {
        "files": len(on_disk),
        "entries": len(entries),
        "without_an_entry": missing,
        "entries_without_a_file": stale[:20],
        "ok": not missing,
    }
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(report, indent=1))
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        print(f"{len(on_disk)} files in assets/, {len(missing)} without an entry naming their generator")
        for f in missing[:12]:
            print(f"   {f}")
        if len(missing) > 12:
            print(f"   ... and {len(missing) - 12} more")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
