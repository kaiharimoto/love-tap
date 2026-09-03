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
    """The largest rectangle inside the crop that is certainly paper, as fractions of the crop.

    A torn edge wanders inward, so the bounding box of the piece is not where writing can go. For
    every row (ignoring the outer twentieth, which is the torn end itself) the first and last solid
    column is found, and the safe rectangle is the intersection of all of them; the same is done
    down the columns. Writing inset by this much can never be cut by the tear."""
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(mask_path).convert("L"), dtype=np.float32) / 255.0
    a = a[box[1]:box[3], box[0]:box[2]]
    solid = a > 0.85
    h, w = solid.shape
    y0, y1 = int(h * 0.06), int(h * 0.94)
    x0, x1 = int(w * 0.06), int(w * 0.94)
    lefts, rights = [], []
    for y in range(y0, y1):
        xs = np.where(solid[y])[0]
        if len(xs):
            lefts.append(xs[0])
            rights.append(xs[-1])
    tops, bottoms = [], []
    for x in range(x0, x1):
        ys = np.where(solid[:, x])[0]
        if len(ys):
            tops.append(ys[0])
            bottoms.append(ys[-1])
    if not lefts or not tops:
        return [0.08, 0.08, 0.08, 0.08]
    # a single deep notch should not cost the whole note: take a high percentile of the edges and
    # add a small margin, so writing clears the tear everywhere but the very worst bite
    def hi(v):
        return float(np.percentile(np.asarray(v, dtype=np.float32), 98))

    def lo(v):
        return float(np.percentile(np.asarray(v, dtype=np.float32), 2))

    margin = 0.02
    left = hi(lefts) / w + margin
    right = 1.0 - (lo(rights) + 1) / w + margin
    top = hi(tops) / h + margin
    bottom = 1.0 - (lo(bottoms) + 1) / h + margin
    cap = 0.2
    return [round(min(left, cap), 4), round(min(top, cap), 4), round(min(right, cap), 4), round(min(bottom, cap), 4)]


def pack_family(name, index, verbose=True):
    src_dir = os.path.join(SRC, name)
    if not os.path.isdir(src_dir):
        return
    out = []
    boxes = {}
    safes = {}
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
        size = convert(os.path.join(src_dir, fn), dst, SIZES.get(name, 1024), QUALITY.get(name, 90),
                       keep_alpha=name != "paper", luminance_to_alpha=plain_mask, crop=crop)
        row = {"id": stem, "w": size[0], "h": size[1]}
        if stem in safes:
            row["safe"] = safes[stem]
        out.append(row)
    index[name] = out
    if verbose:
        print(f"{name}: {len(out)} files")


def pack_folds(index, verbose=True):
    src_dir = os.path.join(SRC, "folds")
    if not os.path.isdir(src_dir):
        return
    seqs = {}
    for seq in sorted(os.listdir(src_dir)):
        d = os.path.join(src_dir, seq)
        if not os.path.isdir(d):
            continue
        frames = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        for f in frames:
            convert(os.path.join(d, f), os.path.join(DST, "folds", seq, os.path.splitext(f)[0] + ".webp"),
                    SIZES["folds"], QUALITY["folds"], keep_alpha=True)
        seqs[seq] = len(frames)
        if verbose:
            print(f"folds/{seq}: {len(frames)} frames")
    index["folds"] = seqs


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
    return 0


if __name__ == "__main__":
    sys.exit(main())
