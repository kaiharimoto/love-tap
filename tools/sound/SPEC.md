# tools/sound — SPEC

Synthesises every sound in the app from paper-noise models. No recordings exist in this container;
each recipe names the real sound so a builder can replace the file with a recording of the same
length and the app never knows.

```
python3 tools/sound/synth.py --out assets/sound          # 34 feeling sounds + UI paper sounds
python3 tools/sound/voice.py --index seed/voice/index.json --out seed/voice
```

Output: mono OGG/Vorbis 44.1 kHz (via ffmpeg from 16-bit WAV), peak −3 dBFS, ≤ 2.5 s per feeling
sound. `assets/sound/MANIFEST.sound.json` records recipe, parameters, seed; merged into
`assets/MANIFEST.json`.

## Primitives (numpy)

- `press(dur, depth)`: band-limited pink noise with a slow attack and a soft release; a hand on paper.
- `rustle(dur, density)`: sparse crackle grains (2–6 ms) with random band-pass filtering, 1–6 kHz.
- `flick(pitch)`: 8 ms click with a resonant tail (paper edge).
- `tap(hard)`: short impulse through a low-pass (pencil on a desk).
- `scratch(dur, pressure)`: filtered noise with a 30–80 Hz amplitude modulation (biro on paper).
- `crumple(dur)`: dense crackle with rising density then release.
- `tear(dur)`: crackle chain with a slow downward pitch sweep.
- `punch()`: tap + short rustle.
- `peel(dur)`: rising-density crackle with a high-pass sweep (tape or sticker coming off).
- `pour(dur)`: filtered noise with a slow low-pass sweep and a faint ring.
- `breath(dur, in)`: very low pink noise with a long envelope.

## Feeling recipes (`snd_<id>`)

Each recipe places primitives on the feeling's haptic timeline (`docs/FEELINGS.md`) so the sound and
the haptic share one envelope: an `on@amp` segment becomes a primitive at that time with gain ∝
amp/255; `off` is silence. Family tone:

| family | primitives |
|---|---|
| Warmth | press, rustle (low density) |
| Ache | breath, slow page-turn rustle |
| Shelter | press with longer release, tap (soft) |
| Mischief | flick, tap (hard), rustle (high density) |
| Static | scratch, crumple, tear |
| Sparkle | punch, peel, rustle (bright) |

Specific overrides: `snd_tea` = two taps + pour; `snd_snap` = stretch (rising rustle) + flick +
soft tap; `snd_stuck` = eight `tap(hard)`; `snd_notokay` = tear + three taps; `snd_didit` = three
taps rising in pitch + peel; `snd_confetti` = seven punches; `snd_crown` = four rustles rising + peel.

## UI paper sounds (`ui_*`)

`ui_send` (a note sliding off the desk), `ui_land` (a note settling: press + one rustle),
`ui_unfold` (three soft rustles, 1.2 s), `ui_tape` (peel, short), `ui_tear` (tear, 0.4 s),
`ui_page` (page turn), `ui_pencil` (scratch, 0.15 s), `ui_tick` (tap).

## Voice notes (`voice.py`)

For the seed only: a rhythmic vocal-like signal — a glottal pulse train (100–180 Hz, per-person
range: Noor higher, Teo lower) through a slowly wandering two-formant filter, shaped into syllable
bursts (3–5 per second) with pauses, plus faint walking-outside noise for Teo's. Length from
`duration_ms`. The result reads as a muffled voice at a distance, never as words. Each file's
waveform (48 buckets, 0–1) is written to `seed/voice/index.json` for the thread rendering.
