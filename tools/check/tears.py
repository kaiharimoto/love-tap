#!/usr/bin/env python3
"""The standard 02_chat.png carries: at least eight notes on screen and no tear used twice.

This reads the capture report the app itself wrote at the moment of the shot, which lists the
event ids that were on screen and the tear mask each one was torn with. The masks come out of the
same assignment the renderer used, so this is checking the frame rather than trusting a note.

AND IT READS THE WHOLE FRAME, NOT ONLY THE NOTES, which it did not until firing 40.

`docs/BRIEF.md` 09 makes reusing one tear mask a failure condition of the build and rubric row 02
asks for "tear masks with no visible repeat on a single screen". A SCREEN. The report's `tears`
map is keyed by event id, so it sees the notes and nothing else -- and a frame repeats a mask in
its chrome while this printed `distinct_tears 7, repeats {}` about it. On firing 39's capture
`12_search.surfaces.json` had 28 tear draws on screen and 13 distinct masks, because
`tear_001_shadow.webp` was drawn fourteen times: every filter tab was a `Slip` with no `row`, and
`Slip.row` defaults to 0, so all thirteen asked for `writableTears[0]` and got it. The gate was
narrower than the clause it was enforcing, which is how the defect survived four captures.

So the surfaces sidecar is read as well, where there is one: every `assets/tears/*` surface whose
rect meets the frame, counted the way a person looking at the still would count them. The frame's
size is taken from the text sidecar, which is the app's own declaration of what it drew into,
rather than from a number written here.
"""
import argparse
import json
import pathlib
import sys
from collections import Counter


def _frame_surfaces(report_path, given):
    """Every tear the frame actually drew, whatever it belongs to.

    Silent when there is no sidecar, because every capture taken before the handle existed has
    none and a missing file is not a repeated mask -- but it says so, so `frame_tear_draws: null`
    is never read as `no repeats`.
    """
    r = json.loads(pathlib.Path(report_path).read_text())
    at = r.get("at") or ""
    base = pathlib.Path(report_path).parent
    stem = pathlib.PurePosixPath(at).stem
    side = pathlib.Path(given) if given else None
    if side is None and stem:
        for d in (base, base.parent, pathlib.Path("evidence")):
            p = d / f"{stem}.surfaces.json"
            if p.exists():
                side = p
                break
    if side is None or not side.exists():
        return {"frame_surfaces": None,
                "frame_note": f"no surfaces sidecar for {stem or report_path}, so only the "
                              f"notes' tears were read"}
    surfaces = json.loads(side.read_text())

    # The frame is what the app said it drew into, not a number written here.
    w = h = None
    text = side.with_name(side.name.replace(".surfaces.json", ".text.json"))
    if text.exists():
        size = (json.loads(text.read_text()) or {}).get("size")
        if isinstance(size, list) and len(size) == 2:
            w, h = size
    if w is None:
        # the desk is the one surface that is always the whole frame
        for s in surfaces:
            if s.get("asset", "").endswith("shell/desk.webp"):
                _, _, w, h = s["rect"]
                break
    if w is None:
        return {"frame_surfaces": None,
                "frame_note": "the frame's size is not declared anywhere, so an on-screen test "
                              "would be a guess"}

    drawn = []
    for s in surfaces:
        if not s.get("asset", "").startswith("assets/tears/"):
            continue
        x, y, rw, rh = s["rect"]
        if x < w and y < h and x + rw > 0 and y + rh > 0:
            drawn.append(s["asset"])
    seen = Counter(drawn)
    return {
        "frame": [w, h],
        "frame_surfaces": str(side),
        "frame_tear_draws": len(drawn),
        "frame_distinct_tears": len(seen),
        "frame_repeats": {t: n for t, n in seen.items() if n > 1},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--min-notes", type=int, default=8)
    ap.add_argument("--out", default="")
    ap.add_argument("--frame-fatal", action="store_true",
                    help="fold the frame-wide answer into the exit code. Off by default "
                         "while the repeats filed at firing 40 are still open.")
    ap.add_argument("--surfaces", default="",
                    help="the surfaces sidecar for this shot. Found beside the report "
                         "from the artifact it names when this is not given.")
    args = ap.parse_args()

    r = json.loads(pathlib.Path(args.report).read_text())
    tears = {k: v for k, v in (r.get("tears") or {}).items() if v}
    counts = Counter(tears.values())
    repeats = {t: n for t, n in counts.items() if n > 1}
    out = {
        "report": args.report,
        "visible": len(r.get("visible") or []),
        "notes_with_tears": len(tears),
        "distinct_tears": len(counts),
        "repeats": repeats,
        "pool": r.get("masks_in_pool"),
        "scroll": r.get("scroll"),
        "driven_ms": r.get("driven_ms"),
        "seed": r.get("seed"),
    }
    frame = _frame_surfaces(args.report, args.surfaces)
    out.update(frame)

    # The frame verdict is its own verdict, and it is deliberately NOT what decides `ok` unless
    # asked for. capture.sh turns a failed `ok` into `note_missing`, and booking the hero chat
    # still as MISSING because its chrome repeats a mask would throw away the artifact rather than
    # measure it -- the reason line would read "a tear is used twice" where a reader expects "there
    # is no chat screenshot", which is the exact ambiguity this build keeps paying for. So the
    # frame answer is loud, separate, and written into the log every time; `--frame-fatal` folds it
    # into `ok` in one flag, for the firing that clears the last repeat.
    out["frame_ok"] = not frame.get("frame_repeats") and frame.get("frame_surfaces") is not None
    if frame.get("frame_surfaces") is None:
        out["frame_why"] = frame.get("frame_note", "the frame was not read")
    elif frame.get("frame_repeats"):
        out["frame_why"] = (
            "a tear is used twice in the frame: "
            + ", ".join(f"{k} x{v}" for k, v in sorted(frame["frame_repeats"].items()))
            + ". The notes are fine; this is the chrome, which the event-id map cannot see."
        )

    out["ok"] = (
        len(tears) >= args.min_notes
        and not repeats
        and (out["frame_ok"] or not args.frame_fatal)
    )
    if not out["ok"]:
        if repeats:
            out["why"] = "a tear is used twice"
        elif len(tears) < args.min_notes:
            out["why"] = f"only {len(tears)} notes on screen"
        else:
            out["why"] = out.get("frame_why", "the frame repeats a tear")
    if args.out:
        pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        pathlib.Path(args.out).write_text(json.dumps(out, indent=1))
    print(json.dumps(out, indent=1))
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
