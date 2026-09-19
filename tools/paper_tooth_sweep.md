# The tooth sweep, firing 26 — the numbers behind `albedo_tooth`

Reproduce any row with:

    bash blender/run.sh blender/paper/stocks.py -- --stock <s> --variant 1 \
        --res <r> --samples <n> --condition day --format PNG \
        --border 0.30 0.35 0.72 0.65 --albedo-tooth <k> --out <dir>
    python3 tools/paper_tooth.py --probe <dir> --probe-res <r> --border 0.30 0.35 0.72 0.65

The border is 12.6% of the frame, which is the largest crop that still renders in under a minute
and the smallest that holds eight full 400x200 windows after the draw. Every number below is a
`--border` reading, so it is comparable across rows and NOT comparable with a whole-sheet run.

## 1. `tooth` cannot be turned up. It is a compound knob and the bump half wins.

`rig/common.paper_material` spends `tooth` twice: on the four albedo mottle amplitudes, and on
`bump.inputs["Strength"] = 0.85 * tooth`. Blender's bump strength is meaningful over 0..1. Past
about 1.2 it tilts the shading normal far enough off the surface that the sheet loses light faster
than the mottle adds variance. lined_01, res 3000, samples 24:

| `--tooth-scale` | mean L | L_std | relative |
|---|---|---|---|
| 1.0 | 218.92 | 6.834 | 3.12% |
| 1.5 | 193.94 | 6.141 | 3.17% |
| 2.0 | 173.91 | 6.517 | 3.75% |
| 3.0 | 137.40 | 5.700 | 4.15% |

Relative contrast rises the whole way; the sheet just goes dark faster than it goes toothy. **This
is why five firings could not raise the tooth: the obvious knob does the opposite of what it says.**
The shipped library is not affected — per-stock `tooth` tops out at 1.10, so bump strength tops out
at 0.935 and stays in range. It is the knob that is broken, not the assets.

A ColorRamp clamp was the first hypothesis and it is WRONG, checked directly in Blender 4.5.13:
element colours store 1.09 and 1.3 unclamped.

## 2. `albedo_tooth` is the half that works, and it is clean.

It multiplies only the mottle amplitudes. lined_01, res 3000, samples 24:

| `--albedo-tooth` | mean L | L_std (probe) | OKLab C mean | L p01 | L p99 |
|---|---|---|---|---|---|
| 1.0 | 218.92 | 6.683 | 0.0431 | 182 | 225 |
| 1.5 | 218.92 | 6.837 | 0.0430 | 182 | 226 |
| 2.0 | 218.91 | 7.034 | 0.0429 | 183 | 227 |
| 3.0 | 218.91 | 7.523 | 0.0427 | 182 | 229 |
| 3.75 | 218.91 | 7.975 | 0.0426 | 182 | 230 |
| 5.0 | 218.89 | 8.875 | 0.0424 | 182 | 231 |

Mean luminance is constant to 0.03 of a grey level across a 5x change. Chroma moves -1.6% — nowhere
near a `docs/COLOR.md` §5 ceiling (ground <= 0.09 against 0.043). **The dark end does not move at
all**: p01 is 182 at every k, and only the bright end extends. That is the legibility argument in
one number — the tooth adds no new dark paper for ink to compete with, and `legibility.py` takes its
ground at the 90th percentile of the local window, which rises slightly rather than falling.

Decomposed by feature size (1px = 0.098mm here), the addition is grain and not blotch:

| k | total | >3.9mm | 0.8–3.9mm | <0.8mm |
|---|---|---|---|---|
| 1.0 | 6.834 | 0.606 | 2.361 | 6.384 |
| 3.75 | 8.252 | 0.578 | 2.594 | 7.812 |
| 5.0 | 9.247 | 0.558 | 2.772 | 8.804 |

The coarse band FALLS. Nothing here makes the paper look stained.

## 3. The response is a variance model, and it predicts.

Total variance is `V_other + V_mottle * k^2` — the mottle is one independent contributor on top of
everything else in the window. Fitted on k = 1.0/1.5/2.0/3.0 it gave V_other 43.36, V_mottle 1.48,
and predicted **8.011 at k=3.75**; the render measured **7.975**, 0.45% out. The model is how a
successor can price a k without rendering it.

At the shipped `--res 1800 --samples 48` the model refits per stock, and the samples matter: at
samples 24 a chunk of the measured L_std is Monte Carlo noise, and the same k reads lower once the
render is properly converged. **Everything below is at the shipping settings, through the full
committed chain — LANCZOS to 1500, WEBP q88, bilinear to the 2908px box.**

| stock | k=1.0 | k=5.0 | V_other | V_mottle | k needed for 8.0 |
|---|---|---|---|---|---|
| lined_01 | 6.295 (0/8) | 7.577 (0/8) | 38.89 | 0.741 | **5.82** |
| graph_01 | 8.755 (5/8) | 9.395 (8/8) | 76.17 | 0.484 | already passes |
| receipt_01 | 4.030 (0/8) | 4.827 (1/8) | 15.95 | 0.294 | **12.78** |

## 4. What that says about the 8.0 floor

`V_other` is the whole story and it is not the paper: 76 for a printed grid, 39 for feint rules, 16
for a blank thermal receipt. The floor is dominated by *printed content*, which is why `graph`
clears it untouched and no plain sheet clears it anywhere in the library.

A thermal receipt needs k = 12.8 — mottle amplitudes of roughly ±21% — to read 8.0. A real
thermal receipt is a coated, near-featureless surface; the correct render of one has almost no
tooth. **A floor that asks a receipt to have the surface variance of graph paper is measuring the
wrong thing on that stock**, and this is the strongest evidence yet for reading (b) of the item.

Reading (b) as written — "re-derived against what a photograph of real paper at this magnification
actually measures" — **cannot be executed in this container**: there is no photograph of real paper
in the repository. `seed/photos/*.jpg` are themselves Blender renders out of `blender/photos/`, so
measuring them would be measuring this build's own rig and calling it ground truth. Obtaining a real
photograph is an `asks[]` item, not a queue item.
