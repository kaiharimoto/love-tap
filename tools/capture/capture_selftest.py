#!/usr/bin/env python3
"""Proof that the capture says something true about an artifact it refused.

    python3 tools/capture/capture_selftest.py

Three faults, each of which let a capture go red and tell the reader the wrong thing, or nothing
at all. They are tested together because they are one story: an artifact was refused, and the
manifest -- the only file in this repository whose job is to record what the build measured of
itself -- could not say whose it was or why.

  1. `collect.py` appended "a copy from an earlier run is still on disk ... it is not this
     session's" to EVERY refused artifact whose file existed, without comparing the time it
     printed to anything. The branch immediately below it made exactly that comparison and was
     never reached. MANIFEST.json said of `02_chat.png` that it was not this session's; it had
     been written fourteen minutes into the run. Firing 31's visual-design critic believed it.

  2. A reason that is the EMPTY STRING is falsy, and `reasons.get(name) or reasons.get(key)`
     fell through it to None -- so a scene that refused an artifact and said nothing about why
     had that artifact booked as present and complete. The same empty reason, keyed by the bare
     scene name that `capture.sh`'s run_scene uses, then survived the filter meant to catch
     unknown keys and was added to `missing` under a name no artifact has. That is why firing
     30's manifest read 14 present plus 4 missing against a set of seventeen.

  3. `scene.js` recorded a page error as `String(e)`, which is the empty string for the class of
     value the app throws, and wrote its problems to stdout while `capture.sh` reads the first
     line of stderr. Either one alone empties the reason. Two captures lost a hero artifact with
     nothing attached to say why.

  4. A capture HANDLE that could not do what it was asked returned quietly, and `hook()` reads a
     handle that returns as a handle that worked. `__deskScrollTo` was given a seeded event id
     that named nothing in the PWA -- the two rigs minted different ids, repaired at firing 38 --
     so `indexWhere` returned -1, the function returned, the list never moved, and the shutter
     photographed the thread where it stood. 02_chat came back with six notes against a floor of
     eight, exit 0, a clean log and a clean manifest. Nothing anywhere said an anchor had not been
     found. That is the one failure shape the three above cannot catch, because there was no
     refusal to attribute: the artifact was booked PRESENT.

Each section runs the real tool against a throwaway directory, checks it says the true thing, and
then puts the fault back and checks it says the false one. A section that only asserts the fixed
behaviour cannot tell a fix from a tool that stopped looking.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
COLLECT = os.path.join(HERE, "collect.py")
SCENE = os.path.join(HERE, "scene.js")

STAMP_FMT = "%Y-%m-%dT%H:%M:%SZ"


def a_png(path, w=64, h=64):
    from PIL import Image
    Image.new("RGB", (w, h), (200, 190, 170)).save(path)


def collect(evidence, stamp, missing_lines):
    """Run collect.py against a throwaway evidence directory and hand back its manifest."""
    mfile = os.path.join(evidence, "missing.txt")
    with open(mfile, "w", encoding="utf-8") as f:
        f.write("\n".join(missing_lines) + ("\n" if missing_lines else ""))
    p = subprocess.run([sys.executable, COLLECT, "--stamp", stamp, "--missing", mfile,
                        "--evidence", evidence],
                       capture_output=True, text=True, cwd=ROOT)
    out = os.path.join(evidence, "MANIFEST.json")
    if not os.path.exists(out):
        return p, None
    with open(out, encoding="utf-8") as f:
        return p, json.load(f)


def main():
    failures = []

    def check(ok, line):
        print(("ok    " if ok else "FAIL  ") + line)
        if not ok:
            failures.append(line)

    now = time.time()
    # The run began a minute ago; everything the scenes wrote is younger than that.
    stamp = time.strftime(STAMP_FMT, time.gmtime(now - 60))

    # ---- 1. whose file it is, decided by the clock --------------------------------------
    with tempfile.TemporaryDirectory() as ed:
        png = os.path.join(ed, "02_chat.png")
        a_png(png)
        os.utime(png, (now - 10, now - 10))          # written during the run, then refused
        _, m = collect(ed, stamp, ["02_chat.png|the scene refused it"])
        said = m["missing"].get("02_chat.png", "")
        check("not this session" not in said,
              "an artifact written during the run and refused is not called someone else's")
        check("refused it, so the file on disk is this run's" in said,
              "and the manifest says what it actually is: this run's, and still not counted")
        check("02_chat.png" not in m["artifacts"],
              "still not counted -- a refused artifact is missing whatever is on disk")

        # The other half of the pair. Same artifact, same refusal, one thing changed: the clock.
        os.utime(png, (now - 7200, now - 7200))
        _, m2 = collect(ed, stamp, ["02_chat.png|the scene refused it"])
        said2 = m2["missing"].get("02_chat.png", "")
        check("a copy from an earlier run is still on disk" in said2,
              "and a file that really does predate the run is still called an earlier run's")
        check("02_chat.png" not in m2["artifacts"],
              "and is not counted either, which is the sentence that was always the true half")

    # ---- 2. a refusal with nothing said, under the name run_scene uses -------------------
    with tempfile.TemporaryDirectory() as ed:
        png = os.path.join(ed, "13_messenger_states.png")
        a_png(png)
        os.utime(png, (now - 10, now - 10))
        # Exactly what capture.sh writes when `head -1` of an empty stderr is the reason: the
        # BARE scene name, a pipe, and nothing.
        _, m = collect(ed, stamp, ["13_messenger_states|"])
        check("13_messenger_states.png" in m["missing"],
              "a refusal keyed by the bare scene name misses the artifact it is about")
        check("13_messenger_states.png" not in m["artifacts"],
              "so an artifact refused with an empty reason is not booked as complete")
        check("13_messenger_states" not in m["missing"],
              "and no phantom entry appears under the bare name beside it")
        check(len(m["artifacts"]) + len(m["missing"]) == 17,
              f"the set still adds up to seventeen "
              f"({len(m['artifacts'])} present + {len(m['missing'])} missing)")
        check("reported no reason" in m["missing"]["13_messenger_states.png"],
              "and a scene that refused an artifact silently is named as having done so")

    # ---- 3. a thrown value with an empty toString still names a throw site ---------------
    # scene.js drives a real browser, so this section needs the toolchain's playwright. Where it
    # is absent the section says so rather than passing: a check that skips itself quietly is the
    # same failure as a floor that gates nothing.
    pw = os.path.join(ROOT, "toolchain", "pw", "node_modules", "playwright")
    if not os.path.isdir(pw):
        check(False, "scene.js needs toolchain/pw; run ./bootstrap.sh --profile=web first")
    else:
        with tempfile.TemporaryDirectory() as sd:
            probe = os.path.join(sd, "probe.html")
            with open(probe, "w", encoding="utf-8") as f:
                # A thrown value whose name, message and toString are all empty. This is the
                # shape the app throws, and the shape that reported `pageerror: ` and nothing.
                f.write("<!doctype html><meta charset=utf-8><title>probe</title><script>\n"
                        "window.__deskReady = true;\n"
                        "function throwsHere() {\n"
                        "  const e = new Error(); e.name = ''; e.message = '';\n"
                        "  e.toString = () => ''; throw e;\n"
                        "}\n"
                        "setTimeout(throwsHere, 30);\n"
                        "</script>\n")
            logp = os.path.join(sd, "probe.json")
            scene = os.path.join(sd, "probe_scene.json")
            with open(scene, "w", encoding="utf-8") as f:
                json.dump({"name": "probe", "viewport": {"width": 320, "height": 480, "dpr": 1},
                           "settle": 100, "log": logp,
                           "steps": [{"do": "wait", "ms": 400}]}, f)
            p = subprocess.run(["node", SCENE, scene, "--url", "file://" + probe,
                                "--browser", "chromium"],
                               capture_output=True, text=True, cwd=ROOT)
            first = (p.stderr.strip().splitlines() or [""])[0]
            with open(logp, encoding="utf-8") as f:
                log = json.load(f)
            said = " ".join(log.get("problems", []))
            check(p.returncode == 1, f"a scene that collected a problem exits 1 ({p.returncode})")
            # Worth writing down, because this check does NOT discriminate and a successor
            # reading it as though it did would be misled. Playwright re-marshals a page error
            # across the protocol boundary, so by the time the handler sees it `String(e)` is
            # `PlaywrightError: Error` rather than the empty string the app produces in a real
            # capture. Putting `String(e)` back leaves this one passing. The two checks below are
            # the ones that fail with the fault in, and they are the substance of it either way:
            # what was lost was never the word "Error", it was the throw site.
            check(said.strip() not in ("", "pageerror:"),
                  f"the problem is recorded with something in it ({said!r})")
            check("throwsHere" in said,
                  "it names the function it was thrown from, which is what e.stack always held")
            # The channel, which is the half that recording the stack does not fix. capture.sh
            # books the failure with `head -1` of stderr, so the first line has to be the
            # sentence -- not stdout, not the log file, and not a stack trace's opening line.
            check(first and "probe refused:" in first,
                  f"and the first line of STDERR is the sentence capture.sh reads ({first!r})")
            check("throwsHere" in first,
                  "so the reason that reaches MANIFEST.json names the throw site")

    # ---- 4. a handle that cannot do what it was asked does not pass for one that did ----
    # The app is not built here, so the two behaviours are put on a probe page directly: one
    # `__deskScrollTo` that throws the way the repaired handle throws, and one that returns the
    # way it used to. What is under test is the whole path from a handle that cannot land to an
    # artifact that is not booked -- `hook()` refusing, the reason carrying the anchor, and the
    # PNG never being written.
    if not os.path.isdir(pw):
        check(False, "scene.js needs toolchain/pw; run ./bootstrap.sh --profile=web first")
    else:
        anchor = "01KPV0SDX06FA58CJ9JXH23W7R"  # the id from the capture that found this

        def run_scroll_probe(handle_body):
            with tempfile.TemporaryDirectory() as sd:
                probe = os.path.join(sd, "probe.html")
                with open(probe, "w", encoding="utf-8") as f:
                    # The two sidecar handles are stubbed so the only thing that differs
                    # between the two runs below is what __deskScrollTo does. Without them the
                    # scene refuses for want of a handle and the comparison measures that
                    # instead -- though even then the PNG is written, which is the half that
                    # matters and the half the old behaviour got wrong.
                    f.write("<!doctype html><meta charset=utf-8><title>probe</title><script>\n"
                            "window.__deskReady = true;\n"
                            "window.__deskTextRuns = function () { return '[]'; };\n"
                            "window.__deskPaperSurfaces = function () { return '[]'; };\n"
                            "window.__deskScrollTo = function (a) { " + handle_body + " };\n"
                            "</script>\n")
                shot = os.path.join(sd, "02_chat.png")
                scene = os.path.join(sd, "probe_scene.json")
                with open(scene, "w", encoding="utf-8") as f:
                    json.dump({"name": "02_chat",
                               "viewport": {"width": 320, "height": 480, "dpr": 1},
                               "settle": 50,
                               "steps": [{"do": "scrollTo", "arg": anchor},
                                         {"do": "shot", "out": shot}]}, f)
                p = subprocess.run(["node", SCENE, scene, "--url", "file://" + probe,
                                    "--browser", "chromium"],
                                   capture_output=True, text=True, cwd=ROOT)
                return p, os.path.exists(shot)

        # The repaired handle: it throws, naming the anchor it could not find.
        p, shot_exists = run_scroll_probe(
            "throw new Error('no anchor \"' + a + '\" in the thread');")
        said = (p.stderr or "") + (p.stdout or "")
        check(p.returncode != 0,
              f"a scene whose handle could not land is refused ({p.returncode})")
        check(not shot_exists,
              "and no PNG is written, so the artifact is booked missing rather than present")
        check(anchor in said,
              "and the anchor it could not find is in the reason, which is what makes it findable")

        # The fault put back: the handle returns, exactly as it did before firing 38.
        p2, shot_exists2 = run_scroll_probe("return;")
        check(p2.returncode == 0 and shot_exists2,
              "and with the silent return put back the scene passes and writes a PNG, which is "
              "how a shot of six notes was booked as a shot of twelve")

    if failures:
        print(f"\n{len(failures)} check(s) failed", file=sys.stderr)
        return 1
    print("\nevery check passed: a refused artifact is named, dated and attributed correctly")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
