# tools/handwriting — SPEC

Builds the three faces in `assets/fonts/` from authored stroke skeletons. Nothing is downloaded.

```
python3 tools/handwriting/build.py --out assets/fonts --preview assets/fonts/previews
```

## Outputs

| file | face | pen model | slant | variants per glyph |
|---|---|---|---|---|
| `NoorHand.ttf` | Noor's hand | ballpoint: thin (0.055 em), ink pooling at stroke starts and sharp direction changes, occasional skip | 12° | 5 |
| `TeoHand.ttf` | Teo's hand | pencil: wide (0.075 em), soft roughened edge, weight rises with pressure, heavy on the baseline | 0° | 5 |
| `DeskStamp.ttf` | stamp / typewriter furniture | stamp: slab strokes, ink spread, misregistration between variants, slightly uneven baseline | 0° | 3 |

Plus `previews/<face>.png` (a pangram, a paragraph, digits) and `assets/fonts/MANIFEST.fonts.json`
(inputs, seed, parameters) merged into `assets/MANIFEST.json` by `tools/manifest.py`.

## Glyph set

Basic Latin printable (U+0020–U+007E), Latin-1 letters with accents used in English/French/Spanish
names (àáâäçèéêëìíîïñòóôöùúûüÿ and capitals), £ € ’ ‘ “ ” … – — • ° × ½, and `.notdef`.

## Skeletons (`skeletons.json`)

One entry per glyph: strokes as ordered lists of points `[x, y, pressure]` in a 1000-unit em, with
`x-height 480`, `cap 720`, `ascender 760`, `descender -220`. Each stroke is a Catmull-Rom path.
Skeletons are hand-neutral single-stroke letterforms; a glyph may carry **structural alternates**
(`"alts"`: e.g. `a` single-storey and double-storey, `g` open loop and closed loop, `e` open loop
and pinched, `t` crossed late, `y` straight tail and looped). Variants must be structurally
different as well as jittered, so at least two of the five variants for a-z use a different alt
or a different stroke order.

## Hand parameters (`hands.json`)

Per face: slant, x-height scale, width scale, baseline wobble amplitude, letter-spacing jitter,
stroke-start overshoot, curve tension, pen model (width, pressure→width curve, pooling, edge noise),
pressure profile (Noor: light with heavy stops; Teo: heavy throughout, heaviest on downstrokes),
rounding (Teo rounder), loop openness (Noor open), t-cross lateness (Noor late).

## Variants and features

For each glyph: variant 0 is the skeleton styled by the hand; variants 1–4 (1–2 for DeskStamp)
re-sample with a seeded RNG (`--seed 20260903`): control-point jitter (±18 units), per-stroke
rotation (±2.5°), pressure-profile jitter, alt selection. The font cycles variants with a
`calt` chain (five classes, standard rotation) and also exposes `ss01`–`ss05` and `rand`. A repeated
letter in running text never shows the same outline twice in a row.

## Outline generation

Stroke path → sampled polyline (≥ 64 samples per stroke) → variable-width offset (width from the
pressure profile through the pen model) → polygon → union of all strokes with `skia-pathops` →
cubic-simplified TrueType quadratic outlines. Ballpoint: add small ink blobs (r ≈ 1.4 × width) at
stroke starts and at turns sharper than 70°. Pencil: perturb the outline with ±1.2 % width noise at
~40 samples per em. Stamp: rectangular slab strokes, outline dilated by ink spread 0.02 em, then
eroded irregularly at the edge; misregister variants by (±6, ±4) units.

## Metrics and spacing

Sidebearings from the outline bounds plus a hand-specific gap (Noor 28, Teo 46, Stamp 90), plus
±12 jitter per variant. Kerning: none. Line gap 1.35 em. Space width 0.32 em (Noor), 0.36 em (Teo),
0.5 em (Stamp). `OS/2`, `hhea`, `post`, `name` filled; family names as above, no vendor URL.

## Tests (`tools/handwriting/test_build.py`)

- every glyph in the set has 5 (3) variants with distinct outlines (Hausdorff distance > 12 units);
- `calt` cycles: shaping "aaaaa" with a HarfBuzz-free shaper stub (fontTools `feaLib` compile +
  a simple GSUB apply in the test) yields five different glyph ids;
- the fonts load in FreeType (via Pillow ImageFont) and render the preview;
- no glyph outline is empty except space.
