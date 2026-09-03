#!/usr/bin/env python3
"""tools/sound/synth.py — every sound in the app, synthesised from paper-noise models.

    python3 tools/sound/synth.py --out assets/sound [--seed 20260903] [--only snd_tea,ui_tick]
                                 [--plot DIR] [--wav]

No recordings exist in this container. Each recipe names the real sound and lists where every
primitive lands on the feeling's haptic timeline, so a builder can replace any file with a recording
of the same length and the app never knows.

Sounds are built from the primitives in SPEC.md (press, rustle, flick, tap, scratch, crumple, tear,
punch, peel, pour, breath) placed on the haptic timeline parsed from docs/FEELINGS.md: an `on@amp`
segment becomes a primitive at that time with gain ∝ amp/255, `off` is silence. The rendered
length is the haptic timeline (end of the last `on`) plus 400 ms of tail, never more than 2.5 s.

Output: mono OGG/Vorbis 44.1 kHz through toolchain/ffmpeg from 16-bit WAV, peak −3 dBFS measured
on the *encoded* file (the encoder is run, decoded and compensated). Deterministic for a seed: each
recipe gets its own RNG stream derived from (seed, recipe name), so adding a recipe never changes
another. Every output is recorded with blender/rig/manifest.record() and mirrored in
assets/sound/MANIFEST.sound.json.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import wave
import zlib
from collections import namedtuple

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "blender", "rig"))
from manifest import record  # noqa: E402  (blender/rig/manifest.py)

GENERATOR = "tools/sound/synth.py"
FS = 44100
PEAK_DBFS = -3.0
TAIL_MS = 400
MAX_MS = 2500
DEFAULT_SEED = 20260903
VORBIS_QUALITY = 6
FEELINGS_MD = os.path.join(ROOT, "docs", "FEELINGS.md")
DEFAULT_OUT = os.path.join(ROOT, "assets", "sound")

FFMPEG = os.path.join(ROOT, "toolchain", "ffmpeg", "ffmpeg")
FFPROBE = os.path.join(ROOT, "toolchain", "ffmpeg", "ffprobe")
if not os.path.exists(FFMPEG):
    FFMPEG = shutil.which("ffmpeg") or FFMPEG
if not os.path.exists(FFPROBE):
    FFPROBE = shutil.which("ffprobe") or FFPROBE

FAMILIES = ("Warmth", "Ache", "Shelter", "Mischief", "Static", "Sparkle")

# The two user-authored feelings from the seeded year (seed/FORMAT.md): they join the table at
# runtime and are synthesised exactly like the built-ins.
USER_FEELINGS = [
    {"id": "pigeon", "family": "Mischief", "shown": "the pigeon", "asset": "obj_user_pigeon",
     "object": "a pigeon on top of the classroom cupboard", "author": "noor", "month": "2025-10",
     "haptic": "30@200 off80 30@200 off80 30@200 off300 200@160",
     "sound": "snd_user_pigeon", "sound_desc": "three claw taps on a cupboard, a wing rustle"},
    {"id": "soup", "family": "Shelter", "shown": "tuesday soup", "asset": "obj_user_soup",
     "object": "a pot of Teo's day-off soup", "author": "teo", "month": "2026-02",
     "haptic": "150@130 off150 150@130 off150 600@170",
     "sound": "snd_user_soup", "sound_desc": "two lid taps, a slow pour"},
]


# =============================================================================================
# Haptic notation  (docs/FEELINGS.md)
#
#   on@amp  — vibrate `on` ms at amplitude 0–255
#   offN    — N ms of silence
#   ×N      — repeat: the parenthesised group just before it, or, without parentheses, everything
#             before it at the same level ("50@180 off120 ×6" is six folds)
# =============================================================================================
Segment = namedtuple("Segment", "kind start dur amp")  # kind 'on' | 'off'; start/dur in ms


class HapticError(ValueError):
    pass


_TOKEN = re.compile(
    r"\s*(?:(?P<open>\()|(?P<close>\))"
    r"|(?P<rep>[×x\*]\s*(?P<repn>\d+))"
    r"|(?P<off>off\s*(?P<offn>\d+))"
    r"|(?P<on>(?P<ond>\d+)\s*@\s*(?P<amp>\d+)))\s*"
)


def _tokenize(text):
    s = text.strip()
    tokens, pos = [], 0
    while pos < len(s):
        m = _TOKEN.match(s, pos)
        if not m or m.end() == pos:
            raise HapticError(f"bad haptic token near {s[pos:pos + 16]!r} in {text!r}")
        tokens.append(m)
        pos = m.end()
    return tokens


def _seq(tokens, i, depth, text):
    items = []          # (dur_ms, amp) with amp None for off
    group = None        # slice of `items` holding the most recent parenthesised group
    prev_group = False
    while i < len(tokens):
        m = tokens[i]
        if m.group("open"):
            sub, i = _seq(tokens, i + 1, depth + 1, text)
            group = (len(items), len(items) + len(sub))
            items.extend(sub)
            prev_group = True
            continue
        if m.group("close"):
            if depth == 0:
                raise HapticError(f"unbalanced ')' in {text!r}")
            return items, i + 1
        if m.group("rep"):
            n = int(m.group("repn"))
            if n < 1:
                raise HapticError(f"×{n} in {text!r}")
            if not items:
                raise HapticError(f"nothing to repeat in {text!r}")
            if prev_group:
                items = items[:group[0]] + items[group[0]:group[1]] * n
            else:
                items = items * n
            prev_group = False
        elif m.group("off"):
            items.append((int(m.group("offn")), None))
            prev_group = False
        else:
            dur, amp = int(m.group("ond")), int(m.group("amp"))
            if dur <= 0:
                raise HapticError(f"zero-length on segment in {text!r}")
            if not 0 <= amp <= 255:
                raise HapticError(f"amplitude {amp} out of 0–255 in {text!r}")
            items.append((dur, amp))
            prev_group = False
        i += 1
    if depth > 0:
        raise HapticError(f"unbalanced '(' in {text!r}")
    return items, i


def parse_haptic(text):
    """'80@90 off40 160@160' → [Segment('on',0,80,90), Segment('off',80,40,None), Segment('on',120,160,160)]"""
    if not text or not text.strip():
        raise HapticError("empty haptic")
    items, _ = _seq(_tokenize(text), 0, 0, text)
    if not any(amp is not None for _, amp in items):
        raise HapticError(f"no on segment in {text!r}")
    segs, t = [], 0
    for dur, amp in items:
        segs.append(Segment("on" if amp is not None else "off", t, dur, amp))
        t += dur
    return segs


def format_haptic(segs):
    """The expanded, canonical form of a parsed sequence (no groups, no ×)."""
    return " ".join(f"{s.dur}@{s.amp}" if s.kind == "on" else f"off{s.dur}" for s in segs)


def on_segments(segs):
    return [s for s in segs if s.kind == "on"]


def timeline_ms(segs):
    """Total length of the notation, trailing off included."""
    return segs[-1].start + segs[-1].dur if segs else 0


def last_on_end_ms(segs):
    return max(s.start + s.dur for s in on_segments(segs))


def bound_ms(segs):
    """Longest a feeling sound may be: haptic timeline + 400 ms tail, capped at 2.5 s."""
    return min(MAX_MS, last_on_end_ms(segs) + TAIL_MS)


def haptic_envelope(segs, n):
    """amp/255 per sample over an n-sample canvas (the page-rhythm envelope)."""
    env = np.zeros(n)
    for s in on_segments(segs):
        a, b = _n(s.start), min(n, _n(s.start + s.dur))
        env[a:b] = s.amp / 255.0
    return env


# =============================================================================================
# docs/FEELINGS.md
# =============================================================================================
_ROW = re.compile(
    r"^\|\s*`(?P<id>[a-z_]+)`\s*\|\s*(?P<family>Warmth|Ache|Shelter|Mischief|Static|Sparkle)\s*\|"
    r"\s*(?P<shown>[^|]*?)\s*\|\s*`(?P<asset>obj_[a-z_0-9]+)`\s*[—-]+\s*(?P<object>[^|]*?)\s*\|"
    r"\s*(?P<haptic>[^|]*?)\s*\|\s*`(?P<sound>snd_[a-z_0-9]+)`\s*(?P<sound_desc>[^|]*?)\s*\|"
    r"\s*`(?P<colour>#[0-9a-fA-F]{6})`\s*\|"
)


def load_feelings(path=FEELINGS_MD):
    """The 34 built-in rows of the table, in order."""
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = _ROW.match(line)
            if m:
                rows.append(m.groupdict())
    if not rows:
        raise RuntimeError(f"no feeling rows found in {path}")
    return rows


def all_feelings(path=FEELINGS_MD):
    return load_feelings(path) + [dict(r) for r in USER_FEELINGS]


# =============================================================================================
# DSP helpers
# =============================================================================================
def _n(ms):
    return max(1, int(round(ms * FS / 1000.0)))


def _norm(x, peak=1.0):
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x * (peak / m) if m > 1e-12 else x


def _ramp(n):
    """0 → 1 raised cosine."""
    if n <= 1:
        return np.ones(max(n, 0))
    return 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))


def env_asr(n, attack_ms, release_ms, hold=1.0):
    a, r = min(_n(attack_ms), n), min(_n(release_ms), n)
    env = np.full(n, hold)
    env[:a] *= _ramp(a)
    env[n - r:] *= _ramp(r)[::-1]
    return env


def _clampf(f):
    return float(np.clip(f, 20.0, 0.45 * FS))


_SOS_CACHE = {}


def _sos(kind, lo, hi=None, order=2):
    key = (kind, round(lo, 1), None if hi is None else round(hi, 1), order)
    sos = _SOS_CACHE.get(key)
    if sos is None:
        if kind == "band":
            sos = signal.butter(order, [_clampf(lo), _clampf(max(hi, lo * 1.05))], "bandpass", fs=FS, output="sos")
        else:
            sos = signal.butter(order, _clampf(lo), kind, fs=FS, output="sos")
        _SOS_CACHE[key] = sos
    return sos


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", lo, hi, order), x)


def lowpass(x, fc, order=2):
    return signal.sosfilt(_sos("lowpass", fc, order=order), x)


def highpass(x, fc, order=2):
    return signal.sosfilt(_sos("highpass", fc, order=order), x)


def resonator(x, f0, q):
    """A damped resonance (2nd-order peak) excited by x — a body, an edge, a mug. Never a tone on
    its own: it only colours what is fed through it."""
    b, a = signal.iirpeak(_clampf(f0), q, fs=FS)
    return signal.lfilter(b, a, x)


def tv_filter(x, fcs, kind="lowpass", width_oct=1.0, block=64):
    """Time-varying 2nd-order filter; `fcs` is the cutoff (or centre) per sample in Hz. Coefficients
    are updated every `block` samples (1.45 ms) and quantised to 1/24 octave so the filter cache
    is reused."""
    y = np.empty_like(x)
    zi = None
    n = len(x)
    for s in range(0, n, block):
        fc = float(fcs[s])
        fc = 20.0 * 2 ** (round(np.log2(max(fc, 20.0) / 20.0) * 24) / 24)
        if kind == "band":
            sos = _sos("band", fc * 2 ** (-width_oct / 2), fc * 2 ** (width_oct / 2))
        else:
            sos = _sos(kind, fc)
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0.0
        y[s:s + block], zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
    return y


def white(n, rng):
    return rng.standard_normal(n)


def pink(n, rng):
    """Paul Kellet's economy pink filter, as three first-order sections."""
    w = rng.standard_normal(n)
    y = (signal.lfilter([0.0990460], [1, -0.99765], w)
         + signal.lfilter([0.2965164], [1, -0.96300], w)
         + signal.lfilter([1.0526913], [1, -0.57000], w)
         + 0.1848 * w)
    return y / 3.2


def am(x, hz, depth, rng, phase=None):
    """Amplitude modulation of a noise (a hand moving, a wing beating) — modulates, never rings."""
    t = np.arange(len(x)) / FS
    ph = rng.uniform(0, 2 * np.pi) if phase is None else phase
    return x * (1 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * hz * t + ph)))


def sweep(n, f_start, f_end):
    """Exponential frequency track over n samples."""
    return np.exp(np.linspace(np.log(f_start), np.log(f_end), n))


# ---- grains: the crackle every paper sound is made of ------------------------------------------
def _grain_bank(rng, band, size_ms, k=14):
    lo, hi = band
    bank = []
    for _ in range(k):
        fc = float(np.exp(rng.uniform(np.log(lo), np.log(hi))))
        bw = fc * rng.uniform(0.5, 1.3)
        n = _n(rng.uniform(*size_ms))
        g = rng.standard_normal(n)
        # asymmetric window: a fibre lets go fast and settles slower
        t = np.linspace(0, 1, n)
        g *= np.sin(np.pi * t ** 0.6)
        g = bandpass(g, max(60.0, fc - bw / 2), fc + bw / 2)
        bank.append(_norm(g))
    return bank


def grains(n, density, rng, band=(1000, 6000), size_ms=(2, 6), shape=None, gain=(0.3, 1.0), k=14):
    """Sparse crackle: `density` grains per second (mean, when `shape` is given) of 2–6 ms
    band-passed noise, each with its own random band inside `band` (Hz)."""
    bank = _grain_bank(rng, band, size_ms, k)
    maxlen = max(len(g) for g in bank)
    out = np.zeros(n + maxlen)
    count = int(round(density * n / FS))
    if count <= 0:
        return out[:n]
    if shape is None:
        pos = rng.integers(0, n, size=count)
    else:
        w = np.clip(np.asarray(shape, dtype=float), 0, None)
        if w.sum() <= 0:
            return out[:n]
        cdf = np.cumsum(w)
        cdf /= cdf[-1]
        pos = np.searchsorted(cdf, rng.uniform(0, 1, size=count))
    which = rng.integers(0, len(bank), size=count)
    gains = rng.uniform(gain[0], gain[1], size=count) * rng.choice([-1.0, 1.0], size=count)
    for p, wi, gi in zip(pos, which, gains):
        g = bank[wi]
        out[p:p + len(g)] += g * gi
    return out[:n]


# =============================================================================================
# Primitives (SPEC.md).  Every primitive returns a float array normalised to peak 1.0 so recipe
# gains compare, with a per-primitive trim so a tap and a press sit at similar loudness.
# =============================================================================================
def press(dur_ms, depth=0.5, rng=None, release=1.0):
    """A hand on paper: band-limited pink noise, slow attack, soft release."""
    rel_ms = 90 + 140 * release
    n = _n(dur_ms + rel_ms)
    x = pink(n, rng)
    lo = 110 + 160 * (1 - depth)
    hi = 1600 + 1800 * (1 - depth)
    x = bandpass(x, lo, hi)
    # hand motion: a slow wobble, 2–5 Hz, plus fibre grains under the fingers
    wob = lowpass(white(n, rng), 3.0, order=1)
    wob = 1.0 + 0.35 * _norm(wob)
    g = grains(n, 40 + 90 * depth, rng, band=(1400, 5000), size_ms=(2, 5), gain=(0.1, 0.5))
    attack = max(12.0, 0.35 * dur_ms)
    env = env_asr(n, attack, rel_ms)
    y = (x * wob + 0.16 * g) * env
    return _norm(y, 0.8)


def rustle(dur_ms, density=150, rng=None, band=(1000, 6000), bright=False, shape=None, bed=0.25):
    """Sparse crackle grains with random band-pass filtering, 1–6 kHz; `density` grains/s."""
    n = _n(dur_ms)
    if bright:
        band = (max(band[0], 1800), max(band[1], 7500))
    g = grains(n, density, rng, band=band, size_ms=(2, 6), shape=shape)
    b = bandpass(white(n, rng), band[0] * 0.8, band[1] * 0.8)
    if shape is not None:
        b = b * (np.asarray(shape) / max(1e-9, float(np.max(shape))))
    env = env_asr(n, min(8.0, dur_ms * 0.2), min(0.3 * dur_ms, 40))
    y = (g + bed * 0.35 * b) * env
    return _norm(y, 0.8)


def flick(pitch=2400.0, rng=None):
    """An 8 ms click with a short resonant tail — a paper edge flicked."""
    n = _n(48)
    click = white(n, rng) * np.exp(-np.arange(n) / _n(2.2))
    click[:_n(0.3)] *= _ramp(_n(0.3))
    click = bandpass(click, 1400, 9000)
    tail = 0.5 * resonator(click, pitch, 32) + 0.25 * resonator(click, pitch * 1.62, 24)
    y = click + 0.55 * _norm(tail)
    y *= env_asr(n, 0.2, 20)
    return _norm(y, 1.0)


def tap(hard=0.5, rng=None):
    """Short impulse through a low-pass, with a small desk body — pencil on a desk."""
    n = _n(80)
    imp = white(n, rng) * np.exp(-np.arange(n) / _n(1.2 + 2.5 * (1 - hard)))
    imp = lowpass(imp, 500 + 3400 * hard, order=2)
    body = resonator(imp, 150 + 110 * hard, 5.5)
    y = imp + (0.9 - 0.4 * hard) * _norm(body)
    y *= env_asr(n, 0.1, 40)
    return _norm(y, 1.0)


def scratch(dur_ms, pressure=0.6, rng=None):
    """Filtered noise with a 30–80 Hz amplitude modulation: a biro on paper."""
    n = _n(dur_ms + 18)
    x = white(n, rng)
    x = bandpass(x, 650 + 700 * (1 - pressure), 4200 + 2600 * pressure)
    t = np.arange(n) / FS
    f = rng.uniform(30, 80)
    drift = 1 + 0.12 * _norm(lowpass(white(n, rng), 4.0, order=1))
    ph = 2 * np.pi * np.cumsum(f * drift) / FS + rng.uniform(0, 2 * np.pi)
    mod = (0.5 + 0.5 * np.sin(ph)) ** (1.6 + 1.5 * pressure)
    mod = 0.25 + 0.75 * mod
    g = grains(n, 250 + 400 * pressure, rng, band=(1500, 7000), size_ms=(1.5, 4), gain=(0.2, 0.7))
    y = (x * mod + 0.5 * g * mod) * env_asr(n, 5, 16)
    return _norm(y, 0.85)


def crumple(dur_ms, rng=None, shape=None):
    """Dense crackle with rising density then release; a low paper body underneath."""
    n = _n(dur_ms + 70)
    t = np.linspace(0, 1, n)
    dens = np.where(t < 0.6, 150 + 800 * (t / 0.6) ** 1.3, 950 - 700 * ((t - 0.6) / 0.4) ** 0.8)
    prof = dens / dens.max()
    if shape is not None:
        s = np.zeros(n)
        s[:min(n, len(shape))] = shape[:n]
        prof = prof * (0.45 + 0.55 * s / max(1e-9, s.max()))
    g = grains(n, 620, rng, band=(500, 8500), size_ms=(2, 8), shape=prof, gain=(0.25, 1.0), k=20)
    cracks = grains(n, 40, rng, band=(300, 1800), size_ms=(6, 14), shape=prof, gain=(0.5, 1.0), k=6)
    body = lowpass(pink(n, rng), 420) * prof
    y = (g + 0.7 * cracks + 0.5 * _norm(body)) * env_asr(n, 6, 60)
    return _norm(y, 0.9)


def tear(dur_ms, rng=None):
    """A crackle chain with a slow downward pitch sweep — paper tearing."""
    n = _n(dur_ms + 40)
    chain = grains(n, 900, rng, band=(1200, 7000), size_ms=(1.5, 5), gain=(0.4, 1.0), k=18)
    bed = white(n, rng)
    fcs = sweep(n, 5200, 1250)
    y = tv_filter(chain + 0.35 * bed, fcs, kind="band", width_oct=1.6)
    fibres = grains(n, 120, rng, band=(300, 1500), size_ms=(5, 12), gain=(0.3, 0.8), k=6)
    y = y + 0.35 * fibres
    ramp = 0.75 + 0.25 * np.linspace(0, 1, n)
    y *= env_asr(n, 6, 30) * ramp
    return _norm(y, 0.9)


def punch(rng=None):
    """A hole punch: tap + short bright rustle."""
    t = tap(0.85, rng)
    r = rustle(45, 520, rng, band=(1800, 7500))
    n = max(len(t), _n(4) + len(r))
    y = np.zeros(n)
    y[:len(t)] += t
    y[_n(4):_n(4) + len(r)] += 0.55 * r
    return _norm(y, 1.0)


def peel(dur_ms, rng=None):
    """Rising-density crackle through a rising high-pass: tape or a sticker coming off."""
    n = _n(dur_ms + 30)
    t = np.linspace(0, 1, n)
    prof = 0.15 + 0.85 * t ** 1.4
    g = grains(n, 520, rng, band=(700, 7500), size_ms=(1.5, 5), shape=prof, gain=(0.3, 1.0), k=18)
    bed = white(n, rng) * prof
    y = tv_filter(g + 0.3 * bed, sweep(n, 260, 3300), kind="highpass")
    y *= env_asr(n, 8, 28) * (0.55 + 0.45 * t)
    return _norm(y, 0.85)


def pour(dur_ms, rng=None):
    """Filtered noise with a slow low-pass sweep and a faint ring: liquid into a mug."""
    n = _n(dur_ms + 60)
    x = white(n, rng)
    y = tv_filter(x, sweep(n, 900, 3800), kind="lowpass")
    y = highpass(y, 260)
    bubbles = lowpass(grains(n, 28, rng, band=(250, 1200), size_ms=(4, 12), gain=(0.4, 1.0), k=8), 1500)
    ring_src = bandpass(white(n, rng), 300, 1200)
    ring = tv_filter(ring_src, sweep(n, 380, 760), kind="band", width_oct=0.12)
    y = y + 0.45 * bubbles + 0.22 * _norm(ring)
    y *= env_asr(n, 70, 0.3 * dur_ms)
    return _norm(y, 0.85)


def breath(dur_ms, in_=True, rng=None):
    """Very low pink noise with a long envelope: breathing in (rises, brighter) or out (falls)."""
    n = _n(dur_ms)
    x = pink(n, rng)
    x = bandpass(x, 140, 900) if in_ else lowpass(x, 640)
    t = np.linspace(0, 1, n)
    if in_:
        env = np.sin(np.pi * t ** 0.75) ** 1.2
    else:
        env = np.where(t < 0.18, (t / 0.18) ** 1.5, ((1 - t) / 0.82) ** 1.6)
    air = grains(n, 60, rng, band=(1200, 3500), size_ms=(3, 8), gain=(0.1, 0.4)) * env
    y = x * env + 0.12 * air
    return _norm(y, 0.75)


# =============================================================================================
# Recipes
# =============================================================================================
class Placer:
    """Collects primitives on a canvas of `length_ms`. Anything reaching past the end is faded
    out over the last 40 % of the room it has, so no sound ever exceeds its bound."""

    def __init__(self, length_ms):
        self.length_ms = length_ms
        self.n = _n(length_ms)
        self.buf = np.zeros(self.n)
        self.placements = []

    def at(self, ms, audio, gain, name):
        start = _n(ms) if ms > 0 else 0
        if start >= self.n:
            return
        room = self.n - start
        x = np.asarray(audio, dtype=float)
        if len(x) > room:
            x = x[:room].copy()
            f = max(_n(20), int(0.4 * room))
            x[-f:] *= _ramp(f)[::-1]
        self.buf[start:start + len(x)] += x * gain
        self.placements.append({"at_ms": int(round(ms)), "primitive": name,
                                "gain": round(float(gain), 3), "ms": int(round(1000 * len(x) / FS))})

    def render(self):
        y = self.buf
        f = _n(12)  # anti-click at the very end
        if len(y) > f:
            y[-f:] *= _ramp(f)[::-1]
        return y


def g(seg, k=1.0):
    """Gain ∝ amp/255 (times a recipe trim)."""
    return k * seg.amp / 255.0


def page_turn(dur_ms, density, rng, band=(600, 3600)):
    """A page turned: a low-density rustle with a swish of pressed paper under it."""
    n = _n(dur_ms)
    r = rustle(dur_ms, density, rng, band=band, bed=0.5)
    sw = bandpass(pink(n, rng), 300, 2400) * np.sin(np.pi * np.linspace(0, 1, n) ** 0.7)
    return _norm(r + 0.7 * _norm(sw), 0.8)


def pat(dur_ms, hard, depth, rng, release=1.5):
    """A soft tap with a short press body: a hand patting paper."""
    t = tap(hard, rng)
    p = press(dur_ms, depth, rng, release=release)
    n = max(len(t), len(p))
    y = np.zeros(n)
    y[:len(t)] += t
    y[:len(p)] += 0.75 * p
    return _norm(y, 0.9)


def clink(pitch, rng):
    """A ceramic/metal edge tapped: tap + a brief edge resonance."""
    t = tap(0.65, rng)
    f = flick(pitch, rng)
    y = np.zeros(max(len(t), len(f)))
    y[:len(t)] += t
    y[:len(f)] += 0.6 * f
    return _norm(y, 1.0)


# ---- Warmth: press, rustle (low density) ---------------------------------------------------------
def r_squeeze(ons, rng, P):
    for i, s in enumerate(ons):
        P.at(s.start, press(s.dur, 0.35 + 0.3 * i, rng), g(s), "press")
        if i == 2:
            P.at(s.start + 40, rustle(s.dur - 40, 70, rng), g(s, 0.35), "rustle")


def r_forehead(ons, rng, P):
    for s in ons:
        P.at(s.start, press(s.dur, 0.45, rng), g(s), "press")
        P.at(s.start + 20, rustle(s.dur - 20, 55, rng), g(s, 0.25), "rustle")


def r_palm(ons, rng, P):
    s = ons[0]
    P.at(s.start, press(s.dur, 0.5, rng, release=1.4), g(s), "press")
    P.at(s.start, am(rustle(s.dur, 110, rng, band=(900, 3500)), 2.4, 0.7, rng), g(s, 0.45), "rustle")


def r_nuzzle(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, rustle(s.dur + 50, 170, rng), g(s), "rustle")
    s = ons[-1]
    P.at(s.start, press(s.dur, 0.4, rng), g(s), "press")
    P.at(s.start, rustle(s.dur, 60, rng), g(s, 0.4), "rustle")


def r_thinking(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, rustle(s.dur + 20, 520, rng, band=(2000, 6000)), g(s, 0.9), "rustle")
    s = ons[-1]
    P.at(s.start, press(s.dur, 0.5, rng), g(s), "press")


def r_goodnight(ons, rng, P):
    for i, s in enumerate(ons):
        P.at(s.start, press(s.dur, 0.5 - 0.12 * i, rng, release=1.2 + 0.3 * i), g(s), "press")


# ---- Ache: breath, slow page-turn rustle ---------------------------------------------------------
def r_miss(ons, rng, P):
    for i, s in enumerate(ons):
        P.at(s.start, page_turn(s.dur + 160 + 120 * i, 95 / (1 + 0.45 * i), rng), g(s), "page_turn")


def r_chair(ons, rng, P):
    P.at(ons[0].start, breath(ons[0].dur + 200, True, rng), g(ons[0]), "breath_in")
    P.at(ons[1].start, breath(ons[1].dur + 320, False, rng), g(ons[1]), "breath_out")


def r_home(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, tap(0.4, rng), g(s, 0.9), "tap")
    s = ons[-1]
    P.at(s.start, breath(s.dur + 220, False, rng), g(s), "breath_out")


def r_wish(ons, rng, P):
    for i, s in enumerate(ons):
        P.at(s.start, page_turn(s.dur + 60 + 40 * i, 90 / (1 + 0.3 * i), rng), g(s), "page_turn")


def r_longday(ons, rng, P):
    P.at(ons[0].start, breath(ons[0].dur + 220, True, rng), g(ons[0]), "breath_in")
    P.at(ons[1].start, breath(ons[1].dur + 380, False, rng), g(ons[1]), "breath_out")


# ---- Shelter: press with longer release, tap (soft) ---------------------------------------------
def r_here(ons, rng, P):
    for s in ons:
        P.at(s.start, press(s.dur, 0.5, rng, release=1.8), g(s), "press")
        P.at(s.start + 30, rustle(s.dur - 30, 40, rng, band=(800, 3000)), g(s, 0.3), "rustle")


def r_breathe(ons, rng, P):
    P.at(ons[0].start, press(ons[0].dur, 0.4, rng, release=2.0), g(ons[0]), "press")
    P.at(ons[0].start, breath(ons[0].dur, True, rng), g(ons[0], 0.7), "breath_in")
    P.at(ons[1].start, press(ons[1].dur, 0.4, rng, release=2.0), g(ons[1]), "press")
    P.at(ons[1].start, breath(ons[1].dur, False, rng), g(ons[1], 0.7), "breath_out")


def r_okay(ons, rng, P):
    for s in ons:
        P.at(s.start, pat(s.dur, 0.22, 0.35, rng), g(s), "pat")


def r_steady(ons, rng, P):
    for s in ons:
        P.at(s.start, tap(0.45, rng), g(s), "tap")
        P.at(s.start + 8, press(s.dur - 8, 0.3, rng, release=1.6), g(s, 0.55), "press")


def r_tea(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, clink(3100, rng), g(s), "tap")
    s = ons[-1]
    P.at(s.start, pour(s.dur, rng), g(s), "pour")


def r_hold(ons, rng, P):
    for s in ons:
        P.at(s.start, press(s.dur, 0.55, rng, release=2.2), g(s), "press")


def r_user_soup(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, clink(1900, rng), g(s, 0.9), "tap")
        P.at(s.start + 10, press(s.dur - 10, 0.35, rng, release=1.4), g(s, 0.35), "press")
    s = ons[-1]
    P.at(s.start, pour(s.dur, rng), g(s), "pour")


# ---- Mischief: flick, tap (hard), rustle (high density) -------------------------------------------
def r_poke(ons, rng, P):
    P.at(ons[0].start, flick(2600, rng), g(ons[0]), "flick")


def r_nyeh(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, tap(0.8, rng), g(s), "tap")
    s = ons[-1]
    P.at(s.start, scratch(s.dur, 0.85, rng), g(s, 0.8), "scratch")
    P.at(s.start, rustle(s.dur, 700, rng), g(s, 0.7), "rustle")


def r_catch(ons, rng, P):
    for i, s in enumerate(ons[:-1]):
        band = (1100 + 500 * i, 3800 + 1300 * i)
        P.at(s.start, rustle(s.dur + 15, 320 + 60 * i, rng, band=band), g(s), "rustle")
    s = ons[-1]
    P.at(s.start, tap(0.55, rng), g(s), "tap")
    P.at(s.start + 6, press(s.dur - 6, 0.4, rng, release=0.6), g(s, 0.6), "press")
    P.at(s.start + 6, rustle(s.dur - 6, 220, rng), g(s, 0.45), "rustle")


def r_pick(ons, rng, P):
    for i, s in enumerate(ons):
        P.at(s.start, flick(1900 + 140 * i, rng), g(s, 0.8), "flick")
        P.at(s.start + 3, rustle(s.dur + 30, 520, rng), g(s), "rustle")


def r_snap(ons, rng, P):
    s0, s1, s2 = ons
    n = _n(70)
    stretch = rustle(70, 380, rng, band=(900, 4500), shape=np.linspace(0.2, 1.0, n) ** 1.5)
    P.at(s0.start, stretch, g(s0, 0.8), "rustle")
    P.at(s1.start, flick(2400, rng), g(s1), "flick")
    P.at(s1.start + 2, tap(0.9, rng), g(s1, 0.8), "tap")
    P.at(s2.start, tap(0.3, rng), g(s2), "tap")


def r_stuck(ons, rng, P):
    for s in ons:
        P.at(s.start, tap(1.0, rng), g(s), "tap")


def r_user_pigeon(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, tap(0.85, rng), g(s), "tap")
        P.at(s.start + 1, flick(3400, rng), g(s, 0.45), "flick")
    s = ons[-1]
    wing = am(rustle(s.dur, 450, rng, band=(800, 5000)), 11.0, 0.85, rng, phase=-np.pi / 2)
    P.at(s.start, wing, g(s), "rustle")
    P.at(s.start, press(s.dur, 0.3, rng, release=0.8), g(s, 0.35), "press")


# ---- Static: scratch, crumple, tear --------------------------------------------------------------
def r_overwhelmed(ons, rng, P, segs=None):
    total = last_on_end_ms(segs)
    shape = haptic_envelope(segs, _n(total + 70))
    P.at(0, crumple(total, rng, shape=shape), 1.0, "crumple")


def r_ugh(ons, rng, P):
    for s in ons:
        P.at(s.start, scratch(s.dur, 0.9, rng), g(s), "scratch")


def r_snapped(ons, rng, P):
    for s in ons[:-1]:
        P.at(s.start, tap(1.0, rng), g(s), "tap")
        P.at(s.start, flick(1200, rng), g(s, 0.7), "flick")
    s = ons[-1]
    P.at(s.start, scratch(s.dur, 0.85, rng), g(s), "scratch")


def r_tangled(ons, rng, P):
    for s in ons:
        if s.dur <= 50:
            P.at(s.start, scratch(s.dur, 0.5 + 0.4 * s.amp / 255, rng), g(s), "scratch")
        else:
            P.at(s.start, tear(s.dur, rng), g(s), "tear")


def r_grey(ons, rng, P):
    for s in ons:
        for _ in range(int(rng.integers(2, 4))):
            P.at(s.start + rng.uniform(0, s.dur - 10), lowpass(tap(0.15, rng), 1800), g(s, 0.9), "tap")
        P.at(s.start, rustle(s.dur, 120, rng, band=(700, 3000)), g(s, 0.5), "rustle")


def r_notokay(ons, rng, P):
    s = ons[0]
    P.at(s.start, tear(s.dur, rng), g(s), "tear")
    for s in ons[1:]:
        P.at(s.start, tap(0.65, rng), g(s), "tap")


# ---- Sparkle: punch, peel, rustle (bright) ---------------------------------------------------------
def r_didit(ons, rng, P):
    for i, s in enumerate(ons[:-1]):
        P.at(s.start, tap(0.6, rng), g(s), "tap")
        P.at(s.start, flick(1500 * 1.3 ** i, rng), g(s, 0.7), "flick")
    s = ons[-1]
    P.at(s.start, peel(s.dur, rng), g(s), "peel")


def r_confetti(ons, rng, P):
    for s in ons:
        P.at(s.start, punch(rng), g(s), "punch")


def r_yes(ons, rng, P):
    for i, s in enumerate(ons[:3]):
        P.at(s.start, rustle(s.dur + 20, 300 + 120 * i, rng, band=(1400 + 500 * i, 5000 + 1500 * i), bright=True),
             g(s), "rustle")
    for s in ons[3:]:
        P.at(s.start, punch(rng), g(s), "punch")
        P.at(s.start + 5, rustle(s.dur, 700, rng, bright=True), g(s, 0.6), "rustle")


def r_crown(ons, rng, P):
    for i, s in enumerate(ons[:-1]):
        P.at(s.start, rustle(s.dur + 30, 220 + 90 * i, rng, band=(1000 + 500 * i, 4500 + 1500 * i), bright=True),
             g(s), "rustle")
    s = ons[-1]
    P.at(s.start, peel(s.dur, rng), g(s), "peel")
    P.at(s.start + 120, rustle(s.dur - 120 + 60, 600, rng, bright=True), g(s, 0.5), "rustle")


def r_treat(ons, rng, P):
    for s in ons[:2]:
        P.at(s.start, tap(0.7, rng), g(s), "tap")
        P.at(s.start, flick(3000, rng), g(s, 0.8), "flick")
    s = ons[2]
    P.at(s.start, peel(s.dur, rng), g(s, 0.8), "peel")
    s = ons[3]
    P.at(s.start, tap(0.5, rng), g(s), "tap")


FEELING_RECIPES = {
    "snd_squeeze": r_squeeze, "snd_forehead": r_forehead, "snd_palm": r_palm, "snd_nuzzle": r_nuzzle,
    "snd_thinking": r_thinking, "snd_goodnight": r_goodnight,
    "snd_miss": r_miss, "snd_chair": r_chair, "snd_home": r_home, "snd_wish": r_wish, "snd_longday": r_longday,
    "snd_here": r_here, "snd_breathe": r_breathe, "snd_okay": r_okay, "snd_steady": r_steady, "snd_tea": r_tea,
    "snd_hold": r_hold,
    "snd_poke": r_poke, "snd_nyeh": r_nyeh, "snd_catch": r_catch, "snd_pick": r_pick, "snd_snap": r_snap,
    "snd_stuck": r_stuck,
    "snd_overwhelmed": r_overwhelmed, "snd_ugh": r_ugh, "snd_snapped": r_snapped, "snd_tangled": r_tangled,
    "snd_grey": r_grey, "snd_notokay": r_notokay,
    "snd_didit": r_didit, "snd_confetti": r_confetti, "snd_yes": r_yes, "snd_crown": r_crown, "snd_treat": r_treat,
    "snd_user_pigeon": r_user_pigeon, "snd_user_soup": r_user_soup,
}


# ---- UI paper sounds ---------------------------------------------------------------------------------
def ui_send(rng, P):
    n = _n(330)
    slide = tv_filter(white(n, rng), sweep(n, 800, 2600), kind="band", width_oct=1.4)
    slide *= np.linspace(0.3, 1.0, n) ** 1.3 * env_asr(n, 20, 40)
    r = rustle(330, 140, rng, band=(900, 4000), shape=np.linspace(0.2, 1.0, n) ** 2)
    P.at(0, _norm(slide + 0.6 * r, 0.8), 0.9, "slide")
    P.at(300, flick(2200, rng), 0.7, "flick")


def ui_land(rng, P):
    P.at(0, press(250, 0.45, rng), 1.0, "press")
    P.at(30, rustle(120, 150, rng), 0.5, "rustle")


def ui_unfold(rng, P):
    for i, t in enumerate((0, 400, 800)):
        P.at(t, rustle(230, 110 + 20 * i, rng, band=(700, 4000)), 0.7 + 0.1 * i, "rustle")
        P.at(t + 40, press(180, 0.3, rng, release=0.5), 0.35, "press")


def ui_tape(rng, P):
    P.at(0, peel(180, rng), 1.0, "peel")


def ui_tear(rng, P):
    P.at(0, tear(400, rng), 1.0, "tear")


def ui_page(rng, P):
    P.at(0, page_turn(480, 85, rng), 1.0, "page_turn")


def ui_pencil(rng, P):
    P.at(0, scratch(150, 0.5, rng), 1.0, "scratch")


def ui_tick(rng, P):
    P.at(0, tap(0.55, rng), 1.0, "tap")


UI_RECIPES = {
    "ui_send": (ui_send, 450, "a note sliding off the desk"),
    "ui_land": (ui_land, 450, "a note settling: a press and one rustle"),
    "ui_unfold": (ui_unfold, 1200, "a folded note opened: three soft rustles"),
    "ui_tape": (ui_tape, 260, "a short strip of tape peeled"),
    "ui_tear": (ui_tear, 470, "a strip torn off a sheet"),
    "ui_page": (ui_page, 700, "a page turned"),
    "ui_pencil": (ui_pencil, 220, "a pencil mark"),
    "ui_tick": (ui_tick, 140, "a pencil tick on the desk"),
}


# =============================================================================================
# Rendering, encoding, manifest
# =============================================================================================
def rng_for(seed, name):
    """One independent, reproducible stream per recipe."""
    return np.random.default_rng([int(seed), zlib.crc32(name.encode("utf-8"))])


def render_feeling(feeling, seed=DEFAULT_SEED):
    """→ (float array at FS, placements, segs). Peak-normalised to 1.0; not yet dithered/encoded."""
    sound = feeling["sound"]
    fn = FEELING_RECIPES.get(sound)
    if fn is None:
        raise KeyError(f"no recipe for {sound}")
    segs = parse_haptic(feeling["haptic"])
    P = Placer(bound_ms(segs))
    rng = rng_for(seed, sound)
    ons = on_segments(segs)
    if sound == "snd_overwhelmed":
        fn(ons, rng, P, segs=segs)
    else:
        fn(ons, rng, P)
    return _norm(P.render(), 1.0), P.placements, segs


def render_ui(name, seed=DEFAULT_SEED):
    fn, length_ms, _ = UI_RECIPES[name]
    P = Placer(length_ms)
    fn(rng_for(seed, name), P)
    return _norm(P.render(), 1.0), P.placements


def trim_tail(x, floor_db=-66.0, keep_ms=30):
    """Drop trailing digital silence (keeps `keep_ms` after the last audible sample)."""
    thr = 10 ** (floor_db / 20)
    idx = np.nonzero(np.abs(x) > thr)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + _n(keep_ms))
    y = x[:end].copy()
    f = min(_n(10), len(y))
    y[-f:] *= _ramp(f)[::-1]
    return y


def write_wav(path, x, rng=None):
    """16-bit PCM mono, TPDF dither."""
    y = np.clip(x, -1.0, 1.0)
    if rng is not None:
        y = y + (rng.uniform(-1, 1, len(y)) + rng.uniform(-1, 1, len(y))) / 65536.0
    pcm = np.clip(np.round(y * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FS)
        w.writeframes(pcm.tobytes())


def decode(path):
    """Decoded float32 samples of any audio file (mono), via ffmpeg."""
    raw = subprocess.run([FFMPEG, "-loglevel", "error", "-i", path, "-f", "f32le", "-acodec", "pcm_f32le",
                          "-ac", "1", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4")


def probe(path):
    out = subprocess.run([FFPROBE, "-v", "error", "-show_entries",
                          "stream=codec_name,sample_rate,channels:format=duration", "-of", "json", path],
                         capture_output=True, text=True, check=True).stdout
    info = json.loads(out)
    st = info["streams"][0]
    return {"codec": st.get("codec_name"), "sample_rate": int(st.get("sample_rate", 0)),
            "channels": int(st.get("channels", 0)), "duration": float(info["format"]["duration"])}


def peak_dbfs(x):
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return 20 * np.log10(m) if m > 0 else -np.inf


def encode_ogg(x, out_path, rng, target_dbfs=PEAK_DBFS, quality=VORBIS_QUALITY, keep_wav=False, tol_db=0.08):
    """WAV → OGG/Vorbis. The encoded file is decoded and its peak compared with the target; the
    input is rescaled and re-encoded until the *encoded* peak is within `tol_db` (≤ 4 passes)."""
    x = _norm(np.asarray(x, dtype=float), 10 ** (target_dbfs / 20))
    wav_path = os.path.splitext(out_path)[0] + ".wav"
    tmp_dir = os.path.dirname(os.path.abspath(out_path))
    fd, tmp_ogg = tempfile.mkstemp(dir=tmp_dir, prefix=".enc.", suffix=".ogg")
    os.close(fd)
    dither = np.random.default_rng(rng.integers(0, 2 ** 31))
    measured = None
    try:
        for _ in range(4):
            write_wav(wav_path, x, np.random.default_rng(dither.integers(0, 2 ** 31)))
            subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis",
                            "-q:a", str(quality), "-ar", str(FS), "-ac", "1", tmp_ogg], check=True)
            measured = peak_dbfs(decode(tmp_ogg))
            err = target_dbfs - measured
            if abs(err) <= tol_db:
                break
            x = x * 10 ** (err / 20)
            if np.max(np.abs(x)) > 0.999:  # never clip the WAV to chase the encoder
                x = _norm(x, 0.999)
        os.replace(tmp_ogg, out_path)
    finally:
        if os.path.exists(tmp_ogg):
            os.remove(tmp_ogg)
        if not keep_wav and os.path.exists(wav_path):
            os.remove(wav_path)
    return measured


def describe(feeling):
    return f"{feeling['object']}: {feeling['sound_desc']}".strip()


def build(out_dir, seed=DEFAULT_SEED, only=None, keep_wav=False, use_manifest=True, plot_dir=None, verbose=True):
    os.makedirs(out_dir, exist_ok=True)
    entries = {}
    feelings = all_feelings()
    wanted = set(only) if only else None

    def log(msg):
        if verbose:
            print(msg)

    for f in feelings:
        sound = f["sound"]
        if wanted and sound not in wanted and f["id"] not in wanted:
            continue
        x, placements, segs = render_feeling(f, seed)
        x = trim_tail(x)
        out_path = os.path.join(out_dir, sound + ".ogg")
        measured = encode_ogg(x, out_path, rng_for(seed, sound + "/encode"), keep_wav=keep_wav)
        entry = {
            "recipe": sound, "seed": int(seed), "haptic": f["haptic"],
            "haptic_expanded": format_haptic(segs), "feeling": f["id"], "family": f["family"],
            "sound": describe(f), "duration_ms": int(round(1000 * len(x) / FS)), "bound_ms": bound_ms(segs),
            "peak_dbfs": round(float(measured), 2), "sample_rate": FS, "channels": 1,
            "format": f"ogg/vorbis q{VORBIS_QUALITY}", "primitives": sorted({p["primitive"] for p in placements}),
            "placements": placements,
        }
        if f.get("author"):
            entry["authored_by"] = f["author"]
        entries[out_path] = entry
        log(f"  {sound:20s} {f['family']:8s} {entry['duration_ms']:5d} ms (bound {entry['bound_ms']})"
            f"  peak {measured:6.2f} dBFS  {f['haptic']}")
        if plot_dir:
            plot_envelope(x, segs, sound, os.path.join(plot_dir, sound + ".png"))

    for name, (_, length_ms, desc) in UI_RECIPES.items():
        if wanted and name not in wanted:
            continue
        x, placements = render_ui(name, seed)
        x = trim_tail(x)
        out_path = os.path.join(out_dir, name + ".ogg")
        measured = encode_ogg(x, out_path, rng_for(seed, name + "/encode"), keep_wav=keep_wav)
        entries[out_path] = {
            "recipe": name, "seed": int(seed), "haptic": None, "sound": desc,
            "duration_ms": int(round(1000 * len(x) / FS)), "bound_ms": length_ms,
            "peak_dbfs": round(float(measured), 2), "sample_rate": FS, "channels": 1,
            "format": f"ogg/vorbis q{VORBIS_QUALITY}", "primitives": sorted({p["primitive"] for p in placements}),
            "placements": placements,
        }
        log(f"  {name:20s} {'ui':8s} {entries[out_path]['duration_ms']:5d} ms  peak {measured:6.2f} dBFS")

    # manifests: the per-tool file, then the shared assets/MANIFEST.json through record()
    local = {"version": 1, "generator": GENERATOR, "seed": int(seed), "sample_rate": FS, "files": {}}
    local_path = os.path.join(out_dir, "MANIFEST.sound.json")
    if os.path.exists(local_path) and wanted:
        try:
            with open(local_path, encoding="utf-8") as fh:
                local = json.load(fh)
        except json.JSONDecodeError:
            pass
    for path, entry in entries.items():
        rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
        e = dict(entry)
        e["bytes"] = os.path.getsize(path)
        local["files"][rel] = e
        if use_manifest:
            record(path, GENERATOR, entry, kind="sound")
    with open(local_path, "w", encoding="utf-8") as fh:
        json.dump(local, fh, indent=1, sort_keys=True)
    return entries


# =============================================================================================
# Listening with your eyes: the envelope against the haptic timeline
# =============================================================================================
def envelope(x, hop_ms=2.0):
    """RMS envelope in hop_ms frames, normalised to 1."""
    h = _n(hop_ms)
    n = (len(x) + h - 1) // h
    pad = np.zeros(n * h)
    pad[:len(x)] = x
    e = np.sqrt(np.mean(pad.reshape(n, h) ** 2, axis=1))
    m = e.max()
    return e / m if m > 0 else e


def plot_envelope(x, segs, title, out_png):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    e = envelope(x)
    t = np.arange(len(e)) * 2.0
    fig, ax = plt.subplots(figsize=(10, 2.8), dpi=110)
    ax.fill_between(t, 0, e, color="#3a3a3c", alpha=0.85, linewidth=0, label="sound envelope (RMS, 2 ms)")
    if segs is not None:
        for s in on_segments(segs):
            ax.add_patch(plt.Rectangle((s.start, 0), s.dur, s.amp / 255.0, facecolor="#a8322b", alpha=0.28,
                                       edgecolor="#a8322b", linewidth=1.0))
        ax.plot([], [], color="#a8322b", alpha=0.6, linewidth=6, label="haptic on@amp/255")
    ax.set_xlim(0, max(t[-1] if len(t) else 1, 1))
    ax.set_ylim(0, 1.05)
    ax.set_xlabel("ms")
    ax.set_title(title, loc="left")
    ax.legend(loc="upper right", frameon=False, fontsize=8)
    fig.tight_layout()
    fig.savefig(out_png)
    plt.close(fig)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=DEFAULT_OUT, help="output directory (default assets/sound)")
    ap.add_argument("--seed", type=int, default=DEFAULT_SEED)
    ap.add_argument("--only", default=None, help="comma-separated sound ids or feeling ids to (re)build")
    ap.add_argument("--wav", action="store_true", help="keep the 16-bit WAV next to each OGG")
    ap.add_argument("--plot", default=None, metavar="DIR", help="write envelope-vs-haptic PNGs (matplotlib)")
    ap.add_argument("--no-manifest", action="store_true", help="do not touch assets/MANIFEST.json")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)
    out_dir = os.path.abspath(args.out)
    inside = out_dir.startswith(os.path.join(ROOT, "assets") + os.sep) or out_dir == os.path.join(ROOT, "assets")
    use_manifest = not args.no_manifest and inside
    only = [s.strip() for s in args.only.split(",")] if args.only else None
    entries = build(out_dir, seed=args.seed, only=only, keep_wav=args.wav, use_manifest=use_manifest,
                    plot_dir=args.plot, verbose=not args.quiet)
    if not args.quiet:
        print(f"{len(entries)} files → {out_dir}" + ("" if use_manifest else " (assets/MANIFEST.json not updated)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
