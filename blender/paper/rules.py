#!/usr/bin/env python3
"""blender/paper/rules.py — the printed rules of every paper stock, as images.

Plain Python (numpy + Pillow, no Blender): one image per stock and variant at 300 px/cm for the
sheet size, white where there is no ink, the ink colour where the press printed. Blender's
paper material multiplies it over the paper base colour (common.paper_material rules_image).

Nothing here is a clean vector rule. Every rule set is a separate press pass with its own
misregistration (offset of a few tenths of a millimetre, a fraction of a degree of rotation),
the pitch drifts a hair per rule, the rule width wobbles along its length, the ink density
varies slowly along the rule and skips on the paper tooth, and a few rules carry a faint
double print (the sheet moved under the plate).

    python3 blender/paper/rules.py --stock lined --variant 1
    python3 blender/paper/rules.py --all

Output: blender/paper/cache/rules_<stock>_<variant>.png (+ .json with the parameters).
`params_for(stock, variant)` is importable from Blender (numpy only) so stocks.py can record the
exact parameters of the sheet it renders.
"""
import argparse
import json
import math
import os
import sys
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cache")

PX_PER_CM = 300
MM = PX_PER_CM / 10.0            # pixels per millimetre
BAND_ROWS = 384                  # rows processed at a time (memory)

# sheet sizes in mm (SPEC.md, real-world scale)
SHEETS_MM = {
    "lined": (148.0, 210.0),
    "graph": (148.0, 210.0),
    "spiral": (148.0, 210.0),
    "looseleaf": (148.0, 210.0),
    "legal": (148.0, 210.0),
    "index": (127.0, 76.0),
    "sticky_yellow": (76.0, 76.0),
    "sticky_pink": (76.0, 76.0),
    "sticky_blue": (76.0, 76.0),
    "receipt": (80.0, 180.0),
}
VARIANTS = {
    "lined": 4, "graph": 4, "spiral": 4, "looseleaf": 4, "legal": 2, "index": 2,
    "sticky_yellow": 2, "sticky_pink": 2, "sticky_blue": 2, "receipt": 1,
}
STOCKS = list(SHEETS_MM)

BLUE = "#b9cbe0"      # feint rule blue (DIRECTION.md palette)
RED = "#d98c86"       # margin red
GREY = "#8a8a8a"      # thermal print grey


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def seed_for(stock, variant):
    return zlib.crc32(f"rules:{stock}:{variant}".encode()) & 0xFFFFFFFF


# ---- parameters -----------------------------------------------------------------------------
# One press pass = one layer. Every number below ends up in assets/MANIFEST.json via stocks.py.

def _ink_defaults():
    return dict(
        along_var=0.20,      # slow ink-density variation along the rule (fraction)
        along_cell=6.0,      # mm, wavelength of that variation
        width_jitter=0.18,   # wobble of the rule width along its length (fraction)
        width_cell=0.7,      # mm
        skip_amt=0.55,       # ink skipping on the tooth: how much density is lost in a skip
        skip_cell=0.13,      # mm, size of the tooth cells
        skip_lo=0.60, skip_hi=0.92,
        pitch_jitter=0.045,  # mm, per-rule position jitter (roller drift)
        ghost_frac=0.0,      # fraction of rules with a faint double print
        ghost_offset=0.0,    # mm, offset of the double print
        ghost_density=0.30,  # density of the double print relative to the rule
    )


def _reg(rng, offset_mm, rot_deg):
    """A press pass registration: offset (mm) and rotation (deg) of the whole layer."""
    return dict(dx=round(float(rng.uniform(-offset_mm, offset_mm)), 4),
                dy=round(float(rng.uniform(-offset_mm, offset_mm)), 4),
                rot_deg=round(float(rng.uniform(-rot_deg, rot_deg)), 4))


def _layer(kind, colour, rng, **kw):
    d = _ink_defaults()
    d.update(kind=kind, colour=colour)
    d.update(kw)
    if d["ghost_frac"] > 0 and d["ghost_offset"] == 0:
        d["ghost_offset"] = round(float(rng.uniform(0.12, 0.26)), 3)
    return d


def params_for(stock, variant):
    """Deterministic parameters of the printed layers of one sheet."""
    if stock not in SHEETS_MM:
        raise KeyError(stock)
    seed = seed_for(stock, variant)
    rng = np.random.default_rng(seed)
    w, h = SHEETS_MM[stock]
    layers = []
    if stock in ("lined", "spiral"):
        # 8 mm feint rules, red margin at 32 mm. Variants differ in registration (±0.4 mm, ±0.2°).
        layers.append(_layer("hrules", BLUE, rng, pitch=8.0, start=round(float(rng.uniform(21.0, 25.0)), 3),
                             end=h - 5.0, width=0.30, density=0.92, reg=_reg(rng, 0.4, 0.2),
                             ghost_frac=0.18))
        layers.append(_layer("vrules", RED, rng, positions=[32.0], width=0.40, density=0.95,
                             reg=_reg(rng, 0.5, 0.15), ghost_frac=0.5, along_var=0.12))
    elif stock == "graph":
        layers.append(_layer("grid", BLUE, rng, pitch=5.0, heavy_every=2,
                             phase_x=round(float(rng.uniform(0, 5)), 3), phase_y=round(float(rng.uniform(0, 5)), 3),
                             width=0.17, heavy_width=0.30, density=0.85, heavy_density=0.95,
                             reg=_reg(rng, 0.4, 0.2), ghost_frac=0.08, width_jitter=0.14))
    elif stock == "looseleaf":
        layers.append(_layer("hrules", BLUE, rng, pitch=7.0, start=round(float(rng.uniform(20.0, 24.0)), 3),
                             end=h - 6.0, width=0.30, density=0.90, reg=_reg(rng, 0.4, 0.2), ghost_frac=0.15))
    elif stock == "legal":
        layers.append(_layer("hrules", BLUE, rng, pitch=8.7, start=round(float(rng.uniform(27.0, 31.0)), 3),
                             end=h - 6.0, width=0.28, density=0.90, reg=_reg(rng, 0.4, 0.2), ghost_frac=0.15))
        layers.append(_layer("vrules", RED, rng, positions=[32.0, 34.2], width=0.36, density=0.95,
                             reg=_reg(rng, 0.5, 0.15), ghost_frac=0.5, along_var=0.12))
    elif stock == "index":
        # one red head rule, then 6 mm blue rules
        top = round(float(rng.uniform(12.5, 14.0)), 3)
        layers.append(_layer("hrules", BLUE, rng, pitch=6.0, start=top + 6.0, end=h - 4.0, width=0.28,
                             density=0.90, reg=_reg(rng, 0.35, 0.2), ghost_frac=0.15))
        layers.append(_layer("hrules", RED, rng, pitch=6.0, start=top, end=top + 0.1, width=0.45,
                             density=0.95, reg=_reg(rng, 0.4, 0.15), ghost_frac=0.6, along_var=0.10))
    elif stock.startswith("sticky"):
        layers.append(dict(kind="adhesive_band", colour="#000000", band_mm=round(float(rng.uniform(13.0, 16.0)), 2),
                           density=0.028, edge_mm=1.6))
    elif stock == "receipt":
        layers.append(dict(kind="thermal_print", colour=GREY, density=0.55, fade_cell=9.0, fade_var=0.5,
                           band_var=0.18, char_w=1.75, line_pitch=3.5, dot_mm=0.24, margin=6.0,
                           top=13.0, items=int(rng.integers(7, 12)), barcode=True))
    return dict(stock=stock, variant=variant, seed=int(seed), sheet_mm=[w, h], px_per_cm=PX_PER_CM,
                layers=layers)


# ---- noise ----------------------------------------------------------------------------------
class Noise2D:
    """Smooth value noise: a random grid sampled with a cubic-smoothstep bilinear blend."""

    def __init__(self, rng, nu, nv):
        self.g = rng.random((int(nv) + 2, int(nu) + 2), dtype=np.float32)

    def sample(self, gu, gv):
        iu = np.floor(gu)
        iv = np.floor(gv)
        fu = gu - iu
        fv = gv - iv
        fu = fu * fu * (3.0 - 2.0 * fu)
        fv = fv * fv * (3.0 - 2.0 * fv)
        nv, nu = self.g.shape
        iu = iu.astype(np.int64) % (nu - 1)
        iv = iv.astype(np.int64) % (nv - 1)
        g = self.g
        a = g[iv, iu]
        b = g[iv, iu + 1]
        c = g[iv + 1, iu]
        d = g[iv + 1, iu + 1]
        return (a * (1.0 - fu) + b * fu) * (1.0 - fv) + (c * (1.0 - fu) + d * fu) * fv


def smoothstep(x, lo, hi):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---- rule drawing ---------------------------------------------------------------------------
class RuleLayer:
    """One press pass. Precomputes its noise fields; draws coverage band by band."""

    def __init__(self, layer, w_mm, h_mm, rng):
        self.p = layer
        self.w, self.h = w_mm, h_mm
        p = layer
        self.ink = np.array(hex_rgb(p["colour"]), dtype=np.float32)
        reg = p.get("reg", dict(dx=0.0, dy=0.0, rot_deg=0.0))
        self.dx, self.dy = reg["dx"], reg["dy"]
        th = math.radians(reg["rot_deg"])
        self.cos, self.sin = math.cos(th), math.sin(th)
        span = max(w_mm, h_mm) * 1.2
        # noise fields (grid units per mm chosen by the cell sizes)
        self.n_along = Noise2D(rng, span / p["along_cell"], 512)     # per rule index along u
        self.n_width = Noise2D(rng, span / p["width_cell"], 512)
        self.n_skip = Noise2D(rng, span / p["skip_cell"], span / p["skip_cell"])
        self.aa = 1.0 / MM
        # per-rule tables
        self.tables = {}

    def _rule_table(self, n, key):
        """Per-rule jitter and double-print flags, cached per rule set."""
        if key in self.tables:
            return self.tables[key]
        p = self.p
        rng = np.random.default_rng(zlib.crc32(f"{p['kind']}{key}{p['colour']}".encode()) ^ 0x5bd1e995)
        jit = rng.uniform(-p["pitch_jitter"], p["pitch_jitter"], size=max(n, 1)).astype(np.float32)
        ghost = (rng.random(max(n, 1)) < p["ghost_frac"])
        gdir = np.where(rng.random(max(n, 1)) < 0.5, -1.0, 1.0).astype(np.float32)
        self.tables[key] = (jit, ghost, gdir)
        return self.tables[key]

    def frame(self, X, Y):
        """Sheet coordinates (mm, y down) → the press pass' own frame."""
        cx, cy = self.w / 2.0, self.h / 2.0
        xr = X - cx
        yr = Y - cy
        u = xr * self.cos + yr * self.sin + cx + self.dx
        v = -xr * self.sin + yr * self.cos + cy + self.dy
        return u, v

    def _ink_of(self, cov, along, across_k, kind_key):
        """Apply the ink model to a geometric coverage: density along the rule and tooth skips."""
        p = self.p
        dens = 1.0 - p["along_var"] * self.n_along.sample(along / p["along_cell"], across_k.astype(np.float32) * 0.37 + 3.1)
        skip = 1.0 - p["skip_amt"] * smoothstep(self.n_skip.sample(along / p["skip_cell"], self._across_mm / p["skip_cell"]),
                                                p["skip_lo"], p["skip_hi"])
        return cov * dens * skip

    def _rules(self, along, across, start, pitch, n, base_width, base_density, key, heavy_every=None,
               heavy_width=None, heavy_density=None):
        """Coverage × density of a set of n parallel rules at start + k·pitch across."""
        p = self.p
        jit, ghost, gdir = self._rule_table(n, key)
        k = np.floor((across - start) / pitch + 0.5)
        kk = np.clip(k, 0, n - 1).astype(np.int64)
        valid = (k >= 0) & (k <= n - 1)
        centre = start + kk.astype(np.float32) * pitch + jit[kk]
        width = np.float32(base_width)
        density = np.float32(base_density)
        if heavy_every:
            heavy = (kk % heavy_every) == 0
            width = np.where(heavy, np.float32(heavy_width), np.float32(base_width))
            density = np.where(heavy, np.float32(heavy_density), np.float32(base_density))
        wob = 1.0 + p["width_jitter"] * (self.n_width.sample(along / p["width_cell"], kk.astype(np.float32) * 0.61 + 7.3) - 0.5) * 2.0
        hw = 0.5 * width * wob
        d = np.abs(across - centre)
        cov = np.clip((hw - d) / self.aa + 0.5, 0.0, 1.0) * valid
        out = self._ink_of(cov, along, kk, key) * density
        if p["ghost_frac"] > 0:
            g = ghost[kk]
            if g.any():
                dg = np.abs(across - (centre + gdir[kk] * p["ghost_offset"]))
                covg = np.clip((hw * 0.8 - dg) / self.aa + 0.5, 0.0, 1.0) * valid * g
                out = 1.0 - (1.0 - out) * (1.0 - covg * density * p["ghost_density"])
        return out

    def coverage(self, X, Y):
        p = self.p
        u, v = self.frame(X, Y)
        kind = p["kind"]
        if kind == "hrules":
            self._across_mm = v
            n = int(math.floor((p["end"] - p["start"]) / p["pitch"])) + 1
            return self._rules(u, v, p["start"], p["pitch"], n, p["width"], p["density"], "h")
        if kind == "vrules":
            self._across_mm = u
            out = None
            for i, pos in enumerate(p["positions"]):
                c = self._rules(v, u, pos, 1000.0, 1, p["width"], p["density"], f"v{i}")
                out = c if out is None else np.maximum(out, c)
            return out
        if kind == "grid":
            self._across_mm = v
            nh = int(math.floor((self.h * 1.5) / p["pitch"])) + 2
            ch = self._rules(u, v, p["phase_y"] - p["pitch"] * 2, p["pitch"], nh, p["width"], p["density"], "gh",
                             p["heavy_every"], p["heavy_width"], p["heavy_density"])
            self._across_mm = u
            nw = int(math.floor((self.w * 1.5) / p["pitch"])) + 2
            cw = self._rules(v, u, p["phase_x"] - p["pitch"] * 2, p["pitch"], nw, p["width"], p["density"], "gv",
                             p["heavy_every"], p["heavy_width"], p["heavy_density"])
            return 1.0 - (1.0 - ch) * (1.0 - cw)
        raise ValueError(kind)


def _composite(band, cov, ink):
    """Multiply ink coverage into an RGB float band."""
    band *= (1.0 - cov[..., None] * (1.0 - ink[None, None, :]))


# ---- special layers -------------------------------------------------------------------------
def _adhesive_band(band, y_mm, layer, rng_noise):
    """Sticky note: the glue strip on the back shows through very faintly at the top."""
    d = layer["density"]
    edge = layer["edge_mm"]
    t = 1.0 - smoothstep(y_mm, layer["band_mm"] - edge, layer["band_mm"] + edge)
    cov = (t * d)[:, None] * np.ones((1, band.shape[1]), dtype=np.float32)
    band *= (1.0 - cov[..., None])


_GLYPHS = None


def _glyph_bank(rng):
    """A fixed alphabet of 7×9 dot-matrix masses. Not letters; the memory of letters."""
    global _GLYPHS
    if _GLYPHS is None:
        bank = []
        for _ in range(28):
            g = rng.random((9, 7)) < 0.5
            g[:, 0] &= rng.random(9) < 0.6
            g[0, :] &= rng.random(7) < 0.5
            g[8, :] &= rng.random(7) < 0.5
            bank.append(g)
        _GLYPHS = bank
    return _GLYPHS


def _thermal_print(W, H, layer, rng):
    """Receipt: a faded thermal printout (header, items, a barcode), drawn with Pillow."""
    from PIL import Image, ImageDraw
    img = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(img)
    glyphs = _glyph_bank(np.random.default_rng(1234))
    cw = layer["char_w"] * MM
    lp = layer["line_pitch"] * MM
    dot = layer["dot_mm"] * MM
    margin = layer["margin"] * MM
    text_w = W - 2 * margin
    ncols = int(text_w // cw)

    def text_line(y, col0, nchars, weight=1.0):
        for c in range(nchars):
            if rng.random() < 0.18:
                continue
            g = glyphs[int(rng.integers(len(glyphs)))]
            x0 = margin + (col0 + c) * cw
            for r in range(9):
                for q in range(7):
                    if g[r, q]:
                        px = x0 + q * dot * 1.05
                        py = y + r * dot * 1.05
                        rad = dot * 0.55 * weight
                        draw.ellipse([px - rad, py - rad, px + rad, py + rad], fill=255)

    def dashed(y):
        x = margin
        while x < W - margin:
            draw.rectangle([x, y, x + cw * 0.7, y + dot * 0.9], fill=255)
            x += cw

    y = layer["top"] * MM
    # header: two centred lines
    for n in (int(rng.integers(9, 15)), int(rng.integers(12, 20))):
        text_line(y, (ncols - n) // 2, n, 1.1)
        y += lp
    y += lp * 0.4
    dashed(y)
    y += lp * 0.9
    text_line(y, 0, int(rng.integers(10, 16)))
    y += lp * 1.4
    for _ in range(layer["items"]):
        nl = int(rng.integers(6, 22))
        text_line(y, 0, nl)
        text_line(y, ncols - 5, 5)
        y += lp
    y += lp * 0.3
    dashed(y)
    y += lp * 0.9
    text_line(y, 0, 5, 1.2)
    text_line(y, ncols - 6, 6, 1.2)
    y += lp * 1.8
    if layer["barcode"]:
        bw = 38.0 * MM
        bx = (W - bw) / 2.0
        x = bx
        while x < bx + bw:
            wbar = float(rng.choice([0.25, 0.25, 0.5, 0.75])) * MM
            if rng.random() < 0.55:
                draw.rectangle([x, y, x + wbar, y + 11.0 * MM], fill=255)
            x += wbar + 0.25 * MM
        y += 13.5 * MM
        n = 12
        text_line(y, (ncols - n) // 2, n, 0.9)
        y += lp * 1.6
    n = int(rng.integers(8, 14))
    text_line(y, (ncols - n) // 2, n)
    cov = np.asarray(img, dtype=np.float32) / 255.0
    # thermal fade: patchy (the paper aged) and banded (the head)
    fade = Noise2D(rng, W / (layer["fade_cell"] * MM), H / (layer["fade_cell"] * MM))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    f = 1.0 - layer["fade_var"] * fade.sample(xx / (layer["fade_cell"] * MM), yy / (layer["fade_cell"] * MM))
    bands = 1.0 - layer["band_var"] * rng.random(H, dtype=np.float32)
    cov *= f * bands[:, None] * layer["density"]
    return cov


# ---- the generator --------------------------------------------------------------------------
def output_path(stock, variant):
    return os.path.join(CACHE, f"rules_{stock}_{variant}.png")


def generate(stock, variant, force=False, verbose=True):
    from PIL import Image
    path = output_path(stock, variant)
    params = params_for(stock, variant)
    if os.path.exists(path) and not force:
        if verbose:
            print(f"rules: {path} exists")
        return path, params
    os.makedirs(CACHE, exist_ok=True)
    w, h = params["sheet_mm"]
    W, H = int(round(w * MM)), int(round(h * MM))
    rng = np.random.default_rng(params["seed"] ^ 0xA5A5A5)
    layers = params["layers"]
    out = np.empty((H, W, 3), dtype=np.uint8)
    rule_layers = [RuleLayer(l, w, h, rng) for l in layers if l["kind"] in ("hrules", "vrules", "grid")]
    thermal = None
    for l in layers:
        if l["kind"] == "thermal_print":
            thermal = (l, _thermal_print(W, H, l, rng))
    xs = ((np.arange(W, dtype=np.float32) + 0.5) / MM)
    for y0 in range(0, H, BAND_ROWS):
        rows = min(BAND_ROWS, H - y0)
        ys = ((np.arange(rows, dtype=np.float32) + y0 + 0.5) / MM)
        X = np.broadcast_to(xs[None, :], (rows, W)).astype(np.float32)
        Y = np.broadcast_to(ys[:, None], (rows, W)).astype(np.float32)
        band = np.ones((rows, W, 3), dtype=np.float32)
        for rl in rule_layers:
            _composite(band, rl.coverage(X, Y), rl.ink)
        for l in layers:
            if l["kind"] == "adhesive_band":
                _adhesive_band(band, ys, l, rng)
        if thermal is not None:
            l, cov = thermal
            _composite(band, cov[y0:y0 + rows], np.array(hex_rgb(l["colour"]), dtype=np.float32))
        out[y0:y0 + rows] = np.clip(band * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save(path, compress_level=6)
    with open(path[:-4] + ".json", "w", encoding="utf-8") as f:
        json.dump(params, f, indent=1, sort_keys=True)
    if verbose:
        print(f"rules: wrote {path} ({W}x{H})")
    return path, params


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--stock", choices=STOCKS)
    ap.add_argument("--variant", type=int, default=1)
    ap.add_argument("--all", action="store_true", help="every stock and variant")
    ap.add_argument("--force", action="store_true", help="regenerate even if cached")
    a = ap.parse_args(argv)
    if a.all:
        for s in STOCKS:
            for v in range(1, VARIANTS[s] + 1):
                generate(s, v, force=a.force)
    elif a.stock:
        generate(a.stock, a.variant, force=a.force)
    else:
        ap.error("--stock or --all")


if __name__ == "__main__":
    main()
