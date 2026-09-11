#!/usr/bin/env python3
"""No pale rectangle on the glass may be flatter than the paper the library actually holds.

The material row's hard rule is that a surface must not read as an approximation of paper, and the
one shape that always does is a flat fill with a shadow under it. Every check the build had for
that read the *assets* — the paper floor in surfaces.py, the tooth measured on a stock. None of
them read the glass, and the thing they missed was on the glass for a second and a half of a clip:
an authored feeling landing on a pale, square-cornered, untextured card, luma standard deviation
0.87 over 80 device pixels against 32.5 and 43.2 on the module strips either side of it.

**The floor is now taken from the library instead of from one screenshot, and that changed it by a
factor of seven.** It used to be 2.0, read off 02_chat.png: 288 pale windows, flattest 4.58, median
33.6. But 02_chat is a screen of small notes, and the quietest stocks never appear on it. Measured
over all twenty-seven packed stocks, the first-percentile 80-pixel window is 0.67 and the quietest
single window is 0.57, both on receipt_01 — thermal receipt paper, which is smooth, because that is
what receipt paper is. A floor of 2.0 was four times above what the material itself produces, so
what it had been reporting on 05_settings, 03_us and 17_setup_pwa was not fills. It was paper.

So: the floor is the quietest first-percentile in the library, halved. Halved because a stock drawn
larger than life is resampled and a resample only ever smooths — measured, magnifying by three
takes the same number from 0.671 to 0.508, a factor of 0.76, and half covers it with room. The
report carries its own negative control: a flat fill of the app's own paper colour, measured by the
same code in the same box, so a reader can see the gate has something to catch.

Everything under 2.0 is still counted, as `quiet_windows`, because that is the number four cycles
of reports have been carrying and it should not silently vanish. Quiet is not flat.

    python3 tools/check/flat.py --out evidence/logs/flat.json
    python3 tools/check/flat.py evidence/02_chat.png
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EVIDENCE = os.path.join(ROOT, "evidence")
PAPER = os.path.join(ROOT, "assets", "paper")
QUIET = 2.0


def _lum(rgb):
    return rgb.mean(axis=2)


def windows(path, box, step, pale):
    """Every pale, paper-coloured window, with how flat it is.

    Paper-coloured, not merely pale: a photograph of a bright sky is flat and pale too — 305
    windows of 14_media_viewer read a standard deviation of 0.00, and every one of them is the
    sky over the water in the picture somebody sent. That is content, not a rectangle standing in
    for paper. The app's paper is cream and warm, so a window counts only when its red channel
    leads its blue by between four and forty levels, which the sky never does and the wood never
    reaches.
    """
    import numpy as np
    from PIL import Image
    with Image.open(path) as im:
        rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
    a = _lum(rgb)
    warm = rgb[..., 0] - rgb[..., 2]
    h, w = a.shape
    worst = (1e9, None)
    flat = []
    for y in range(0, h - box, step):
        for x in range(0, w - box, step):
            q = a[y:y + box, x:x + box]
            if q.mean() < pale:
                continue
            k = float(warm[y:y + box, x:x + box].mean())
            if k < 4.0 or k > 40.0:
                continue
            s = float(q.std())
            if s < worst[0]:
                worst = (s, [x, y])
            flat.append((s, x, y))
    return worst, flat


def library_floor(box, step=120):
    """The quietest first-percentile window in the packed library, halved.

    Every stock, at the density it was rendered. A stock drawn larger is resampled and a resample
    only smooths, so half of this is under anything the app can put on the glass.
    """
    import numpy as np
    from PIL import Image
    lowest = None
    for path in sorted(glob.glob(os.path.join(PAPER, "*.webp"))):
        if "_dusk" in os.path.basename(path):
            continue
        with Image.open(path) as im:
            a = _lum(np.asarray(im.convert("RGB"), dtype=np.float32))
        h, w = a.shape
        got = []
        for y in range(0, h - box, step):
            for x in range(0, w - box, step):
                q = a[y:y + box, x:x + box]
                if q.mean() < 190.0:
                    continue
                got.append(float(q.std()))
        if not got:
            continue
        p1 = float(np.percentile(np.array(got), 1))
        if lowest is None or p1 < lowest[0]:
            lowest = (p1, os.path.basename(path), float(min(got)), len(got))
    if lowest is None:
        return None
    return {
        "stock": lowest[1],
        "windows_measured_on_it": lowest[3],
        "first_percentile": round(lowest[0], 3),
        "quietest_window": round(lowest[2], 3),
        "floor": round(lowest[0] / 2.0, 3),
        "why_halved": "a stock drawn larger than life is resampled and a resample only smooths: "
                      "magnifying the same stock by three takes 0.671 to 0.508, a factor of 0.76",
    }


def negative_control(box):
    """What a flat fill of the app's own paper colour measures, by this same code.

    So the gate can be seen to have something to catch rather than asserted to.
    """
    import numpy as np
    fill = np.full((box, box, 3), (243, 238, 227), dtype=np.float32)
    return {
        "a_flat_fill_of_0xFFF3EEE3": round(float(_lum(fill).std()), 3),
        "note": "the literal Container colour that used to stand in for a sheet in authoring.dart",
    }


def _frame_px(path):
    try:
        from PIL import Image
        w, h = Image.open(path).size
        return w * h
    except Exception:
        return 1


# The colours a PaperPiece falls back to when its render has not arrived, read off
# app/lib/material/palette.dart. A flat area of one of these exact values is a sheet with no paper
# on it; a flat area of anything else is a photograph of something flat, which is not this build's
# fault. That distinction is the whole reason 14_media_viewer's sky is not counted: it is 219 to
# 230 and slightly blue, and none of these.
FALLBACKS = {
    (0xF1, 0xEC, 0xDF): "Paper.lined",
    (0xEC, 0xE0, 0xC2): "Paper.aged",
    (0xE9, 0xEC, 0xEC): "Paper.graph",
    (0xF3, 0xE6, 0xA8): "Paper.legal",
    (0xF6, 0xF1, 0xE6): "Paper.index",
    (0xF2, 0xED, 0xE2): "Paper.looseleaf",
    (0xEF, 0xEA, 0xDC): "Paper.spiral",
    (0xF3, 0xE0, 0x8A): "Paper.stickyYellow",
    (0xF2, 0xC1, 0xC1): "Paper.stickyPink",
    (0xE7, 0xE0, 0xCE): "Paper.underside",
    (0xF3, 0xEE, 0xE3): "the literal Container fill authoring.dart used to use",
}


def _fallback_name(rgb, tol=2):
    for k, name in FALLBACKS.items():
        if all(abs(a - b) <= tol for a, b in zip(rgb, k)):
            return name
    return None


def plateaus(path, pale=190.0, span=1.0, smallest=2000):
    """Every pale patch of the frame that is flat, found directly rather than through a window.

    The 80-pixel window is the gate and it under-counts: a voice-note tile is 410 by 170 with a
    waveform and a line of writing across the middle of it, so only one of six identical cards had
    an 80-pixel square of nothing in it and the report said `windows_under_the_floor: 1` for five
    point eight per cent of the frame. This says what is actually there — a pixel whose five-by-five
    neighbourhood spans no more than [span] grey levels is flat, and the connected regions of those
    that are at least [smallest] pixels are the shapes a reader can go and look at.
    """
    try:
        import numpy as np
        from PIL import Image
    except Exception:
        return []
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    h, w = lum.shape
    k = 5
    lo = np.full(lum.shape, np.inf, dtype=np.float32)
    hi = np.full(lum.shape, -np.inf, dtype=np.float32)
    for dy in range(-(k // 2), k // 2 + 1):
        for dx in range(-(k // 2), k // 2 + 1):
            sh = np.roll(np.roll(lum, dy, axis=0), dx, axis=1)
            lo = np.minimum(lo, sh)
            hi = np.maximum(hi, sh)
    flat = (hi - lo <= span) & (lum >= pale)
    flat[: k // 2, :] = flat[-(k // 2):, :] = False
    flat[:, : k // 2] = flat[:, -(k // 2):] = False
    try:
        from scipy import ndimage
        lab, n = ndimage.label(flat)
        out = []
        for i in range(1, n + 1):
            ys, xs = np.where(lab == i)
            if len(ys) < smallest:
                continue
            rgb = tuple(int(v) for v in a[ys[0], xs[0]])
            out.append({
                "area_px": int(len(ys)),
                "box": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                "luma": round(float(lum[ys[0], xs[0]]), 1),
                "rgb": "#%02X%02X%02X" % rgb,
                # named only when it is one of the app's own fallback fills
                "a_sheet_with_no_paper_on_it": _fallback_name(rgb),
            })
    except Exception:
        return []
    out.sort(key=lambda r: -r["area_px"])
    return out


def extents(path, offenders, tol=1.0):
    """How big each flat area actually is, not just the window that found it.

    A window is 80 pixels and the shape it lands in is a card. `windows_under_the_floor: 1` was the
    whole of what this check said about six cream rectangles covering 260,907 pixels — 5.8 per cent
    of the frame — which is a number a reader has to go and measure for themselves before they can
    tell a sampling artefact from a fifth of the screen. So each offending window is grown over
    everything within `tol` grey levels of it, four-connected, and what comes back is the area and
    the box it sits in.
    """
    if not offenders:
        return []
    try:
        import numpy as np
        from PIL import Image
    except Exception:
        return []
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    h, w = lum.shape
    seen = np.zeros(lum.shape, dtype=bool)
    out = []
    for o in offenders:
        x0, y0 = o["at"]
        cx, cy = min(x0 + 40, w - 1), min(y0 + 40, h - 1)
        if seen[cy, cx]:
            continue
        target = lum[cy, cx]
        near = (np.abs(lum - target) <= tol) & ~seen
        # four-connected region containing (cx, cy), by repeated dilation inside `near`
        region = np.zeros(lum.shape, dtype=bool)
        region[cy, cx] = True
        while True:
            grown = region.copy()
            grown[1:, :] |= region[:-1, :]
            grown[:-1, :] |= region[1:, :]
            grown[:, 1:] |= region[:, :-1]
            grown[:, :-1] |= region[:, 1:]
            grown &= near
            if grown.sum() == region.sum():
                break
            region = grown
        seen |= region
        ys, xs = np.where(region)
        out.append({
            "area_px": int(region.sum()),
            "box": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            "luma": round(float(target), 1),
        })
    out.sort(key=lambda r: -r["area_px"])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--box", type=int, default=80, help="window side in device pixels")
    ap.add_argument("--step", type=int, default=40)
    ap.add_argument("--pale", type=float, default=190.0, help="mean luma above which a window is paper-coloured")
    ap.add_argument("--floor", type=float, default=0.0,
                    help="override the floor the library gives; 0 means take it from the library")
    ap.add_argument("--allow", type=int, default=0, help="how many such windows a file may have")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    derived = library_floor(a.box)
    floor = a.floor if a.floor > 0 else (derived["floor"] if derived else 2.0)

    files = a.files or sorted(glob.glob(os.path.join(EVIDENCE, "*.png")))
    report = {
        "box": a.box,
        "pale": a.pale,
        "floor": floor,
        "floor_from": derived or "the packed library was not on disk; fell back to 2.0",
        "negative_control": negative_control(a.box),
        "the_one_it_used_to_get_wrong": "the sky of the photograph open in 14_media_viewer. This "
                "file used to say the sky no longer tripped the check because its flattest window "
                "read 0.619 — and an anti-goal critic measured the same still over the same "
                "windows and found sixty-one under 0.5, one of them a hundred per cent a single "
                "RGB triple at standard deviation exactly zero. The claim was wrong and the "
                "sampling was the reason: a window grid at step 40 lands where it lands. "
                "`flat_areas` finds the flat shapes directly now and 14_media_viewer has eight of "
                "them covering thirteen per cent of the frame, which is what a photograph of a sky "
                "actually is. What separates that from a fault is not how flat it is but what "
                "colour it is: `sheets_with_no_paper_on_them` names only the shapes whose colour "
                "is one of the app's own paper fallback fills, and none of the sky's is.",
        "quiet_is_not_flat": "windows_quieter_than_2 is what this check used to gate on, kept "
                "because four cycles of reports carry it. It is not a fault: receipt stock's own "
                "median window is under it, and the 05_settings windows it names are lined writing "
                "paper with its tooth plainly in the crop.",
        "stills": {},
    }
    bad = 0
    for f in files:
        if not os.path.exists(f):
            continue
        worst, flat = windows(f, a.box, a.step, a.pale)
        offenders = [{"at": [x, y], "std": round(s, 3)} for s, x, y in flat if s < floor]
        offenders.sort(key=lambda o: o["std"])
        # every flat shape in the frame, and then the ones the window gate actually landed in
        areas = plateaus(f) or extents(f, offenders)
        report["stills"][os.path.basename(f)] = {
            "flattest": round(worst[0], 3) if worst[1] else None,
            "where": worst[1],
            "pale_windows": len(flat),
            "windows_under_the_floor": len(offenders),
            "windows_quieter_than_2": sum(1 for s, _, _ in flat if s < QUIET),
            "worst_few": offenders[:5],
            # what the flat windows are *part of*: the shape, its size, and how much of the frame
            "flat_areas": areas[:8],
            "flat_px": sum(r["area_px"] for r in areas),
            "flat_share_of_the_frame": round(
                sum(r["area_px"] for r in areas) / max(1, _frame_px(f)), 4),
        }
        # A window under the floor, or any flat shape of one of the app's own fallback colours.
        # The window gate under-counts badly: a voice-note tile is 410 by 170 with a waveform and a
        # line of writing across the middle, so only one of six identical cream cards had an
        # 80-pixel square of nothing in it, and the report said `windows_under_the_floor: 1` for
        # five per cent of the frame.
        unpapered = [r for r in areas if r.get("a_sheet_with_no_paper_on_it")]
        report["stills"][os.path.basename(f)]["sheets_with_no_paper_on_them"] = unpapered[:8]
        if len(offenders) > a.allow or unpapered:
            bad += 1
    report["ok"] = bad == 0
    report["files_with_a_flat_fill"] = bad
    text = json.dumps(report, indent=1) + "\n"
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text)
    print(text)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
