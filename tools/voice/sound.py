"""tools/voice/sound.py — the world a voice note is recorded in.

A voice note is never a voice. It is a hill at twenty past eight with traffic building below it,
or a kitchen at three in the morning with the fridge cycling, and somewhere in the middle of that
a person talking. The seeded year names fifty-four of these and says exactly what is in each one,
so this file makes the things it names: footsteps on grit, a gate latch, a bus pulling away, rain
on a hood, an empty art room's echo.

Everything is synthesised from first principles at 24 kHz mono. Nothing is sampled from anywhere,
because nothing in this build may be downloaded, and a library of stock sound effects would fail
the same test the stock illustration fails.

Signals are float arrays in roughly -1..1. `at(bed, sound, t)` mixes one into another at a time in
seconds. Everything takes a numpy Generator so a note renders the same way twice.
"""
import math

import numpy as np

SR = 24000


# ------------------------------------------------------------------ small dsp
def secs(n):
    return int(round(n * SR))


def silence(dur):
    return np.zeros(secs(dur), dtype=np.float64)


def at(bed, sound, t, gain=1.0):
    """Mix `sound` into `bed` starting at t seconds. Clips to the bed's length."""
    i = secs(t)
    if i >= len(bed) or len(sound) == 0:
        return bed
    n = min(len(sound), len(bed) - i)
    bed[i:i + n] += sound[:n] * gain
    return bed


def white(n, rng):
    return rng.standard_normal(n)


def pink(n, rng):
    """Pink noise by the usual three-pole approximation. Rooms and wind are pink, not white."""
    w = white(n, rng)
    b = np.zeros(3)
    out = np.empty(n)
    for i in range(n):
        b[0] = 0.99765 * b[0] + w[i] * 0.0990460
        b[1] = 0.96300 * b[1] + w[i] * 0.2965164
        b[2] = 0.57000 * b[2] + w[i] * 1.0526913
        out[i] = b[0] + b[1] + b[2] + w[i] * 0.1848
    return out * 0.11


def brown(n, rng):
    """Traffic and engines live down here: a random walk, leaked back to zero."""
    w = white(n, rng) * 0.02
    out = np.empty(n)
    x = 0.0
    for i in range(n):
        x = 0.998 * x + w[i]
        out[i] = x
    return out / (np.max(np.abs(out)) + 1e-9)


def onepole_lp(x, hz):
    a = math.exp(-2 * math.pi * hz / SR)
    out = np.empty_like(x)
    y = 0.0
    for i in range(len(x)):
        y = a * y + (1 - a) * x[i]
        out[i] = y
    return out


def onepole_hp(x, hz):
    return x - onepole_lp(x, hz)


def biquad(x, b, a):
    out = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        y = b[0] * x[i] + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        out[i] = y
        x2, x1 = x1, x[i]
        y2, y1 = y1, y
    return out


def bandpass(x, hz, q=2.0):
    w = 2 * math.pi * hz / SR
    alpha = math.sin(w) / (2 * q)
    b = [alpha, 0.0, -alpha]
    a = [1 + alpha, -2 * math.cos(w), 1 - alpha]
    return biquad(x, [v / a[0] for v in b], [1.0, a[1] / a[0], a[2] / a[0]])


def lowpass(x, hz, q=0.707):
    w = 2 * math.pi * min(hz, SR * 0.45) / SR
    alpha = math.sin(w) / (2 * q)
    c = math.cos(w)
    b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    a = [1 + alpha, -2 * c, 1 - alpha]
    return biquad(x, [v / a[0] for v in b], [1.0, a[1] / a[0], a[2] / a[0]])


def highpass(x, hz, q=0.707):
    w = 2 * math.pi * max(hz, 5.0) / SR
    alpha = math.sin(w) / (2 * q)
    c = math.cos(w)
    b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    a = [1 + alpha, -2 * c, 1 - alpha]
    return biquad(x, [v / a[0] for v in b], [1.0, a[1] / a[0], a[2] / a[0]])


def resonator(n, hz, decay, rng=None, amp=1.0, phase=0.0):
    """One decaying partial. Metal, glass and bells are a handful of these at once."""
    t = np.arange(n) / SR
    return amp * np.exp(-t / decay) * np.sin(2 * math.pi * hz * t + phase)


def env_ad(n, attack, decay, power=2.0):
    a = max(1, secs(attack))
    e = np.ones(n)
    e[:min(a, n)] = np.linspace(0, 1, min(a, n)) ** 0.7
    t = np.arange(n) / SR
    return e * np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4)) ** 1.0 ** power


def modulate(x, hz, depth, rng, wander=0.0):
    """Slow amplitude movement. Nothing in a room holds a steady level."""
    n = len(x)
    t = np.arange(n) / SR
    m = 1.0 - depth * 0.5 * (1 + np.sin(2 * math.pi * hz * t + rng.uniform(0, 6.28)))
    if wander:
        slow = onepole_lp(white(n, rng), 0.3)
        slow /= (np.max(np.abs(slow)) + 1e-9)
        m = m * (1 + wander * slow)
    return x * m


# ------------------------------------------------------------------ rooms
def reverb(x, rt60=1.2, wet=0.3, rng=None, predelay=0.012):
    """Schroeder: four combs into two allpasses. An art room stripped to the boards has an RT60
    close to two seconds, and that echo is the whole point of one of these notes."""
    rng = rng or np.random.default_rng(0)
    combs = [0.0297, 0.0371, 0.0411, 0.0437]
    out = np.zeros(len(x) + secs(rt60))
    src = np.concatenate([np.zeros(secs(predelay)), x, np.zeros(secs(rt60))])
    acc = np.zeros_like(src)
    for d in combs:
        g = 10 ** (-3 * d / max(rt60, 0.05))
        buf = np.zeros_like(src)
        dn = secs(d)
        for i in range(dn, len(src)):
            buf[i] = src[i] + g * buf[i - dn]
        acc += buf / len(combs)
    for d, g in ((0.0050, 0.7), (0.0017, 0.7)):
        dn = secs(d)
        buf = np.zeros_like(acc)
        for i in range(dn, len(acc)):
            buf[i] = -g * acc[i] + acc[i - dn] + g * buf[i - dn]
        acc = buf
    acc = lowpass(acc, 4200)
    n = min(len(out), len(acc))
    out[:n] = acc[:n]
    dry = np.zeros_like(out)
    dry[:len(x)] = x
    return dry * (1 - wet * 0.6) + out * wet


# ------------------------------------------------------------------ beds
def air(dur, rng, bright=0.4, level=0.02):
    """The floor under everything outdoors: moving air, no source you could point at."""
    n = secs(dur)
    x = pink(n, rng)
    x = lowpass(x, 400 + 2600 * bright)
    return modulate(x, 0.07, 0.4, rng, wander=0.5) * level


def wind_on_mic(dur, rng, strength=1.0):
    """Wind is not a hiss. It is the microphone itself being overloaded in gusts, which is why
    the low end swells and the top end vanishes while it happens."""
    n = secs(dur)
    x = lowpass(pink(n, rng), 220)
    gust = onepole_lp(white(n, rng), 0.25)
    gust = np.abs(gust) / (np.max(np.abs(gust)) + 1e-9)
    gust = gust ** 1.6
    x = x * (0.25 + 2.4 * gust) * 0.16 * strength
    return np.tanh(x * 2.2) * 0.5


def traffic(dur, rng, distance=1.0, building=0.0):
    """A road below a hill: brown noise with the top rolled off by the air between."""
    n = secs(dur)
    x = brown(n, rng)
    x = lowpass(x, 320 / max(distance, 0.4))
    x = modulate(x, 0.05, 0.35, rng, wander=0.7)
    ramp = np.linspace(1.0, 1.0 + building, n)
    return x * 0.09 / max(distance, 0.4) * ramp


def rain(dur, rng, on_hood=False, level=1.0):
    """Rain is a hiss plus a great many individual arrivals. On a hood the arrivals are enormous
    and the hiss is behind them; in the open it is the other way round."""
    n = secs(dur)
    hiss = highpass(pink(n, rng), 900) * (0.05 if on_hood else 0.09)
    out = hiss
    rate = 55 if on_hood else 20
    count = int(dur * rate)
    for _ in range(count):
        t = rng.uniform(0, max(dur - 0.02, 0.01))
        m = secs(rng.uniform(0.004, 0.016))
        drop = white(m, rng) * np.exp(-np.arange(m) / (m * 0.30))
        drop = bandpass(drop, rng.uniform(700, 2600), q=1.4)
        at(out, drop, t, gain=rng.uniform(0.15, 0.55) * (1.6 if on_hood else 0.7))
    return out * level


def hum(dur, rng, base=50.0, harmonics=(1, 2, 3, 4), level=0.03, cycling=None):
    """A fridge, an extractor, a boiler: mains harmonics and a little mechanical noise."""
    n = secs(dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in harmonics:
        x += np.sin(2 * math.pi * base * k * t + rng.uniform(0, 6.28)) / (k ** 1.4)
    x += lowpass(white(n, rng), 500) * 0.35
    x = x * level
    if cycling:
        gate = np.zeros(n)
        for (a, b) in cycling:
            i, j = secs(a), min(secs(b), n)
            if j > i:
                gate[i:j] = 1.0
        gate = onepole_lp(gate, 1.2)
        x = x * gate
    return x


def fan(dur, rng, level=0.03, blade=88.0):
    n = secs(dur)
    x = bandpass(white(n, rng), 620, q=0.6) * 0.5 + lowpass(white(n, rng), 240) * 0.9
    t = np.arange(n) / SR
    x = x * (1 + 0.10 * np.sin(2 * math.pi * blade * t))
    return x * level


def rails(dur, rng, level=0.05):
    """A train seat: rumble under everything, and the joints going past underneath."""
    n = secs(dur)
    x = lowpass(brown(n, rng), 150) * 1.0
    x = modulate(x, 0.9, 0.15, rng)
    every = 1.35
    t = 0.0
    while t < dur:
        m = secs(0.05)
        clack = white(m, rng) * np.exp(-np.arange(m) / (m * 0.22))
        clack = lowpass(clack, 900)
        at(x, clack, t, gain=0.5)
        at(x, clack, t + 0.09, gain=0.35)
        t += every * rng.uniform(0.94, 1.06)
    return x * level


def engine_drone(dur, rng, level=0.05, base=42.0):
    n = secs(dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in (1, 2, 3, 5, 7):
        x += np.sin(2 * math.pi * base * k * t + rng.uniform(0, 6.28)) / (k ** 1.6)
    x += lowpass(white(n, rng), 700) * 0.6
    x = modulate(x, 0.11, 0.25, rng, wander=0.4)
    return x * level


def bubbling(dur, rng, level=0.6, rate=9.0):
    """A pan at a simmer. A bubble is a cavity whose resonance rises as it collapses."""
    n = secs(dur)
    out = lowpass(white(n, rng), 700) * 0.008
    for _ in range(int(dur * rate)):
        t = rng.uniform(0, max(dur - 0.05, 0.01))
        m = secs(rng.uniform(0.012, 0.045))
        f0 = rng.uniform(300, 1400)
        tt = np.arange(m) / SR
        sweep = f0 * (1 + 3.2 * tt / (m / SR))
        ph = 2 * math.pi * np.cumsum(sweep) / SR
        pop = np.sin(ph) * np.exp(-tt / (m / SR * 0.30))
        at(out, pop, t, gain=rng.uniform(0.03, 0.11))
    return out * level


def room_tone(dur, rng, level=0.012):
    return lowpass(pink(dur and secs(dur) or 1, rng), 900) * level


def birds(dur, rng, level=0.5, density=1.4, gulls=False):
    """Chirps are frequency sweeps with a very fast envelope; a gull is a longer harsh cry."""
    out = silence(dur)
    for _ in range(max(1, int(dur * density))):
        t = rng.uniform(0, max(dur - 0.4, 0.01))
        if gulls:
            m = secs(rng.uniform(0.28, 0.5))
            tt = np.arange(m) / SR
            f = rng.uniform(700, 1000) * (1.25 - 0.5 * tt / (m / SR))
            ph = 2 * math.pi * np.cumsum(f) / SR
            cry = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph))
            cry *= np.exp(-((tt / (m / SR) - 0.35) ** 2) / 0.09)
            cry *= 1 + 0.4 * np.sin(2 * math.pi * 26 * tt)
            at(out, cry, t, gain=rng.uniform(0.03, 0.09) * level)
        else:
            n_notes = rng.integers(1, 4)
            for k in range(int(n_notes)):
                m = secs(rng.uniform(0.035, 0.09))
                tt = np.arange(m) / SR
                a = rng.uniform(2600, 5200)
                b = a * rng.uniform(0.7, 1.5)
                f = np.linspace(a, b, m)
                ph = 2 * math.pi * np.cumsum(f) / SR
                note = np.sin(ph) * np.sin(np.pi * np.linspace(0, 1, m)) ** 0.6
                at(out, note, t + k * rng.uniform(0.09, 0.16), gain=rng.uniform(0.02, 0.07) * level)
    return out


def band_through_canvas(dur, rng, level=0.05):
    """A band a marquee away: you hear the kick and the bass line and nothing above 500 Hz."""
    n = secs(dur)
    bpm = 104.0
    beat = 60.0 / bpm
    out = np.zeros(n)
    notes = [55.0, 55.0, 73.42, 82.41, 65.41, 65.41, 49.0, 55.0]
    t = 0.0
    k = 0
    while t < dur:
        m = secs(beat * 0.9)
        tt = np.arange(m) / SR
        f = notes[k % len(notes)]
        line = np.sin(2 * math.pi * f * tt) * np.exp(-tt / (beat * 0.5))
        at(out, line, t, gain=0.5)
        kick = np.sin(2 * math.pi * np.cumsum(np.linspace(90, 42, secs(0.14))) / SR)
        kick *= np.exp(-np.arange(secs(0.14)) / (SR * 0.05))
        at(out, kick, t, gain=0.7)
        t += beat
        k += 1
    out = lowpass(out, 340)
    return modulate(out, 0.06, 0.3, rng) * level


# ------------------------------------------------------------------ one-shots
def footstep(rng, surface="grit", weight=1.0):
    """A step is a heel arriving and a sole scuffing after it. The surface decides the scuff."""
    heel_n = secs(0.045)
    # A heel does not arrive instantaneously: the foot rolls onto it over two or three
    # milliseconds. Starting the decay at full amplitude on sample zero is a step edge, and a
    # step edge has energy everywhere, which is what put a click at eight kilohertz under a man
    # walking down a hill on Christmas morning.
    rise = min(secs(0.0035), heel_n // 3)
    shape = np.exp(-np.arange(heel_n) / (SR * 0.008))
    shape[:rise] *= np.linspace(0, 1, rise) ** 1.4
    heel = white(heel_n, rng) * shape
    if surface == "grit":
        heel = bandpass(heel, 2100, q=0.8) + lowpass(heel, 420) * 0.8
        scuff_hz, scuff_len, scuff_g = 3400, 0.10, 0.5
    elif surface == "wet":
        heel = bandpass(heel, 1500, q=0.9) + lowpass(heel, 380) * 1.0
        scuff_hz, scuff_len, scuff_g = 1800, 0.07, 0.7
    elif surface == "slush":
        heel = bandpass(heel, 900, q=0.7) + lowpass(heel, 300) * 1.1
        scuff_hz, scuff_len, scuff_g = 1100, 0.14, 0.9
    elif surface == "boards":
        heel = bandpass(heel, 700, q=1.6) + lowpass(heel, 220) * 1.3
        scuff_hz, scuff_len, scuff_g = 2400, 0.05, 0.25
    else:  # road, lino
        heel = bandpass(heel, 1200, q=1.0) + lowpass(heel, 300) * 0.9
        scuff_hz, scuff_len, scuff_g = 2600, 0.06, 0.35
    sn = secs(scuff_len)
    scuff = white(sn, rng) * np.linspace(1, 0, sn) ** 2
    scuff = bandpass(scuff, scuff_hz, q=0.7) * scuff_g
    out = np.zeros(max(heel_n, sn) + secs(0.02))
    out[:heel_n] += heel
    out[:sn] += scuff
    # A shoe on a road is a thud and a drag. Almost nothing it does happens above two kilohertz,
    # and leaving the top end in is what made the first pass read as a metronome of clicks laid
    # over a voice rather than as somebody walking while they talked.
    ceiling = {"grit": 2600, "slush": 1400, "wet": 1900, "boards": 2400}.get(surface, 1900)
    out = lowpass(lowpass(out, ceiling, q=0.6), ceiling * 1.3, q=0.6)
    return out * 0.34 * weight


def walking(dur, rng, surface="grit", pace=0.56, unsteady=0.0, level=1.0, gaps=()):
    """Someone walking downhill for forty seconds, with the gaps where they stopped."""
    out = silence(dur)
    t = rng.uniform(0, 0.3)
    left = True
    while t < dur:
        if not any(a <= t <= b for a, b in gaps):
            w = 1.0 if left else 0.88
            at(out, footstep(rng, surface, w * rng.uniform(0.8, 1.15)), t, gain=level)
        left = not left
        t += pace * rng.uniform(1 - 0.05 - unsteady, 1 + 0.05 + unsteady * 2)
    return out


def gate_latch(rng, kind="latch"):
    """Cold iron: two or three inharmonic partials, and a wooden thud under them if it is a gate."""
    n = secs(1.1)
    out = np.zeros(n)
    base = rng.uniform(760, 1080)
    for mult, dec, amp in ((1.0, 0.35, 1.0), (2.41, 0.20, 0.55), (4.07, 0.11, 0.30), (6.9, 0.06, 0.18)):
        out += resonator(n, base * mult, dec, amp=amp, phase=rng.uniform(0, 6.28))
    click = white(secs(0.01), rng) * np.linspace(1, 0, secs(0.01)) ** 2
    at(out, bandpass(click, 3200, q=0.8), 0.0, gain=2.0)
    thud = lowpass(white(secs(0.14), rng), 220) * np.exp(-np.arange(secs(0.14)) / (SR * 0.03))
    at(out, thud, 0.004, gain=1.2)
    if kind == "shut":
        at(out, out[:secs(0.5)].copy(), 0.17, gain=0.5)
    return out * 0.20


def door_bang(rng, distant=True):
    n = secs(0.8)
    out = lowpass(white(n, rng), 260) * np.exp(-np.arange(n) / (SR * 0.035))
    out += resonator(n, rng.uniform(90, 150), 0.18, amp=0.8)
    out += bandpass(white(n, rng), 1400, q=1.2) * np.exp(-np.arange(n) / (SR * 0.012)) * 0.6
    if distant:
        out = lowpass(out, 900) * 0.35
    return out * 0.30


def keys(rng, count=7):
    n = secs(0.9)
    out = np.zeros(n)
    for _ in range(count):
        t = rng.uniform(0, 0.35)
        m = secs(0.35)
        k = np.zeros(m)
        f = rng.uniform(2400, 5200)
        for mult, dec, amp in ((1.0, 0.10, 1.0), (2.7, 0.06, 0.5), (5.1, 0.03, 0.25)):
            k += resonator(m, f * mult, dec, amp=amp, phase=rng.uniform(0, 6.28))
        at(out, k, t, gain=rng.uniform(0.3, 1.0))
    return out * 0.10


def vehicle_pass(dur, rng, kind="car", close=0.6):
    """A vehicle going past: a swell whose top end arrives with it and leaves with it."""
    n = secs(dur)
    t = np.arange(n) / SR
    centre = dur * 0.5
    prox = np.exp(-((t - centre) ** 2) / (2 * (dur * 0.22) ** 2))
    if kind == "bus" or kind == "lorry":
        base = 32.0
        x = np.zeros(n)
        for k in (1, 2, 3, 4, 6, 9):
            x += np.sin(2 * math.pi * base * k * t * (1 + 0.06 * prox) + rng.uniform(0, 6.28)) / (k ** 1.5)
        x += lowpass(white(n, rng), 1100) * 0.8
        rattle = bandpass(white(n, rng), 180, q=3.0) * 0.5
        x = x + rattle * prox
    elif kind == "train_pass":
        x = lowpass(brown(n, rng), 400) * 1.2
    else:
        base = 55.0
        x = np.zeros(n)
        for k in (1, 2, 3, 5):
            x += np.sin(2 * math.pi * base * k * t * (1 + 0.05 * prox) + rng.uniform(0, 6.28)) / (k ** 1.6)
        x += highpass(white(n, rng), 600) * 0.4
    tyres = highpass(white(n, rng), 900) * prox * 0.5
    return (x * prox + tyres) * 0.09 * close


def bus_door(rng):
    """The hiss of air and the two panels folding."""
    n = secs(1.4)
    hiss = highpass(white(n, rng), 2200) * np.concatenate(
        [np.linspace(0, 1, secs(0.05)), np.ones(secs(0.35)), np.linspace(1, 0, n - secs(0.40))])
    out = hiss * 0.10
    at(out, lowpass(white(secs(0.12), rng), 700) * np.exp(-np.arange(secs(0.12)) / (SR * 0.03)), 0.62, gain=0.5)
    at(out, lowpass(white(secs(0.12), rng), 700) * np.exp(-np.arange(secs(0.12)) / (SR * 0.03)), 0.78, gain=0.4)
    return out


def reversing_beep(dur, rng, hz=1000.0, level=0.03):
    """A delivery lorry somewhere below the hill: an alarm, heard through a street of buildings."""
    n = secs(dur)
    out = np.zeros(n)
    t = 0.0
    while t < dur:
        m = secs(0.32)
        tt = np.arange(m) / SR
        beep = np.sign(np.sin(2 * math.pi * hz * tt)) * 0.3 + np.sin(2 * math.pi * hz * tt)
        beep *= np.concatenate([np.linspace(0, 1, secs(0.01)), np.ones(m - secs(0.02)), np.linspace(1, 0, secs(0.01))])
        at(out, lowpass(beep, 1800), t, gain=1.0)
        t += 0.85
    return out * level


def church_bell(rng, hz=262.0):
    n = secs(4.5)
    out = np.zeros(n)
    # hum, prime, tierce, quint, nominal — what makes a bell a bell rather than a sine
    for mult, dec, amp in ((0.5, 3.6, 0.7), (1.0, 3.0, 1.0), (1.2, 2.2, 0.6),
                           (1.5, 1.8, 0.4), (2.0, 1.4, 0.5), (2.5, 0.9, 0.25), (3.0, 0.6, 0.2)):
        out += resonator(n, hz * mult, dec, amp=amp, phase=rng.uniform(0, 6.28))
    strike = white(secs(0.03), rng) * np.linspace(1, 0, secs(0.03)) ** 2
    at(out, bandpass(strike, 2600, q=0.7), 0.0, gain=1.5)
    return lowpass(out, 3000) * 0.035


def chair_scrape(rng, dur=0.55):
    n = secs(dur)
    x = white(n, rng)
    x = bandpass(x, 480, q=1.1) + bandpass(x, 1250, q=2.0) * 0.6
    x *= (0.4 + 0.6 * np.abs(onepole_lp(white(n, rng), 40)) / 0.05).clip(0, 3)
    x *= np.concatenate([np.linspace(0, 1, secs(0.03)), np.ones(n - secs(0.09)), np.linspace(1, 0, secs(0.06))])
    return x * 0.12


def chair_onto_table(rng):
    out = np.zeros(secs(1.2))
    at(out, chair_scrape(rng, 0.30), 0.0, gain=0.7)
    knock = lowpass(white(secs(0.20), rng), 900) * np.exp(-np.arange(secs(0.20)) / (SR * 0.02))
    knock += resonator(secs(0.20), 320, 0.09, amp=0.6)
    at(out, knock, 0.42, gain=0.5)
    at(out, knock, 0.55, gain=0.3)
    return out


def tap_water(dur, rng, level=1.0):
    n = secs(dur)
    x = highpass(white(n, rng), 1400) * 0.5 + bandpass(white(n, rng), 2600, q=0.7) * 0.4
    x = modulate(x, 7.0, 0.25, rng, wander=0.8)
    x *= np.concatenate([np.linspace(0, 1, secs(0.04)), np.ones(n - secs(0.10)), np.linspace(1, 0, secs(0.06))])
    return x * 0.10 * level


def drip(rng):
    n = secs(0.25)
    tt = np.arange(n) / SR
    f = 900 * (1 + 2.4 * tt / (n / SR))
    ph = 2 * math.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-tt / 0.030) * 0.10


def set_down(rng, what="mug", surface="wood"):
    """Something put down on something. Which two things decides the whole sound."""
    n = secs(0.7)
    out = np.zeros(n)
    if what == "mug":
        parts = ((rng.uniform(1100, 1500), 0.09, 1.0), (rng.uniform(2600, 3400), 0.05, 0.4))
    elif what == "plate":
        parts = ((rng.uniform(1700, 2200), 0.16, 1.0), (rng.uniform(3900, 4600), 0.07, 0.5))
    elif what == "lid":
        parts = ((rng.uniform(640, 820), 0.22, 1.0), (rng.uniform(1600, 2000), 0.12, 0.6),
                 (rng.uniform(2900, 3400), 0.06, 0.3))
    elif what == "spoon":
        parts = ((rng.uniform(1800, 2400), 0.06, 0.8),)
    else:  # folder, paper, bag
        parts = ()
    for f, d, a in parts:
        out += resonator(n, f, d, amp=a, phase=rng.uniform(0, 6.28))
    thud = lowpass(white(secs(0.09), rng), 500 if surface == "wood" else 1400)
    thud *= np.exp(-np.arange(secs(0.09)) / (SR * 0.012))
    at(out, thud, 0.0, gain=1.4)
    if what in ("folder", "paper", "bag"):
        at(out, paper_rustle(0.35, rng), 0.0, gain=1.2)
    return out * 0.11


def knife_on_board(rng):
    n = secs(0.35)
    out = lowpass(white(n, rng), 1600) * np.exp(-np.arange(n) / (SR * 0.014))
    out += resonator(n, rng.uniform(220, 300), 0.07, amp=0.7)
    out += bandpass(white(n, rng), 3400, q=0.9) * np.exp(-np.arange(n) / (SR * 0.005)) * 0.6
    return out * 0.16


def lid_rattle(rng):
    n = secs(0.9)
    out = np.zeros(n)
    t = 0.0
    while t < 0.6:
        m = secs(0.09)
        tick = resonator(m, rng.uniform(700, 900), 0.02, amp=1.0)
        tick += bandpass(white(m, rng), 2600, q=1.0) * np.exp(-np.arange(m) / (SR * 0.004))
        at(out, tick, t, gain=rng.uniform(0.4, 1.0))
        t += rng.uniform(0.07, 0.14)
    return out * 0.07


def paper_rustle(dur, rng, level=1.0):
    """Paper is thousands of tiny fibre releases, not a hiss: crackle, bunched into movements."""
    n = secs(dur)
    out = np.zeros(n)
    bursts = int(dur * 26)
    for _ in range(bursts):
        t = rng.uniform(0, max(dur - 0.02, 0.005))
        m = secs(rng.uniform(0.002, 0.010))
        c = white(m, rng) * np.linspace(1, 0, m) ** 1.5
        at(out, c, t, gain=rng.uniform(0.2, 1.0))
    out = bandpass(out, 3600, q=0.5) + bandpass(out, 1500, q=0.7) * 0.4
    shape = np.abs(onepole_lp(white(n, rng), 3.0))
    shape /= (np.max(shape) + 1e-9)
    return out * (0.3 + shape) * 0.10 * level


def radiator_tick(dur, rng, level=1.0):
    out = silence(dur)
    t = rng.uniform(0, 3)
    while t < dur:
        m = secs(0.06)
        tick = resonator(m, rng.uniform(1400, 2600), 0.012, amp=1.0)
        tick += lowpass(white(m, rng), 800) * np.exp(-np.arange(m) / (SR * 0.004)) * 0.5
        at(out, tick, t, gain=rng.uniform(0.2, 0.6))
        t += rng.uniform(2.5, 9.0)
    return out * 0.06 * level


def trolley(dur, rng, level=1.0):
    """A caretaker's trolley in a corridor: small hard wheels on hard floor, going past."""
    n = secs(dur)
    t = np.arange(n) / SR
    prox = np.exp(-((t - dur * 0.5) ** 2) / (2 * (dur * 0.25) ** 2))
    x = bandpass(white(n, rng), 1800, q=0.6) * 0.6 + lowpass(white(n, rng), 400) * 0.5
    x = modulate(x, 11.0, 0.3, rng)
    for _ in range(int(dur * 3)):
        tt = rng.uniform(0, dur)
        m = secs(0.05)
        clink = resonator(m, rng.uniform(1200, 2600), 0.02, amp=1.0)
        at(x, clink, tt, gain=0.4)
    return x * prox * 0.06 * level


def bell_ping(rng):
    n = secs(1.0)
    out = resonator(n, 1760, 0.35, amp=1.0) + resonator(n, 2640, 0.20, amp=0.4)
    return out * 0.045


def bin_lid(rng):
    n = secs(1.0)
    out = lowpass(white(n, rng), 500) * np.exp(-np.arange(n) / (SR * 0.03))
    for f, d, a in ((rng.uniform(210, 300), 0.28, 0.8), (rng.uniform(520, 700), 0.14, 0.5)):
        out += resonator(n, f, d, amp=a)
    return out * 0.15


def car_door(rng):
    n = secs(0.9)
    out = lowpass(white(n, rng), 300) * np.exp(-np.arange(n) / (SR * 0.028))
    out += resonator(n, rng.uniform(70, 110), 0.16, amp=1.0)
    out += bandpass(white(n, rng), 1100, q=1.2) * np.exp(-np.arange(n) / (SR * 0.010)) * 0.5
    return out * 0.20


def gravel(dur, rng, level=1.0):
    return walking(dur, rng, surface="grit", pace=0.62, level=0.7 * level)


def window_catch(rng):
    n = secs(0.6)
    out = np.zeros(n)
    for _ in range(3):
        m = secs(0.12)
        r = resonator(m, rng.uniform(1600, 2600), 0.03, amp=1.0)
        r += bandpass(white(m, rng), 4200, q=0.8) * np.exp(-np.arange(m) / (SR * 0.003))
        at(out, r, rng.uniform(0, 0.3), gain=rng.uniform(0.4, 1.0))
    return out * 0.08


def stack_chairs(dur, rng, level=1.0):
    out = silence(dur)
    t = 0.2
    while t < dur - 1.0:
        at(out, chair_onto_table(rng), t, gain=level)
        t += rng.uniform(2.2, 3.4)
    return out


def echo_room(x, rng, size="classroom"):
    rt = {"classroom": 1.05, "artroom": 1.9, "corridor": 1.5, "stairwell": 2.2,
          "kitchen": 0.35, "small": 0.25}.get(size, 0.8)
    wet = {"classroom": 0.30, "artroom": 0.46, "corridor": 0.38, "stairwell": 0.5,
           "kitchen": 0.10, "small": 0.07}.get(size, 0.2)
    return reverb(x, rt60=rt, wet=wet, rng=rng)


# ------------------------------------------------------------------ the phone itself
def phone_mic(x, rng, tunnel=(), handling=0.0):
    """What the recording device does to all of it: band limit, a little compression, and the
    handling noise of a hand holding a phone that is also being walked with."""
    y = highpass(x, 95, q=0.7)
    y = lowpass(y, 7200, q=0.7)
    if handling:
        n = len(y)
        rub = lowpass(white(n, rng), 160) * np.abs(onepole_lp(white(n, rng), 1.6))
        rub /= (np.max(np.abs(rub)) + 1e-9)
        y = y + rub * 0.035 * handling
    for (a, b) in tunnel:
        i, j = secs(a), min(secs(b), len(y))
        if j > i:
            seg = lowpass(y[i:j], 420)
            ramp = np.ones(j - i)
            fade = min(secs(0.4), (j - i) // 3)
            ramp[:fade] = np.linspace(1, 0, fade)
            ramp[-fade:] = np.linspace(0, 1, fade)
            y[i:j] = seg * (1 - ramp * 0) * 0.55 + y[i:j] * 0.12
            rumble = lowpass(white(j - i, rng), 90) * 0.05
            y[i:j] += rumble
    # gentle limiting, the way a phone's own gain control behaves
    peak = np.max(np.abs(y)) + 1e-9
    if peak > 0.9:
        y = y / peak * 0.9
    return np.tanh(y * 1.15) * 0.87
