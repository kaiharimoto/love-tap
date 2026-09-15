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
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT = os.path.join(ROOT, "app", "build", "app", "outputs", "flutter-apk")


def apksigner():
    """Wherever the Android tools happen to be.

    This looked only inside `toolchain/android-sdk`, which is where bootstrap.sh puts them and is
    nowhere on a CI runner: the check then reported "no apksigner" and said nothing about the
    signature, which is the one thing it exists to read. Ordered by how specific each answer is.
    """
    named = os.environ.get("APKSIGNER", "")
    if named and os.access(named, os.X_OK):
        return named
    roots = [os.path.join(ROOT, "toolchain", "android-sdk")]
    for var in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        where = os.environ.get(var, "")
        if where:
            roots.append(where)
    for where in roots:
        got = sorted(glob.glob(os.path.join(where, "build-tools", "*", "apksigner")))
        if got:
            return got[-1]
    return shutil.which("apksigner")


def whose_signature(path):
    tool = apksigner()
    if not tool:
        return {"read": False, "why": "no apksigner in toolchain/android-sdk/build-tools"}
    try:
        got = subprocess.run([tool, "verify", "--print-certs", path],
                             capture_output=True, text=True, timeout=180)
    except Exception as e:                                   # noqa: BLE001
        return {"read": False, "why": str(e)}
    out = got.stdout
    dn = re.search(r"Signer #1 certificate DN: (.+)", out)
    sha = re.search(r"Signer #1 certificate SHA-256 digest: (\w+)", out)
    name = dn.group(1).strip() if dn else None
    if name is None:
        # This used to fall through with signed_by null and is_the_debug_key false, and say in
        # words that the APK was "signed with a key that is not the shared debug one" — about a
        # file whose signature it had just failed to read. The first CI run did exactly that to a
        # debug-signed APK, which is the one thing this check exists to catch. A signature nobody
        # could read is not a signature that passed.
        return {
            "read": False,
            "why": "apksigner ran and printed no 'Signer #1 certificate DN' line",
            "apksigner": tool,
            "exit_code": got.returncode,
            "it_said": (out.strip() + ("\n" + got.stderr.strip() if got.stderr.strip() else ""))[:1200],
            "what_that_means": "not knowing who signed an APK is not the same as it being signed "
                               "properly, and nothing whose signature cannot be read gets released",
        }
    # The debug key is the same on every machine that has ever run the Android tools.
    debug = bool("CN=Android Debug" in name)
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


def the_web_app_inside(path):
    """Whether this APK can hand the iPhone a page, and what it weighs.

    Step 4 of docs/PHONES.md tells a person to open the host's address in Safari. Before
    tools/pack_pwa.py existed there was nothing there to open: the app never passed a bundle to
    its own server and every static GET answered 404, silently, with the setup list still ticking
    the step. So it is read out of the built APK rather than assumed from a build log.
    """
    files, total = 0, 0
    with zipfile.ZipFile(path) as z:
        for i in z.infolist():
            if i.filename.startswith("assets/pwa/"):
                files += 1
                total += i.file_size
        names = {i.filename for i in z.infolist()}
    has_page = "assets/pwa/index.html" in names
    out = {
        "files": files,
        "mb": round(total / 1e6, 1),
        "index_html": has_page,
        "engine": any(n.startswith("assets/pwa/canvaskit/") for n in names),
        "service_worker": "assets/pwa/push/sw.js" in names,
    }
    if not has_page:
        out["why_it_matters"] = (
            "no assets/pwa/index.html: this phone has no web app to serve, so the iPhone opening "
            "https://100.x.y.z:8443 gets a 404 and there is nothing to add to a home screen. "
            "Run flutter build web and then tools/pack_pwa.py before building the APK."
        )
    return out


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
        # Two measurements from earlier builds on this machine, kept because they are what the
        # build flags in docs/PHONES.md are for and neither can be re-measured from the file that
        # happens to be on disk now. They are stated as history, not as this build.
        "measured_on_earlier_builds_here": {
            "with_no_key.properties": {
                "signed_by": "C=US, O=Android, CN=Android Debug",
                "what_that_means": "Flutter's template signs a release with the shared debug key "
                                   "and says nothing. The build prints a block about it now, and "
                                   "this check reads the certificate out of the file rather than "
                                   "trusting the log.",
            },
            "without_--split-per-abi": {
                "mb": 145.0,
                "abis": ["arm64-v8a", "armeabi-v7a", "x86_64"],
                "what_that_means": "38.6 MB of engines and app images for phones the owner does "
                                   "not have. Every Android phone made this decade is arm64.",
            },
        },
        "the_key_that_signs_these": "an RSA key made in this session's scratchpad, outside the repository, and handed to the "
                                    "owner along with the APK it signed. Keeping it is the point: only a "
                                    "build signed with the same key can replace this one on the phone, and "
                                    "uninstalling to get round that takes the log with it. It exists in this "
                                    "record only as the distinguished name below, which is how a reader can see "
                                    "that the signing config works and that it was not the shared debug key. No "
                                    "keystore, no password and no key.properties is in this repository or ever "
                                    "was; app/android/.gitignore covers all three.",
        "apks": {},
    }
    ok = True
    for p in paths:
        if not os.path.exists(p):
            continue
        got = {"mb": round(os.path.getsize(p) / 1e6, 1)}
        got.update(weigh(p))
        got["signature"] = whose_signature(p)
        got["the_web_app_it_hands_over"] = the_web_app_inside(p)
        report["apks"][os.path.basename(p)] = got
        if got["signature"].get("is_the_debug_key") or not got["signature"].get("read"):
            ok = False
        if not got["the_web_app_it_hands_over"]["index_html"]:
            ok = False
    report["ok"] = ok and bool(report["apks"])
    if not report["apks"]:
        report["ok"] = False
        report["why_not"] = "no APK has been built; run flutter build apk --release"
    elif not ok:
        debug = [n for n, g in report["apks"].items() if g["signature"].get("is_the_debug_key")]
        unread = [n for n, g in report["apks"].items() if not g["signature"].get("read")]
        if debug:
            report["why_not"] = "an APK here is signed with the shared debug key"
        elif unread:
            report["why_not"] = ("the signature on an APK here could not be read, and an unread "
                                 "signature is not a passed one; see `it_said` beside it")
        else:
            report["why_not"] = "an APK here carries no web app, so the iPhone has nothing to install"
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        os.makedirs(os.path.dirname(a.out), exist_ok=True)
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
