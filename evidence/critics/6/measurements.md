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
  **This does not close the hairline.** A reviewer took that apart: over the 1,084,043 pixels that
  are bare desk in both 02_chat and 12_search, 72 per cent agree to within one grey level, and
  02_chat's rows 553-563 match 03_us to within half a level on every row except 556. The line is
  drawn on top of an identical desk in one screenshot and not the other, which rules the asset out.
  It is the paper piece's own bounding box: drawImageNine lands the tear mask flush against the
  edge of the composed texture and the shader samples half a texel outside it, so a sliver of the
  sheet is drawn beyond the sheet. The mask is composed one device pixel in from every side now.
  Two rows in 02_chat, twenty-three in 12_search, four in 03_us — all of them 2 to 12 device pixels
  outside a paper band's edge. To be re-measured on the new artifacts.
- objects: bounce plane two millimetres under the object's own lowest vertex. obj_crumple_ball at
  8 samples: left-to-right 37.6 grey levels, biggest row-to-row step 8.0, no burial line. On the
  first four the queue re-rendered: obj_crane -13.9 and +28.8 at dusk, obj_boat +4.5 and -44.8,
  against the near-zero the whole library read before.
- three of the objects a critic called near-neutral grey geometric forms are different objects now,
  because no lighting change puts a gradient on a plane and the fault was the geometry:
  **obj_plane** (`catch`) was two constant-chord rectangular wings whose union in plan is a
  rectangle — silhouette IoU 0.995 against its own minimum-area rectangle, the highest number in
  the library, where a literal rectangle scores 1.000 and a triangle 0.501. It is a dart now:
  **0.995 -> 0.368**, internal luminance sd 42.6.
  **obj_boat** (`here`) was a rectangular dish with a square card in it called a sail, and a folded
  paper boat has no sail: box IoU **0.902 -> 0.713** (a leaf control scores 0.721), with a hull
  that comes to a point at the prow and the stern and two folded flaps along the gunwales.
  **obj_candle** (`hold`) was `create_cone(radius1=0.010, radius2=0.0095, depth=0.020)` — an
  untapered wax cylinder with a speck on top. Its ellipse IoU barely moves (0.948 -> 0.943) and
  should not: a candle stub is a cylinder. What changed is what the flame did to it — a melted rim
  that has run down one side, a hollow burnt round the wick, the burnt ring — and that is internal
  contrast: luminance sd **30.4 -> 37.9**, saturation 0.113 -> 0.119. Its wax also carried 25 per
  cent transmission, which washed the body from behind and took more than half of the gradient it
  had; wax that thick is not translucent.
  Three more are named and not done: obj_dog_ear (box IoU 0.946, 4 per cent of the object carrying
  all of its identity), obj_bookmark (luminance sd 4.0, the lowest in the library) and obj_pinch
  (box IoU 0.809, a 4 mm pucker on a 52 mm slab). And obj_ticket measures worse than two of the six
  the critic named.
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
