#!/usr/bin/env python3
"""What is actually in the APK, and who actually signed it.

Two things about an Android build can only be known by opening the file it produced, and both of
them decide whether it can go on somebody's phone.

**Who signed it.** `flutter build apk --release` produces a release APK signed with the *debug*
key when no signing config is set — which is Flutter's template default and was this project's
until it was noticed. The build says so now, and a line in a build log is not evidence; this reads
the certificate out of the APK. A real key has the owner's own distinguished name. The debug key
says `CN=Android Debug` and every machine in the world has the same one, so an APK signed with it
can be replaced by anybody's build of anything with the same application id.

**What is in it.** A release built without `--split-per-abi` carries every architecture: measured
on this build, 33 MB of the 145 is two engines and two app images for phones the owner does not
have. The arm64 half is the one a phone made this decade runs.

    python3 tools/check/apk.py                       # whatever the last build left
    python3 tools/check/apk.py --out evidence/logs/apk.json
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT = os.path.join(ROOT, "app", "build", "app", "outputs", "flutter-apk")


def apksigner():
    got = sorted(glob.glob(os.path.join(ROOT, "toolchain", "android-sdk", "build-tools", "*", "apksigner")))
    return got[-1] if got else None


def whose_signature(path):
    tool = apksigner()
    if not tool:
        return {"read": False, "why": "no apksigner in toolchain/android-sdk/build-tools"}
    try:
        out = subprocess.run([tool, "verify", "--print-certs", path],
                             capture_output=True, text=True, timeout=180).stdout
    except Exception as e:                                   # noqa: BLE001
        return {"read": False, "why": str(e)}
    dn = re.search(r"Signer #1 certificate DN: (.+)", out)
    sha = re.search(r"Signer #1 certificate SHA-256 digest: (\w+)", out)
    name = dn.group(1).strip() if dn else None
    # The debug key is the same on every machine that has ever run the Android tools.
    debug = bool(name and "CN=Android Debug" in name)
    return {
        "read": True,
        "signed_by": name,
        "sha256": sha.group(1) if sha else None,
        "is_the_debug_key": debug,
        "what_that_means": (
            "this APK is signed with the key every Android install has, so anybody's build of "
            "anything with this application id can replace it, and a build signed with a real key "
            "cannot — it has to be uninstalled first, which takes the log with it"
            if debug else
            "signed with a key that is not the shared debug one; keep the keystore, because only a "
            "build signed with it can update this one"),
    }


def weigh(path):
    by = {}
    with zipfile.ZipFile(path) as z:
        for i in z.infolist():
            parts = i.filename.split("/")
            if parts[0] == "lib" and len(parts) > 1:
                by.setdefault("lib/" + parts[1], 0)
                by["lib/" + parts[1]] += i.file_size
            elif parts[0] == "assets" and len(parts) > 2:
                key = "assets/" + parts[1] + "/" + parts[2]
                by.setdefault(key, 0)
                by[key] += i.file_size
            else:
                by.setdefault(parts[0], 0)
                by[parts[0]] += i.file_size
    abis = sorted(k.split("/")[1] for k in by if k.startswith("lib/"))
    other = sum(v for k, v in by.items() if k.startswith("lib/") and "arm64-v8a" not in k)
    return {
        "abis": abis,
        "one_abi_would_save_mb": round(other / 1e6, 1) if len(abis) > 1 else 0.0,
        "biggest": [
            {"what": k, "mb": round(v / 1e6, 1)}
            for k, v in sorted(by.items(), key=lambda kv: -kv[1])[:10]
        ],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("apk", nargs="?", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    paths = [a.apk] if a.apk else sorted(glob.glob(os.path.join(DEFAULT, "*.apk")))
    report = {
        "why": "a release APK signed with the debug key installs and is not a release, and a line "
               "in a build log is not evidence of which key was used. This opens the file.",
        "apks": {},
    }
    ok = True
    for p in paths:
        if not os.path.exists(p):
            continue
        got = {"mb": round(os.path.getsize(p) / 1e6, 1)}
        got.update(weigh(p))
        got["signature"] = whose_signature(p)
        report["apks"][os.path.basename(p)] = got
        if got["signature"].get("is_the_debug_key"):
            ok = False
    report["ok"] = ok and bool(report["apks"])
    if not report["apks"]:
        report["ok"] = False
        report["why_not"] = "no APK has been built; run flutter build apk --release"
    elif not ok:
        report["why_not"] = "an APK here is signed with the shared debug key"
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
