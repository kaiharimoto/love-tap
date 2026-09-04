#!/usr/bin/env python3
"""tools/pack_assets.py — build app/assets/ from the baked library and the seeded year.

    python3 tools/pack_assets.py                 # material only
    python3 tools/pack_assets.py --seed=year     # material + the seeded year

assets/ holds the library at render resolution; the app cannot carry that (a 2200 px sheet is
megabytes, and WebKit has a texture budget). This step copies it into app/assets/ at display
resolution as WebP, writes app/assets/INDEX.json describing what is actually there, and — only
when asked — copies the seeded year in as well, so a build started without --seed=year cannot
contain the seed.

app/assets/ is gitignored: it is derived, and capture.sh regenerates it.
"""
import argparse
import json
import os
import re
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "assets")
DST = os.path.join(ROOT, "app", "assets")
SEED_SRC = os.path.join(ROOT, "seed")
SEED_DST = os.path.join(DST, "seed")

# display sizes: the long side in the app, per family
SIZES = {
    "paper": 1500,        # a sheet fills at most the screen width at 3x
    "tears": 1024,        # masks are alpha only
    "objects": 420,       # a feeling object is at most ~140 dp
    "bits": 420,
    "folds": 540,
    "shell": 1500,
}
QUALITY = {"paper": 88, "tears": 92, "objects": 92, "bits": 92, "folds": 90, "shell": 88}


def convert(src, dst, long_side, quality, keep_alpha, luminance_to_alpha=False, crop=None):
    from PIL import Image
    im = Image.open(src)
    if crop is not None:
        # every render of one tear shares a camera, so one box keeps them registered
        sx = im.width / 2048.0
        sy = im.height / 2048.0
        im = im.crop((round(crop[0] * sx), round(crop[1] * sy), round(crop[2] * sx), round(crop[3] * sy)))
    if luminance_to_alpha:
        # a tear mask is white paper on black; the app masks with dstIn against the alpha channel,
        # so pack it as white with the paper in alpha
        a = im.convert("L")
        im = Image.merge("RGBA", (Image.new("L", a.size, 255), Image.new("L", a.size, 255),
                                  Image.new("L", a.size, 255), a))
    else:
        im = im.convert("RGBA" if keep_alpha else "RGB")
    if max(im.size) > long_side:
        s = long_side / max(im.size)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    # alpha-carrying files are packed losslessly: a lossy alpha frays a torn edge
    if im.mode == "RGBA":
        im.save(dst, "WEBP", lossless=True, method=4, exact=True)
    else:
        im.save(dst, "WEBP", quality=quality, method=5, lossless=False)
    return im.size


def paper_box(mask_path, margin=0.02):
    """The rectangle the piece of paper occupies inside its square render, with a little margin so
    the fibres that hang past the break survive the crop. The mask, the edge light and the shadow
    all come from the same camera, so one box crops all three and they stay registered."""
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(mask_path).convert("L"), dtype=np.float32) / 255.0
    # the loose fibres that hang past the break are not the piece: open the mask so a hair does
    # not push the box out by half a centimetre
    import cv2
    body = cv2.morphologyEx((a > 0.5).astype(np.uint8), cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
    ys, xs = np.where(body > 0)
    if len(xs) == 0:
        return None
    h, w = a.shape
    mx, my = int(w * margin), int(h * margin)
    return (max(0, int(xs.min()) - mx), max(0, int(ys.min()) - my),
            min(w, int(xs.max()) + 1 + mx), min(h, int(ys.max()) + 1 + my))


def safe_inset(mask_path, box):
    """The largest rectangle that is entirely paper, as fractions in from each edge.

    A torn edge wanders, and a bite out of one corner is exactly where a first line would sit, so
    this is not a percentile: it is the maximal axis-aligned rectangle inscribed in the solid part
    of the mask (the classic largest-rectangle-in-a-histogram sweep), which cannot be wrong.
    Writing laid inside it can never be cut by the tear."""
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(mask_path).convert("L"), dtype=np.float32) / 255.0
    a = a[box[1]:box[3], box[0]:box[2]]
    solid = (a > 0.85).astype(np.int32)
    h, w = solid.shape
    # work at a coarse resolution: a millimetre of precision is plenty and this is O(h*w)
    step = max(1, min(h, w) // 220)
    if step > 1:
        solid = solid[::step, ::step]
        h, w = solid.shape
    heights = np.zeros(w, dtype=np.int32)
    best = (0, 0, 0, 0, 0)   # area, top, left, bottom, right
    for y in range(h):
        heights = np.where(solid[y] > 0, heights + 1, 0)
        stack = []
        for x in range(w + 1):
            cur = heights[x] if x < w else 0
            start = x
            while stack and stack[-1][1] > cur:
                sx, sh = stack.pop()
                area = sh * (x - sx)
                if area > best[0]:
                    best = (area, y - sh + 1, sx, y, x - 1)
                start = sx
            stack.append((start, cur))
    _, top, left, bottom, right = best
    if best[0] == 0:
        return [0.08, 0.08, 0.08, 0.08]
    return [
        round(left / w, 4),
        round(top / h, 4),
        round(1.0 - (right + 1) / w, 4),
        round(1.0 - (bottom + 1) / h, 4),
    ]


# How much wider than the piece the packed contact shadow is. The renderer frames the shadow wider
# than the sheet because the visible part of one is the part outside the paper; packing keeps that
# margin relative to the piece's own box, so the app can put every shadow back with one number
# instead of a different one per mask.
SHADOW_MARGIN = 1.25


def _expand(box, factor):
    cx = (box[0] + box[2]) / 2.0
    cy = (box[1] + box[3]) / 2.0
    return (cx + (box[0] - cx) * factor, cy + (box[1] - cy) * factor,
            cx + (box[2] - cx) * factor, cy + (box[3] - cy) * factor)


def _into_frame(box, frame, side=2048.0):
    """The same physical rectangle, in the coordinates of a render framed [frame] times as wide."""
    half = side / 2.0
    return tuple(half + (c - half) / frame for c in box)


def render_frame():
    """What blender/paper/tear_relief.py framed the shadow pass at, from the file it wrote."""
    path = os.path.join(SRC, "tears", "relief.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return float(json.load(f).get("shadow_frame", 1.0))
    return 1.0


def pack_family(name, index, verbose=True):
    src_dir = os.path.join(SRC, name)
    if not os.path.isdir(src_dir):
        return
    out = []
    boxes = {}
    safes = {}
    frame = render_frame() if name == "tears" else 1.0
    if name == "tears":
        for fn in sorted(os.listdir(src_dir)):
            stem = os.path.splitext(fn)[0]
            if fn.endswith(".png") and "_edge" not in stem and "_shadow" not in stem:
                box = paper_box(os.path.join(src_dir, fn))
                if box:
                    boxes[stem] = box
                    safes[stem] = safe_inset(os.path.join(src_dir, fn), box)
    for fn in sorted(os.listdir(src_dir)):
        if not fn.lower().endswith((".png", ".webp", ".jpg")):
            continue
        stem = os.path.splitext(fn)[0]
        dst = os.path.join(DST, name, stem + ".webp")
        plain_mask = name == "tears" and "_edge" not in stem and "_shadow" not in stem
        crop = None
        if name == "tears":
            base = stem.split("_edge")[0].split("_shadow")[0]
            crop = boxes.get(base)
            if crop and "_shadow" in stem:
                # the shadow keeps a margin around the piece, and its render is framed wider than
                # the mask, so the box is grown about the piece and then read in the render's own
                # coordinates. Anything past the render's edge crops to transparent, which is
                # what is there anyway.
                crop = _into_frame(_expand(crop, SHADOW_MARGIN), frame)
        size = convert(os.path.join(src_dir, fn), dst, SIZES.get(name, 1024), QUALITY.get(name, 90),
                       keep_alpha=name != "paper", luminance_to_alpha=plain_mask, crop=crop)
        row = {"id": stem, "w": size[0], "h": size[1]}
        if stem in safes:
            row["safe"] = safes[stem]
            sf = safes[stem]
            row["usable"] = round((1 - sf[0] - sf[2]) * (1 - sf[1] - sf[3]), 4)
        out.append(row)
    index[name] = out
    if verbose:
        print(f"{name}: {len(out)} files")


def _fold_band(paths):
    """The columns any frame of a sequence ever covers, and the rows each one covers.

    Every frame comes off Blender on the same canvas, sized for the sheet fully open, so a folded
    frame is a strip of paper with two thirds of the canvas transparent above and below it. Drawn
    as-is, a note that has arrived and not been opened is a strip of paper with a hand's width of
    nothing over and under it: on 13_messenger_states it read as a hole in the thread nine hundred
    pixels tall.

    So the canvas is cut away. The columns are the union over the whole sequence — the sheet never
    changes width, and cutting each frame to its own columns would make the paper breathe sideways
    as it opens. The rows are per frame, because that is the unfold: the sheet grows out from a
    centre that does not move.
    """
    from PIL import Image
    import numpy as np
    left, right = 10**9, -1
    rows = []
    for path in paths:
        with Image.open(path) as im:
            a = np.asarray(im.convert("RGBA"))[..., 3]
        # By how much a row or column carries, not by whether any single pixel in it is non-zero.
        # Cycles leaves a whisker of alpha over the whole film — a per-pixel test at any threshold
        # low enough to keep the contact shadow also keeps that, and the frame does not get cut at
        # all. Two per cent of the strongest row is under the shadow's own tail and well over the
        # noise.
        rowsum, colsum = a.sum(axis=1), a.sum(axis=0)
        cols = np.where(colsum > colsum.max() * 0.02)[0]
        rs = np.where(rowsum > rowsum.max() * 0.02)[0]
        if len(cols):
            left = min(left, int(cols.min()))
            right = max(right, int(cols.max()))
        pad = 3  # the softest edge of the shadow, kept rather than sliced square
        h = a.shape[0]
        rows.append((max(0, int(rs.min()) - pad), min(h - 1, int(rs.max()) + pad))
                    if len(rs) else (0, h - 1))
    if right < 0:
        return None, rows
    return (left, right), rows


def pack_folds(index, verbose=True):
    src_dir = os.path.join(SRC, "folds")
    if not os.path.isdir(src_dir):
        return
    from PIL import Image
    seqs = {}
    sizes = {}
    for seq in sorted(os.listdir(src_dir)):
        d = os.path.join(src_dir, seq)
        if not os.path.isdir(d):
            continue
        frames = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        paths = [os.path.join(d, f) for f in frames]
        band, rows = _fold_band(paths)
        for i, f in enumerate(frames):
            src = paths[i]
            dst = os.path.join(DST, "folds", seq, os.path.splitext(f)[0] + ".webp")
            if band is None:
                convert(src, dst, SIZES["folds"], QUALITY["folds"], keep_alpha=True)
                continue
            top, bottom = rows[i]
            with Image.open(src) as im:
                cut = im.convert("RGBA").crop((band[0], top, band[1] + 1, bottom + 1))
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                tmp = dst + ".cut.png"
                cut.save(tmp)
            convert(tmp, dst, SIZES["folds"], QUALITY["folds"], keep_alpha=True)
            os.remove(tmp)
        seqs[seq] = len(frames)
        if frames:
            # the shape of the *first* frame, so a note that is about to open is the size it is
            # while it is still folded, before that frame has decoded. Without it the note is zero
            # high until the decoder catches up, and then it is not — which moves everything under
            # it. It used to be the shape of the whole canvas, which reserved the open size.
            with Image.open(os.path.join(DST, "folds", seq,
                                         os.path.splitext(frames[0])[0] + ".webp")) as im:
                sizes[seq] = list(im.size)
        if verbose:
            band_says = "no alpha" if band is None else f"cols {band[0]}..{band[1]}"
            print(f"folds/{seq}: {len(frames)} frames, {band_says}, "
                  f"folded {sizes.get(seq)} → open "
                  f"{[band[1] - band[0] + 1, rows[-1][1] - rows[-1][0] + 1] if band else None}")
    index["folds"] = seqs
    index["fold_size"] = sizes


def copy_flat(name, index, exts=(".ttf", ".ogg", ".json"), verbose=True):
    src_dir = os.path.join(SRC, name)
    if not os.path.isdir(src_dir):
        return
    out = []
    for fn in sorted(os.listdir(src_dir)):
        if not fn.lower().endswith(exts):
            continue
        dst = os.path.join(DST, name, fn)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(os.path.join(src_dir, fn), dst)
        out.append(os.path.splitext(fn)[0])
    index[name] = out
    if verbose:
        print(f"{name}: {len(out)} files")


def pack_seed(verbose=True):
    """The seeded year, only when asked for."""
    months = []
    year_src = os.path.join(SEED_SRC, "year")
    if os.path.isdir(year_src):
        for fn in sorted(os.listdir(year_src)):
            if fn.endswith(".jsonl"):
                months.append(os.path.splitext(fn)[0])
                os.makedirs(os.path.join(SEED_DST, "year"), exist_ok=True)
                shutil.copy2(os.path.join(year_src, fn), os.path.join(SEED_DST, "year", fn))
    for sub, exts in (("photos", (".jpg",)), ("videos", (".mp4", ".jpg")), ("voice", (".ogg",))):
        s = os.path.join(SEED_SRC, sub)
        if not os.path.isdir(s):
            continue
        for fn in sorted(os.listdir(s)):
            if fn.lower().endswith(exts) or fn == "index.json":
                os.makedirs(os.path.join(SEED_DST, sub), exist_ok=True)
                shutil.copy2(os.path.join(s, fn), os.path.join(SEED_DST, sub, fn))
    shutil.copy2(os.path.join(SEED_SRC, "people.json"), os.path.join(SEED_DST, "people.json"))
    with open(os.path.join(SEED_DST, "index.json"), "w", encoding="utf-8") as f:
        json.dump({"months": months}, f, indent=1)
    if verbose:
        print(f"seed: {len(months)} months")
    return months


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--seed", default="", help="'year' to include the seeded history")
    ap.add_argument("--clean", action="store_true")
    a = ap.parse_args(argv)
    if a.clean and os.path.isdir(DST):
        shutil.rmtree(DST)
    os.makedirs(DST, exist_ok=True)
    # every directory declared in pubspec.yaml must exist, even before its family is baked
    for fam in ("paper", "tears", "objects", "bits", "shell", "fonts", "sound", "seed",
                "seed/year", "seed/photos", "seed/videos", "seed/voice"):
        os.makedirs(os.path.join(DST, fam), exist_ok=True)
    index = {}
    for fam in ("paper", "tears", "objects", "bits", "shell"):
        pack_family(fam, index)
    # how the three tear layers line up, straight from the renderer that made them
    relief_path = os.path.join(SRC, "tears", "relief.json")
    if os.path.exists(relief_path):
        with open(relief_path, encoding="utf-8") as f:
            index["relief"] = json.load(f)
        # what the app has to scale the packed shadow by, which is the margin packing kept rather
        # than the frame the renderer used
        index["relief"]["shadow_frame"] = SHADOW_MARGIN
    pack_folds(index)
    copy_flat("fonts", index, exts=(".ttf",))
    copy_flat("sound", index, exts=(".ogg",))
    if a.seed == "year":
        index["seed"] = pack_seed()
    else:
        if os.path.isdir(SEED_DST):
            shutil.rmtree(SEED_DST)
        for sub in ("", "year", "photos", "videos", "voice"):
            os.makedirs(os.path.join(SEED_DST, sub), exist_ok=True)
        index["seed"] = None
    with open(os.path.join(DST, "INDEX.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, indent=1)
    # a marker so an empty family is still a directory the build can see
    for dp, dns, fns in os.walk(DST):
        if not fns and not dns:
            with open(os.path.join(dp, "empty.txt"), "w", encoding="utf-8") as f:
                f.write("this family is not baked yet; tools/pack_assets.py fills it\n")
    total = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(DST) for f in fs)
    print(f"app/assets: {total / 1e6:.1f} MB, seed {'included' if index['seed'] else 'absent'}")
    left_out = not_in_pubspec()
    if left_out:
        # Packing a family and not declaring it is silent in every direction: the files are on
        # disk, INDEX.json counts them, and the build simply does not carry them. The hundred and
        # fifty frames of a note opening were packed, counted and left out for as long as there
        # were frames, and what it looked like was a note that would not open.
        print("\npack_assets: packed but not in app/pubspec.yaml, so the build will not carry it:")
        for d, n in left_out:
            print(f"  {d}  ({n} files)")
        return 1
    return 0


def not_in_pubspec():
    """Directories with files in them that pubspec.yaml does not ask the build to carry.

    Flutter bundles a directory, not a tree: `assets/folds/` brings nothing when the files are in
    `assets/folds/unfold_thirds/`. So every directory that directly holds a file has to be named.
    """
    pubspec = os.path.join(ROOT, "app", "pubspec.yaml")
    if not os.path.exists(pubspec):
        return []
    declared = set()
    with open(pubspec, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("- assets/"):
                declared.add(line[2:].strip())
            m = re.search(r"asset:\s*(assets/\S+)", line)
            if m:
                declared.add(m.group(1))
    missing = []
    for dp, _, fns in os.walk(DST):
        real = [f for f in fns if f != "empty.txt"]
        if not real:
            continue
        rel = "assets/" + os.path.relpath(dp, DST).replace(os.sep, "/")
        rel = "assets/" if rel == "assets/." else rel
        as_dir = rel if rel.endswith("/") else rel + "/"
        if as_dir in declared:
            continue
        if any(os.path.join(as_dir, f) in declared or as_dir + f in declared for f in real):
            continue
        missing.append((as_dir, len(real)))
    return missing


if __name__ == "__main__":
    sys.exit(main())
