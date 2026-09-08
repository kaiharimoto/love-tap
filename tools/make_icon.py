#!/usr/bin/env python3
"""The app's icon, made of the app's own material.

The icon shipped for six cycles was the unaltered Flutter framework logo — on the home screen, on
the favicon, and on every arrival banner the service worker draws, which is the one place the app
appears when nobody has opened it. An anti-goal critic found it by md5.

It is not drawn here so much as photographed: a torn note off the same paper stock the thread is
written on, masked by one of the same tear masks, wearing its own baked contact shadow, lying on
the same desk. Nothing in it is a shape invented for a logo, and no glyph or emoji appears in it.

    python3 tools/make_icon.py            # writes every size the app ships
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESK = os.path.join(ROOT, "assets/shell/desk.png")
STOCK = os.path.join(ROOT, "assets/paper/lined_02.webp")
TEAR = os.path.join(ROOT, "assets/tears/tear_031.png")
SHADOW = os.path.join(ROOT, "assets/tears/tear_031_shadow.png")

WEB = [("app/web/icons/Icon-192.png", 192, False),
       ("app/web/icons/Icon-512.png", 512, False),
       ("app/web/icons/Icon-maskable-192.png", 192, True),
       ("app/web/icons/Icon-maskable-512.png", 512, True),
       ("app/web/favicon.png", 16, False)]
ANDROID = [("app/android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48),
           ("app/android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72),
           ("app/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96),
           ("app/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144),
           ("app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192)]

SIDE = 1024          # everything is composed at this size and sampled down


def compose(maskable=False):
    """A torn note on the desk, square on, at [SIDE] pixels."""
    desk = Image.open(DESK).convert("RGB")
    # a patch of the desk from the middle of a board, not from a join
    x = desk.width // 2 - SIDE // 2
    y = desk.height // 3
    ground = desk.crop((x, y, x + SIDE, y + SIDE)).resize((SIDE, SIDE), Image.LANCZOS)

    # the note: as much of the icon as a note on a desk takes, less on a maskable one because the
    # platform crops a maskable icon to whatever shape it likes
    frac = 0.62 if maskable else 0.74
    side = int(SIDE * frac)
    stock = Image.open(STOCK).convert("RGB")
    sx = (stock.width - side) // 2 if stock.width > side else 0
    sy = (stock.height - side) // 2 if stock.height > side else 0
    sheet = stock.crop((sx, sy, sx + min(side, stock.width), sy + min(side, stock.height)))
    sheet = sheet.resize((side, side), Image.LANCZOS)
    # the masks are single-channel greyscale: the shape is the light, not the alpha
    mask = Image.open(TEAR).convert("L").resize((side, side), Image.LANCZOS)

    shade = Image.open(SHADOW).convert("RGBA")
    # the shadow render is framed wider than the piece it belongs to
    shade = shade.resize((int(side * 1.2), int(side * 1.2)), Image.LANCZOS)

    out = ground.convert("RGBA")
    at = ((SIDE - side) // 2, (SIDE - side) // 2)
    sh_at = (at[0] - int(side * 0.1), at[1] - int(side * 0.1))
    out.alpha_composite(shade, sh_at)
    piece = Image.new("RGBA", (side, side))
    piece.paste(sheet, (0, 0))
    piece.putalpha(mask)
    out.alpha_composite(piece, at)
    return out.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="say what would be written and stop")
    a = ap.parse_args()
    for missing in (DESK, STOCK, TEAR, SHADOW):
        if not os.path.exists(missing):
            print(f"missing {missing}", file=sys.stderr)
            return 1
    plain = compose(maskable=False)
    masked = compose(maskable=True)
    wrote = []
    for path, size, is_maskable in WEB:
        src = masked if is_maskable else plain
        if not a.check:
            src.resize((size, size), Image.LANCZOS).save(os.path.join(ROOT, path))
        wrote.append(f"{path} {size}")
    for path, size in ANDROID:
        if not a.check:
            os.makedirs(os.path.dirname(os.path.join(ROOT, path)), exist_ok=True)
            plain.resize((size, size), Image.LANCZOS).save(os.path.join(ROOT, path))
        wrote.append(f"{path} {size}")
    print("\n".join(wrote))
    return 0


if __name__ == "__main__":
    sys.exit(main())
