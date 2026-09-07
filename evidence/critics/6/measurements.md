# Cycle 6 — what was measured, before and after

Taken by me, on this machine, with the tool named. Numbers I did not take myself are marked as
somebody else's.

## The library
- lined_01 ink-free 32px block field, p5-p95: **1.33 -> 5.86** grey levels (range 2.04 -> 7.22).
  Paper cockle scaled to a fraction of the sheet's width. `python3 + PIL`, interior 20-80%.
- paper packing: re-encoding an already-lossy WebP at quality 95 gave 15.44 MB and a high-pass of
  1.144; copying the bytes gives 13.91 MB and 1.194, which is the render's own number. (The
  1.144/1.194 pair is a refuter's measurement, reproduced in outline by the packer's own sizes.)
- desk: packed at 685x1500 from a 1400x3067 render and magnified 2.1x by BoxFit.cover. Now packed
  at its own size; the app draws it at 1.03x. Radial power-spectrum slope measured on the assets:
  desk -2.92, paper -3.03 — the same material. The critic's -3.88 vs -2.53 was the resampling.
- objects: bounce plane two millimetres under the object's own lowest vertex. obj_crumple_ball at
  8 samples: left-to-right 37.6 grey levels, biggest row-to-row step 8.0, no burial line.
- fold sequence: unfold_thirds stops moving at frame 208 of 240; its noise floor is 0.708 grey
  levels. Packed at 209 frames, and what was dropped is in the manifest.

## The hands
- stroke width along a stroke, coefficient of variation over twenty lower-case letters, at
  54 px/em: TeoHand **0.168 -> 0.249**, NoorHand **0.190 -> 0.259** (width_curve, instrumented).
  Measured on the built outlines by the check: TeoHand 0.238, NoorHand 0.313, floor 0.22.
- DeskStamp: built. 155 glyphs in 112.5 s, against 390.3 s for one glyph before the union was
  batched. 216 variants, 0 broken, variants apart min 10.8 / median 16.9.
- NoorHand 'i' and '0' sit at 24.6 and 24.3 against a floor of 26 — five per cent under, on two
  glyphs of 155, and the builder's own measurement of the same pair is over 40. Recorded.

## The app
- composer band, WCAG between the 3rd and 97th luminance percentiles on 13_messenger_states.png:
  **1.76 to 2.22** across its height (reproduced; the critic said 1.78/2.19/2.22). It is on paper
  now — to be re-measured on the new artifact.
- scroll: build p50 20 ms, p95 1426, max 1785 against a raster of 166-212, spikes every third
  frame. jumpTo(index:) per frame, which is a rebuild. Now a pixel scroll — to be re-measured.
- Us: with the year's own 351 module events in the shell's own slot, the old row budget puts the
  dates section 956 pt and the rituals 1142 pt into an 884 pt slot, and the shelf is not built at
  all. The point budget puts all five headings inside it. (Measured by the new guard test, which
  fails on the old layout.)
- projector: the rebuild test loses one row of 7018 on the code of two commits ago.
- 04_moments: 14 of the seeded year's videos have no poster frame; those tiles asked for no
  picture and drew nothing. Now drawn as what a video is.
- the outbox: a refused event was re-pushed every round for ever, and the host never refused
  anything — it dropped what it would not take without answering. Both fixed, with a test.

## Still open, measured or named
- paper is rendered as WebP at Blender's default quality 92 and then packed, so every downstream
  number is measured against an already-degraded ceiling.
- the world is a constant Background: it carries no direction at all. Halving DAY_SKY_STRENGTH
  would buy as much as the bounce plane did and would change every family at once.
- eight of the feeling objects are flat-lying sheets and stains: no lighting change puts a
  gradient on a plane, and those want different objects.
- a module's renderer bodies still live in the chat region.
- 09 and 16 need an Android device; the vibrator is untested; transport is local.
