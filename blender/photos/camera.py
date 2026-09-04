"""blender/photos/camera.py — what happens between the light and the file.

A render is what a scene looks like. A photograph is what a particular sensor and a particular
piece of phone software did to what the scene looked like, and the gap between those two is most
of why a render reads as a render. Nothing in here is a filter in the Instagram sense: every step
is a thing a real camera does and cannot help doing.

  · the lens darkens and softens toward the corners, and its three colours do not land in
    quite the same place there
  · the sensor counts photons, so the noise in a dark part of the frame is larger than the
    noise in a bright one, and it is in the colour channels more than the luminance
  · the phone then pulls the shadows up, rolls the highlights off, sharpens hard, and writes
    a JPEG at a quality that leaves its own ringing along every high-contrast edge

Applied outside Blender on the rendered float image, so it costs a second rather than a render.
"""
import math

import numpy as np


def _srgb_to_linear(x):
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def _linear_to_srgb(x):
    x = np.clip(x, 0.0, None)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * x ** (1 / 2.4) - 0.055)


def _blur(a, sigma):
    """Separable Gaussian, written out because Blender's Python has no scipy."""
    if sigma <= 0.35:
        return a
    r = max(1, int(sigma * 3))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    out = a
    for axis in (0, 1):
        pad = [(0, 0)] * a.ndim
        pad[axis] = (r, r)
        p = np.pad(out, pad, mode="edge")
        acc = np.zeros_like(out)
        for i, w in enumerate(k):
            sl = [slice(None)] * a.ndim
            sl[axis] = slice(i, i + out.shape[axis])
            acc += p[tuple(sl)] * w
        out = acc
    return out


def _radius(h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    cy, cx = (h - 1) / 2, (w - 1) / 2
    r = np.sqrt(((yy - cy) / cy) ** 2 + ((xx - cx) / cx) ** 2) / math.sqrt(2)
    return r


def vignette(img, strength=0.34):
    """Cos-fourth falloff, which is geometry rather than taste: the corners of a frame see the
    aperture obliquely and at a greater distance."""
    h, w = img.shape[:2]
    r = _radius(h, w)
    fall = np.cos(np.arctan(r * 1.15)) ** 4
    return img * (1 - strength + strength * fall)[..., None]


def lateral_chroma(img, amount=0.0016):
    """The three colours focus at slightly different scales, so the corners fringe. It is small
    and it is always there, and its absence is one of the things that reads as computer."""
    h, w = img.shape[:2]
    out = img.copy()
    for c, scale in ((0, 1.0 + amount), (2, 1.0 - amount)):
        ys = (np.arange(h) - (h - 1) / 2) / scale + (h - 1) / 2
        xs = (np.arange(w) - (w - 1) / 2) / scale + (w - 1) / 2
        ys = np.clip(ys, 0, h - 1)
        xs = np.clip(xs, 0, w - 1)
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        y1 = np.minimum(y0 + 1, h - 1)
        x1 = np.minimum(x0 + 1, w - 1)
        fy = (ys - y0)[:, None]
        fx = (xs - x0)[None, :]
        p = img[..., c]
        out[..., c] = ((p[np.ix_(y0, x0)] * (1 - fx) + p[np.ix_(y0, x1)] * fx) * (1 - fy)
                       + (p[np.ix_(y1, x0)] * (1 - fx) + p[np.ix_(y1, x1)] * fx) * fy)
    return out


def corner_softness(img, amount=1.1):
    """No small lens is as sharp at the corner as it is in the middle."""
    h, w = img.shape[:2]
    r = _radius(h, w)
    soft = _blur(img, amount)
    m = np.clip((r - 0.42) / 0.58, 0, 1) ** 2
    return img * (1 - m[..., None]) + soft * m[..., None]


def shot_noise(img, iso=400.0, rng=None):
    """Photon counting. The noise is proportional to the square root of the signal, so it looks
    even in a bright frame and enormous in a dark one, and the phone's own denoiser leaves the
    chroma coarser than the luminance because it blurs chroma harder."""
    rng = rng or np.random.default_rng(4)
    h, w = img.shape[:2]
    # full-well electrons at base sensitivity, scaled down as the sensitivity is pushed
    well = 9000.0 * (100.0 / max(iso, 50.0))
    lin = np.clip(img, 0, None)
    sigma = np.sqrt(np.maximum(lin, 1e-4) / well)
    lum = rng.standard_normal((h, w))[..., None] * sigma * 0.55
    chroma = rng.standard_normal((h, w, 3)) * sigma * 0.85
    chroma = np.stack([_blur(chroma[..., c], 1.4) for c in range(3)], axis=-1) * 2.2
    # a little fixed-pattern row noise, which every phone sensor has and no render does
    rows = rng.standard_normal((h, 1, 1)) * float(np.mean(sigma)) * 0.35
    return lin + lum + chroma + rows


def tone(img, lift=0.030, roll=0.86, contrast=1.06):
    """What the phone does before it shows you anything: pull the shadows up so the picture is
    readable, roll the top off so the window is not a white hole, and add a little contrast."""
    x = np.clip(img, 0, None)
    x = x / (1.0 + x / roll)                       # highlight rolloff
    x = x + lift * np.exp(-x / 0.06)               # shadow lift, only down in the shadows
    s = _linear_to_srgb(x)
    s = np.clip((s - 0.5) * contrast + 0.5, 0, 1)
    return _srgb_to_linear(s)


def white_balance(img, warm=0.0, tint=0.0):
    """Automatic white balance is a guess, and under one warm bulb it is usually a bit wrong."""
    g = np.array([1.0 + warm * 0.06, 1.0 + tint * 0.02, 1.0 - warm * 0.06])
    return img * g


def sharpen(img, amount=0.55, radius=0.9):
    """Phones sharpen far harder than anyone would by hand, and the halo it leaves along a hard
    edge is one of the most recognisable things about a phone photograph."""
    s = _blur(img, radius)
    return img + (img - s) * amount


def jpeg_ready(img):
    return np.clip(_linear_to_srgb(img) * 255.0 + 0.0, 0, 255).astype(np.uint8)


PHONES = {
    # (iso, vignette, chroma, sharpen, warm, handshake px)
    "noor": {"iso": 500.0, "vig": 0.30, "chroma": 0.0018, "sharp": 0.62, "warm": 0.35, "shake": 0.0},
    "teo":  {"iso": 800.0, "vig": 0.38, "chroma": 0.0022, "sharp": 0.45, "warm": -0.25, "shake": 0.6},
}


def develop(linear_rgb, by="noor", light="window_left", seed=1, handheld=0.0):
    """The whole path, in the order a camera does it. `linear_rgb` is the render, float, linear."""
    rng = np.random.default_rng(seed)
    prof = PHONES.get(by, PHONES["noor"])
    dim = light in ("kitchen_bulb", "torch")
    iso = prof["iso"] * (3.2 if dim else 1.0)

    img = np.asarray(linear_rgb, dtype=np.float64)[..., :3]
    if handheld or prof["shake"]:
        img = _blur(img, 0.35 + 0.5 * (handheld + prof["shake"]) * (1.6 if dim else 1.0))
    img = lateral_chroma(img, prof["chroma"])
    img = corner_softness(img, 0.9 if not dim else 1.3)
    img = vignette(img, prof["vig"])
    img = shot_noise(img, iso=iso, rng=rng)
    img = white_balance(img, warm=prof["warm"] + (0.5 if dim else 0.0),
                        tint=float(rng.uniform(-0.4, 0.4)))
    img = tone(img, lift=0.045 if dim else 0.028, roll=0.80 if dim else 0.88,
               contrast=1.10 if not dim else 1.02)
    img = sharpen(img, prof["sharp"])
    return jpeg_ready(img)
