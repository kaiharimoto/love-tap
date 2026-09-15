#!/usr/bin/env python3
"""The notes that go with a build, written from what was measured rather than from memory.

A release whose description is prose somebody typed once drifts from the file attached to it
within two builds. This reads the APK's own record — `evidence/logs/apk.json`, which
`tools/check/apk.py` writes by opening the file — plus what went into the web app, and says only
what those say. The part that cannot be measured, what is still rough, lives in docs/ROUGH_EDGES.md
so it is edited where it is true rather than inside a string in here.

    python3 tools/release_notes.py --tag v0.1.1 --out notes.md
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path, default=None):
    try:
        with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def commit():
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:                                        # noqa: BLE001
        return ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True)
    ap.add_argument("--apk", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    apk_path = a.apk or os.path.join(
        ROOT, "app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk")
    if not os.path.exists(apk_path):
        print(f"release_notes: no APK at {apk_path}", file=sys.stderr)
        return 1

    record = read("evidence/logs/apk.json", {})
    got = (record.get("apks") or {}).get(os.path.basename(apk_path), {})
    sig = got.get("signature") or {}
    signer = sig.get("signed_by")
    debug = sig.get("is_the_debug_key")
    unread = not sig.get("read", False)
    web = got.get("the_web_app_it_hands_over") or {}
    packed = read("evidence/logs/pwa_packed.json", {})
    mb = round(os.path.getsize(apk_path) / 1e6, 1)

    lines = [
        f"The Android build at `{commit() or a.tag}`. Download it, allow installs from whatever you "
        "downloaded it with, and open it. arm64 only — every Android phone made this decade. It "
        "starts on an empty log; no seeded year is compiled in.",
        "",
        "```",
        f"{mb} MB",
        f"sha256  {sha256(apk_path)}",
        "```",
        "",
    ]

    if debug:
        lines += [
            "> **This build is signed with the shared Android debug key.** It installs, and it is "
            "not a release: anybody's build of anything with this application id can replace it, "
            "and a build signed with a real key cannot — that needs an uninstall, which takes the "
            "log with it. Do not put this on a phone you intend to keep a conversation on.",
            "",
        ]
    elif unread:
        # Said, rather than left out. A release whose notes are silent about signing reads as a
        # release that was signed, and the first CI run proved this file can fail to read one.
        lines += [
            "> **Nobody could read the signature on this build.** "
            f"`{sig.get('why', 'apksigner said nothing this could parse')}` — so it is not known "
            "whether it carries a real key or the shared Android debug one. Treat it as a test "
            "build: install it on a phone you are willing to wipe, because if it turns out to be "
            "debug-signed, a real build cannot replace it without an uninstall that takes the log.",
            "",
        ]
    elif signer:
        lines += [
            f"Signed `{signer}`, not the shared Android debug key. The keystore is not in this "
            "repository and never will be; only a build signed with it can replace this one on the "
            "phone, and uninstalling to get round that takes the log.",
            "",
        ]

    if web.get("index_html"):
        lines += [
            "## What the iPhone gets",
            "",
            f"The web app is inside this APK — {web.get('files', '?')} files, "
            f"{web.get('mb', '?')} MB of page, engine and service worker — and the Android phone "
            "serves it at its own address. The material library is not packed twice: "
            f"{(packed.get('served_from_the_apps_own_assets') or {}).get('mb', '?')} MB of paper, "
            "tears, objects and folds are answered out of what the app already draws with. "
            "`docs/PHONES.md` is the setup list, in the order it has to happen.",
            "",
        ]
    else:
        lines += [
            "> **This APK carries no web app**, so there is nothing for the iPhone to install at "
            "the host's address and step 4 of `docs/PHONES.md` ends at a 404. Build it with "
            "`tools/pack_pwa.py` between the web build and the APK.",
            "",
        ]

    rough = os.path.join(ROOT, "docs/ROUGH_EDGES.md")
    if os.path.exists(rough):
        with open(rough, encoding="utf-8") as fh:
            body = fh.read().split("\n")
        # everything from the first bullet on: the file's own preamble is for whoever edits it
        first = next((i for i, l in enumerate(body) if l.startswith("- ")), None)
        if first is not None:
            lines += ["## Known rough edges", "", *body[first:], ""]

    text = "\n".join(lines).rstrip() + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
