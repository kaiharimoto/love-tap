"""tools/voice/talk.py — a person talking, synthesised rather than recorded.

Nobody's voice can be downloaded into this build, so the two voices are made the way a voice is
actually made: a glottal source driven at a pitch, pushed through a vocal tract that moves between
vowel shapes, interrupted by the consonants that separate them, and phrased by the breath.

What comes out is unmistakably a person speaking and is not intelligible as words, which is the
right answer for a seeded year: these are two fictional people, the sentences they say are written
down in seed/year/*.jsonl where they can be read, and the audio is the sound of them saying
something rather than a claim about what was said. seed/voice/index.*.json records this.

Noor and Teo differ where two people actually differ: pitch range, tract length, how fast they
speak, how far their pitch travels in a sentence, and what they do at the end of one.
"""
import math

import numpy as np

from sound import SR, secs, white, lowpass, highpass, bandpass, onepole_lp

# Formant targets: F1, F2, F3 in Hz for a male tract of about 17 cm. A shorter tract scales
# these up, which is most of what makes a voice sound higher than its pitch alone.
VOWELS = {
    "i":  (300, 2300, 3000),   # fleece
    "I":  (400, 1900, 2550),   # kit
    "e":  (530, 1850, 2500),   # dress
    "a":  (700, 1250, 2550),   # trap / bath
    "A":  (640,  920, 2550),   # thought
    "o":  (450,  800, 2600),   # goat
    "u":  (330,  900, 2300),   # goose
    "V":  (620, 1220, 2550),   # strut
    "@":  (500, 1450, 2500),   # the unstressed vowel that most of English actually is
    "3":  (500, 1500, 2500),   # nurse
}
# The unstressed vowel is far commoner than any other, which is what makes speech sound like
# speech rather than like a list of syllables.
VOWEL_WEIGHTS = {"@": 0.30, "I": 0.13, "V": 0.09, "e": 0.09, "a": 0.09, "i": 0.08,
                 "o": 0.07, "u": 0.05, "A": 0.05, "3": 0.05}

# Consonants by how they are made, because that is what decides the sound.
PLOSIVES = {"p": (0.055, 1200, 0.55), "t": (0.045, 3400, 0.75), "k": (0.055, 2000, 0.65),
            "b": (0.035, 900, 0.40), "d": (0.030, 2600, 0.50), "g": (0.040, 1600, 0.45)}
FRICATIVES = {"s": (0.085, 6200, 1.00, 2.4), "S": (0.095, 2700, 0.85, 2.0), "f": (0.070, 4600, 0.30, 1.2),
              "T": (0.055, 5200, 0.24, 1.1), "v": (0.050, 3200, 0.18, 1.0), "z": (0.070, 5400, 0.45, 2.0),
              "h": (0.060, 1500, 0.22, 0.8)}
NASALS = {"m": (0.070, 280), "n": (0.065, 320), "N": (0.070, 300)}
LIQUIDS = {"l": (0.060, (380, 900, 2600)), "r": (0.065, (400, 1100, 1600)),
           "w": (0.055, (330, 700, 2300)), "j": (0.050, (300, 2200, 3000))}

ONSETS = list(PLOSIVES) + list(FRICATIVES) + list(NASALS) + list(LIQUIDS) + [""] * 4
CODAS = ["", "", "", "n", "t", "s", "l", "d", "m", "z", "k", "N", "r"]


class Voice:
    """One person's instrument."""

    def __init__(self, name):
        self.name = name
        if name == "noor":
            self.f0 = 196.0             # her speaking pitch, roughly G3
            self.range = 0.30           # how far it travels within a phrase
            self.tract = 1.16           # a shorter tract: every formant scaled up
            self.rate = 5.0             # syllables a second when unhurried
            self.breathy = 0.22
            self.jitter = 0.011
        else:
            self.f0 = 108.0             # roughly A2
            self.range = 0.22
            self.tract = 1.0
            self.rate = 4.3
            self.breathy = 0.13
            self.jitter = 0.014

    # -------------------------------------------------------------- source
    def glottal(self, n, f0_curve, rng, tension=0.6):
        """A Rosenberg pulse train. The open phase decides the spectral tilt, which is the
        difference between a voice that is pressed and one that is tired."""
        out = np.zeros(n)
        i = 0
        open_q = 0.55 + 0.20 * (1 - tension)
        while i < n:
            f = f0_curve[min(i, n - 1)]
            f = f * (1.0 + rng.normal(0, self.jitter))
            period = max(8, int(SR / max(f, 40.0)))
            op = int(period * open_q)
            cp = max(2, int(period * 0.14))
            if op < 3:
                op = 3
            t1 = np.linspace(0, 1, op)
            rise = 0.5 * (1 - np.cos(math.pi * t1))
            t2 = np.linspace(0, 1, cp)
            fall = np.cos(math.pi * t2 / 2)
            pulse = np.concatenate([rise, fall])
            amp = 1.0 + rng.normal(0, 0.035)          # shimmer
            m = min(len(pulse), n - i)
            out[i:i + m] += pulse[:m] * amp
            i += period
        out = out - np.mean(out)
        out = out / (np.max(np.abs(out)) + 1e-9)
        # the breath that gets past the folds even when they are closed: quiet, and falling
        # away with frequency the way real aspiration does rather than sitting flat on top
        asp = lowpass(highpass(white(n, rng), 400), 3600)
        return out + asp * self.breathy * 0.06

    # -------------------------------------------------------------- tract
    @staticmethod
    def _resonate(x, track, bw):
        """One formant, as a two-pole resonator with unity gain at DC, its centre frequency
        swept along the track. Coefficients are refreshed every 64 samples, which is faster than
        a tongue moves and slow enough to cost nothing."""
        n = len(x)
        out = np.empty(n)
        y1 = y2 = 0.0
        c = math.exp(-2 * math.pi * bw / SR)
        step = 64
        for start in range(0, n, step):
            stop = min(start + step, n)
            f = float(track[min(start, n - 1)])
            b = -2.0 * math.exp(-math.pi * bw / SR) * math.cos(2 * math.pi * f / SR)
            a = 1.0 - b - c
            for i in range(start, stop):
                y = a * x[i] - b * y1 - c * y2
                out[i] = y
                y2, y1 = y1, y
        return out

    def tract_filter(self, x, tracks, bandwidths=(65, 100, 150, 220)):
        """A cascade, not a bank. Resonators in series give the relative formant amplitudes for
        free; a parallel bank has to be told them, and gets them wrong for every vowel it was
        not tuned on.

        The differentiation at the end is the lip radiation. Without it the source's own falling
        spectrum buries the second and third formants under the fundamental, which is exactly
        what the first version of this sounded like: a hum with something happening inside it.
        """
        y = x
        for k, track in enumerate(tracks):
            y = self._resonate(y, track, bandwidths[min(k, len(bandwidths) - 1)])
        y = np.concatenate([[0.0], np.diff(y)]) * (SR / 6000.0)
        return y

    # -------------------------------------------------------------- pieces
    def _vowel(self, dur, targets_from, targets_to, f0_curve, rng, amp=1.0, tension=0.6):
        n = secs(dur)
        if n < 8:
            return np.zeros(max(n, 0))
        src = self.glottal(n, f0_curve, rng, tension)
        tracks = []
        for k in range(3):
            a = targets_from[k] * self.tract
            b = targets_to[k] * self.tract
            # move fast at first and settle, the way a tongue does
            s = np.linspace(0, 1, n) ** 0.55
            tracks.append(a + (b - a) * s)
        tracks.append(np.full(n, 3900.0 * self.tract))
        y = self.tract_filter(src, tracks)
        env = np.ones(n)
        r = min(secs(0.012), n // 3)
        env[:r] = np.linspace(0, 1, r)
        env[-r:] = np.linspace(1, 0, r)
        return y * env * amp

    def _plosive(self, ch, rng, amp=1.0):
        dur, hz, g = PLOSIVES[ch]
        gap = secs(dur * 0.6)
        bn = secs(0.012)
        burst = white(bn, rng) * np.linspace(1, 0, bn) ** 1.5
        burst = bandpass(burst, hz, q=0.8) * g
        asp = white(secs(0.030), rng) * np.linspace(1, 0, secs(0.030)) ** 2
        asp = bandpass(asp, hz * 0.8, q=0.5) * g * 0.5
        out = np.zeros(gap + bn + secs(0.030))
        out[gap:gap + bn] += burst
        out[gap:gap + secs(0.030)] += asp
        return out * 0.16 * amp

    def _fricative(self, ch, rng, amp=1.0):
        dur, hz, g, q = FRICATIVES[ch]
        n = secs(dur)
        x = white(n, rng)
        x = bandpass(x, hz, q=q) * g
        env = np.concatenate([np.linspace(0, 1, n // 4), np.ones(n - n // 4 - n // 5),
                              np.linspace(1, 0, n // 5)])
        return x[:len(env)] * env * 0.16 * amp

    def _nasal(self, ch, f0_curve, rng, amp=1.0):
        dur, f1 = NASALS[ch]
        n = secs(dur)
        src = self.glottal(n, f0_curve[:n] if len(f0_curve) >= n else np.full(n, self.f0), rng)
        tracks = [np.full(n, f1 * self.tract), np.full(n, 1100 * self.tract),
                  np.full(n, 2400 * self.tract), np.full(n, 3300 * self.tract)]
        y = self.tract_filter(src, tracks, bandwidths=(110, 180, 260, 320))
        env = np.ones(n)
        r = min(secs(0.010), n // 3)
        env[:r] = np.linspace(0, 1, r)
        env[-r:] = np.linspace(1, 0, r)
        return lowpass(y, 2200) * env * 0.5 * amp

    def _liquid(self, ch, f0_curve, rng, amp=1.0):
        dur, targets = LIQUIDS[ch]
        n = secs(dur)
        f0 = f0_curve[:n] if len(f0_curve) >= n else np.full(n, self.f0)
        return self._vowel(dur, targets, targets, f0, rng, amp=0.7 * amp)

    # -------------------------------------------------------------- phrases
    def phrase(self, dur, rng, tone="level", energy=1.0, rate=1.0, ending="fall"):
        """One utterance between two breaths, filled with syllables to exactly `dur` seconds."""
        n = secs(dur)
        if n < secs(0.15):
            return np.zeros(max(n, 0))
        rate_hz = self.rate * rate
        count = max(2, int(round(dur * rate_hz)))
        # declination: pitch falls across a phrase, and a tired voice starts lower and falls less
        start = self.f0 * {"flat": 0.94, "level": 1.0, "bright": 1.10, "low": 0.88,
                           "quick": 1.04, "hoarse": 0.90}.get(tone, 1.0)
        travel = self.range * {"flat": 0.35, "level": 1.0, "bright": 1.35, "low": 0.6,
                               "quick": 1.1, "hoarse": 0.5}.get(tone, 1.0)
        tension = {"flat": 0.35, "hoarse": 0.30, "bright": 0.75, "quick": 0.7}.get(tone, 0.6)
        out = np.zeros(n + secs(0.4))
        pos = 0.0
        prev = VOWELS["@"]
        keys = list(VOWEL_WEIGHTS)
        probs = np.array([VOWEL_WEIGHTS[k] for k in keys])
        probs = probs / probs.sum()
        for s in range(count):
            frac = s / max(count - 1, 1)
            stressed = (s % rng.integers(2, 4) == 0)
            # the pitch of this syllable: declining, with stress lifting it
            f = start * (1 - travel * 0.55 * frac)
            if stressed:
                f *= 1 + travel * 0.28
            if s == count - 1:
                f *= {"fall": 1 - travel * 0.30, "rise": 1 + travel * 0.45,
                      "level": 1.0, "trail": 1 - travel * 0.45}[ending]
            vlen = (0.085 if not stressed else 0.135) / rate * rng.uniform(0.8, 1.25)
            if s == count - 1 and ending == "trail":
                vlen *= 1.8
            onset = str(rng.choice(ONSETS))
            coda = str(rng.choice(CODAS)) if rng.random() < 0.42 else ""
            v = keys[int(rng.choice(len(keys), p=probs))]
            target = VOWELS[v]
            amp = (0.75 if not stressed else 1.0) * energy * rng.uniform(0.85, 1.1)

            if onset in PLOSIVES:
                piece = self._plosive(onset, rng, amp)
                _mix(out, piece, pos)
                pos += len(piece) / SR
            elif onset in FRICATIVES:
                piece = self._fricative(onset, rng, amp)
                _mix(out, piece, pos)
                pos += len(piece) / SR * 0.85
            elif onset in NASALS:
                f0c = np.full(secs(NASALS[onset][0]), f)
                piece = self._nasal(onset, f0c, rng, amp)
                _mix(out, piece, pos)
                pos += len(piece) / SR * 0.9
            elif onset in LIQUIDS:
                f0c = np.full(secs(LIQUIDS[onset][0]), f)
                piece = self._liquid(onset, f0c, rng, amp)
                _mix(out, piece, pos)
                pos += len(piece) / SR * 0.85
                prev = LIQUIDS[onset][1]

            vn = secs(vlen)
            f0c = np.linspace(f, f * rng.uniform(0.94, 1.03), max(vn, 1))
            piece = self._vowel(vlen, prev, target, f0c, rng, amp=amp, tension=tension)
            _mix(out, piece, pos)
            pos += vlen * 0.92
            prev = target

            if coda:
                if coda in PLOSIVES:
                    piece = self._plosive(coda, rng, amp * 0.7)
                elif coda in FRICATIVES:
                    piece = self._fricative(coda, rng, amp * 0.8)
                elif coda in NASALS:
                    piece = self._nasal(coda, np.full(secs(NASALS[coda][0]), f), rng, amp * 0.8)
                else:
                    piece = self._liquid(coda, np.full(secs(LIQUIDS[coda][0]), f), rng, amp * 0.7)
                _mix(out, piece, pos)
                pos += len(piece) / SR * 0.75
            # the gap between words, which is not silence but a slackening
            if rng.random() < 0.30:
                pos += rng.uniform(0.03, 0.13) / rate
            if pos > dur:
                break
        return out[:n]

    def breath(self, dur, rng, voiced=0.0, level=1.0):
        n = secs(dur)
        x = white(n, rng)
        x = bandpass(x, 600 * self.tract, q=0.55) * 0.8 + bandpass(x, 1800 * self.tract, q=0.5) * 0.5
        env = np.sin(np.pi * np.linspace(0, 1, n)) ** 1.3
        out = x * env * 0.06 * level
        if voiced:
            f0 = np.full(n, self.f0 * 0.86)
            v = self._vowel(dur, VOWELS["@"], VOWELS["@"], f0, rng, amp=voiced * 0.5, tension=0.3)
            out[:len(v)] += v * env[:len(v)]
        return out

    def laugh(self, rng, short=True):
        """A laugh is a run of pulses on one falling breath, not a word."""
        beats = int(rng.integers(2, 4)) if short else int(rng.integers(4, 7))
        out = np.zeros(secs(0.15 * beats + 0.5))
        pos = 0.0
        f = self.f0 * 1.5
        for k in range(beats):
            d = rng.uniform(0.07, 0.11)
            f0 = np.linspace(f, f * 0.93, secs(d))
            piece = self._vowel(d, VOWELS["a"], VOWELS["V"], f0, rng, amp=0.9 - 0.12 * k, tension=0.8)
            h = self._fricative("h", rng, 0.5)
            _mix(out, h, pos)
            _mix(out, piece, pos + 0.02)
            pos += d + rng.uniform(0.045, 0.075)
            f *= 0.90
        return out * 0.9

    def yawn(self, rng, dur=2.6):
        """The jaw opens all the way, so F1 climbs and F2 collapses, and the pitch goes with it."""
        n = secs(dur)
        f0 = np.concatenate([np.linspace(self.f0 * 0.95, self.f0 * 1.25, n // 3),
                             np.linspace(self.f0 * 1.25, self.f0 * 0.62, n - n // 3)])
        src = self.glottal(n, f0, rng, tension=0.3)
        t = np.linspace(0, 1, n)
        open_ = np.sin(np.pi * t) ** 0.8
        tracks = [(320 + 620 * open_) * self.tract,
                  (1900 - 950 * open_) * self.tract,
                  (2600 - 200 * open_) * self.tract,
                  np.full(n, 3800 * self.tract)]
        y = self.tract_filter(src, tracks, bandwidths=(90, 130, 200, 280))
        y += white(n, rng) * 0.02 * open_
        env = np.sin(np.pi * t) ** 1.1
        return y * env * 0.55

    def hum_notes(self, rng, notes=(0, 2, 4, 2), dur=0.42):
        """Four notes under the breath, in a gap, without noticing."""
        out = np.zeros(secs(dur * len(notes) + 0.3))
        pos = 0.0
        for k in notes:
            f = self.f0 * (2 ** (k / 12.0)) * 1.05
            n = secs(dur)
            f0 = np.full(n, f) * (1 + 0.006 * np.sin(np.linspace(0, 12, n)))
            m = self._nasal("m", f0, rng, amp=1.0)
            _mix(out, m, pos)
            more = self._nasal("m", f0, rng, amp=1.0)
            _mix(out, more, pos + len(m) / SR * 0.9)
            pos += dur
        return out * 0.55


def _mix(bed, piece, t):
    i = secs(t)
    if i >= len(bed) or len(piece) == 0:
        return
    n = min(len(piece), len(bed) - i)
    bed[i:i + n] += piece[:n]
