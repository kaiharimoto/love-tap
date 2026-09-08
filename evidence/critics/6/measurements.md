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
  And the other three, which the same measure named:
  **obj_dog_ear** (`goodnight`) was a blank card with a 13 mm triangle on it — four per cent of the
  object carrying all of its identity and the other ninety-six a rectangle, box IoU 0.946. It is a
  page torn from a book now, with the ragged edge that is the only silhouette a page has and the
  turned corner lifted a millimetre off the card so it throws its own triangle of shadow: 0.925.
  **obj_bookmark** (`thinking_of_you`) had the lowest internal contrast in the library, 4.3 grey
  levels, because the body and the flap were two plain rectangles and the fold read as a second
  slab. It has the head it was torn from the sheet at, and a rounded spine where the paper turns
  back so the crease catches a highlight instead of ending in a butt edge: box IoU 0.724 -> 0.689.
  I tried folding it as one continuous warped sheet first and that was worse in both directions —
  a smooth ramp with no fold at all, 2.3 grey levels — which is written down here because it is
  the kind of thing that looks like the tidier answer.
  **obj_pinch** (`squeeze`) was a 7.5 mm bump over 4 mm of a 52 mm strip: four millimetres of
  gesture on a slab. The pinch is wider and deeper, the ends lift off the desk, and the two creases
  converge in plan so the waist is in the silhouette and not only in the shading — luminance sd
  15.5 -> 20.0. Its box IoU goes the wrong way (0.809 -> 0.839) because a waisted strip fills more
  of its own bounding rectangle than a straight one does; the silhouette measure is a curvature
  meter and it disagrees with the picture here.
  These six were measured at 10 render samples against the shipped 48, so the internal-contrast
  numbers are not like for like — the silhouette ones are.
  And obj_ticket measures worse than two of the six the critic named, and is not done.
- fold sequence: unfold_thirds stops moving at frame **146** of 240; its noise floor is 0.527 grey
  levels and its gate 1.318. Packed at 147 frames, and what was dropped is in the manifest.
  The first number I wrote here was 208 of 240, and it was wrong: the packer registered a
  sequence's frames by their crop offsets, so the rest detector was differencing a frame against
  one that was not its neighbour and found motion in the difference between two crops. Corrected,
  the sequence is 2.35 s, not 3.34, and the 06 clip makes its four seconds out of two more takes
  rather than out of a longer hold.

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
  frame. jumpTo(index:) per frame, which is a rebuild. Now a pixel scroll, and measured in rows
  built rather than in milliseconds, because milliseconds on a busy machine are not a measurement:
  twenty frames of the fling against a four-hundred-row thread build **17 rows** with six on the
  glass — under one a frame, which is the rows coming into view and nothing else. The same twenty
  frames driven by jumping to an index build **543**. Both taken here, by the new guard test.
- Us: with the year's own 351 module events in the shell's own slot, the old row budget puts the
  dates section 956 pt and the rituals 1142 pt into an 884 pt slot, and the shelf is not built at
  all. The point budget puts all five headings inside it. (Measured by the new guard test, which
  fails on the old layout.)
- projector: the rebuild test loses one row of 7018 on the code of two commits ago.
- 04_moments: the gallery branched on whether an event had a `poster_blob`, and a photograph can
  never have one — the spec is required ['blob','w','h'] and validate() rejects unknown keys — so
  **every photograph went down the video path**: a probe with six photos and one video built one
  BlobImage and six play-mark cards. On the seeded year (115 photos, 14 videos) that is 129 cards
  and no pictures at all. It branches on the type now.
  I wrote in an earlier draft of this sheet that 14 of the year's videos have no poster frame.
  That is wrong and it is corrected here: `seed_loader.dart` puts both blobs and drops the event
  if either is missing, and all 14 posters are on disk. The no-poster row exists because frame
  extraction is not on both platforms yet, not because the year has one.
- the outbox: a refused event was re-pushed every round for ever, and the host never refused
  anything — it dropped what it would not take without answering. Both fixed, with a test.
- the five delivery states. Measured on 13_messenger_states.png: one distinct mark on five rows.
  The ink clusters into five bands 171-172 px wide, and the rightmost 78x48 px of each differ from
  each other by 0.047-0.079 mean absolute — the same double tick five times. Zero refusal marks in
  the frame. The cause was that the staging annotated rather than produced: `markInFlight` changes
  nothing (a pending row already reads `sending` while the link is up) and the sync engine clears
  it in its own `finally`; `markRefused` is cleared by the next round that pushes the same event
  and gets a seq. And the scene's `far read` ran *after* the staging, covering everything.
  Now: the far phone reads first (so what is written after comes back `sent` and everything under
  it is `read`), the host refuses one on request in its own words, and the last message is written
  into a link slowed to six seconds so its push is genuinely in flight when the shutter opens —
  `sending` lasts exactly as long as a push does, which on a loopback is nothing at all.
  `queued` is the one state not staged: it needs the link down, and a frame of a disconnected phone
  would contradict every other artifact. The report says which states were on the glass.

- what a fifth module costs, counted by reading the source: five shared files at cycle 2, two at
  cycle 5, one now (the spine registry, which is a principle — one list validates every payload
  written or taken off the wire). The two that went this cycle were the thread body and the
  sentence, both of which lived in the chat region. Two more per-type switches went with them and
  they were not merely duplicated, they were short: the search page's "found as ..." table named
  **11 of the 18** types, so a thing passed on told the reader `passed on` — its own registry id
  with the underscore taken out — and Moments' "what happened" lens named **4 of the 5** kinds of
  thing that happen, so the shelf appeared in no lens at all. Both read the type's own declaration
  now. `module_costs_test` fails on a table with 'date_event' in it, checked.

## What an adversarial pass over this session's own diff found, and what it measured

Fifteen findings, each put to three refuters with a different lens; none of the fifteen was
refuted by two of three. Six of them were mine, from this session.

- **06 would have failed its own frame check.** I widened the first take from 24 grabs to 40, and
  the only thing moving in it is the arriving note's landing at `Motion.land` = 420 ms — 26 grabs.
  Reproduced end to end by a refuter who rebuilt the seeded PWA and ran the take: 43 frames,
  **16 identical to the one before**, longest still run 15, `ok false`. The 45-grab take after the
  second arrival had the same shape. And the fling take I added had nowhere to go: 06 opens with
  `scrollTo: end` and every arrival re-pins it there, so a forward fling at 1500 px/s has about one
  logical pixel of extent. 06 is now the landing (16), the fold (147), the second landing (16) and
  the second fold (147): 326 frames, 5.22 s, every take as long as the motion in it.
- **`tooth` was measuring the halo the printed rules cast on the paper, not the paper.** The
  high-pass was taken over the whole image and then sampled through a mask that removes the rule's
  own pixels but not the pixels beside it. A refuter replaced the paper of every stock with its own
  box mean, leaving the rules untouched — a sheet with mathematically no tooth — and **35 of 54
  files still passed the floor**. With the mask eroded by the blur radius: graph_01 3.743 -> 0.810
  and its flattened control 0.410; receipt_01 0.580 against 0.016; lined_01 1.388 against 0.276;
  legal_01 1.331 against 0.258. Floors recalibrated to the corrected instrument (0.45 and 3.0).
- Both shading numbers are linear in exposure and both floors were grey levels: receipt_01 at 0.7
  of its light fails both with nothing about the paper changed. They are reported at a reference
  exposure now. And the cut that separates sheet from ground was `body - 20` while its own comment
  said it was relative — 8.6 per cent at body 233, 37 per cent at a quarter of the light, at which
  point the sheet's dark border is inside the cut and field_swing is the sheet edge again.
- **The check passed vacuously on an empty tree**, and capture.sh ran it before the pack that
  builds the tree. A fresh clone would have greenlit the library without opening a file.
- With the instrument corrected, **obj_bookmark measured patch_std 0.913 against a floor of 2.0** —
  the flattest thing in the library, because it was two plates 0.4 mm apart and a plane under a
  soft window light has one value. Curled (the torn head 3 mm off the desk): **16.1**.
- **The list module's sentence knew three words the module has never written.** `ticked`,
  `unticked`, `dropped` against the module's own `added/assigned/done/reopened/removed`: 95 `done`
  and 43 `reopened` events in the seeded year read as their own text with a space in front of it,
  and the thread drew a finished job as an empty pencil box captioned "put down" while Us showed it
  ticked and struck through.
- **The Moments lens read the search facets, so 'happened' became a search term.** Typing it
  returned 81 dates, 53 rituals, 12 shelf cards and 6 milestones as keyword hits beside the 49
  messages in the year that say the word. A lens is its own field now.
- `--skip-existing` in the tear rig looked for a file only the day pass writes, so
  `--conditions dusk` skipped all 56 and the queue recorded "1 of 56" as the job done.
- One finding I looked at and left: the clip's four-second floor now depends on the packer's trim,
  and the guard that used to bound the trim was loosened. It is true and it is reported rather than
  hidden — 06 is 16 + 147 + 16 + 147 = 326 frames, and a fold trimmed to 40 would give 112 frames
  and `frames.py` would say "1.8s is short of 4.0s" on the artifact. A second mechanism tying the
  two numbers together would be a third place for them to disagree.

## What rehearsing 06 against the real far phone found, before the capture

The scene was run end to end against `host_daemon --seed year` and the frames put through
`frames.py`, three times, because the artifact has failed five captures.

- **326 frames, 5.22 s**, and the fold length came from the app (`__deskReport().fold.length` =
  147, twice) rather than from the repo's index.
- **15 isolated held frames, first at 199** — every one of them in the *second* fold of the take
  and none in the first. One `FoldFrames` serves every folded note in the thread and `at()` treated
  any request as the playhead, so an open note (drawing the last frame for as long as it is on the
  glass) and an opening one moved the decode window between the two ends of the sequence. Measured
  on the running app after one fold: `decoded 13, held_from 134, held_to 146` — the far end, while
  the opening note needs the near end. Fixed; the last frame is answered without moving the
  playhead.
- The same rehearsal's console carried `WebGL: INVALID_VALUE: texImage2D: no image` and a null
  check thrown inside a paint: the window was disposing the frame a widget was still holding while
  the next one decoded. Nothing on the glass is disposed now.
- **After both fixes the third rehearsal is clean**: 326 frames, 5.22 s, `ok: true`, **0 repeated
  frames**, 0 brightness jumps, and the scene log's `problems` list is empty — no console error at
  all, where the first two runs carried four. The frame nearest the held-frame test that still
  counts as motion is frame 16 (mean 0.067, busiest tile 4.6 against a floor of 2.0). The last
  frame shows both notes open, with their ink, their hands and their timestamps: the blank letter
  three critics measured is not there.

## The sixth capture, measured

Taken from the artifacts and the records the app wrote at the shutter, on this machine.

- **The composer band, the thing three critics measured at 1.78, 2.19 and 2.22 to one against the
  wood.** WCAG between the 3rd and 97th luminance percentiles of each row of the writing pad on
  13_messenger_states.png: reply banner **8.71:1**, attachment row **4.66:1**, the draft being
  typed **12.45:1**. It is on paper now, and every row of it is over the 4.5 the row asks for.
- **13 carries the whole grammar in one frame**: read 4, sent 1, refused 1 — `it would not go` in
  red — an edit with its caret, a row taken back with no delivery mark on it (a delivery state is
  about writing on its way, and there is none), a reply banner, the attachment row, a draft, and
  `noor writing…`.
- **14_media_viewer**: the viewer's own record says `kind: video, initialised: true, playing:
  true, position_ms: 1530 of 2500`. A video playing, not a poster.
- **04_moments**: three lenses populated at once — 183 media, 154 things that happened, 1340
  feelings — with **26 tiles built** for a viewport onto 183, and **18 pictures asked for and 18
  arrived**. Zero "still fetching".
- **03_us**: all five modules on the desk with their own counts — dates 81, the list 199, calendar
  6, rituals 53, the shelf 12 — each with the line it would tell you at a glance.
- **06_unfolding**: 326 frames, 5.22 s, **zero held frames**, no brightness jump.
  **07_feeling_landing**: 421 frames, zero held frames.
- **The hand**: 273 marks of ink on the hero, twin share **0.147**, best-fit IoU median 0.655 and
  p90 0.866. A font repeats itself exactly; this does not.
- What I could not measure myself: the hairline the completeness pass found (a sliver of paper
  outside a sheet's own edge). My sweep for rows that are mostly desk with a thin bright streak
  cannot tell that from the standing line's own edge — it reports the same rows on every artifact.
  The mask is composed one device pixel in from every side; whether that closed it is for a reader
  with the critic's own method.

## Still open, measured or named
- paper is rendered as WebP at Blender's default quality 92 and then packed, so every downstream
  number is measured against an already-degraded ceiling.
- the world is a constant Background: it carries no direction at all. Halving DAY_SKY_STRENGTH
  would buy as much as the bounce plane did and would change every family at once.
- eight of the feeling objects are flat-lying sheets and stains: no lighting change puts a
  gradient on a plane, and those want different objects.
- 09 and 16 need an Android device; the vibrator is untested; transport is local.
