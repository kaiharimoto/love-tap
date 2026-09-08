# Cycle 7 — what was measured, before and after

Taken by me, on this machine, with the tool named. Numbers I did not take myself are marked as
somebody else's. Written as the work is done, before any cycle-7 critic has run.

## What cycle 6's reports said, and what was done about each

### The pale rule on the wood: five cycles, six hypotheses, still open
Nine of ten stills carry one-pixel bright rules across the wood, up to +48 grey and 440 px long.
This is the honest state of it, because five of the six explanations tried have been mine.

**Ruled out, by measurement, this session:**
- *the desk asset* — the render carries **zero** one-row spikes at any threshold I tried, and
  resampling it by nearest, bilinear, bicubic or Lanczos to the size the app draws it at produces
  none either;
- *the baked contact shadows* — none carries a one-row spike, using the test the artifact actually
  shows (a row brighter than **both** neighbours). A looser test — a row differing from their mean
  — flags 51 of 56, but every one of those is a steep edge of the shadow itself, and that looser
  test is what sent me at the denoiser;
- *the denoiser* — the shadow pass renders without it now, at four times the samples, and the
  rules are unchanged. Kept on its own merits; **it was not the cause**, and the commit that made
  it said otherwise;
- *the piece's bounding box* and *the mask inset* — fixed in earlier cycles, and the rules survived
  both;
- *an unfiltered rotation* — `Transform.rotate` now passes `filterQuality`, and the rules survived
  that too. One still came back with a longer one than before.

**What is known about it.** On the hero the rules step one row down for every ~170 px along: a
slope of 0.006 radians, which is exactly the tilt `Slip` gives a piece, and the strip it sits under
is tilted -0.006. They lie just outside the paper, where the tear's own fibres are feathered. So it
is a piece's own edge, one device pixel of it, drawn where the paper is only a few per cent opaque.

**And the lead for next cycle.** A widget-test rasterisation of the same drawing at device pixel
ratio one *and* three, over a flat desk, produces **no such row at all** — 0 px of 1140, with and
without the change I tried. Whatever makes it is something CanvasKit does in the browser and the
test binding does not. Two things I tried and reverted rather than ship unverified: masking the lit
edge a second time by the same mask, and a bilinear sampler on the baked shadow. The first is a
real cost per note per frame and the second I kept, because bilinear is the cheaper and safer
sampler for an image that is only ever stretched — with a comment saying plainly that it is not the
explanation.

### The fold, on all four of its blocking measurements
- silhouette: the settled sheet's left edge had **0.00 px** of deviation over 320 rows against
  22-35 on the notes beside it. The sheet is torn now — the boundary bites inward on two runs at
  once, one about a finger's width and one about a fibre bundle's: **1.17 px** on the left and
  **1.75** on the top, measured the way a critic separates paper from wood.
- shading: the face was a one-dimensional gradient, per-row standard deviation across the width
  1.50 grey. Cockled now: **3.12 -> 4.87** grey levels of lateral variation in render space.
- shadow: composited over the app's own desk it went to 23 grey against a desk at 80 — "a hard
  slab, not a contact shadow". The rendered alpha is the true occlusion (0.70 of the light) and
  the desk a note lies on is lit by more than the sun this rig models, so it is scaled to the
  ceiling the app's own baked shadows are drawn at: **23 -> 45 grey**.
- and the cockle is lifted so it never dips below the shadow catcher. At 0.45 mm it went under the
  plane, and a shadow catcher is invisible to the camera, so the settled sheet came back as a grid
  of twenty black holes in the cockle's own pattern. That is written down because it looked like a
  material change and was a rendering mistake.

### The module cards
"0.00 to 0.81 px of edge roughness on all four sides, one exactly 673x164 with 0.00 on every side."
There was already a cut outline; it moved the four corners and drew straight lines between them,
which is a quadrilateral with wobbly corners. Each edge is walked now. Measured by rasterising a
card and finding its bottom edge to a fraction of a pixel, then removing the line it runs on:
**0.030 px of wander over 536 columns before, 0.269 after**.

### The desk's grain, and where I disagree
"All of its texture is one-directional bands: mean absolute horizontal gradient 5.58x the vertical
one, where paper measures 0.52." Two things were missing and are there now — the open pores of a
ring-porous hardwood, which the saw cuts along the grain, and any break-up of the fibre along its
own length. On the grain map that moves a lot: the face was **8.08** times more variable across
than along and is **3.94**, the fibre map alone 91 to 6.6.

**On the render it moves almost nothing: 5.23 to 5.18**, measured the critic's way, on eighty
64-pixel windows of bare desk. I tried the two levers that could move it further — a stronger ray
fleck and a stronger fibre — and predicted both on the albedo before spending a render: 5.53 as
shipped, 5.28 with the fleck at half again, 5.75 with the fibre. Nothing reaches paper's 0.63
without weakening the growth rings, and the growth rings are what make it read as oak. A quartered
board is directional by construction and a sheet of paper is not, so I do not think the comparison
to paper is a defect to close. What was a defect, and is fixed, is that the ray fleck was a
Gaussian one to three pixels across with hard ends — a scratch, not a fleck. It is a lens now,
three to seven across, fading at both ends and both sides, and there are fewer of them.

### The scroll's build spikes
The completeness pass established these are periodic on the wall clock at 20.4 s — the sync
engine's long poll — not in app time, and that the capture oversamples anything real-time about
111 times. So it was never scroll jank. What it is instead: the transport set its status on every
successful request, and the only thing that had changed was the time of the last contact, which
nothing draws. The scope listens to that stream and every region under it rebuilds, so a year-deep
thread was rebuilt every twenty seconds for nothing. Six polls that carry nothing now say nothing.

### The messenger's three blocking findings
- the media viewer had no play, no pause, no scrubber, no duration and nothing saying it was a
  video. It has a film strip: the same marks the voice note uses, a pencil rule with the played
  part inked in and a tick at the playhead, the times in the margin hand, seek on tap or drag.
- search chrome filled 67.1 per cent of the screen with one hit readable. A `Slip` takes the room
  it is given, so each of fifteen tabs took the whole width and the wrap put one on every row.
  Measured on the laid-out page at the size the scene shoots: **66 per cent with three hits, and
  29 per cent with six**. The tab that is chosen stands proud, is stamped in ink rather than
  pencil, and is underlined.
- the record said `sent` for a row with no `sent` in the frame and never recorded `sending`, whose
  word is `going`. One table now, read by the mark that draws a state and the record that reports
  it, and rows that draw no mark are not counted.

### The code row's two "declared and never read"
Every event type declared a notification treatment and a person could set one per type, and nothing
at runtime read either. The service worker is where that question is actually asked — it is what
decides whether a phone in a pocket makes a sound, and it runs when the app does not — so it reads
the answer out of the app's own store: off shows nothing, quiet does not ask to be looked at, and
the quiet hours turn interrupt into quiet. And the worker's per-type word table is gone: the words
live in the registry beside the treatments, the app writes them into its store at startup, and the
worker names one event type — the kind a payload defaults to when it cannot be read.

### The anti-goal row's two
The icon on the home screen and on every arrival banner was the unaltered Flutter logo. It is made
now out of the app's own material: a torn note off the same stock the thread is written on, masked
by one of the same tear masks, on the same desk. And the gold star and the crown — the two objects
in the library that mean *you have earned something* — are out of the recipes, out of assets, and
out of the manifest.

### The vocabulary, playing inside out
"On a phone without amplitude control the whole vocabulary plays inverted." Right, and in the worst
place: a phone with no amplitude control is where the rhythm has to do all the work of telling
thirty-six feelings apart, and there the silences were buzzing. A zero-length wait in front puts it
the right way round; the filled-in amplitudes had the same inversion in the other branch.

### Two scenes that were photographing the wrong moment
- 08: "no partner-state change is ever visible happening" — both state lines were pushed before the
  camera rolled, so the mood already read `restless` in frame one. They are driven inside a frames
  run now, at a named frame, the way an arriving message already was.
- the 300 per cent crops the material row is judged on landed on the composer's placeholder and on
  bare desk. The finder took the densest band of paper and called it the note, and the densest band
  on a chat screen is the sheet you write on. It searches the thread now, and it looked for ink
  that was also paper — a contradiction, since paper_mask says paper is light — so the box never
  moved. The record carries how much ink the crop holds: **0.2373 of it, against nothing before**.

### The renders, as they came back
- **112 contact shadows**, day and dusk, without the denoiser at 96 samples: 1 h 43 m.
- **the fold sequence**, 240 frames, 1 h 07 m, packed to 139. Measured on the packed frames the app
  actually plays: left edge deviation **1.18 px** on the folded packet, **4.39** on the settled
  sheet, against 0.00 before; lateral shading 3.4 to 3.9 grey levels across the sheet.
- **the desk**, day and dusk.
- and `tools/check/fold_inset.py` re-measured where the writing goes on the open sheet, because the
  sheet is torn now and its shadow grades further below it: the paper occupies 0.027/0.014/0.110/
  0.209 of the packed frame, so the inset moved from [0.064, 0.062, 0.148, 0.062] to
  [0.067, 0.064, 0.15, 0.259]. fold.dart has always said to re-run that tool when the rig changes.

## Still open
- **the pale rule on the wood**, above: open, with six explanations ruled out and one lead
- 09 and 16 need an Android device; the vibrator is untested; transport is local.
- the hand still repeats: 8.9 per cent of marks have a near-twin at 0.99 by the critic's method.
- the ink's core darkness varies by 3.52 grey levels — the plate is in the outline, not in the ink.
