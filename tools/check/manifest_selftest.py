#!/usr/bin/env python3
"""Proof that the manifest gate goes red for each fault it is named after, one fault at a time.

    python3 tools/check/manifest_selftest.py

`tools/check/manifest.py` has now been caught reading green over a real defect twice. Firing 5:
an entry naming a generator that cannot build it, because the gate asked whether an entry existed
and never whether it was true. Firing 19: twenty entries with no file beside `ok: true`, because
`ok` was computed from two of the four things the report measures — and the list of twenty was the
visible end of a hundred and thirty-four, cut with no count beside it, of which a hundred and
fifteen were present files the gate had looked for in the wrong directory.

Every one of those was a gate that measured the right thing and then did not gate on it, or gated
on a number it had quietly truncated. So this does not test the report's wording. It builds a
throwaway library, checks the gate passes it, and then breaks it one fault at a time — the four
faults `ok` is made of — and checks the matching field fires and `ok` goes false. The item this
closes names the re-break directly: delete one seed photo and watch ok go false.

It is a ruler for the ruler: a temporary directory, never `assets/` and never `evidence/`.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def a_library(tmp):
    """A whole small repository: assets/ with a manifest, and a seed photo at the root.

    The root-level file is the point of the third case. The real manifest records
    `seed/photos/*.jpg` relative to the repository, not to `assets/`, and a gate that resolves
    only under `assets/` calls a hundred and fifteen present photographs missing.
    """
    os.makedirs(os.path.join(tmp, "assets", "paper"), exist_ok=True)
    os.makedirs(os.path.join(tmp, "assets", "folds", "unfold_thirds"), exist_ok=True)
    os.makedirs(os.path.join(tmp, "seed", "photos"), exist_ok=True)
    os.makedirs(os.path.join(tmp, "blender", "paper"), exist_ok=True)
    os.makedirs(os.path.join(tmp, "tools", "check"), exist_ok=True)
    shutil.copy2(os.path.join(ROOT, "tools/check/manifest.py"),
                 os.path.join(tmp, "tools/check/manifest.py"))

    # a generator with a catalogue in it, read statically by the gate
    with open(os.path.join(tmp, "blender/paper/stocks.py"), "w", encoding="utf-8") as f:
        f.write('STOCK_LOOK = {"lined": {}, "graph": {}}\n')

    files = {
        "assets/paper/lined_01.webp": {"generator": "blender/paper/stocks.py",
                                       "settings": {"stock": "lined"}},
        "assets/paper/graph_01.webp": {"generator": "blender/paper/stocks.py",
                                       "settings": {"stock": "graph"}},
        "seed/photos/a_photograph.jpg": {"generator": "blender/photos/still.py", "settings": {}},
    }
    for rel in ("assets/paper/lined_01.webp", "assets/paper/graph_01.webp",
                "seed/photos/a_photograph.jpg"):
        with open(os.path.join(tmp, rel), "wb") as f:
            f.write(b"not really an image, and the gate does not open it")
    with open(os.path.join(tmp, "assets", "MANIFEST.json"), "w", encoding="utf-8") as f:
        json.dump({"files": files}, f, indent=1)


def run(tmp):
    out = os.path.join(tmp, "report.json")
    r = subprocess.run([sys.executable, os.path.join(tmp, "tools/check/manifest.py"),
                        "--out", out], capture_output=True, text=True, cwd=tmp)
    with open(out, encoding="utf-8") as f:
        return r.returncode, json.load(f)


def edit_manifest(tmp, fn):
    path = os.path.join(tmp, "assets", "MANIFEST.json")
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    fn(raw["files"])
    with open(path, "w", encoding="utf-8") as f:
        json.dump(raw, f, indent=1)


# Each break, and the field in the report that has to fire because of it.
BREAKS = [
    ("a seed photograph at the repository root is deleted",
     "entries_without_a_file_count",
     lambda tmp: os.unlink(os.path.join(tmp, "seed/photos/a_photograph.jpg"))),
    ("a file under assets/ is deleted",
     "entries_without_a_file_count",
     lambda tmp: os.unlink(os.path.join(tmp, "assets/paper/lined_01.webp"))),
    ("a file arrives in assets/ with no entry",
     "without_an_entry_count",
     lambda tmp: open(os.path.join(tmp, "assets/paper/legal_01.webp"), "wb").write(b"unaccounted")),
    ("an entry claims a file under gitignored build scratch",
     "entries_for_files_outside_the_library_count",
     lambda tmp: edit_manifest(tmp, lambda files: files.update(
         {"scratch/posters/a_poster.jpg": {"generator": "blender/photos/still.py", "settings": {}}}))),
    ("an entry names a generator that cannot build it",
     "naming_a_generator_that_cannot_build_them",
     lambda tmp: edit_manifest(tmp, lambda files: files.update(
         {"assets/paper/lined_01.webp": {"generator": "blender/paper/stocks.py",
                                         "settings": {"stock": "a_stock_that_is_not_made"}}}))),
]


def size_of(value):
    return value if isinstance(value, int) else len(value)


def main():
    failures = []

    tmp = tempfile.mkdtemp(prefix="manifest_selftest_")
    try:
        a_library(tmp)
        code, report = run(tmp)
        if not report["ok"] or code != 0:
            failures.append("a library built to be whole did not pass: "
                            f"ok {report['ok']}, exit {code}")
            print(f"FAIL  a whole library did not pass (exit {code})")
        else:
            print("ok    a library built to be whole passes, exit 0")
        # the case that was reported as a fault for three cycles and is not one
        elsewhere = report["entries_whose_file_is_not_under_assets"]["count"]
        if elsewhere != 1:
            failures.append(f"the photograph at the repository root was not resolved there "
                            f"({elsewhere} entries counted as elsewhere, wanted 1)")
            print(f"FAIL  a present file at the repository root counted {elsewhere} times, wanted 1")
        else:
            print("ok    a present file recorded relative to the repository root is not called missing")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    for why, field, break_it in BREAKS:
        tmp = tempfile.mkdtemp(prefix="manifest_selftest_")
        try:
            a_library(tmp)
            break_it(tmp)
            code, report = run(tmp)
            if report["ok"] or code == 0:
                failures.append(f"{field}: broke it and the gate stayed green ({why})")
                print(f"FAIL  {field:<46} stayed green when {why}")
            elif size_of(report.get(field, 0)) == 0:
                fired = [k for k, v in report.items()
                         if k.endswith("_count") or k.startswith("naming_") and size_of(v or 0)]
                failures.append(f"{field}: broke it and a different field caught it ({why})")
                print(f"FAIL  {field:<46} did not fire when {why}; fired {fired}")
            else:
                print(f"ok    {field:<46} fires when {why}")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    if failures:
        print(f"\n{len(failures)} of {len(BREAKS) + 2} checks failed", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 1
    print(f"\n{len(BREAKS) + 2} checks passed: the gate can be passed, "
          f"and each fault ok is made of can fail it")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
