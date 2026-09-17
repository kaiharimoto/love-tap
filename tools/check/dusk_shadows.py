#!/usr/bin/env python3
"""Everything the app asks the library for at dusk, the library has.

`Light.suffixOf` (app/lib/material/light.dart:34) is the whole mechanism: at dusk the app appends
`_dusk` to an asset id and loads the render made under the dusk rig, because DIRECTION.md's dusk is
a second set of renders and not a dim overlay laid over the first.

Not one of those places is guarded. `PaperPiece._bakedShadow` (app/lib/material/paper.dart:112)
builds `tear_NNN_shadow$suffix` and hands it straight to `Image.asset` with `errorBuilder: none`, so
a tear whose dusk shadow was never rendered does not fail, does not warn and does not draw: the note
simply has no contact shadow, and the note beside it — if it happened to draw one of the four tears
that do have one — does. `ObjectMark` (app/lib/material/objects.dart:118) does the same thing with
`errorBuilder: _none`. That is the one failure mode this repository has no way to see, because an
absent asset behind an errorBuilder looks exactly like an asset that is there.

`MaterialLibrary` carries a guard for each of these — `hasTearRender` and `hasObjectShadow` — and
neither is called from anywhere. A guard nobody calls and a render nobody made fail together
silently, which is why the gate is here and not in the app: the app cannot tell the difference, and
the library can.

So the rule is not "every file has a dusk twin": masks and lit edges have no dusk form and are not
supposed to. The rule is narrower and comes from the app rather than from the shape of the library —
**for every asset the app can name under `_dusk`, the file the app would name has to exist.** Each
rule below cites the line that names it, so that a change to the app that adds a condition-suffixed
path and forgets the renders is a change that has to come past this file.

    python3 tools/check/dusk_shadows.py
    python3 tools/check/dusk_shadows.py --json --out evidence/logs/dusk_shadows.json
"""
import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"

# family, the day form the app can name, the dusk form it names for the same thing, and the line
# that does it. `day` is a full-match regex over the file stem inside the family's directory.
RULES = [
    {
        "id": "tear_contact_shadow",
        "family": "tears",
        "day": r"tear_\d+_shadow",
        "dusk": "{day}_dusk",
        "asked_by": "app/lib/material/paper.dart:112 — tearAsset('${tearId}_shadow$suffix')",
        "guarded": False,
    },
    {
        "id": "object_contact_shadow",
        "family": "objects",
        "day": r"obj_[a-z0-9_]+_shadow",
        "dusk": "{day}_dusk",
        "asked_by": "app/lib/material/objects.dart:118 — objectAsset('${id}_shadow${dusk...}')",
        "guarded": False,
    },
    {
        "id": "paper_stock",
        "family": "paper",
        "day": r"[a-z]+(?:_[a-z]+)*_\d+",
        "dusk": "{day}_dusk",
        "asked_by": "app/lib/material/paper.dart:126 — paperAsset('${stockId}_dusk')",
        "guarded": False,
    },
    {
        "id": "desk_plate",
        "family": "shell",
        "day": r"desk",
        "dusk": "{day}_dusk",
        "asked_by": "app/lib/material/desk.dart — the plate under everything",
        "guarded": False,
    },
]

EXT = (".png", ".webp")


def stems(family):
    """Every asset stem in a family, whatever extension it is stored at.

    The library is PNG on disk and WebP after tools/pack_assets.py, and this check has to give the
    same answer before and after packing or it is a check on the packer instead of on the library.
    """
    d = ASSETS / family
    if not d.is_dir():
        return set()
    return {p.stem for p in d.iterdir() if p.suffix in EXT}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    report = {"rules": [], "breaches": [], "ok": True}
    for rule in RULES:
        have = stems(rule["family"])
        day = sorted(s for s in have if re.fullmatch(rule["day"], s))
        missing = []
        for s in day:
            want = rule["dusk"].format(day=s)
            if want not in have:
                missing.append(f"{rule['family']}/{want}")
        report["rules"].append({
            "id": rule["id"],
            "family": rule["family"],
            "asked_by": rule["asked_by"],
            "guarded": rule["guarded"],
            "day_assets": len(day),
            "dusk_assets": len(day) - len(missing),
            "missing": len(missing),
        })
        for m in missing:
            report["breaches"].append({"rule": rule["id"], "asset": m,
                                       "asked_by": rule["asked_by"]})
    report["ok"] = not report["breaches"]

    if args.out:
        p = ROOT / args.out
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(report, indent=1) + "\n")
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        for r in report["rules"]:
            mark = "ok " if not r["missing"] else "MISSING"
            print(f"{mark} {r['id']}: {r['dusk_assets']} of {r['day_assets']} have their dusk "
                  f"render  ({r['asked_by']})")
        if report["breaches"]:
            by_rule = {}
            for b in report["breaches"]:
                by_rule.setdefault(b["rule"], []).append(b["asset"])
            print()
            for rid, assets in by_rule.items():
                shown = ", ".join(assets[:6]) + (" ..." if len(assets) > 6 else "")
                print(f"{rid}: {len(assets)} asset(s) the app names at dusk and the library does "
                      f"not hold — {shown}")
            print()
            print("An Image.asset with an errorBuilder draws nothing when the file is absent, so "
                  "these do not fail anywhere else.")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
