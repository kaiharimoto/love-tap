# CONTINUE

The state handed to the next session. `docs/BRIEF.md` is the mission and wins over this file.
Branch: `claude/new-session-f95s8n`.

## 0. Where it stands

**Cycle 9 scored 82**, from 83 and 85 before it. Three floors of five are met (emotional 17/17,
coherence 13/13, anti-goal 9/9). Messenger is 24 against a floor of 26; material 19 against 22.
Both drops across the last two cycles came from the review sharpening, not the build regressing —
in cycle 9 the completeness pass found *both* blocking findings overstated.

**Cycle 10's fixes are in and its capture has not run.** What follows is what changed and, more
importantly, how it was found, because two of the three biggest fixes this cycle corrected a
diagnosis an earlier cycle had been confident about.

### The scroll: two diagnoses disproved by the instruments built to test them

Three cycles blamed the tear mask being baked per note. A counter put on `SlicedMasks.composed`
read **twelve masks across a fling through 8,075 rows in seven throws** — the baking was gone and
the spikes were not the baking. The next hypothesis, named so it could be killed cleanly, was the
hand fonts' contextual alternates shaping a paragraph per new note;
`the_hands_are_not_what_the_scroll_costs_test` shapes a note of handwriting in **0.074 ms**, three
orders of magnitude short.

What it was, found by shooting the same scene twice against the same build. Alone: 135 rows built
over 300 driven frames, build p50 3 ms and p95 26. In a run where the far phone was up and
syncing, which is how the capture actually runs: **5,028 rows over the same 300 frames**, p95
1,562, 269 frames over 400 ms. `Note.build` opened with `AppScope.of(context)`, which registers a
dependency on an InheritedNotifier, and the spine notifies on every sync round — so every note on
the glass was a listener of every round the other phone answered, and the framework dirtied each
row's own element. Caching the row widget did nothing, because the rebuild was not coming from
above. `AppScope.meOf` reads the one thing a row needs — whose phone this is, a constant for the
life of the app — without subscribing. Twenty frames with a message landing on every one: **595
row builds became 16**.

### The material: three measurements that turned out to be one fault

The tooth spread thin on a wide sheet (2.52 grey levels at the stock's own density, 1.26 on the
large Settings sheet). The same ruled stock at rule pitches from **61.5 to 178.5 device pixels**
across ten stills, a ratio of 2.9. Writing that cannot sit on the lines, 0.33 of a pitch off,
where writing with no relation to the rules would be 0.25.

Every stock is printed at 8.57 pixels to the millimetre and every piece drew its stock at whatever
scale that piece happened to be. **The app did not know how big a millimetre was.** A piece takes
a window of its stock at the stock's own density now, positioned by the seeded patch offset and
clamped so the window lands on paper and on the part of the sheet that is ruled; a piece with more
glass than there is paper falls back to covering, and `paper_at_its_own_size` against
`paper_stretched_to_fit` in the capture record says how many of each were on the glass. The paper
stocks were re-rendered at 1574x2200 so a full-width piece fits inside one.

### And the rest of cycle 10

- The fold **bends** instead of hinging: a 2.2 mm radius band and a flap that keeps turning over
  its own length. The crease measurement the completeness pass used goes from **-0.37 to +1.60 and
  +1.52** grey levels. A taller ridge was tried, measured worse (0.88, 0.62), and put back.
- `common.torn_edge` replaces four two-sine "torn" edges. Self-correlation past the central lobe:
  **0.80 to 0.16-0.34**, with the shape it replaced measured in the same report as a control.
- The hash under every cut card was **a sawtooth** — the low sixteen bits of a linear function of
  the index. Every octave of every outline was built out of a ramp.
- **DeskStamp had no counters.** The tabs read `T● D●` and `M●MENTS` in eight captures. A hole
  turned positive and re-unioned is a disc.
- The last literal fill in lib, the search highlighter, became a pen.
- Nine records that did not exist: what the launch was made of, every ask the app made of a motor
  and what answered, which of five checks a 401 failed, the words the other phone refused in, a
  delivered reply with its parent, the tear library's own straightness, whether the writing is on
  the lines, and what each ambient surface may say.

### And what the twelfth capture was waiting on

Six more, all found by reading cycle 9's own reports back against the code rather than by looking
at a picture.

- **A hole in the desk beside every sheet.** A coherence critic measured 758 pixels under luma 30
  at one chip's right edge in 12_search, minimum 4.3, against a desk reading 84-103 either side of
  it. Two faults in one: the paper's tear is nine-sliced so its fibres keep their rendered size,
  and the baked contact shadow under it was stretched with `BoxFit.fill`, so on a piece far from
  the render's proportions the two no longer coincided — and what came out from under the paper is
  black at alpha 255 over a third of every one of those assets, because that third is meant to be
  occluded. Nine-sliced and tinted to `Shadow.warm` now. `tools/check/holes.py` measures the ring
  from three to twelve pixels outside every sheet and gates on it: **nine of the seventeen stills
  had one**, worst 11,346 pixels in 17_setup_pwa.
- **The long poll may be asked for twice.** `401 GET /v1/events?after=14075&wait=20` in two of
  fifteen scene logs, both of them the long clips, with the client's own sync recording `faults:
  0` in the same file. A browser retries an idempotent GET when the connection closes before the
  first response byte, with the header already on the wire; the nonce cache refused the second
  one. The nonce is spent on writes now — a replayed read re-reads events the caller already
  holds — and every refusal names the device it refused and the pairing it held.
- **The first ten seconds are not blank.** `runApp` is not called until the log is open, and on a
  first launch that is 8.9-10.0 seconds in five scene logs. For all of it the page was a flat
  `#4C3E32` rectangle, which is why no artifact showed what is on the screen during it: nothing
  was. The page puts the desk out itself now, with one line on a piece of the real stock in the
  real hand and the month count Dart reports as it reads, and takes it away on the frame that
  replaces it.
- **A way back to now, and the day at the top of the glass.** One hard fling covers 1.2 to 3.1 per
  cent of an 8,075-row thread and there was no scrollbar, no date rail and no way back. Two slips
  now: the day the top row belongs to, and a torn tab saying `back to now` with how far up in the
  units somebody says out loud. Both read from the list's own item positions through a
  `ValueNotifier` with an `==` that compares what would be *written*, so a fling rebuilds two small
  widgets and not eight thousand rows.
- **A reply that has landed.** Every capture carried `replying_to` — the composer's pending target
  — and no artifact ever showed a delivered reply tied to its parent. 13 stages one through the
  composer now, and four answers in the seed that genuinely reach back past what came between them
  were tied (`k:` keys, 2026-08 and 2026-09), because the last four months of the authored year
  had no reply in them and every scene opens at the end of it.
- **The video advancing.** 14 is a still and the set holds exactly seventeen artifacts, so the
  scene grabs 48 of its own frames and they are folded into `crops/14_media_viewer_strip.png` and
  the frame record — not an eighteenth artifact.

### And two the capture itself found, fourteen minutes in

The twelfth capture was stopped after five stills because its first artifact carried two faults
worth more than the fourteen minutes.

- **A black quadrilateral behind every feeling object.** The same fault as the paper's contact
  shadows, in the object path, and the same fix. Those renders are RGB 0,0,0 through their alpha
  with an opaque core nearly the object's own silhouette — `obj_dog_ear_shadow` is 17.4 per cent
  alpha above 240 against the object's 18.7 — so wherever the packed offset puts the core beside
  the thing instead of under it, black lands on the desk. On 01_pulse's object row it reads as a
  hole cut in the wood behind a torn card.
- **A drawn feeling was six translucent rectangles.** Every stroke composited separately at under
  full alpha, so a crossing carried two and came out 46 grey levels darker than the ink; and the
  wobble was one offset per named point, so `obj_window` — six strokes of two points each — drew
  dead straight and uniform. The whole mark goes into one layer now, and a stroke is walked at
  about a pen's width a step with two slow terms and the ends pinned. Four built-ins are drawn
  marks rather than rendered props (`obj_window`, `obj_chair`, `obj_scribble`, `obj_thumbprint`)
  and every critic so far has assumed all thirty-four were props.

**The paper half of the shadow fix is confirmed on the artifacts that run did take.** Pixels darker
than ink in the ring beside a sheet: 02_chat 4,070 → 0, 03_us 3,896 → 0, 12_search 10,995 → 0,
04_moments 2,071 → 0, and the darkest pixel beside a sheet from 5.3–17.3 up to 34.7–48.3.
`paper_at_its_own_size` reads 222 against 3 stretched.

### And two the twelfth capture found in its own clips

- **The folded note's landing does not move under the driven clock.** Scene 06 grabs sixteen frames
  of the note that has just arrived before opening it, and on the frames that capture wrote all
  sixteen are *byte-identical* — mean absolute change 0.0000 between each pair, then 6.68 on the
  frame the unfold starts. The landing is real code (`FoldedNote` wraps its sheet in
  `Settling(duration: Motion.land, curve: Motion.drop)` when `arriving`), the curve moves 2.77
  pixels on its first frame and 17.5 over sixteen, and `awaitArrival` does not step the clock — so
  a frame of it should differ from the one before by more than two grey levels and none of them
  does. Something between `Settling` subscribing to `DrivenClock.ticks` and the note being rebuilt
  is not connected. The scene's pre-roll is one frame now, so the clip has no hole in the front of
  it, and this is written down rather than papered over.
- **Two corners fight over the capture handles.** `FeelingCorner` registered `openCorner`,
  `showFamily`, `holdOver` and `letGo` in `initState` and cleared them unconditionally in
  `dispose`. When the region changes, Flutter builds the new corner before it disposes the old one,
  so the new registration was torn down behind it and the next `__deskOpenCorner` answered `no
  shell`. That is what stopped 15_authored_feeling at its second `goTo`, sixty-six minutes into a
  capture. Whoever mounted last owns them now.

One thing was found on the way and not chased: **a second `AppScope` built inside a second
`testWidgets` in one file never returns.** Reduced to a scratch test that builds one, pumps it,
and does it again — the first case passes in under a second and the second never reaches its first
statement. Every widget test in this build that needs a scope makes it in `setUpAll`, so nothing
had ever asked for two. It is written down in the head of
`app/test/a_year_says_where_you_are_test.dart`.

### Two things measured and deliberately not fixed

Both are in the evidence so the next cycle starts from a number rather than an impression.

1. **Half the tear library is too straight.** Fifty-six masks: min 1.15 px rms, median 2.00,
   28 under 2.0 (`logs/torn.json`). The cause is in `tools/tears/tear.py` — the fracture's Hurst
   exponent runs to 1.15, and 1.15 is a clean pull. The fix is fifty-six masks and their relief
   and their shadows.
2. **The writing is not on the rules**, 0.33 of a pitch off (`logs/lines.json`). Fixing it means
   laying text out against the paper it is drawn on — the pitch, and the phase of the first rule
   under the seeded patch offset — which is a change to every note in the app.

## 4. What is left, in order of what it costs to close

Every number here is a critic's, from `evidence/critics/5/`. Check them before acting on them; two
of the six did not reproduce this cycle and the completeness pass says which.

### 1. ~~The paper is flattened between the library and the glass~~ — it is not (closed, cycle 6)
`surfaces.py`'s `patch_std` is the largest standard deviation among nine 200 px patches of the whole
file, and on a ruled stock every one of those squares contains three or four printed rules at a
55 px pitch. The 9.36-10.28 is a measurement of the ruling. The 1.22 is a median over ink-free 32 px
blocks. Measured the same way at both ends the library reads 1.09-1.49 and the screen 1.24 — they
agree. `BoxFit.cover` does not downscale either: the ruled pitch is 55 px in the asset and 70 on
screen, so the stock is magnified 1.27x. Nothing in `PaperPiece` is averaging anything away.

What was real underneath it, and is fixed: the packer made a second lossy pass over a render that
was already lossy WebP. It copies the bytes when nothing needs doing — 13.91 MB and the render's own
high-pass of 1.194, against 15.44 MB and 1.144 at quality 95.

What is still open: `blender/paper/stocks.py` renders paper as WebP at Blender's default quality 92,
so every number downstream is measured against an already-degraded ceiling. Rendering paper once,
losslessly, and encoding once in the packer would recover more than any quality knob downstream.

`surfaces.json` now reports `tooth` and `field_swing` beside `patch_std`, and says in the record
what `patch_std` is, so this particular confusion cannot be had a second time.

### 2. The light the shadows describe touches nothing else (material)
A note's interior swings 9 to 13 grey levels on 230 across its full width. The 'hold' cylinder on
01_pulse reads 148 on one side of its curve and 153 on the other while throwing a hard directional
shadow. The fold's flap darkens 17 per cent while foreshortening 90. The shadows are baked from
renders and the surfaces they fall on are not, so they read as attached to flat art.

### 3. Nothing pictures a state change reaching somebody who has not opened the app (emotional)
No notification, no lock screen, no home-screen widget, in any of the fifteen artifacts. The ambient
surfaces are recorded as sent in `logs/ambient.json` and never as received.

### 4. The rituals module appears in no artifact (anti-goal, coherence)
It is the one surface the mission itself pairs with the word streaks — the place engagement
machinery would hide, never photographed. 03_us shows three of the five modules its own report
lists, so the Us layout needs more than the row counts it got this cycle.

### 5. 17_setup_pwa.png is 27.3 per cent one exact RGB value (anti-goal)
1,225,541 pixels at zero variance, while every other still sits on wood measuring about 11.

### 6. The frame check is defeated by a one-level dither (evidence)
`frames.json` reports `repeated_frames: 0` while 32 per cent of 06's transitions are visually
identical and the clip is frozen for its last 416 ms. Bit equality is the wrong test; it wants a
perceptual floor.

### 7. Two records say things that are not so (evidence)
Both tailnet records give their direct path as **192.0.2.2**, which is RFC 5737 documentation
space. `reliability.json`'s search capability is an identity map with no hits in it. And
`logs/12_search.report.json` describes the thread behind the search sheet rather than the search.

### 8. The build's own structural claims (code)
A fifth module costs five shared files rather than one line: the registry, the type spec, two
renderer entries and the stock assignment. The passive half of the nervous system has no producer
outside the capture hook and the seed. A host-rejected event is re-pushed forever unmarked, because
the refusal path is unreachable over the wire.

### 9. DeskStamp is still not built (material, coherence)
About five hours on one core here. Start it at the beginning of a session, not the end.

### Not fixable here
09 and 16, as above. The tailnet run is recorded **pending**: no `TS_AUTHKEY` was in this
session's environment, `toolchain/ts/AUTHKEY_STATUS` says `pending`, and the brief says the
question may only be asked from the session in which the Tailscale phase began — which has
happened, so it may not be asked again.

## 5. How to run it

    ./bootstrap.sh                                    # pinned toolchain into ./toolchain
    tools/apt-prereqs.sh                              # and: apt install libevent-2.1-7t64 libwayland-server0
    ./run.sh --seed=year --transport=local
    ./capture.sh                                      # the whole set, about 90 minutes
    ./capture.sh --no-build --only=06_unfolding,08_state_propagating   # a list, against the builds on disk
    cd app && ../toolchain/flutter/bin/flutter test   # 96 tests

`KEEP_FRAMES=yes ./capture.sh` keeps `evidence/frames/` so a clip can be measured frame by frame
after the fact. `python3 tools/check/frames.py evidence/frames/<name> --fps 60` is the check.

**Scoring.** Write your own sheet to `evidence/critics/<cycle>/builder.json` under a `scores` key
*before* reading the critics, then `python3 tools/score.py --cycle <n>`.

**Running the critics.** The Workflow tool, six agents in parallel plus a completeness pass. The
script that ran cycle 3 is worth reusing; it passes each critic its rubric prompt and forbids the
git log, the docs, the task list and any other cycle's reports. Move `evidence/SCORE.json`,
`evidence/critics/<earlier>/` and this cycle's `builder.json` out of `evidence/` while they run.

## 6. Secrets, which are failure conditions

`TS_AUTHKEY`, a CA private key, or a pairing secret in any committed file fails the whole build.
The key is read from the environment and never written down; `toolchain/ts/AUTHKEY_STATUS` holds
only the word `pending` or `supplied`. With no key the tailscale run is recorded **pending** — not
passing, not failing. `ask=TS_AUTHKEY` may appear in the heartbeat only from the session in which
the Tailscale phase begins; that has happened, so it may not appear again.

The host binds its tailnet address or does not start. Spine content travels by no path other than
the Tailscale channel. A Web Push payload carries nothing beyond event kind and sender.

## 7. Outstanding for the user, not for you

Revoke the Tailscale auth key at `login.tailscale.com/admin/settings/keys`, and remove `lovetap-a`
and `lovetap-b` from the admin console — they were not registered ephemeral, so they linger.
