#!/usr/bin/env python3
"""Every recipe can actually be built, checked without rendering anything.

    python3 tools/check/recipes.py
    python3 tools/check/recipes.py --json

A recipe names a builder and hands it a spec; still.py passes the spec straight through as keyword
arguments. So a recipe that says where a wall stands, against a builder that never learned to be
told, is a TypeError — and the way that was found was by a four-hour render stopping ten minutes
in, having exposed eight of a hundred and fifteen photographs. Nothing said anything until then.

This reads the builder table out of still.py, reads every builder's signature out of kit.py and
world.py, and holds each recipe against them. It takes about a second and it does not open
Blender, so it can run before a render rather than during one.
"""
import argparse
import ast
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PHOTOS = os.path.join(ROOT, "blender", "photos")
RECIPE_DIRS = [
    os.path.join(PHOTOS, "recipes"),
    os.path.join(ROOT, "blender", "videos", "shots"),
]

# keys still.py eats before it calls the builder
CONSUMED = {"kind", "on", "as_kind"}


def builder_table():
    """Which builder each recipe key means, straight out of still.py."""
    src = open(os.path.join(PHOTOS, "still.py"), encoding="utf-8").read()
    block = re.search(r"BUILDERS = \{(.*?)\n\}", src, re.S)
    if not block:
        raise SystemExit("recipes.py: still.py has no BUILDERS table any more")
    return {k: (mod, fn) for k, mod, fn in
            re.findall(r'"([a-z_0-9]+)":\s*(kit|world)\.([a-z_0-9]+)', block.group(1))}


def signatures():
    out = {}
    for mod in ("kit", "world"):
        tree = ast.parse(open(os.path.join(PHOTOS, mod + ".py"), encoding="utf-8").read())
        for node in tree.body:
            if isinstance(node, ast.FunctionDef):
                names = [a.arg for a in node.args.args] + [a.arg for a in node.args.kwonlyargs]
                out[(mod, node.name)] = (set(names), node.args.kwarg is not None)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="")
    a = ap.parse_args(argv)

    builders = builder_table()
    sigs = signatures()
    problems = []
    recipes = 0
    specs = 0
    for d in RECIPE_DIRS:
        for path in sorted(glob.glob(os.path.join(d, "*.json"))):
            with open(path, encoding="utf-8") as f:
                recipe = json.load(f)
            recipes += 1
            name = os.path.basename(path)[:-5]
            for spec in recipe.get("objects", []):
                specs += 1
                kind = spec.get("kind")
                where = builders.get(kind)
                if where is None:
                    problems.append({"recipe": name, "kind": kind,
                                     "why": "nothing in the kit is called this"})
                    continue
                args, takes_kwargs = sigs.get(where, (set(), False))
                if not args and not takes_kwargs:
                    problems.append({"recipe": name, "kind": kind,
                                     "why": f"still.py maps it to {where[0]}.{where[1]}, "
                                            "which does not exist"})
                    continue
                if takes_kwargs:
                    continue
                # as_kind is renamed to kind on the way in
                given = (set(spec) - CONSUMED) | ({"kind"} if "as_kind" in spec else set())
                unknown = sorted(given - args)
                if unknown:
                    problems.append({
                        "recipe": name, "kind": kind,
                        "why": f"{where[0]}.{where[1]} cannot be told {', '.join(unknown)} "
                               f"(it takes {', '.join(sorted(args))})"})

    report = {"recipes": recipes, "objects": specs, "problems": problems,
              "ok": not problems}
    if a.out:
        os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
        with open(a.out, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=1)
    if a.json:
        print(json.dumps(report, indent=1))
    else:
        print(f"{specs} things across {recipes} recipes, {len(problems)} that cannot be built")
        for p in problems[:30]:
            print(f"  {p['recipe']}: {p['kind']} — {p['why']}")
        if len(problems) > 30:
            print(f"  … and {len(problems) - 30} more")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
