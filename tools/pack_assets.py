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
    # The render's own long side: resizing paper costs tooth, so this is a cap that nothing
    # should reach rather than a target. It was 1800, which was the size the stocks were rendered
    # at; they are bigger now (see tools/render_stocks_bigger.sh) because a full-width piece is
    # 1,356 device pixels across and a 1,288-wide stock had to be enlarged to cover it, which took
    # the Settings sheet's tooth from 2.52 grey levels to 1.26.
    "paper": 3500,
    "tears": 1024,        # masks are alpha only
    "objects": 420,       # a feeling object is at most ~140 dp
    "bits": 420,
    "folds": 600,
    # The desk is rendered at 1400x3067, which is the screen, and it was being packed down to
    # 685x1500 and magnified 2.1x back up by BoxFit.cover — so the largest surface on every screen
    # was a half-resolution image smoothed to fill the glass. At 300 per cent it resolved into
    # hard-edged parallel bars of flat brown, and its radial power spectrum fell off a full order
    # steeper than the paper's. Measured on the assets themselves the two are the same material
    # (desk -2.92, paper -3.03); the difference the critic measured was the resampling.
    "shell": 3100,
    "ink": 512,          # a coverage plate, tiled: packed at its own size or the tiling shifts
}
QUALITY = {"paper": 92, "tears": 92, "objects": 92, "bits": 92, "folds": 90, "shell": 92, "ink": 92}


def convert(src, dst, long_side, quality, keep_alpha, luminance_to_alpha=False, crop=None):
    from PIL import Image
    im = Image.open(src)
    # A second lossy pass over a file that is already the size it will be shown at, and already
    # WebP, is pure loss: it re-encodes to a different set of coefficients and hands back less of
    # the render than a copy would, for more bytes. Measured over the paper family: re-encoding at
    # quality 95 costs 15.44 MB and delivers a high-pass tooth of 1.144 at screen scale; copying
    # the bytes costs 13.91 MB and delivers 1.194 — the render's own number, RMSE 0.000. So when
    # nothing needs doing to a file, nothing is done to it.
    if (crop is None and not luminance_to_alpha and im.format == "WEBP"
            and max(im.size) <= long_side
            # and only when the file already is what this family ships: a copy skips both the
            # RGBA conversion and the lossless save an alpha family depends on
            and keep_alpha == ("A" in im.mode)):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        return im.size
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


def tear_depth(mask_path, box):
    """How far in the tear actually eats on each side, as fractions — left, top, right, bottom.

    Not the same question as `safe_inset`. That one asks where writing can go and answers with the
    largest rectangle entirely inside the paper; this one asks where the *fibres* are, which is the
    band a nine-patch must keep at its rendered size.

    They were the same number — a flat four tenths, for every mask — and a material critic measured
    what that costs: on a piece four times the width of the band left over in the middle, the
    fibres in that band are stretched to a quarter of their frequency, and a high-pass over 31
    columns stops seeing them. Traced across the tenth capture's 02_chat, the four widest pieces in
    the frame measured 0.78 to 1.01 px rms against the material's own 2.417.

    Measured over the middle eight tenths of each side, because the outer tenth belongs to the
    corner cells, which are never stretched.
    """
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(mask_path).convert("L"), dtype=np.float32) / 255.0
    a = a[box[1]:box[3], box[0]:box[2]]
    solid = a > 0.85
    h, w = solid.shape
    if h < 8 or w < 8:
        return [0.2, 0.2, 0.2, 0.2]

    def deepest(lines, span):
        out = 0
        for i in range(int(span * 0.1), int(span * 0.9)):
            col = np.flatnonzero(lines[i])
            if len(col):
                out = max(out, col[0])
        return out

    top = deepest([solid[:, x] for x in range(w)], w) / h
    bottom = deepest([solid[::-1, x] for x in range(w)], w) / h
    left = deepest([solid[y, :] for y in range(h)], h) / w
    right = deepest([solid[y, ::-1] for y in range(h)], h) / w
    # never more than four tenths — beyond that there is no middle left to stretch — and never
    # less than a twentieth, or the band is thinner than the sampler's own footprint
    return [round(min(0.4, max(0.05, v)), 4) for v in (left, top, right, bottom)]


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


def object_boxes(src_dir, margin=0.02, threshold=20):
    """Two boxes per object, in the 2048-wide space `convert` crops in.

    An object is rendered into a square frame it does not fill: a candle is 27 per cent of its
    picture and the rest is transparent. The app corrected for that by drawing the image up to
    three and a half times the size of the box it was given, which is why a candle arriving on a
    note came out as a grey semicircle — the note clips its children, and most of the candle was
    outside the box. Trimming the frame here is the same correction made once, in the pixels,
    where nothing downstream has to know about it.

    The object is cropped to its own ink and the shadow to the union of the two, because a shadow
    is longer than the thing casting it. Cropping both to the union puts the candle back inside a
    frame two and a third times its size and nothing is gained; cropping both to the object's box
    cuts the shadow off at the candle's foot. So they are cropped differently and the app is told
    how much bigger the shadow's frame is and where its centre sits — a shadow may run off the
    edge of a sheet, which is what shadows do, and the thing casting it may not.

    Returns (tight, wide, spread): the box per object, the box per shadow file, and per shadow
    file how much wider its frame is than the object's and where its centre sits, in units of the
    object's box.
    """
    import numpy as np
    from PIL import Image

    def box_of(path):
        with Image.open(path) as im:
            a = np.asarray(im.convert("RGBA"))[..., 3]
        # Cycles leaves a whisker of alpha over the whole film — under a tenth of an alpha step,
        # invisible, and enough to make every shadow measure as the full frame. The threshold is
        # the one measure_object_ink uses, so the two agree about where a thing ends.
        rows = np.where(a.max(axis=1) > threshold)[0]
        cols = np.where(a.max(axis=0) > threshold)[0]
        if not len(rows) or not len(cols):
            return None
        h, w = a.shape
        return (float(cols.min()) / w, float(rows.min()) / h,
                float(cols.max() + 1) / w, float(rows.max() + 1) / h)

    def squared(box, pad):
        x0, y0, x1, y1 = box
        cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        half = max(x1 - x0, y1 - y0) / 2.0 * (1.0 + pad * 2)
        return (cx - half, cy - half, cx + half, cy + half)

    def base_of(stem):
        """obj_x, obj_x_dusk, obj_x_shadow and obj_x_shadow_dusk are all the same thing."""
        s = stem.split("_shadow")[0]
        return s[:-5] if s.endswith("_dusk") else s

    own, others = {}, {}
    for fn in sorted(os.listdir(src_dir)):
        if not fn.lower().endswith(".png"):
            continue
        stem = os.path.splitext(fn)[0]
        base = base_of(stem)
        box = box_of(os.path.join(src_dir, fn))
        if box is None:
            continue
        if stem == base:
            own[base] = box
        else:
            others[stem] = (base, box)

    tight, wide, spread = {}, {}, {}
    for base, obj in own.items():
        t_box = squared(obj, margin)
        side = t_box[2] - t_box[0]
        tight[base] = tuple(round(v * 2048.0, 2) for v in t_box)
    for stem, (base, sh) in others.items():
        obj = own.get(base)
        if obj is None:
            continue
        t_box = squared(obj, margin)
        side = t_box[2] - t_box[0]
        if "_shadow" not in stem:
            # the dusk render of the object itself: the same box as its daylight twin, so the two
            # are the same thing under two lights rather than two crops
            wide[stem] = tight[base]
            continue
        # each shadow gets its own frame: the daylight one falls down and to the right of the
        # thing, the dusk one falls the other way off the desk lamp, and one box holding both
        # would be half empty whichever was being drawn
        u = (min(obj[0], sh[0]), min(obj[1], sh[1]), max(obj[2], sh[2]), max(obj[3], sh[3]))
        w_box = squared(u, margin)
        wide[stem] = tuple(round(v * 2048.0, 2) for v in w_box)
        spread[stem] = [
            round((w_box[2] - w_box[0]) / side, 4),                                   # how much wider
            round(((w_box[0] + w_box[2]) - (t_box[0] + t_box[2])) / 2.0 / side, 4),   # centre, x
            round(((w_box[1] + w_box[3]) - (t_box[1] + t_box[3])) / 2.0 / side, 4),   # centre, y
        ]
    return tight, wide, spread


def pack_family(name, index, verbose=True):
    src_dir = os.path.join(SRC, name)
    if not os.path.isdir(src_dir):
        return
    out = []
    boxes = {}
    safes = {}
    depths = {}
    frame = render_frame() if name == "tears" else 1.0
    shadow_boxes, shadow_spread = {}, {}
    if name == "objects":
        boxes, shadow_boxes, shadow_spread = object_boxes(src_dir)
    if name == "tears":
        for fn in sorted(os.listdir(src_dir)):
            stem = os.path.splitext(fn)[0]
            if fn.endswith(".png") and "_edge" not in stem and "_shadow" not in stem:
                box = paper_box(os.path.join(src_dir, fn))
                if box:
                    boxes[stem] = box
                    safes[stem] = safe_inset(os.path.join(src_dir, fn), box)
                    depths[stem] = tear_depth(os.path.join(src_dir, fn), box)
    for fn in sorted(os.listdir(src_dir)):
        if not fn.lower().endswith((".png", ".webp", ".jpg")):
            continue
        stem = os.path.splitext(fn)[0]
        dst = os.path.join(DST, name, stem + ".webp")
        plain_mask = name == "tears" and "_edge" not in stem and "_shadow" not in stem
        crop = None
        if name == "objects":
            crop = shadow_boxes.get(stem) or boxes.get(stem)
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
        if stem in depths:
            # the band of the render that is fibre rather than paper, per side, which is what a
            # nine-patch must keep at its rendered size instead of stretching
            row["tear"] = depths[stem]
        out.append(row)
    index[name] = out
    if shadow_spread:
        # [how much wider the shadow's frame is than the object's, and where its centre sits,
        # in units of the object's box] — the app draws the shadow in that frame so a shadow can
        # reach past the paper's edge without the thing casting it being cut off with it
        index["object_shadow"] = shadow_spread
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


def measure_object_ink(verbose=True):
    """The opaque bounding box of each packed object, as fractions of its frame."""
    import numpy as np
    from PIL import Image

    out = {}
    d = os.path.join(DST, "objects")
    if not os.path.isdir(d):
        return out
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".webp") or "_shadow" in fn:
            continue
        path = os.path.join(d, fn)
        with Image.open(path) as im:
            if im.mode not in ("RGBA", "LA"):
                continue
            a = np.asarray(im.convert("RGBA"))[..., 3]
        rows = np.where(a.max(axis=1) > 24)[0]
        cols = np.where(a.max(axis=0) > 24)[0]
        if not len(rows) or not len(cols):
            continue
        h, w = a.shape
        out[os.path.splitext(fn)[0]] = [
            round(float(cols.min()) / w, 5),
            round(float(rows.min()) / h, 5),
            round(float(cols.max() + 1) / w, 5),
            round(float(rows.max() + 1) / h, 5),
        ]
    if verbose and out:
        widest = max(out.items(), key=lambda kv: kv[1][2] - kv[1][0])
        tightest = min(out.items(), key=lambda kv: kv[1][2] - kv[1][0])
        print(f"objects: {len(out)} measured, ink fills "
              f"{tightest[1][2] - tightest[1][0]:.0%} of its frame at {tightest[0]} and "
              f"{widest[1][2] - widest[1][0]:.0%} at {widest[0]}")
    return out


def _fold_rest(seq, rows=None, band=None, src_size=None):  # noqa: C901
    """The last frame of a packed sequence that is still moving, and the noise it was told from.

    The frames are cropped to their own alpha, so they change size as the sheet opens. Comparing
    them anchored to their own bottom edge counts a one-row change in the crop as a whole-image
    shift of a pixel — which is motion by any measure, and it put the cut point exactly where the
    crop height went 329 to 328 rather than where the sheet stopped moving. Given the crops the
    packer already knows, each frame goes back where it was on the source canvas first.

    The floor is the sequence's own: the median difference over its last ten transitions is what
    the renderer leaves behind when nothing is happening, and a transition counts as motion at two
    and a half times that, or 0.4 grey levels, whichever is larger. That assumes the sequence ends
    at rest, so it is checked: a sequence still moving at its last frame is not trimmed at all, and
    neither is one where the cut would throw away more than a third of what was rendered.
    """
    import numpy as np
    from PIL import Image
    d = os.path.join(DST, "folds", seq)
    files = sorted(f for f in os.listdir(d) if f.endswith(".webp"))
    if len(files) < 12:
        return {"frames": len(files), "rendered": len(files), "why": "too short to measure"}
    ims = [Image.open(os.path.join(d, f)).convert("L") for f in files]
    W = max(i.size[0] for i in ims)
    if rows is not None and src_size is not None and len(rows) == len(ims):
        # back where each frame was on the source canvas, so a change of crop is not motion
        scale = ims[-1].size[1] / max(1, (rows[-1][1] - rows[-1][0] + 1))
        H = int(round(src_size[1] * scale)) + 2
        tops = [int(round(t * scale)) for t, _ in rows]
    else:
        H = max(i.size[1] for i in ims)
        tops = [H - i.size[1] for i in ims]
    deltas = []
    prev = None
    for im, top in zip(ims, tops):
        c = Image.new("L", (W, H), 0)
        c.paste(im, (0, max(0, min(top, H - im.size[1]))))
        a = np.asarray(c, dtype=np.float32)
        if prev is not None:
            deltas.append(float(np.abs(a - prev).mean()))
        prev = a
    for im in ims:
        im.close()
    floor = float(np.median(deltas[-10:]))
    quietest = float(np.median(sorted(deltas)[: max(3, len(deltas) // 10)]))
    out = {"rendered": len(files), "noise_floor": round(floor, 3),
           "quietest_tenth": round(quietest, 3)}
    if floor > max(3.0 * quietest, quietest + 0.5):
        # the sequence is still moving when it ends: there is no tail to measure the noise from
        out.update({"frames": len(files),
                    "why": "the sequence is still moving at its last frame, so nothing is trimmed"})
        return out
    gate = max(2.5 * floor, 0.4)
    moving = [i for i, x in enumerate(deltas) if x > gate]
    last = moving[-1] if moving else len(deltas) - 1
    keep = last + 2
    # A floor against a measurement that has gone wrong, and nothing more. It was a third of what
    # was rendered, which is the wrong shape of guard: on a sequence rendered well past its rest
    # point most of the frames are quiet, so "more than a third is quiet" is the normal case rather
    # than the alarm. With the frames registered by their own crops the measurement says 147 of
    # unfold_thirds' 240 move, and a two-thirds floor refused to trim at all — which packed every
    # noise frame, made the manifest disagree with the scene, and tripped the check that compares
    # them on every run afterwards. Two fixes that cancelled each other.
    if keep < 12 or keep < len(files) // 8:
        out.update({"frames": len(files), "gate": round(gate, 3),
                    "why": f"the measurement says only {keep} of {len(files)} frames move, which "
                           "reads as a broken measurement rather than a short sequence; nothing "
                           "is trimmed"})
        return out
    out.update({
        "frames": keep,
        "gate": round(gate, 3),
        "why": "frames after this one are the same image re-sampled; the difference between them "
               "is the renderer's own noise, not motion",
    })
    return out


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
        # Whatever a previous render left here goes before this one is measured. The rest point is
        # read off the packed directory, and a shorter re-render used to leave the old tail behind:
        # the frame count then disagreed with the frame list, the crop registration was skipped for
        # the whole sequence, and the trim was measured over frames belonging to a render that no
        # longer exists — silently, in the direction of packing everything.
        packed_dir = os.path.join(DST, "folds", seq)
        if os.path.isdir(packed_dir):
            keep = {os.path.splitext(f)[0] + ".webp" for f in frames}
            for stale in sorted(os.listdir(packed_dir)):
                if stale.endswith(".webp") and stale not in keep:
                    os.remove(os.path.join(packed_dir, stale))
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
        # Where the sequence actually comes to rest. `unfold_thirds` renders 240 frames and stops
        # moving at 208: its last thirty-one are the same still image re-sampled, and Cycles at 48
        # samples leaves 0.70 grey levels of frame-to-frame noise on it. The app played every one of
        # them faithfully, so the clip ended on half a second a reader sees as frozen while the
        # frame check — a mean absolute difference over the whole frame — called it motion. Noise is
        # not motion. The packed sequence is the moving part, and what was dropped is recorded.
        rest = _fold_rest(seq, rows=rows, band=band,
                          src_size=Image.open(paths[0]).size if paths else None)
        seqs[seq] = rest["frames"]
        index.setdefault("fold_rest", {})[seq] = rest
        for i in range(rest["frames"], len(frames)):
            surplus = os.path.join(DST, "folds", seq, os.path.splitext(frames[i])[0] + ".webp")
            if os.path.exists(surplus):
                os.remove(surplus)
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


def _merge_voice_index():
    """One voice index out of the per-month ones the recorder writes.

    `seed_loader.dart` asks for `seed/voice/index.json`; the recorder writes
    `seed/voice/index.2025-09.json` and eleven siblings. So the app has been asking for a file
    nobody wrote — every launch of the seeded year fetched it, took a 404 and fell back, which is
    why a critic found a 404 in two scene logs, and why the waveform drawn on a voice note has
    never been the one measured off the recording.
    """
    src = os.path.join(SEED_SRC, "voice")
    if not os.path.isdir(src):
        return 0
    merged = {}
    for fn in sorted(os.listdir(src)):
        if not (fn.startswith("index.") and fn.endswith(".json")) or fn == "index.json":
            continue
        with open(os.path.join(src, fn), encoding="utf-8") as f:
            part = json.load(f)
        if isinstance(part, dict):
            merged.update(part)
        elif isinstance(part, list):
            for e in part:
                if isinstance(e, dict) and e.get("id"):
                    merged[e["id"]] = e
    if not merged:
        return 0
    out = os.path.join(SEED_DST, "voice")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "index.json"), "w", encoding="utf-8") as f:
        json.dump(merged, f)
    return len(merged)


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
    voices = _merge_voice_index()
    if verbose:
        print(f"seed: {len(months)} months"
              + (f", {voices} voice notes with a measured waveform" if voices else ""))
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
    for fam in ("paper", "tears", "objects", "bits", "shell", "ink", "fonts", "sound", "seed",
                "seed/year", "seed/photos", "seed/videos", "seed/voice"):
        os.makedirs(os.path.join(DST, fam), exist_ok=True)
    index = {}
    for fam in ("paper", "tears", "objects", "bits", "shell", "ink"):
        pack_family(fam, index)
    # how the three tear layers line up, straight from the renderer that made them
    relief_path = os.path.join(SRC, "tears", "relief.json")
    if os.path.exists(relief_path):
        with open(relief_path, encoding="utf-8") as f:
            index["relief"] = json.load(f)
        # what the app has to scale the packed shadow by, which is the margin packing kept rather
        # than the frame the renderer used
        index["relief"]["shadow_frame"] = SHADOW_MARGIN
    # How much of its own frame each feeling object actually fills.
    #
    # Every object render is a 420x420 frame with the thing somewhere inside it, and how much of
    # the frame the thing fills is a property of the thing: a candle's ink is 27% of its frame,
    # a paper crane's is 85%. The app asked for `size: 96` and got a candle 29 points tall beside
    # a crane 82 points tall, so `size` meant a different physical size for every feeling and the
    # smaller ones read as a smudge beside their own name. This is the number that makes `size`
    # mean the object.
    index["object_ink"] = measure_object_ink()
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
