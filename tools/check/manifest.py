#!/usr/bin/env python3
"""Every file in assets/ names the thing that made it, and that thing can actually make it.

The rule is the brief's, and it is there so that nothing can arrive in the material library from
somewhere unaccounted for — a texture off the internet, a file copied by hand, an experiment left
behind. If a file cannot say which script produced it and with what settings, it does not belong.

Firing 5 found the hole in that. `obj_heart_fold.png` carried a perfectly good entry naming
`blender/objects/objects.py` as its generator, and objects.py builds twenty-five objects of which
heart_fold is not one. The check passed — "634 files in assets/, 0 without an entry naming their
generator" — because it asked whether an entry EXISTS, never whether the generator it names could
produce the file. Two assets in the library were not reproducible and the gate called them all
reproducible. They were found by re-rendering the library and noticing that fifty of fifty-two
object files came back newer, which is an expensive way to learn it.

So the check now has a second half. A generator that keeps its catalogue in a module-level dict or
list has that catalogue read out of it — statically, with `ast`, because these modules import `bpy`
and there is no Blender in most containers that want to run this. Each entry then has to name a
subject that is in its generator's catalogue.

The coverage is deliberately partial and is reported rather than assumed. A generator with no rule
in CATALOGUES is counted as unverifiable and named in the report, so that the gate understates what
it knows instead of overstating it. That is the whole lesson of the bug it exists to catch.

    python3 tools/check/manifest.py
    python3 tools/check/manifest.py --json --out evidence/logs/manifest.json
"""
import argparse
import ast
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


# ---------------------------------------------------------------- can it make it?
#
# For each generator that keeps a catalogue: where the catalogue lives, and how an entry names
# which member of it the file is. Two ways of naming, because the generators differ:
#
#   ("settings", key)  the entry's settings record the subject under `key`
#   ("stem",)          the file's own basename is the subject, once the pass and condition
#                      suffixes a generator appends are taken back off
#
# A generator absent from this table is not checked and is reported as such. Adding one is a few
# lines and the payoff is that a file it cannot build stops being invisible.
CATALOGUES = {
    "blender/objects/objects.py": {
        "subject": ("settings", "object"),
        "declares": [("blender/objects/objects.py", "OBJECTS")],
    },
    "blender/paper/stocks.py": {
        "subject": ("settings", "stock"),
        "declares": [("blender/paper/stocks.py", "STOCK_LOOK")],
    },
    "blender/bits/bits.py": {
        "subject": ("stem",),
        "declares": [("blender/bits/bits.py", "BITS")],
    },
    "blender/folds/fold.py": {
        "subject": ("settings", "sequence"),
        "declares": [("blender/folds/fold.py", "SEQUENCES")],
    },
    "tools/sound/synth.py": {
        "subject": ("settings", "recipe"),
        "declares": [("tools/sound/synth.py", "FEELING_RECIPES"),
                     ("tools/sound/synth.py", "UI_RECIPES")],
    },
}

# What the generators append to a catalogue name to distinguish a pass or a light condition.
# Longest first, so that `_shadow_dusk` is taken off whole rather than leaving `_shadow`.
SUFFIXES = ("_dusk_shadow", "_shadow_dusk", "_shadow", "_dusk")


def declared(path, symbol, _cache={}):
    """The keys of a module-level dict, or the members of a module-level list, read without importing.

    Static because these modules import `bpy` at the top: a container with no Blender still has to
    be able to run this gate, and a gate that only runs where the renderer is installed is a gate
    that does not run.
    """
    if (path, symbol) in _cache:
        return _cache[(path, symbol)]
    out = None
    src = ROOT / path
    if src.exists():
        try:
            tree = ast.parse(src.read_text())
        except SyntaxError:
            tree = None
        for node in (tree.body if tree else []):
            targets = node.targets if isinstance(node, ast.Assign) else []
            if not any(isinstance(t, ast.Name) and t.id == symbol for t in targets):
                continue
            value = node.value
            if isinstance(value, ast.Dict):
                out = [k.value for k in value.keys if isinstance(k, ast.Constant)]
            elif isinstance(value, (ast.List, ast.Tuple, ast.Set)):
                out = [e.value for e in value.elts if isinstance(e, ast.Constant)]
            break
    _cache[(path, symbol)] = out
    return out


def subject_of(rule, relpath, entry):
    """What this entry says it is, in the vocabulary of its generator's catalogue."""
    how = rule["subject"]
    if how[0] == "settings":
        return (entry.get("settings") or {}).get(how[1])
    stem = pathlib.PurePosixPath(relpath).stem
    for suffix in SUFFIXES:
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    return stem


def unbuildable(entries):
    """Entries whose generator has a catalogue that does not contain them.

    Returns (failures, checked, unverifiable_generators). A subject the entry does not record at
    all is counted as unverifiable rather than as a failure: not knowing is not the same as
    knowing it is wrong, and a gate that conflates the two gets switched off.
    """
    failures, checked = [], 0
    unverifiable = {}
    for key, entry in sorted(entries.items()):
        generator = (entry or {}).get("generator")
        rule = CATALOGUES.get(generator)
        if rule is None:
            unverifiable[generator or "(no generator named)"] = \
                unverifiable.get(generator or "(no generator named)", 0) + 1
            continue
        catalogue = []
        for path, symbol in rule["declares"]:
            found = declared(path, symbol)
            if found is None:
                catalogue = None
                break
            catalogue += found
        if catalogue is None:
            unverifiable[generator] = unverifiable.get(generator, 0) + 1
            continue
        relpath = key.replace(os.sep, "/")
        relpath = relpath.split("assets/", 1)[1] if "assets/" in relpath else relpath.lstrip("./")
        subject = subject_of(rule, relpath, entry)
        if subject is None:
            unverifiable[generator] = unverifiable.get(generator, 0) + 1
            continue
        checked += 1
        if subject not in catalogue:
            failures.append({
                "file": relpath,
                "generator": generator,
                "names": subject,
                "but_it_builds": len(catalogue),
            })
    return failures, checked, unverifiable


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

    unbuildable_entries, checked, unverifiable = unbuildable(entries)

    report = {
        "files": len(on_disk),
        "entries": len(entries),
        "without_an_entry": missing,
        "entries_without_a_file": stale[:20],
        "naming_a_generator_that_cannot_build_them": unbuildable_entries,
        "checked_against_a_catalogue": checked,
        "no_catalogue_to_check_against": dict(sorted(unverifiable.items())),
        "ok": not missing and not unbuildable_entries,
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
        unchecked = sum(unverifiable.values())
        print(f"{checked} entries checked against their generator's catalogue, "
              f"{len(unbuildable_entries)} naming a generator that cannot build them; "
              f"{unchecked} have no catalogue to check against")
        for f in unbuildable_entries[:12]:
            print(f"   {f['file']}: {f['generator']} does not build {f['names']!r} "
                  f"(it builds {f['but_it_builds']} things)")
        if len(unbuildable_entries) > 12:
            print(f"   ... and {len(unbuildable_entries) - 12} more")
        for generator, n in sorted(unverifiable.items()):
            print(f"   not verifiable: {n:4d} from {generator}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
