#!/usr/bin/env python3
"""Pack the built web app into the Android build, so the phone that serves it has it.

The iPhone installs the client by opening the Android phone's address in Safari. Until now the
Android phone had nothing to hand over: `pwaRoot` — a directory of files beside the process — was
passed only by the capture's far phone under `dart run`, so `_serveStatic` in the real app
answered 404 to every GET and step four of docs/PHONES.md could not be followed.

What goes in is the web build with two things taken out:

  assets/assets/**   the material library: paper, tears, objects, folds, fonts, the seeded year.
                     Eighty-three megabytes, and byte for byte the same files this build already
                     carries in its own flutter_assets, so the app serves that half out of
                     rootBundle instead (app/lib/transport/pwa_assets.dart) and it is packed once.
  *.symbols          canvaskit's debug symbols, seven megabytes, which no browser ever fetches.

What is left is about forty megabytes: the page, the engine, canvaskit, the icons, the service
worker. It lands in Android's own assets rather than Flutter's, because anything under app/assets/
is bundled into `flutter build web` as well — a copy of the web build kept there would be packed
inside the next web build, and inside the one after that.

    python3 tools/pack_pwa.py --from app/build/web

Run it after `flutter build web` and before `flutter build apk`. docs/PHONES.md has the order.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEST = REPO / "app/android/app/src/main/assets/pwa"

# Served out of this build's own flutter_assets instead; see pwa_assets.dart.
SHARED = "assets/assets/"
# Fetched by nothing. Seven megabytes of canvaskit symbol tables.
SKIP_SUFFIX = (".symbols",)


def pack(src: Path, dest: Path) -> dict:
    if not (src / "index.html").exists():
        sys.exit(f"pack_pwa: {src} has no index.html — run `flutter build web` first")
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)

    kept, shared, skipped = [], 0, 0
    shared_bytes = 0
    for path in sorted(src.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(src).as_posix()
        if rel.startswith(SHARED):
            shared += 1
            shared_bytes += path.stat().st_size
            continue
        if rel.endswith(SKIP_SUFFIX):
            skipped += 1
            continue
        out = dest / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, out)
        kept.append((rel, path.stat().st_size))

    total = sum(size for _, size in kept)
    # What the browser will ask for first. If index.html is not the one this build made, the page
    # and the engine disagree and the other phone gets a blank screen, so its digest is recorded.
    index = hashlib.sha256((dest / "index.html").read_bytes()).hexdigest()[:16]
    report = {
        "from": str(src),
        "files": len(kept),
        "mb": round(total / 1e6, 1),
        "index_sha256_16": index,
        "served_from_the_apps_own_assets": {
            "files": shared,
            "mb": round(shared_bytes / 1e6, 1),
            "why": "the material library is in flutter_assets already; pwa_assets.dart maps "
                   "assets/assets/<x> onto this build's own assets/<x>",
        },
        "left_out": {"symbols": skipped},
        "biggest": [
            {"what": rel, "mb": round(size / 1e6, 2)}
            for rel, size in sorted(kept, key=lambda k: -k[1])[:8]
        ],
    }
    return report


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", default=str(REPO / "app/build/web"))
    ap.add_argument("--dest", default=str(DEST))
    ap.add_argument("--out", default=str(REPO / "evidence/logs/pwa_packed.json"))
    args = ap.parse_args()

    report = pack(Path(args.src), Path(args.dest))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=1) + "\n")
    print(f"pwa: {report['files']} files, {report['mb']} MB into {args.dest}")
    print(f"     {report['served_from_the_apps_own_assets']['files']} files "
          f"({report['served_from_the_apps_own_assets']['mb']} MB) left to the app's own assets")


if __name__ == "__main__":
    main()
