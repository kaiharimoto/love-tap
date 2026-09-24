#!/usr/bin/env python3
"""Does anything written in the app sit on the receipt's own printout?

`assets/paper/receipt_01` is a till roll, 702x1500, and its top half is its own faded thermal
print: a header, seven to eleven item lines and a barcode, from row 130 to row 720 (measured off
the day render at firing 60: 10-row bands whose std rises past 2.5x the blank paper's 1.12). Its
lower half is blank paper to row 1460, where the roll's edge begins. The app chose that stock on
purpose in three places -- a planned date, a voice note, noor's slip pool -- and wrote over the
print, and three critics read it as "pixelated grey pseudo-text blocks, a mosaic of mojibake".

For every surfaces.json entry on receipt_01 (day or dusk) this works out which rows of the render
lie under the entry's piece, from what the entry declares: `rect` is the image box after the
piece's Transform.scale, `drawn` the box before it, `scale` the cover magnification and `align`
(since firing 60) the cover alignment. The piece's own rect comes from its mask entry. A piece
carries writing when a text.json run's rect lies inside it.

It fails when a text-carrying piece shows any row above PRINT_END. An entry with no `align` (a
sidecar written before firing 60) cannot be placed, and is counted as failing: a framing nobody
declared is not a framing anybody can check. The POPULATION -- text-carrying receipt pieces and
text-carrying pieces overall per still -- is printed so a fix that only moves writing off the
screen does not read as a pass.

    python3 tools/check/receipt_print.py [03_us 04_moments 12_search] [--dir D] [-v]
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC_H = 1500
PRINT_END = 720 / SRC_H     # the last printed row, as a fraction of the render
PAPER_END = 1460 / SRC_H    # where the roll's own edge begins


def inside(r, p, slack=4):
    return (r[0] >= p[0] - slack and r[1] >= p[1] - slack and
            r[0] + r[2] <= p[0] + p[2] + slack and r[1] + r[3] <= p[1] + p[3] + slack)


def rows_under(e, piece):
    """[top, bottom] of the render, as fractions, that lie under `piece`; None if unplaceable."""
    if "align" not in e:
        return None
    sw, sh = e["src"]
    dw, dh = e["drawn"]
    rx, ry, rw, rh = e["rect"]
    k = max(dw / sw, dh / sh)             # BoxFit.cover
    t = rh / dh                          # the piece's Transform.scale, as the rect shows it
    ay = e["align"][1]
    y0 = (sh - dh / k) * (ay + 1) / 2    # the first source row the box shows
    top = y0 + (piece[1] - ry) / t / k
    bottom = y0 + (piece[1] + piece[3] - ry) / t / k
    return max(0.0, top / sh), min(1.0, bottom / sh)


def check(name, d):
    surfaces = json.load(open(os.path.join(d, f"{name}.surfaces.json")))
    tp = os.path.join(d, f"{name}.text.json")
    runs = json.load(open(tp))["runs"] if os.path.exists(tp) else []
    masks = {e["piece"]: e["rect"] for e in surfaces if e.get("fit") == "mask" and e.get("piece")}
    writing = {p for p, r in masks.items() if any(inside(x["rect"], r) for x in runs)}
    rows = []
    for e in surfaces:
        if "paper/receipt_01" not in e["asset"] or e.get("fit") != "cover":
            continue
        p = e.get("piece")
        if p not in masks:
            continue
        span = rows_under(e, masks[p])
        written = p in writing
        ok = not written or (span is not None and span[0] >= PRINT_END and span[1] <= PAPER_END)
        rows.append({"piece": p, "asset": e["asset"], "writing": written,
                     "rows": None if span is None else [round(span[0], 3), round(span[1], 3)],
                     "ok": ok})
    return {"text_pieces": len(writing), "receipt_pieces": len(rows),
            "receipt_text_pieces": sum(r["writing"] for r in rows),
            "failing": sum(not r["ok"] for r in rows), "rows": rows}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("only", nargs="*")
    ap.add_argument("--dir", default=os.path.join(ROOT, "evidence"))
    ap.add_argument("--out")
    ap.add_argument("-v", action="store_true")
    a = ap.parse_args(argv)
    names = sorted(os.path.basename(p).split(".")[0]
                   for p in glob.glob(os.path.join(a.dir, "*.surfaces.json")))
    if a.only:
        names = [n for n in names if n in a.only]
    rep, bad = {}, 0
    for n in names:
        r = rep[n] = check(n, a.dir)
        bad += r["failing"]
        print(f"{n}: {r['text_pieces']} pieces carry writing; {r['receipt_pieces']} on the receipt, "
              f"{r['receipt_text_pieces']} of them written on; {r['failing']} show the printout")
        if a.v:
            for x in r["rows"]:
                print(f"   {'ok  ' if x['ok'] else 'FAIL'} {x['piece']} rows {x['rows']} "
                      f"{'written' if x['writing'] else 'bare'}")
    print(f"ALL: {bad} written-on receipt pieces show the printout")
    if a.out:
        json.dump(rep, open(a.out, "w"), indent=1)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
