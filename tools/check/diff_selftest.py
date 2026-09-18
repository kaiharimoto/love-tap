#!/usr/bin/env python3
"""Proof that DIFF.json measures this capture against the last one, and that one writer writes it.

    python3 tools/check/diff_selftest.py

`docs/BRIEF.md` 04 requires that after every cycle each artifact be compared against its
predecessor, labelled, and any regression fixed or rolled back before the build continues. That
rule had never once executed. `capture.sh` ran `tools/check/diff.py --rotate`, which measures
against `evidence/.previous` and only then makes this capture the new baseline — correct — and then
ran `tools/capture/collect.py`, which recomputed SSIM against the baseline that had just been
rotated to hold this very capture and overwrote the file. Every still in every DIFF.json this build
has ever shipped read `ssim: 1.0, unchanged`, because each one was compared with itself. A cycle-2
to cycle-3 regression of 2.5 points went past ten "unchanged" labels that could not have said
anything else.

A test that only asserts there is one writer would pass on a build where the one writer compares a
file with itself, which is the failure that actually happened. So this runs the real thing: a
throwaway repository with the real `tools/` in it, two captures in a row through capture.sh's own
ordering, with one still deliberately altered between them and the others left byte-identical. The
altered still must read `changed` and the others `unchanged`. Re-break it by putting collect.py's
`DIFF.json` write back and the altered still reads `unchanged` with the rest.

It is a ruler for the ruler: it writes to a temporary directory, never to `evidence/`.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

STILLS = ["01_pulse.png", "02_chat.png", "03_us.png"]
ALTERED = "02_chat.png"


def a_still(path, seed, smudge=False):
    """A still with structure in it, so SSIM has something to measure. Deterministic."""
    rng = np.random.default_rng(seed)
    a = np.full((240, 180, 3), 226, dtype=np.float64)
    a += rng.normal(0, 6, a.shape)                       # paper tooth
    for y in range(20, 240, 18):                         # ruled lines
        a[y:y + 2] -= 40
    a[60:120, 30:150] -= 55                              # something dark on it
    if smudge:
        # what "a still deliberately altered upstream" means: one region of the picture changes,
        # the way a relight or a layout change moves one region and leaves the rest alone.
        a[130:200, 40:140] -= 70
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(path)


def a_repository():
    """A throwaway root holding the real tools, so they resolve their own ROOT to it."""
    tmp = tempfile.mkdtemp(prefix="diff_selftest_")
    for sub in ("tools/check", "tools/capture", "evidence/logs"):
        os.makedirs(os.path.join(tmp, sub), exist_ok=True)
    for rel in ("tools/check/diff.py", "tools/check/ssim.py", "tools/capture/collect.py"):
        shutil.copy2(os.path.join(ROOT, rel), os.path.join(tmp, rel))
    return tmp


def a_capture(tmp, smudge_the_altered_one):
    """capture.sh's own ordering: diff.py --rotate, then collect.py."""
    for name in STILLS:
        a_still(os.path.join(tmp, "evidence", name), seed=hash(name) % 10_000,
                smudge=(smudge_the_altered_one and name == ALTERED))
    stamp = "2026-01-01T00:00:00Z"
    for cmd in ([sys.executable, os.path.join(tmp, "tools/check/diff.py"), "--rotate"],
                [sys.executable, os.path.join(tmp, "tools/capture/collect.py"), "--stamp", stamp]):
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=tmp)
        if r.returncode != 0:
            return None, f"{os.path.basename(cmd[1])} exited {r.returncode}: {r.stderr.strip()[:300]}"
    with open(os.path.join(tmp, "evidence", "DIFF.json"), encoding="utf-8") as f:
        return json.load(f), None


def rows_of(diff):
    """diff.py writes a list of rows; collect.py wrote a dict keyed by name. Read either."""
    arts = diff.get("artifacts")
    if isinstance(arts, dict):
        # collect.py's shape, which is what is on disk when the second writer is back: it calls
        # the measured word `reading` and leaves `label` for a critic, so read it as the label.
        return {k: dict(v, label=v.get("label") or v.get("reading")) for k, v in arts.items()}
    return {r["artifact"]: r for r in arts or []}


def one_writer():
    """Exactly one file writes DIFF.json, and exactly one rotates evidence/.previous."""
    problems = []
    writers, rotators = [], []
    for base, _dirs, files in os.walk(os.path.join(ROOT, "tools")):
        for fn in files:
            if not fn.endswith(".py") or fn == os.path.basename(__file__):
                continue
            path = os.path.join(base, fn)
            with open(path, encoding="utf-8") as f:
                src = f.read()
            rel = os.path.relpath(path, ROOT)
            # a write, not a mention: the name next to something that opens or writes it
            if re.search(r'(open\(|write_text|"--out",\s*default=)[^\n]*DIFF\.json', src):
                writers.append(rel)
            # a rotator is a file that both names the baseline directory and copies into it
            if re.search(r'PREVIOUS|\.previous', src) and \
               re.search(r'(shutil\.)?(copy2|copyfile|copytree|move)\(', src):
                rotators.append(rel)
    if writers != ["tools/check/diff.py"]:
        problems.append(f"DIFF.json is written by {writers or 'nothing'}; it must be written only by "
                        f"tools/check/diff.py, which measures before it rotates")
    if rotators != ["tools/check/diff.py"]:
        problems.append(f"evidence/.previous is rotated by {rotators or 'nothing'}; it must be rotated "
                        f"only by tools/check/diff.py, and only after the measurement")
    return problems


def main():
    failures = []

    for p in one_writer():
        failures.append(p)
        print(f"FAIL  {p}")
    if not failures:
        print("ok    one writer of DIFF.json and one rotator of evidence/.previous, both diff.py")

    tmp = a_repository()
    try:
        first, why = a_capture(tmp, smudge_the_altered_one=False)
        if why:
            print(f"FAIL  the first capture did not run: {why}")
            return 1
        rows = rows_of(first)
        if any(rows.get(n, {}).get("label") != "new" for n in STILLS):
            failures.append("the first capture should read new for every still")
            print(f"FAIL  first capture read {[rows.get(n, {}).get('label') for n in STILLS]}, wanted new")
        else:
            print("ok    with no baseline on disk, every still reads new")

        second, why = a_capture(tmp, smudge_the_altered_one=True)
        if why:
            print(f"FAIL  the second capture did not run: {why}")
            return 1
        rows = rows_of(second)

        got = rows.get(ALTERED, {})
        if got.get("label") != "changed":
            failures.append(
                f"a still altered upstream read {got.get('label')!r} with ssim {got.get('ssim')!r}; "
                f"a capture compared with itself is what reads unchanged at 1.0")
            print(f"FAIL  {ALTERED} altered upstream reads {got.get('label')!r} at ssim {got.get('ssim')!r}")
        else:
            print(f"ok    {ALTERED} altered upstream reads changed at ssim {got.get('ssim')}")

        held = [n for n in STILLS if n != ALTERED]
        wrong = [n for n in held if rows.get(n, {}).get("label") != "unchanged"]
        if wrong:
            failures.append(f"stills that did not move read {[rows[n].get('label') for n in wrong]}")
            print(f"FAIL  untouched stills read {[rows[n].get('label') for n in wrong]}, wanted unchanged")
        else:
            print("ok    the stills that did not move read unchanged")

        # the file that survives the capture has to be the one diff.py wrote, not a second writer's
        if "counts" not in second or "baseline" not in second:
            failures.append("the DIFF.json left on disk is not the one tools/check/diff.py writes: "
                            "it carries no counts/baseline, so something wrote over it")
            print("FAIL  the DIFF.json on disk is not diff.py's — it has no counts/baseline")
        else:
            print(f"ok    the DIFF.json on disk is diff.py's: {second['counts']}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if failures:
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 1
    print("\nDIFF.json is measured against the previous capture by one writer, "
          "and an altered still is labelled changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
